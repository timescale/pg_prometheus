#include <postgres.h>
#include <utils/builtins.h>
#include <utils/timestamp.h>
#include <utils/jsonb.h>
#include <utils/json.h>

#include "prom.h"
#include "parse.h"
#include "utils.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

static char * 
prom_label_strip_escape(const char *orig) 
{
   char *new = palloc(strlen(orig)+1);
   int orig_index = 0;
   int new_index = 0;
   while (orig[orig_index] != '\0') {
     if (orig_index==0 || orig[orig_index] != '\\' || orig[orig_index-1] == '\\')
     {
       new[new_index++] = orig[orig_index];
     }
     orig_index++;
   }
   new[new_index] = '\0';
   return new;
}

static char *
prom_labels_to_cstring(PrometheusSample *sample)
{
	PrometheusLabel *label = PROM_LABELS(sample);
	char	   *result;
	size_t		i;
	int			n = 0;

	if (!PROM_CONTAINS_LABELS(sample))
		return NULL;

	result = palloc(PROM_LABEL_DATALEN(sample) + (2 * sample->numlabels) + 1);

	for (i = 0; i < sample->numlabels; i++)
	{
		const char *name = PROM_LABEL_NAME(label);
		const char *value = PROM_LABEL_VALUE(label);

		if (i == sample->numlabels - 1)
			n += sprintf(result + n, "%s=\"%s\"", name, value);
		else
			n += sprintf(result + n, "%s=\"%s\",", name, value);

		label = PROM_LABEL_NEXT(label);
	}

	return result;
}

PG_FUNCTION_INFO_V1(prom_in);

Datum
prom_in(PG_FUNCTION_ARGS)
{
	char	   *str = PG_GETARG_CSTRING(0);

	PG_RETURN_POINTER(prom_from_cstring(str));
}

PG_FUNCTION_INFO_V1(prom_out);

Datum
prom_out(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);
	char	   *result;
	int64		time_ms = prom_timestamp_to_unix_microseconds(PROM_TIME(sample)) / 1000;

	if (PROM_CONTAINS_LABELS(sample))
	{
		result = psprintf("%s{%s} %lf " INT64_FORMAT "",
						  PROM_NAME(sample),
						  prom_labels_to_cstring(sample),
						  PROM_VALUE(sample),
						  time_ms);
	}
	else
	{
		result = psprintf("%s %lf " INT64_FORMAT "",
						  PROM_NAME(sample),
						  PROM_VALUE(sample),
						  time_ms);

	}
	PG_RETURN_CSTRING(result);
}

PG_FUNCTION_INFO_V1(prom_has_label);

Datum
prom_has_label(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);
	text	   *fname = PG_GETARG_TEXT_PP(1);
	char	   *labelname = text_to_cstring(fname);
	PrometheusLabel *label = PROM_LABELS(sample);
	size_t		i;

	for (i = 0; i < sample->numlabels; i++)
	{
		if (strcmp(PROM_LABEL_NAME(label), labelname) == 0)
		{
			PG_RETURN_BOOL(true);
		}

		label = PROM_LABEL_NEXT(label);
	}
	PG_RETURN_BOOL(false);
}

PG_FUNCTION_INFO_V1(prom_label_count);

Datum
prom_label_count(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);

	PG_RETURN_UINT32(sample->numlabels);
}

PG_FUNCTION_INFO_V1(prom_label);

Datum
prom_label(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);
	text	   *fname = PG_GETARG_TEXT_PP(1);
	char	   *labelname = text_to_cstring(fname);
	PrometheusLabel *label = PROM_LABELS(sample);
	size_t		i;

	for (i = 0; i < sample->numlabels; i++)
	{
		if (strcmp(PROM_LABEL_NAME(label), labelname) == 0)
		{
			char	   *value = PROM_LABEL_VALUE(label);

			PG_RETURN_TEXT_P(cstring_to_text(value));
		}

		label = PROM_LABEL_NEXT(label);
	}
	PG_RETURN_NULL();
}

PG_FUNCTION_INFO_V1(prom_name);

Datum
prom_name(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);

	PG_RETURN_TEXT_P(cstring_to_text(PROM_NAME(sample)));
}

PG_FUNCTION_INFO_V1(prom_time);

Datum
prom_time(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);

	PG_RETURN_TIMESTAMPTZ(PROM_TIME(sample));
}

PG_FUNCTION_INFO_V1(prom_value);

Datum
prom_value(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);

	PG_RETURN_FLOAT8(PROM_VALUE(sample));
}

#define JSONB_METRIC_NAME_KEY "name"
#define JSONB_METRIC_NAME_LEN (sizeof(JSONB_METRIC_NAME_KEY) - 1)
#define JSONB_METRIC_NAME_LABEL_KEY "metric_name"
#define JSONB_METRIC_NAME_LABEL_LEN (sizeof(JSONB_METRIC_NAME_LABEL_KEY) - 1)
#define JSONB_METRIC_TIME_KEY "time"
#define JSONB_METRIC_TIME_LEN (sizeof(JSONB_METRIC_TIME_KEY) - 1)
#define JSONB_METRIC_VALUE_KEY "value"
#define JSONB_METRIC_VALUE_LEN (sizeof(JSONB_METRIC_VALUE_KEY) - 1)
#define JSONB_METRIC_LABELS_KEY "labels"
#define JSONB_METRIC_LABELS_LEN (sizeof(JSONB_METRIC_LABELS_KEY) - 1)

static JsonbValue *
prom_labels_to_jsonb_value(PrometheusSample *sample, JsonbParseState **parseState, bool add_name_label)
{
	PrometheusLabel *label = PROM_LABELS(sample);
	size_t		i;

	pushJsonbValue(parseState, WJB_BEGIN_OBJECT, NULL);

	for (i = 0; i < sample->numlabels; i++)
	{
		JsonbValue	v;

		v.type = jbvString;
		v.val.string.len = PROM_LABEL_NAME_LEN(label);
		v.val.string.val = PROM_LABEL_NAME(label);

		pushJsonbValue(parseState, WJB_KEY, &v);

		if (PROM_LABEL_VALUE_IS_NULL(label))
		{
			v.type = jbvNull;
		}
		else
		{
      char * strip_escape = prom_label_strip_escape(PROM_LABEL_VALUE(label));
			v.type = jbvString;
			v.val.string.len = strlen(strip_escape);
			v.val.string.val = strip_escape;
		}

		pushJsonbValue(parseState, WJB_VALUE, &v);
		label = PROM_LABEL_NEXT(label);
	}

	if (add_name_label)
	{
		JsonbValue	v;

		v.type = jbvString;
		v.val.string.len = JSONB_METRIC_NAME_LABEL_LEN;
		v.val.string.val = JSONB_METRIC_NAME_LABEL_KEY;
		pushJsonbValue(parseState, WJB_KEY, &v);

		v.type = jbvString;
		v.val.string.len = PROM_NAME_LEN(sample);
		v.val.string.val = PROM_NAME(sample);
		pushJsonbValue(parseState, WJB_VALUE, &v);
	}

	return pushJsonbValue(parseState, WJB_END_OBJECT, NULL);
}

PG_FUNCTION_INFO_V1(prom_labels);

Datum
prom_labels(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);
	bool		include_name = false;
	JsonbParseState *parseState = NULL;
	JsonbValue *result;

	if (!PG_ARGISNULL(2))
		include_name = PG_GETARG_BOOL(1);

	result = prom_labels_to_jsonb_value(sample, &parseState, include_name);

	PG_RETURN_POINTER(JsonbValueToJsonb(result));
}

static JsonbValue *
prom_to_jsonb_value(PrometheusSample *sample)
{
	JsonbParseState *parseState = NULL;
	JsonbValue	v;
	Datum		time = DirectFunctionCall1(timestamptz_out, PROM_TIME(sample));
	Datum		value = DirectFunctionCall1(float8_numeric,
									 Float8GetDatumFast(PROM_VALUE(sample)));

	pushJsonbValue(&parseState, WJB_BEGIN_OBJECT, NULL);

	/* Add name */
	v.type = jbvString;
	v.val.string.len = JSONB_METRIC_NAME_LEN;
	v.val.string.val = JSONB_METRIC_NAME_KEY;
	pushJsonbValue(&parseState, WJB_KEY, &v);

	v.type = jbvString;
	v.val.string.len = PROM_NAME_LEN(sample);
	v.val.string.val = PROM_NAME(sample);
	pushJsonbValue(&parseState, WJB_VALUE, &v);

	/* Add time */
	v.type = jbvString;
	v.val.string.len = JSONB_METRIC_TIME_LEN;
	v.val.string.val = JSONB_METRIC_TIME_KEY;
	pushJsonbValue(&parseState, WJB_KEY, &v);

	v.type = jbvString;
	v.val.string.len = strlen(DatumGetPointer(time));
	v.val.string.val = DatumGetPointer(time);
	pushJsonbValue(&parseState, WJB_VALUE, &v);

	/* Add value */
	v.type = jbvString;
	v.val.string.len = JSONB_METRIC_VALUE_LEN;
	v.val.string.val = JSONB_METRIC_VALUE_KEY;
	pushJsonbValue(&parseState, WJB_KEY, &v);

	v.type = jbvNumeric;
	v.val.numeric = DatumGetNumeric(value);

	pushJsonbValue(&parseState, WJB_VALUE, &v);

	/* Add labels */
	v.type = jbvString;
	v.val.string.len = JSONB_METRIC_LABELS_LEN;
	v.val.string.val = JSONB_METRIC_LABELS_KEY;
	pushJsonbValue(&parseState, WJB_KEY, &v);
	prom_labels_to_jsonb_value(sample, &parseState, false);

	return pushJsonbValue(&parseState, WJB_END_OBJECT, NULL);
}

PG_FUNCTION_INFO_V1(prom_jsonb);

Datum
prom_jsonb(PG_FUNCTION_ARGS)
{
	PrometheusSample *sample = (PrometheusSample *) PG_GETARG_POINTER(0);

	PG_RETURN_POINTER(JsonbValueToJsonb(prom_to_jsonb_value(sample)));
}



typedef struct PrometheusJsonbParseCtx
{
	PrometheusSample *sample;
	uint16		numlabels;
	uint32		numchars;
} PrometheusJsonbParseCtx;


static void
parse_jsonb_labels(Jsonb *jb, PrometheusJsonbParseCtx *ctx)
{
	PrometheusLabel *curr = ctx->sample == NULL ? NULL : PROM_LABELS(ctx->sample);
	JsonbIterator *it;
	JsonbValue	v;
	JsonbIteratorToken type = WJB_DONE;
	int			cnt_objects = 0;

	ctx->numlabels = 0;
	ctx->numchars = 0;

	it = JsonbIteratorInit(&jb->root);
	while ((type = JsonbIteratorNext(&it, &v, false)) != WJB_DONE)
	{
		switch (type)
		{
			case WJB_KEY:
				ctx->numlabels++;
			case WJB_VALUE:
				if (v.type == jbvString)
				{
					ctx->numchars += v.val.string.len + 1;
					if (curr != NULL)
					{
						if (type == WJB_VALUE)
						{
							PROM_LABEL_VALUE_SET(curr, v.val.string.val, v.val.string.len);
							curr = PROM_LABEL_NEXT(curr);
						}
						else
						{
							PROM_LABEL_NAME_SET(curr, v.val.string.val, v.val.string.len);
						}
					}
				}
				else
				{
					elog(ERROR, "Jsonb labels must be a set of string keys mapped to string values.");
				}
				break;
			case WJB_BEGIN_OBJECT:
				cnt_objects++;
				if (cnt_objects > 1)
				{
					elog(ERROR, "Jsonb labels must be a set of string keys mapped to string values: cannot have nested labels.");
				}
			case WJB_END_OBJECT:
				break;
			default:
				elog(ERROR, "Jsonb labels must be a set of string keys mapped to string values.");
		}
	}
}



PG_FUNCTION_INFO_V1(prom_construct);

Datum
prom_construct(PG_FUNCTION_ARGS)
{
	TimestampTz ts = PG_GETARG_TIMESTAMPTZ(0);
	text	   *name = PG_GETARG_TEXT_PP(1);
	float8		value = PG_GETARG_FLOAT8(2);
	Jsonb	   *jb = PG_GETARG_JSONB(3);

	char	   *metric_name = text_to_cstring(name);
	PrometheusJsonbParseCtx ctx = {0};
	PrometheusSample *sample;
	size_t		samplelen;

	parse_jsonb_labels(jb, &ctx);

	samplelen = PROM_ALLOC_LEN(strlen(metric_name), ctx.numlabels, ctx.numchars);

	sample = palloc(samplelen);
	memset(sample, 0, samplelen);
	sample->numlabels = ctx.numlabels;
	sample->value = value;
	sample->time = ts;
	PROM_NAME_SET(sample, metric_name, strlen(metric_name));

	SET_VARSIZE(sample, samplelen);
	ctx.sample = sample;
	parse_jsonb_labels(jb, &ctx);

	PG_RETURN_POINTER(sample);
}
