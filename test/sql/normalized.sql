\set ECHO ALL
\set ON_ERROR_STOP 1
SET TIME ZONE 'UTC';

DROP TABLE IF EXISTS metrics_labels CASCADE;
DROP TABLE IF EXISTS metrics CASCADE;
DROP TABLE IF EXISTS input;

SELECT create_prometheus_table('input', 'metrics', keep_samples=>true);

\d input
\d metrics
\d metrics_labels

INSERT INTO input VALUES ('cpu_usage{service="nginx",host="machine1"} 34.6 1494595898000'),
                         ('cpu_usage{service="nginx",host="machine2"} 10.3 1494595899000'),
                         ('cpu_usage{service="nginx",host="machine1"} 30.2 1494595928000');

SELECT * FROM input;
SELECT * FROM metrics;
SELECT * FROM metrics_labels;

-- Cleanup
DROP TABLE metrics CASCADE;
DROP TABLE metrics_labels CASCADE;
DROP TABLE input;

-- Test inserts without keeping original samples
SELECT create_prometheus_table('input', 'metrics');

INSERT INTO input VALUES ('cpu_usage{service="nginx",host="machine1"} 34.6 1494595898000');

SELECT * FROM input;
SELECT * FROM metrics;

-- Cleanup
DROP TABLE metrics CASCADE;
DROP TABLE metrics_labels CASCADE;
DROP TABLE input;
