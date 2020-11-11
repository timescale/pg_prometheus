set(TEST_ROLE_SUPERUSER super_user)
set(TEST_ROLE_DEFAULT_PERM_USER default_perm_user)
set(TEST_ROLE_DEFAULT_PERM_USER_2 default_perm_user_2)

set(TEST_INPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(TEST_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
set(TEST_CLUSTER ${TEST_OUTPUT_DIR}/testcluster)

# Basic connection info for test instance
set(TEST_PGPORT_LOCAL 5432 CACHE STRING "The port of a running PostgreSQL instance")
set(TEST_PGHOST localhost CACHE STRING "The hostname of a running PostgreSQL instance")
set(TEST_PGUSER ${TEST_ROLE_DEFAULT_PERM_USER} CACHE STRING "The PostgreSQL test user")
set(TEST_DBNAME single CACHE STRING "The database name to use for tests")
set(TEST_PGPORT_TEMP_INSTANCE 15432 CACHE STRING "The port to run a temporary test PostgreSQL instance on")
set(TEST_SCHEDULE ${CMAKE_CURRENT_BINARY_DIR}/test_schedule)
set(TEST_SCHEDULE_SHARED ${CMAKE_CURRENT_BINARY_DIR}/shared/test_schedule_shared)
set(ISOLATION_TEST_SCHEDULE ${CMAKE_CURRENT_BINARY_DIR}/isolation_test_schedule)

set(PG_REGRESS_OPTS_BASE
  --host=${TEST_PGHOST}
  --load-language=plpgsql
  --dlpath=${PROJECT_BINARY_DIR}/src)

set(PG_REGRESS_OPTS_EXTRA
  --create-role=${TEST_ROLE_SUPERUSER},${TEST_ROLE_DEFAULT_PERM_USER},${TEST_ROLE_DEFAULT_PERM_USER_2}
  --dbname=${TEST_DBNAME}
  --launcher=${PRIMARY_TEST_DIR}/runner.sh)

set(PG_REGRESS_SHARED_OPTS_EXTRA
  --create-role=${TEST_ROLE_SUPERUSER},${TEST_ROLE_DEFAULT_PERM_USER},${TEST_ROLE_DEFAULT_PERM_USER_2}
  --dbname=${TEST_DBNAME}
  --launcher=${PRIMARY_TEST_DIR}/runner_shared.sh)

set(PG_ISOLATION_REGRESS_OPTS_EXTRA
  --create-role=${TEST_ROLE_SUPERUSER},${TEST_ROLE_DEFAULT_PERM_USER},${TEST_ROLE_DEFAULT_PERM_USER_2}
  --dbname=${TEST_DBNAME})

set(PG_REGRESS_OPTS_INOUT
  --inputdir=${TEST_INPUT_DIR}
  --outputdir=${TEST_OUTPUT_DIR})

set(PG_REGRESS_SHARED_OPTS_INOUT
  --inputdir=${TEST_INPUT_DIR}/shared
  --outputdir=${TEST_OUTPUT_DIR}/shared
  --load-extension=PG_PROMETHEUS)

set(PG_ISOLATION_REGRESS_OPTS_INOUT
  --inputdir=${TEST_INPUT_DIR}/isolation
  --outputdir=${TEST_OUTPUT_DIR}/isolation
  --load-extension=PG_PROMETHEUS)

set(PG_REGRESS_OPTS_TEMP_INSTANCE
  --port=${TEST_PGPORT_TEMP_INSTANCE}
  --temp-instance=${TEST_CLUSTER}
  --temp-config=${TEST_INPUT_DIR}/postgresql.conf
)

set(PG_REGRESS_OPTS_TEMP_INSTANCE_PGTEST
  --port=${TEST_PGPORT_TEMP_INSTANCE}
  --temp-instance=${TEST_CLUSTER}
  --temp-config=${TEST_INPUT_DIR}/pgtest.conf
)

set(PG_REGRESS_OPTS_LOCAL_INSTANCE
  --port=${TEST_PGPORT_LOCAL})

if(PG_REGRESS)
  set(PG_REGRESS_ENV
    TEST_PGUSER=${TEST_PGUSER}
    TEST_PGHOST=${TEST_PGHOST}
    TEST_ROLE_SUPERUSER=${TEST_ROLE_SUPERUSER}
    TEST_ROLE_DEFAULT_PERM_USER=${TEST_ROLE_DEFAULT_PERM_USER}
    TEST_ROLE_DEFAULT_PERM_USER_2=${TEST_ROLE_DEFAULT_PERM_USER_2}
    TEST_DBNAME=${TEST_DBNAME}
    TEST_INPUT_DIR=${TEST_INPUT_DIR}
    TEST_OUTPUT_DIR=${TEST_OUTPUT_DIR}
    TEST_SCHEDULE=${TEST_SCHEDULE}
    PG_BINDIR=${PG_BINDIR}
    PG_REGRESS=${PG_REGRESS})
endif()

if(PG_ISOLATION_REGRESS)
  set(PG_ISOLATION_REGRESS_ENV
    TEST_PGUSER=${TEST_PGUSER}
    TEST_ROLE_SUPERUSER=${TEST_ROLE_SUPERUSER}
    TEST_ROLE_DEFAULT_PERM_USER=${TEST_ROLE_DEFAULT_PERM_USER}
    TEST_ROLE_DEFAULT_PERM_USER_2=${TEST_ROLE_DEFAULT_PERM_USER_2}
    TEST_DBNAME=${TEST_DBNAME}
    TEST_INPUT_DIR=${TEST_INPUT_DIR}
    TEST_OUTPUT_DIR=${TEST_OUTPUT_DIR}
    ISOLATION_TEST_SCHEDULE=${ISOLATION_TEST_SCHEDULE}
    PG_ISOLATION_REGRESS=${PG_ISOLATION_REGRESS})
endif()

if (${PG_VERSION_MAJOR} GREATER "9")
    set(TEST_VERSION_SUFFIX ${PG_VERSION_MAJOR})
else ()
    set(TEST_VERSION_SUFFIX ${PG_VERSION_MAJOR}.${PG_VERSION_MINOR})
endif ()

