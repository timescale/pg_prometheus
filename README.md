# Prometheus metrics for PostgreSQL

`pg_prometheus` is an extension for PostgreSQL that defines a
Prometheus metric samples data type and provides several storage formats
for storing Prometheus data. 

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

##  Integrating with Prometheus

For quickly connect prometheus to pg_prometheus simply 
connect the [Prometheus PostgreSQL adapter](https://github.com/prometheus-adapter) to a
database that has pg_prometheus installed.

For more technical details, or to use pg_prometheus without prometheus, read below.


## Creating the Prometheus tables.

To create the appropriate Prometheus tables use:
```SQL
SELECT create_prometheus_table('metrics');
```

This will create a `metrics` table for inserting data in the Prometheus exposition format
using the Prometheus data type (see below). It will also create
a `metrics_view` to easily query data.

Other supporting tables may also be created depending on the storage format (see
below).

## Inserting data

With either storage format, data can be inserted in Prometheus format into the
main table (e.g. `metrics` in our running example). Data should be formatted
according to the Prometheus exposition format.

```SQL
INSERT INTO metrics VALUES ('cpu_usage{service="nginx",host="machine1"} 34.6 1494595898000');
```

Since `metrics` is a view, and PostgreSQL does not allow `COPY` to views, we
create a specialized table to be the target of copy commands for normalized
tables (raw tables could write directly to the underlying `_sample` table).
By default, copy tables have a `_copy` suffix.

One interesting usage is to scrape a Prometheus endpoint directly:

```bash
curl http://localhost:8080/metrics | grep -v "^#" | psql -h localhost -U postgres -p 5432 -c "COPY metrics_copy FROM STDIN
```

## Querying data

Pg prometheus creates a view with the `_view` suffix (e.g. `metrics_view`). It has
the following schema:

```SQL
  Column |           Type           | Modifiers
 --------+--------------------------+-----------
  time   | timestamp with time zone |
  name   | text                     |
  value  | double precision         |
  labels | jsonb                    |
```

An example query over that view would be 
```SQL
SELECT time, value
FROM metrics_view
WHERE time > NOW() - interval '10 min' AND
      name = 'cpu_usage' AND
      labels @> '{ "service": "nginx"}';
```

## Storage formats

Pg_prometheus allows two main ways of storing Prometheus metrics: raw and
normalized (the default). With raw, a table simply stores all the Prometheus samples as the
prom_sample data type in a single column.  The normalized storage format
separates out the labels into a separate table. The advantage of the normalized
format is disk space savings when labels are long and repetitive.

Note that the `metrics` table used for inserting data and `metrics_view` table
used to query data is created regardless of the storage format and serves to
hide the underlying storage from the user.

### Raw format

In raw format, data is stored in a table with one column of type `prom_sample`.
To define a raw table use pass `normalized_tables=>false` to `create_prometheus_table`.
This will also create appropriate indexes on the raw table.

### Normalized format

In the normalized format, data is stored in two tables. The `values` table
holds the data values with a foreign key to the labels. It has the following schema:

```SQL
  Column   |           Type           | Modifiers
-----------+--------------------------+-----------
 time      | timestamp with time zone |
 value     | double precision         |
 labels_id | integer                  |
```

Labels are stored in a companion table called `labels`
(note that `metric_name` is its own columns since it is always
present):

```SQL
   Column    |  Type   |                          Modifiers                          
-------------+---------+-------------------------------------------------------------
 id          | integer | not null default nextval('metrics_labels_id_seq'::regclass)
 metric_name | text    | not null
 labels      | jsonb   | 
```

## Prometheus data type 

The Prometheus data type allow seamless import of metrics in the [Prometheus exposition
format](https://prometheus.io/docs/instrumenting/exposition_formats/)
(currently, only text is supported). Given a service with a `/metrics` endpoint
exposing Prometheus metrics, one can import metrics to the `input` table with
the following command:

```bash
curl http://localhost:8080/metrics | grep -v "^#" | psql -h localhost -U postgres -p 5432 -c "COPY metrics_copy FROM STDIN"
```

## Use with TimescaleDB

[TimescaleDB](http://www.timescale.com/) allows PostgresSQL to better scale for
time-series data (of which metrics is an example). To enable timescale, simply
install TimescaleDB! By default, pg_prometheus will use TimescaleDB if it is
installed. You can explicitly control whether or not to use TimescaleDB with the
`use_timescaledb` parameter to `create_prometheus_table`.

For example, the following will force pg_prometheus to use Timescale (and will
error out if it isn't installed):
```SQL
SELECT create_prometheus_table('metrics', 'use_timescaledb'=>true);
```
