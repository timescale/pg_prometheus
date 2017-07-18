\set ECHO ALL
\set ON_ERROR_STOP 1
SET TIME ZONE 'UTC';

DROP TABLE IF EXISTS metrics_labels CASCADE;
DROP TABLE IF EXISTS metrics CASCADE;
DROP TABLE IF EXISTS input;

SELECT create_prometheus_table('input');

\dt
\d input
\d input_values
\d input_labels
\d+ input_copy

INSERT INTO input VALUES ('cpu_usage{service="nginx",host="machine1"} 34.6 1494595898000'),
                         ('cpu_usage{service="nginx",host="machine2"} 10.3 1494595899000'),
                         ('cpu_usage{service="nginx",host="machine1"} 30.2 1494595928000');

INSERT INTO input(sample) VALUES ('cpu_usage{service="nginx",host="machine1"} 34.6 1494595898000'),
                         ('cpu_usage{service="nginx",host="machine2"} 10.3 1494595899000'),
                         ('cpu_usage{service="nginx",host="machine1"} 30.2 1494595928000');


SELECT * FROM input;
SELECT * FROM input_values;
SELECT * FROM input_labels;

SELECT sample FROM input
WHERE time >  'Fri May 12 13:31:00 2017' AND
      name = 'cpu_usage' AND
      labels @> '{"service": "nginx", "host": "machine1"}';


EXPLAIN (costs off, verbose on) SELECT * FROM input
WHERE time >  'Fri May 12 13:31:00 2017' AND
      name = 'cpu_usage' AND
      labels @> '{"service": "nginx", "host": "machine1"}';

EXPLAIN (costs off, verbose on) SELECT time, name, value, labels FROM input
WHERE time >  'Fri May 12 13:31:00 2017' AND
      name = 'cpu_usage' AND
      labels @> '{"service": "nginx", "host": "machine1"}';


-- Cleanup
DROP TABLE input_values CASCADE;
DROP TABLE input_labels CASCADE;


