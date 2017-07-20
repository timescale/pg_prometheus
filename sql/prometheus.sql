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

CREATE FUNCTION prom_construct(TIMESTAMPTZ, TEXT, double precision, jsonb)
    RETURNS prom_sample
    AS '$libdir/pg_prometheus', 'prom_construct'
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

CREATE OR REPLACE FUNCTION prometheus.insert_view_normal()
    RETURNS TRIGGER LANGUAGE PLPGSQL AS
$BODY$
DECLARE
    metric_labels     JSONB = prom_labels(NEW.sample);
    metric_labels_id  INTEGER;
    labels_table      NAME;
    values_table      NAME;
BEGIN
    IF TG_NARGS != 2 THEN
        RAISE EXCEPTION 'insert_view_normal requires 2 parameters';
    END IF;

    values_table := TG_ARGV[0];
    labels_table := TG_ARGV[1];

    -- Insert labels
    EXECUTE format('SELECT id FROM %I l WHERE %L = l.labels AND %L = l.metric_name',
          labels_table, metric_labels, prom_name(NEW.sample)) INTO metric_labels_id;

    IF metric_labels_id IS NULL THEN
      EXECUTE format(
          $$
          INSERT INTO %I (metric_name, labels) VALUES (%L, %L) RETURNING id
          $$,
          labels_table,
          prom_name(NEW.sample),
          metric_labels
      ) INTO STRICT metric_labels_id;
    END IF;

    EXECUTE format('INSERT INTO %I (time, value, labels_id) VALUES (%L, %L, %L)',
          values_table, prom_time(NEW.sample), prom_value(NEW.sample), metric_labels_id);

    RETURN NULL;
END
$BODY$;

CREATE OR REPLACE FUNCTION prometheus.insert_view_sample()
    RETURNS TRIGGER LANGUAGE PLPGSQL AS
$BODY$
DECLARE
    sample_table      NAME;
BEGIN
    IF TG_NARGS != 1 THEN
        RAISE EXCEPTION 'insert_view_normal requires 2 parameters';
    END IF;

    sample_table := TG_ARGV[0];

    EXECUTE format('INSERT INTO %I (sample) VALUES (%L)',
          sample_table, NEW.sample);

    RETURN NULL;
END
$BODY$;


CREATE OR REPLACE FUNCTION create_prometheus_table(
       metrics_view_name NAME,
       metrics_values_table_name NAME = NULL,
       metrics_labels_table_name NAME = NULL,
       metrics_samples_table_name NAME = NULL,
       metrics_copy_table_name NAME = NULL,
       normalized_tables BOOL = TRUE,
       use_timescaledb BOOL = NULL,
       chunk_time_interval INTERVAL = interval '1 day'
)
    RETURNS VOID LANGUAGE PLPGSQL VOLATILE AS
$BODY$
DECLARE
    timescaledb_ext_relid OID = NULL;
BEGIN
    SELECT oid FROM pg_extension
    WHERE extname = 'timescaledb'
    INTO timescaledb_ext_relid;

    IF use_timescaledb IS NULL THEN
      IF timescaledb_ext_relid IS NULL THEN
        use_timescaledb := FALSE;
      ELSE
        use_timescaledb := TRUE;
      END IF;
    END IF;

    IF use_timescaledb AND  timescaledb_ext_relid IS NULL THEN
      RAISE 'TimescaleDB not installed';
    END IF;

    IF metrics_view_name IS NULL THEN
       RAISE EXCEPTION 'Invalid table name';
    END IF;

    IF metrics_values_table_name IS NULL THEN
       metrics_values_table_name := format('%I_values', metrics_view_name);
    END IF;

    IF metrics_labels_table_name IS NULL THEN
       metrics_labels_table_name := format('%I_labels', metrics_view_name);
    END IF;

    IF metrics_samples_table_name IS NULL THEN
       metrics_samples_table_name := format('%I_samples', metrics_view_name);
    END IF;

    IF metrics_copy_table_name IS NULL THEN
       metrics_copy_table_name := format('%I_copy', metrics_view_name);
    END IF;



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
            CREATE INDEX %I_labels_idx ON %1$I USING GIN (labels)
            $$,
            metrics_labels_table_name
        );

         -- Add a index on metric name
        EXECUTE format(
            $$
            CREATE INDEX %I_metric_name_idx ON %1$I USING BTREE (metric_name)
            $$,
            metrics_labels_table_name
        );

        EXECUTE format(
          $$
          CREATE TABLE %I (sample prom_sample NOT NULL)
          $$,
          metrics_copy_table_name
        );

        -- Create normalized metrics table
        IF use_timescaledb THEN
          --does not support foreign  references
          EXECUTE format(
              $$
              CREATE TABLE %I (time TIMESTAMPTZ, value FLOAT8, labels_id INTEGER)
              $$,
              metrics_values_table_name
          );
        ELSE
          EXECUTE format(
              $$
              CREATE TABLE %I (time TIMESTAMPTZ, value FLOAT8, labels_id INTEGER REFERENCES %I(id))
              $$,
              metrics_values_table_name,
              metrics_labels_table_name
          );
        END IF;

        -- Make metrics table a hypertable if the TimescaleDB extension is present
        IF use_timescaledb THEN
           PERFORM create_hypertable(metrics_values_table_name::regclass, 'time',
                   chunk_time_interval => _timescaledb_internal.interval_to_usec(chunk_time_interval));
        END IF;

        -- Create labels ID column index
        EXECUTE format(
            $$
            CREATE INDEX %I_labels_id_idx ON %1$I USING BTREE (labels_id, time desc)
            $$,
            metrics_values_table_name
        );

        -- Create a view for the metrics
        EXECUTE format(
            $$
            CREATE VIEW %I AS 
            SELECT prom_construct(m.time, l.metric_name, m.value, l.labels) AS sample,
                   m.time AS time, l.metric_name AS name,  m.value AS value, l.labels AS labels
            FROM %I AS m
            INNER JOIN %I l ON (m.labels_id = l.id)
            $$,
            metrics_view_name,
            metrics_values_table_name,
            metrics_labels_table_name
        );

        EXECUTE format(
            $$
            CREATE TRIGGER insert_trigger INSTEAD OF INSERT ON %I
            FOR EACH ROW EXECUTE PROCEDURE prometheus.insert_view_normal(%L, %L)
            $$,
            metrics_view_name,
            metrics_values_table_name,
            metrics_labels_table_name
        );

        EXECUTE format(
            $$
            CREATE TRIGGER insert_trigger BEFORE INSERT ON %I
            FOR EACH ROW EXECUTE PROCEDURE prometheus.insert_view_normal(%L, %L)
            $$,
            metrics_copy_table_name,
            metrics_values_table_name,
            metrics_labels_table_name
        );


    ELSE
        EXECUTE format(
          $$
          CREATE TABLE %I (sample prom_sample NOT NULL)
          $$,
          metrics_samples_table_name
        );

        -- Create labels index on raw samples table
        EXECUTE format(
            $$
            CREATE INDEX %I_labels_idx ON %1$I USING GIN (prom_labels(sample))
            $$,
            metrics_samples_table_name
        );

        -- Create time index on raw samples table
        EXECUTE format(
            $$
            CREATE INDEX %I_time_idx ON %1$I USING BTREE (prom_time(sample))
            $$,
            metrics_samples_table_name
        );

        -- Create a view for the metrics
        EXECUTE format(
            $$
            CREATE VIEW %I AS 
            SELECT sample AS sample, prom_time(sample) AS time, prom_name(sample) AS name, prom_value(sample) AS value, prom_labels(sample) AS labels
            FROM %I
            $$,
            metrics_view_name,
            metrics_samples_table_name
        );

        EXECUTE format(
            $$
            CREATE TRIGGER insert_trigger INSTEAD OF INSERT ON %I
            FOR EACH ROW EXECUTE PROCEDURE prometheus.insert_view_sample(%L)
            $$,
            metrics_view_name,
            metrics_samples_table_name
        );

    END IF;

END
$BODY$;
