PG_CONFIG = pg_config

EXTENSION = pg_prometheus
SQL_FILES = sql/prometheus.sql

EXT_VERSION = $(shell cat pg_prometheus.control | grep 'default' | sed "s/^.*'\(.*\)'$\/\1/g")
EXT_SQL_FILE = sql/$(EXTENSION)--$(EXT_VERSION).sql

DATA = $(EXT_SQL_FILE)
MODULE_big = $(EXTENSION)

SRCS = \
	src/prom.c \
	src/parse.c \
	src/utils.c

OBJS = $(SRCS:.c=.o)
DEPS = $(SRCS:.c=.d)

MKFILE_PATH := $(abspath $(MAKEFILE_LIST))
CURRENT_DIR = $(dir $(MKFILE_PATH))

TEST_PGPORT ?= 5432
TEST_PGHOST ?= localhost
TEST_PGUSER ?= postgres
TESTS = $(sort $(wildcard test/sql/*.sql))
USE_MODULE_DB=true
REGRESS = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = \
	--inputdir=test \
	--outputdir=test \
	--host=$(TEST_PGHOST) \
	--port=$(TEST_PGPORT) \
	--user=$(TEST_PGUSER) \
	--load-language=plpgsql \
	--load-extension=$(EXTENSION)

PGXS := $(shell $(PG_CONFIG) --pgxs)

EXTRA_CLEAN = $(EXT_SQL_FILE) $(DEPS)

DOCKER_IMAGE_NAME=pg_prometheus

include $(PGXS)
override CFLAGS += -DINCLUDE_PACKAGE_SUPPORT=0 -MMD
override pg_regress_clean_files = test/results/ test/regression.diffs test/regression.out tmp_check/ log/
-include $(DEPS)

all: $(EXT_SQL_FILE)

$(EXT_SQL_FILE): $(SQL_FILES)
	@cat $^ > $@

check-sql-files:
	@echo $(SQL_FILES)

install: $(EXT_SQL_FILE)

package: clean $(EXT_SQL_FILE)
	@mkdir -p package/lib
	@mkdir -p package/extension
	$(install_sh) -m 755 $(EXTENSION).so 'package/lib/$(EXTENSION).so'
	$(install_sh) -m 644 $(EXTENSION).control 'package/extension/'
	$(install_sh) -m 644 $(EXT_SQL_FILE) 'package/extension/'

docker-image: Dockerfile
	docker build -t $(DOCKER_IMAGE_NAME) .

typedef.list: clean $(OBJS)
	./scripts/generate_typedef.sh

pgindent: typedef.list
	pgindent --typedef=typedef.list

.PHONY: check-sql-files all docker-image
