set(SOURCES
  parse.c
  prom.c
  utils.c
)

# Add test source code in Debug builds
if (CMAKE_BUILD_TYPE MATCHES Debug)
  set(TS_DEBUG 1)
  set(DEBUG 1)
endif (CMAKE_BUILD_TYPE MATCHES Debug)

include(build-defs.cmake)
set(GITCOMMIT_H ${CMAKE_CURRENT_BINARY_DIR}/gitcommit.h)

if (WIN32)
  add_custom_command(
    OUTPUT ${GITCOMMIT_H}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    COMMAND ${CMAKE_COMMAND} -E echo_append "#define EXT_GIT_COMMIT " > ${GITCOMMIT_H}
    COMMAND (${GIT_EXECUTABLE} describe --abbrev=4 --dirty --always --tags 2> $null || call && echo "${PROJECT_VERSION_MOD}") >> ${GITCOMMIT_H}
    COMMENT "Generating gitcommit.h"
    VERBATIM)
else ()
  add_custom_command(
    OUTPUT ${GITCOMMIT_H}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    COMMAND ${CMAKE_COMMAND} -E echo_append "#define EXT_GIT_COMMIT " > ${GITCOMMIT_H}
    COMMAND sh -c "if `${GIT_EXECUTABLE} status > /dev/null 2>&1`; then ${GIT_EXECUTABLE} describe --abbrev=4 --dirty --always --tags ; else echo ${PROJECT_VERSION_MOD} ; fi" >> ${GITCOMMIT_H}
    COMMENT "Generating gitcommit.h"
    VERBATIM)
endif (WIN32)

if (CMAKE_BUILD_TYPE MATCHES Debug)
add_library(${PROJECT_NAME} MODULE ${SOURCES} ${GITCOMMIT_H})
# add_library(${PROJECT_NAME} MODULE ${SOURCES} ${GITCOMMIT_H} $<TARGET_OBJECTS:${TESTS_LIB_NAME}>)
else ()
add_library(${PROJECT_NAME} MODULE ${SOURCES} ${GITCOMMIT_H})
endif ()

if (SEND_TELEMETRY_DEFAULT)
  set(TELEMETRY_DEFAULT TELEMETRY_BASIC)
else ()
  set(TELEMETRY_DEFAULT TELEMETRY_OFF)
endif ()

set_target_properties(${PROJECT_NAME} PROPERTIES
  OUTPUT_NAME ${PROJECT_NAME}
  PREFIX "")

install(
  TARGETS ${PROJECT_NAME}
  DESTINATION ${PG_PKGLIBDIR})

if (USE_OPENSSL)
  set(TS_USE_OPENSSL ${USE_OPENSSL})
  target_include_directories(${PROJECT_NAME} SYSTEM PUBLIC ${OPENSSL_INCLUDE_DIR})
  target_link_libraries(${PROJECT_NAME} ${OPENSSL_LIBRARIES})
endif (USE_OPENSSL)

configure_file(config.h.in config.h)

include_directories(${CMAKE_CURRENT_SOURCE_DIR})
# add_subdirectory(bgw)
# add_subdirectory(chunk_append)
# add_subdirectory(net)
# add_subdirectory(telemetry)
# add_subdirectory(loader)
# add_subdirectory(bgw_policy)
