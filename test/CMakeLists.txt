set(PRIMARY_TEST_DIR ${CMAKE_CURRENT_LIST_DIR})
set(PRIMARY_TEST_DIR ${CMAKE_CURRENT_LIST_DIR} PARENT_SCOPE)
set(_local_install_checks)
set(_install_checks)

# Testing support
find_program(PG_REGRESS pg_regress
  HINTS
  "${PG_PKGLIBDIR}/pgxs/src/test/regress/")

find_program(PG_ISOLATION_REGRESS
  NAMES pg_isolation_regress
  HINTS
  ${BINDIR}
  ${PG_PKGLIBDIR}/pgxs/src/test/isolation
  ${PG_SOURCE_DIR}/src/test/isolation)

include(test-defs.cmake)

if(PG_REGRESS)
  message(STATUS "Using pg_regress ${PG_REGRESS}")

  add_custom_target(regresscheck
    COMMAND ${CMAKE_COMMAND} -E env
    ${PG_REGRESS_ENV}
    ${CMAKE_CURRENT_SOURCE_DIR}/pg_regress.sh
    ${PG_REGRESS_OPTS_BASE}
    ${PG_REGRESS_OPTS_EXTRA}
    ${PG_REGRESS_OPTS_INOUT}
    ${PG_REGRESS_OPTS_TEMP_INSTANCE}
    USES_TERMINAL)

  add_custom_target(regresschecklocal
    COMMAND ${CMAKE_COMMAND} -E env
    ${PG_REGRESS_ENV}
    ${CMAKE_CURRENT_SOURCE_DIR}/pg_regress.sh
    ${PG_REGRESS_OPTS_BASE}
    ${PG_REGRESS_OPTS_EXTRA}
    ${PG_REGRESS_OPTS_INOUT}
    ${PG_REGRESS_OPTS_LOCAL_INSTANCE}
    USES_TERMINAL)

  list(APPEND _local_install_checks regresschecklocal)
  list(APPEND _install_checks regresscheck)
elseif(REGRESS_CHECKS)
  message(FATAL_ERROR
    "Program 'pg_regress' not found, but regressions checks were required.\n"
    "Skip regression checks using -DREGRESS_CHECKS=OFF")
else()
  message(STATUS "Skipping isolation regress checks since program 'pg_regress' was not found")
endif()

# installcheck starts up new temporary instances for testing code

if(_install_checks)
  add_custom_target(installcheck DEPENDS ${_install_checks})
endif()
  
# installchecklocal tests against an existing postgres instance
if(_local_install_checks)
  add_custom_target(installchecklocal DEPENDS ${_local_install_checks})
endif()

add_subdirectory(sql)

