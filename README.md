# Prometheus metrics for PostgreSQL

`pg_prometheus` is an extension for PostgreSQL that defines a
Prometheus metric samples data type and provides several storage formats
for storing Prometheus data.

Related packages to install:
- [Prometheus remote storage adaptor](https://github.com/timescale/prometheus-postgresql-adapter) (required)
- [TimescaleDB](https://github.com/timescale/timescaledb) (optional
for better performance and scalability)

## Running from Docker

A PostgreSQL docker image with both pg_prometheus and TimescaleDB installed is
available in Docker Hub at [timescale/pg_prometheus](https://hub.docker.com/r/timescale/pg_prometheus/).

Example usage:
```
docker run --name pg_prometheus -d -p 5432:5432 timescale/pg_prometheus:master postgres \
      -csynchronous_commit=off
```

Note that this image inherits from the official [postgres image](https://hub.docker.com/_/postgres/) and
so all options documented there are applicable to this image as well. Especially
important for users that wish to persist data outside of docker volumes is the
`PGDATA` environmental variable and accompanying volume mount.

## Installation

### Requirements

* Install PostgreSQL libraries and headers for C language backend development (https://www.postgresql.org/download/)
* Make sure you have PostgreSQL bin in your `PATH` 

To install from source, do:

```bash
make
make install # Might require super user permissions
```

Edit `postgresql.conf` to include the `pg_prometheus` extension:

```
shared_preload_libraries = 'pg_prometheus'
```

Start PostgreSQL and install the extension as a superuser using the `psql` CLI:
```SQL
CREATE EXTENSION pg_prometheus;
```

Optionally grant permissions to the database user (`prometheus`) that will own the Prometheus data:

```SQL
-- Create the role
CREATE ROLE prometheus WITH LOGIN PASSWORD 'secret';

-- Grant access to the schema
GRANT ALL ON SCHEMA prometheus TO prometheus;
```

This also requires superuser privileges.

##  Integrating with Prometheus

For quickly connecting Prometheus to pg_prometheus simply
connect the [Prometheus PostgreSQL adapter](https://github.com/timescale/prometheus-postgresql-adapter) to a
database that has pg_prometheus installed.

For more technical details, or to use pg_prometheus without Prometheus, read below.


## Creating the Prometheus tables.

To create the appropriate Prometheus tables use:
```SQL
SELECT create_prometheus_table('metrics');
```

This will create a `metrics` table for inserting data in the  [Prometheus exposition
format](https://prometheus.io/docs/instrumenting/exposition_formats/)
using the Prometheus data type. It will also create
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

One interesting usage is to scrape a Prometheus endpoint (e.g. `http://localhost:8080/metrics`) directly (without using Prometheus):

```bash
curl http://localhost:8080/metrics | grep -v "^#" | psql -h localhost -U postgres -p 5432 -c "COPY metrics_copy FROM STDIN"
```

## Querying data

The `metrics` view has the following schema:

```SQL
  Column |           Type           | Modifiers
 --------+--------------------------+-----------
  time   | timestamp with time zone |
  name   | text                     |
  value  | double precision         |
  labels | jsonb                    |
```

An example query would be
```SQL
SELECT time, value
FROM metrics
WHERE time > NOW() - interval '10 min' AND
      name = 'cpu_usage' AND
      labels @> '{ "service": "nginx"}';
```

## Storage formats

Pg_prometheus allows two main ways of storing Prometheus metrics: raw and
normalized (the default). With raw, a table simply stores all the Prometheus samples in a single
column of type `prom_sample`.  The normalized storage format
separates out the labels into a separate table. The advantage of the normalized
format is disk space savings when labels are long and repetitive.

Note that the `metrics` view can be used to query and insert data
regardless of the storage format and serves to hide the underlying storage from the user.

### Raw format

In raw format, data is stored in a table with one column of type `prom_sample`.
To define a raw table use pass `normalized_tables=>false` to `create_prometheus_table`.
This will also create appropriate indexes on the raw table. The schema is:

```SQL
  Column   |           Type           | Modifiers
-----------+--------------------------+-----------
 sample    | prom_sampe               |
```


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
(note that `metric_name` is in its own column since it is always
present):

```SQL
   Column    |  Type   |                          Modifiers
-------------+---------+-------------------------------------------------------------
 id          | integer | not null default nextval('metrics_labels_id_seq'::regclass)
 metric_name | text    | not null
 labels      | jsonb   |
```

## Use with TimescaleDB

[TimescaleDB](http://www.timescale.com/) scales PostgreSQL for
time-series data workloads (of which metrics is one example). If
TimescaleDB is installed, pg_prometheus will use it by default.
To install TimescaleDB, follow the instruction [here](http://docs.timescale.com/getting-started/installation).
You can explicitly control whether or not to use TimescaleDB with the
`use_timescaledb` parameter to `create_prometheus_table`.

For example, the following will force pg_prometheus to use Timescale (and will
error out if it isn't installed):
```SQL
SELECT create_prometheus_table('metrics',use_timescaledb=>true);
```

## Contributing

We welcome contributions to this extension, which like TimescaleDB is
released under the Apache2 Open Source License.
The same [Contributors
Agreement](//github.com/timescale/timescaledb/blob/master/CONTRIBUTING.md)
applies; please sign the [Contributor License
Agreement](https://cla-assistant.io/timescale/pg_prometheus) (CLA) if
you're a new contributor.
