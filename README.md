# Prometheus metrics for PostgreSQL

`pg_prometheus` is an extension for PostgreSQL that defines a
Prometheus metric samples data type. This allows seamless import of
metrics in the
[Prometheus exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/)
(currently, only text is supported). Given a service with a `/metrics`
endpoint exposing Prometheus metrics, one can import metrics to the
`input` table with the following command:

```bash
curl http://localhost:8080/metrics | grep -v "^#" | psql -h localhost -U postgres -p 5432 -c "COPY metrics FROM STDIN"
```

The only configuration necessary is to first create the extension and
`metrics` table:

```SQL
CREATE TABLE metrics (sample prom_sample);
```

## Installation

If installing from source, do:

```bash
make 
make install # Might require super user permissions
```

Then restart PostgreSQL and create the extension in the `psql` CLI:

```SQL
CREATE EXTENSION pg_prometheus;
```

## Querying and indexing

A Prometheus sample table can be indexed for better query performance.

```SQL
-- Add time index
CREATE INDEX metrics_time_idx ON metrics USING (prom_time(sample));

-- Add labels index
CREATE INDEX metrics_labels_idx ON metrics USING GIN (prom_labels(sample));
```

It's then possible to do performant queries, such as:

```SQL
SELECT prom_time(sample), prom_value(sample) FROM metrics 
WHERE prom_time(sample) > NOW() - interval '10 min' AND
      prom_name(sample) = 'cpu_usage' AND
      prom_labels(sample) @> '{ "service": "nginx"}';
```

## Metrics normalization

Alternatively, metric samples can be normalized into more traditional
tables using native PostgreSQL data types. Instead of creating the metrics
table directly, do:

```SQL
SELECT create_prometheus_table('input', 'metrics');
```

This creates one `input` table holding the raw Prometheus metric
samples, and one `metrics` table with the following schema:

```SQL
  Column   |           Type           | Modifiers
-----------+--------------------------+-----------
 time      | timestamp with time zone |
 value     | double precision         |
 labels_id | integer                  |
 ```

Labels will be stored in a companion table called `metrics_labels`:

```SQL
Column |  Type   |                          Modifiers
--------+---------+-------------------------------------------------------------
 id     | integer | not null default nextval('metrics_labels_id_seq'::regclass)
 labels | jsonb   | not null
 ```

The incoming metrics should now be directed to the `input` table. A
trigger on the `input` table will normalize the Prometheus metric
samples written to the `input` table and insert it into `metrics` and
`metrics_labels`.

Optionally, one can choose to throw away the original Prometheus
sample data (i.e., the raw samples will not be stored in the `input`
table, only in `metrics`). In that case, the tables should be created
as follows:

```SQL
SELECT create_prometheus_table('input', 'metrics', keep_samples => false);
```
