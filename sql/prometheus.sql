CREATE SCHEMA prometheus;

CREATE TYPE prom_sample;

CREATE FUNCTION prom_in(cstring)
    RETURNS prom_sample
    AS '$libdir/pg_prometheus', 'prom_in'
    LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION prom_out(prom_sample)
    RETURNS cstring
    AS '$libdir/pg_prometheus', 'prom_out'
    LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE prom_sample (
   internallength = VARIABLE,
   input = prom_in,
   output = prom_out
);


-- Functions and operators

CREATE FUNCTION to_prom(cstring)
    RETURNS prom_sample
    AS '$libdir/pg_prometheus', 'prom_in'
    LANGUAGE C IMMUTABLE STRICT;


CREATE FUNCTION prom_has_label(prom_sample, text)
    RETURNS bool
    AS '$libdir/pg_prometheus', 'prom_has_label'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR ? (
   leftarg = prom_sample,
   rightarg = text,
   procedure = prom_has_label
);

CREATE FUNCTION prom_label_count(prom_sample)
    RETURNS integer
    AS '$libdir/pg_prometheus', 'prom_label_count'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR # (
   leftarg = prom_sample,
   procedure = prom_label_count
);

CREATE FUNCTION prom_label(prom_sample, text)
    RETURNS text
    AS '$libdir/pg_prometheus', 'prom_label'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR @ (
   leftarg = prom_sample,
   rightarg = text,
   procedure = prom_label
);

CREATE FUNCTION prom_labels(prom_sample, include_name bool)
    RETURNS jsonb
    AS '$libdir/pg_prometheus', 'prom_labels'
    LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION prom_labels(prom_sample)
    RETURNS jsonb
    AS '$libdir/pg_prometheus', 'prom_labels'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR @ (
   leftarg = prom_sample,
   procedure = prom_labels
);

CREATE FUNCTION prom_name(prom_sample)
    RETURNS text
    AS '$libdir/pg_prometheus', 'prom_name'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR | (
   leftarg = prom_sample,
   procedure = prom_name
);

CREATE FUNCTION prom_time(prom_sample)
    RETURNS timestamptz
    AS '$libdir/pg_prometheus', 'prom_time'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR ! (
   leftarg = prom_sample,
   procedure = prom_time
);

CREATE FUNCTION prom_value(prom_sample)
    RETURNS float8
    AS '$libdir/pg_prometheus', 'prom_value'
    LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR -> (
   leftarg = prom_sample,
   procedure = prom_value
);


-- JSONB functions
CREATE FUNCTION prom_jsonb(prom_sample)
    RETURNS jsonb
    AS '$libdir/pg_prometheus', 'prom_jsonb'
    LANGUAGE C IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION prometheus.insert_metric()
    RETURNS TRIGGER LANGUAGE PLPGSQL AS
$BODY$
DECLARE
    target_table        NAME;
    target_labels_table NAME;
    metric_labels_id    INTEGER;
    metric_labels       JSONB = prom_labels(NEW.sample);
    keep_samples        BOOL = true;
BEGIN

    IF TG_NARGS < 1 THEN
        RAISE EXCEPTION 'No target table in insert trigger';
    ELSE
        target_table := TG_ARGV[0];
    END IF;

    IF TG_NARGS > 1 THEN
        target_labels_table := TG_ARGV[1];
    ELSE
        target_labels_table := format('%I_labels', target_table);
    END IF;

    IF TG_NARGS > 2 THEN
        keep_samples := TG_ARGV[2];
    END IF;

    -- Insert labels
    EXECUTE format('SELECT id FROM %I l WHERE %L = l.labels',
            target_labels_table, metric_labels) INTO metric_labels_id;

    IF metric_labels_id IS NULL THEN
        EXECUTE format(
            $$
            INSERT INTO %I (metric_name, labels) VALUES (%L, %L) RETURNING id
            $$,
            target_labels_table,
            prom_name(NEW.sample),
            metric_labels
        ) INTO STRICT metric_labels_id;
    END IF;

    EXECUTE format('INSERT INTO %I (time, value, labels_id) VALUES (%L, %L, %L)',
            target_table, prom_time(NEW.sample), prom_value(NEW.sample), metric_labels_id);

    IF keep_samples THEN
       RETURN NEW;
    END IF;

    RETURN NULL;
END
$BODY$;

CREATE OR REPLACE FUNCTION create_prometheus_table(
       table_name NAME,
       metrics_table_name NAME = NULL,
       metrics_labels_table_name NAME = NULL,
       normalized_tables BOOL = TRUE,
       keep_samples BOOL = TRUE
)
    RETURNS VOID LANGUAGE PLPGSQL VOLATILE AS
$BODY$
DECLARE
    timescaledb_ext_relid OID = NULL;
BEGIN
    SELECT oid FROM pg_extension
    WHERE extname = 'timescaledb'
    INTO timescaledb_ext_relid;

    IF table_name IS NULL THEN
       RAISE EXCEPTION 'Invalid table name';
    END IF;

    IF metrics_table_name IS NULL THEN
       metrics_table_name := format('%I_metrics', table_name);
    END IF;

    IF metrics_labels_table_name IS NULL THEN
       metrics_labels_table_name := format('%I_labels', metrics_table_name);
    END IF;

    EXECUTE format(
        $$
        CREATE TABLE %I (sample prom_sample NOT NULL)
        $$,
        table_name
    );

    IF normalized_tables THEN
        -- Create labels table
        EXECUTE format(
            $$
            CREATE TABLE %I (
                  id SERIAL PRIMARY KEY,
                  metric_name TEXT NOT NULL,
                  labels jsonb,
                  UNIQUE(metric_name, labels)
            )
            $$,
            metrics_labels_table_name
        );
        -- Add a GIN index on labels
        EXECUTE format(
            $$
            CREATE INDEX %I_idx ON %1$I USING GIN (labels)
            $$,
            metrics_labels_table_name
        );

        -- Create samples table
        EXECUTE format(
            $$
            CREATE TABLE %I (time TIMESTAMPTZ, value FLOAT8, labels_id INTEGER REFERENCES %I(id))
            $$,
            metrics_table_name,
            metrics_labels_table_name
        );

        -- Create time column index
        EXECUTE format(
            $$
            CREATE INDEX %I_time_idx ON %1$I USING BTREE (time)
            $$,
            metrics_table_name
        );

        -- Create labels ID column index
        EXECUTE format(
            $$
            CREATE INDEX %I_label_id_idx ON %1$I USING BTREE (labels_id)
            $$,
            metrics_table_name
        );

        -- Create a trigger to redirect samples into normalized tables
        EXECUTE format(
            $$
            CREATE TRIGGER insert_trigger BEFORE INSERT ON %I
            FOR EACH ROW EXECUTE PROCEDURE prometheus.insert_metric(%I, %I, %L)
            $$,
            table_name,
            metrics_table_name,
            metrics_labels_table_name,
            keep_samples
        );
    ELSE
        -- Create labels index on raw samples table
        EXECUTE format(
            $$
            CREATE INDEX %I_labels_idx ON %1$I USING GIN (prom_labels(sample))
            $$,
            table_name
        );

        -- Create time index on raw samples table
        EXECUTE format(
            $$
            CREATE INDEX %I_time_idx ON %1$I USING BTREE (prom_time(sample))
            $$,
            table_name
        );
    END IF;

    IF timescaledb_ext_relid IS NOT NULL THEN
        PERFORM create_hypertable(metrics_table_name::regclass, 'time');
    END IF;
END
$BODY$;
