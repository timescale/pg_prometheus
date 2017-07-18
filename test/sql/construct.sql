\set ECHO ALL
\set ON_ERROR_STOP 1
SET TIME ZONE 'UTC';

SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test'::text, 12.7::double precision, '{}'::jsonb);
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test'::text, 12.7::double precision, '{"key": "value"}'::jsonb);
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test2'::text, 12.7::double precision, '{"key1": "value1", "key2": "value2"}'::jsonb);

\set ON_ERROR_STOP 0
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test2'::text, 12.7::double precision, '{"key1": "value1", "key2": 4}'::jsonb);
SELECT prom_construct(Timestamp with time zone 'Fri May 12 13:31:38 2017', 'test2'::text, 12.7::double precision, '{"key1": "value1", "key2": {"key3":"value2"}}'::jsonb);
