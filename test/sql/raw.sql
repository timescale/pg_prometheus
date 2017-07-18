\set ECHO ALL
\set ON_ERROR_STOP 1
SET TIME ZONE 'UTC';

DROP TABLE IF EXISTS metrics CASCADE;

CREATE TABLE metrics (sample prom_sample);
CREATE INDEX metrics_time_idx ON metrics (prom_time(sample));
CREATE INDEX metrics_labels_idx ON metrics USING GIN (prom_labels(sample));

\d metrics

INSERT INTO metrics VALUES ('cpu_usage{service="nginx",host="machine1"} 34.6 1494595898000'),
                           ('cpu_usage{service="nginx",host="machine2"} 10.3 1494595899000'),
                           ('cpu_usage{service="nginx",host="machine1"} 30.2 1494595928000'),
                           -- Test various corner-case values
                           ('cpu_usage{service="nginx",host="machine1"} NaN 1494595928000'),
                           ('cpu_usage{service="nginx",host="machine1"} +Inf 1494595928000'),
                           ('cpu_usage{service="nginx",host="machine1"} -Inf 1494595928000'),
                           -- Test with no labels
                           ('cpu_usage 30.2 1494595928000');

SELECT * FROM metrics;

SELECT prom_time(sample), prom_value(sample), prom_labels(sample) FROM metrics;

SELECT prom_time(sample), prom_value(sample) FROM metrics
WHERE prom_time(sample) >  'Fri May 12 13:31:00 2017' AND
      prom_name(sample) = 'cpu_usage' AND
      prom_labels(sample) @> '{"service": "nginx", "host": "machine1"}';

EXPLAIN SELECT prom_time(sample), prom_value(sample) FROM metrics
WHERE prom_time(sample) >  'Fri May 12 13:31:00 2017' AND
      prom_name(sample) = 'cpu_usage' AND
      prom_labels(sample) @> '{"service": "nginx", "host": "machine1"}';

-- Insert sample with no timestamp
INSERT INTO metrics VALUES ('cpu_usage{service="nginx",host="machine3"} 30.2');

-- Cannot show time since different every test run
SELECT prom_value(sample), prom_labels(sample) FROM metrics;

-- Cleanup
DROP TABLE metrics CASCADE;

--create table using functio and create the appropriate view
SELECT create_prometheus_table('metrics', normalized_tables=>false);
INSERT INTO metrics VALUES ('cpu_usage{service="nginx",host="machine1"} 34.6 1494595898000'),
                           ('cpu_usage{service="nginx",host="machine2"} 10.3 1494595899000'),
                           ('cpu_usage{service="nginx",host="machine1"} 30.2 1494595928000'),
                           -- Test various corner-case values
                           ('cpu_usage{service="nginx",host="machine1"} NaN 1494595928000'),
                           ('cpu_usage{service="nginx",host="machine1"} +Inf 1494595928000'),
                           ('cpu_usage{service="nginx",host="machine1"} -Inf 1494595928000'),
                           -- Test with no labels
                           ('cpu_usage 30.2 1494595928000');

SELECT * FROM metrics;
SELECT * FROM metrics_samples;
EXPLAIN (costs off, verbose on) SELECT * FROM metrics
WHERE time >  'Fri May 12 13:31:00 2017' AND
      name = 'cpu_usage' AND
      labels @> '{"service": "nginx", "host": "machine1"}';

