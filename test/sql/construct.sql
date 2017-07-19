\set ECHO ALL
\set ON_ERROR_STOP 1
SET TIME ZONE 'UTC';

SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test'::text, 12.7::double precision, '{}'::jsonb);
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test'::text, 12.7::double precision, '{"key": "value"}'::jsonb);
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test2'::text, 12.7::double precision, '{"key1": "value1", "key2": "value2"}'::jsonb);

\set ON_ERROR_STOP 0
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test2'::text, 12.7::double precision, '{"key1": "value1", "key2": 4}'::jsonb);
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test2'::text, 12.7::double precision, '{"key1": "value1", "key2": {"key3":"value2"}}'::jsonb);

\set ON_ERROR_STOP 1

--test parsing with escaped characters
SELECT 'prombench_query_latency_seconds_bucket{benchmark="insert-then-sum",instance=":9999",job="prombench",le="+Inf",query="sum(sum_over_time({__name__=~\"test.+\", instance=\"localhost:10003\"}[51s]))",run_name="run1"} 1 1500469393334'::prom_sample;
SELECT prom_labels('prombench_query_latency_seconds_bucket{benchmark="insert-then-sum",instance=":9999",job="prombench",le="+Inf",query="sum(sum_over_time({__name__=~\"test.+\", instance=\"localhost:10003\"}[51s]))",run_name="run1"} 1 1500469393334'::prom_sample);

SELECT prom_labels('test{label_with_quote="val\"quote\""} 1 1500469393334'::prom_sample);
SELECT prom_labels('test{label_with_quote="val\"quote\""} 1 1500469393334'::prom_sample) @>  '{"label_with_quote":"val\"quote\""}';
