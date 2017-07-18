#include <postgres.h>
#include <datatype/timestamp.h>

#include "utils.h"

/*
 * Convert a Postgres TIMESTAMP to BIGINT microseconds relative the UNIX epoch.
 */
int64
prom_timestamp_to_unix_microseconds(TimestampTz timestamp)
{
	int64		epoch_diff_microseconds = (POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * USECS_PER_DAY;
	int64		microseconds;

	if (timestamp < MIN_TIMESTAMP)
		ereport(ERROR,
				(errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
				 errmsg("timestamp out of range")));

	if (timestamp >= (END_TIMESTAMP - epoch_diff_microseconds))
		ereport(ERROR,
				(errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
				 errmsg("timestamp out of range")));

#ifdef HAVE_INT64_TIMESTAMP
	microseconds = timestamp + epoch_diff_microseconds;
#else
	if (1)
	{
		int64		seconds = (int64) timestamp;

		microseconds = (seconds * USECS_PER_SEC) + ((timestamp - seconds) * USECS_PER_SEC) + epoch_diff_microseconds;
	}
#endif
	return microseconds;
}

/*
 * Convert BIGINT microseconds relative the UNIX epoch to a Postgres TIMESTAMP.
 */
TimestampTz
prom_unix_microseconds_to_timestamp(int64 microseconds)
{
	TimestampTz timestamp;

	/*
	 * Test that the UNIX us timestamp is within bounds. Note that an int64 at
	 * UNIX epoch and microsecond precision cannot represent the upper limit
	 * of the supported date range (Julian end date), so INT64_MAX is the
	 * natural upper bound for this function.
	 */
	if (microseconds < ((int64) USECS_PER_DAY * (DATETIME_MIN_JULIAN - UNIX_EPOCH_JDATE)))
		ereport(ERROR,
				(errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
				 errmsg("timestamp out of range")));

#ifdef HAVE_INT64_TIMESTAMP
	timestamp = microseconds - ((POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * USECS_PER_DAY);
#else
	/* Shift the epoch using integer arithmetic to reduce precision errors */
	timestamp = microseconds / USECS_PER_SEC;	/* seconds */
	microseconds = microseconds - ((int64) timestamp * USECS_PER_SEC);
	timestamp = (float8) ((int64) seconds - ((POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * SECS_PER_DAY))
		+ (float8) microseconds / USECS_PER_SEC;
#endif
	return timestamp;
}
