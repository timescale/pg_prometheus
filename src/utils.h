#ifndef PG_PROMETHEUS_UTILS_H
#define PG_PROMETHEUS_UTILS_H

#include <datatype/timestamp.h>

int64		prom_timestamp_to_unix_microseconds(TimestampTz timestamp);
TimestampTz prom_unix_microseconds_to_timestamp(int64 microseconds);

#endif   /* PG_PROMETHEUS_UTILS_H */
