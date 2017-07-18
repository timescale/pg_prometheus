#ifndef PG_PROMETHEUS_PROM_H
#define PG_PROMETHEUS_PROM_H

#ifndef IGNORE_POSTGRES_INCLUDES
#include <postgres.h>
#include <datatype/timestamp.h>
#else
typedef int64_t TimestampTz;
typedef double float8;
typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef int32_t int32;
#define FLEXIBLE_ARRAY_MEMBER 0
struct varhdr
{
	uint32		length;
};
#define offsetof(type, field)	((long) &((type *)0)->field)
#define SET_VARSIZE(d, len)						\
  do {											\
	struct varhdr *h = (struct varhdr *)(d);	\
	h->length = len;							\
  } while (0);
#define VARSIZE(d) ((struct varhdr *)d)->length
#endif

typedef struct PrometheusLabel
{
	/*
	 * The label name must be ASCII and match the following regexp:
	 * "[a-zA-Z_][a-zA-Z0-9_]*"
	 */
	/* Label values can be any valid unicode (UTF-8) string */
	uint16		length;
	uint16		valueidx;		/* The offset in data where one can find the
								 * value string */
	char		data[FLEXIBLE_ARRAY_MEMBER];
} PrometheusLabel;

#define PROM_LABEL_HDRLEN						\
  offsetof(struct PrometheusLabel, data)

/* The metric name is always encoded as the first label in a sample and must be
 * ASCII, matching the following regexp: "[a-zA-Z_:][a-zA-Z0-9_:]*". */
typedef struct PrometheusSample
{
	int32		vl_len_;		/* Do not touch directly */
	uint16		numlabels;
	float8		value;
	TimestampTz time;
	PrometheusLabel labels[FLEXIBLE_ARRAY_MEMBER];
} PrometheusSample;

#define PROM_SAMPLE_HDRLEN						\
  offsetof(struct PrometheusSample, labels)

#define PROM_LABEL_NAME(l)						\
  (&((PrometheusLabel *)l)->data[0])

#define PROM_LABEL_NAME_LEN(l)							\
  (size_t)(((PrometheusLabel *)l)->valueidx - 1)

#define PROM_LABEL_VALUE(l)												\
  (&((PrometheusLabel *)l)->data[((PrometheusLabel *)l)->valueidx])

#define PROM_LABEL_VALUE_LEN(l)					\
  (size_t)(((PrometheusLabel *)l)->length -		\
		   ((PrometheusLabel *)l)->valueidx -	\
		   PROM_LABEL_HDRLEN - 1)

#define PROM_LABEL_VALUE_IS_NULL(l)				\
  ((((PrometheusLabel *)l)->length -			\
	((PrometheusLabel *)l)->valueidx -			\
	PROM_LABEL_HDRLEN) == 0)

#define PROM_LABEL_NAME_SET(label, name, namelen)		\
  do {													\
	PrometheusLabel *l = (PrometheusLabel *)(label);	\
	memcpy(l->data, name, namelen);						\
	l->data[namelen] = '\0';							\
	l->valueidx = namelen + 1;							\
  } while (0);

#define PROM_LABEL_VALUE_SET(label, value, valuelen)					\
  do {																	\
	PrometheusLabel *l = (PrometheusLabel *)(label);					\
	memcpy(PROM_LABEL_VALUE(l), value, valuelen);						\
	PROM_LABEL_VALUE(l)[valuelen] = '\0';								\
	l->length = PROM_LABEL_HDRLEN +		l->valueidx + valuelen + 1;		\
  } while (0);

#define PROM_LABEL_NEXT(l)												\
  ((PrometheusLabel *)(((char *)l) + ((PrometheusLabel *)l)->length))

#define PROM_LABELS(s)									\
  PROM_LABEL_NEXT((PrometheusLabel *)&(s)->labels[0])

#define PROM_NAME(s)							\
  PROM_LABEL_VALUE((s)->labels)

#define PROM_NAME_LEN(s)						\
  (size_t)((s)->labels->length -				\
		   PROM_LABEL_HDRLEN - 1)

#define PROM_NAME_SET(s, name, namelen)							\
  do {															\
	PrometheusLabel *l = (PrometheusLabel *)(s)->labels;		\
	l->valueidx = 0;											\
	PROM_LABEL_VALUE_SET((s)->labels, name, namelen);			\
  } while (0);

#define PROM_ALLOC_LEN(metric_namelen, numlabels, datalen)		\
  (PROM_SAMPLE_HDRLEN + metric_namelen							\
   + 1 + datalen + (1 + numlabels) * PROM_LABEL_HDRLEN)

#define PROM_LABEL_DATALEN(sample)				\
  VARSIZE((sample)) - PROM_SAMPLE_HDRLEN -		\
  ((sample)->labels)->length -					\
  ((sample)->numlabels * PROM_LABEL_HDRLEN)

#define PROM_CONTAINS_LABELS(sample)			\
  (PROM_LABEL_DATALEN((sample)) > 0)

#define PROM_TIME(sample)						\
  (sample)->time

#define PROM_VALUE(sample)						\
  (sample)->value

#endif   /* PG_PROMETHEUS_PROM_H */
