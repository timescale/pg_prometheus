# Hide symbols by default in shared libraries
if(NOT USE_DEFAULT_VISIBILITY)
  set(CMAKE_C_VISIBILITY_PRESET "hidden")
endif()

# postgres CFLAGS includes -Wdeclaration-after-statement which leads
# to problems when compiling with -Werror since we aim for C99 and allow
# that so we strip this flag from PG_CFLAGS before adding postgres flags
# to our own
string(REPLACE "-Wdeclaration-after-statement" "" PG_CFLAGS "${PG_CFLAGS}")

if (WIN32)
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /MANIFEST:NO")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} /MANIFEST:NO")
endif()

# PG_LDFLAGS can have strange values if not found, so we just add the
# flags if they are defined.
if(PG_LDFLAGS)
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${PG_LDFLAGS}")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} ${PG_LDFLAGS}")
endif()


include_directories(${PROJECT_SOURCE_DIR}/src ${PROJECT_BINARY_DIR}/src)
include_directories(SYSTEM ${PG_INCLUDEDIR_SERVER})

# Only Windows and FreeBSD need the base include/ dir instead of include/server/, and including
# both causes problems on Ubuntu where they frequently get out of sync
if (WIN32 OR (CMAKE_SYSTEM_NAME STREQUAL "FreeBSD"))
  include_directories(SYSTEM ${PG_INCLUDEDIR})
endif ()

if (WIN32)
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} ${PG_LIBDIR}/postgres.lib ws2_32.lib Version.lib")
  set(CMAKE_C_FLAGS "-D_CRT_SECURE_NO_WARNINGS")
  include_directories(SYSTEM ${PG_INCLUDEDIR_SERVER}/port/win32)

  if (MSVC)
    include_directories(SYSTEM ${PG_INCLUDEDIR_SERVER}/port/win32_msvc)
  endif (MSVC)
endif (WIN32)

# Name of library with test-specific code
set(TESTS_LIB_NAME ${PROJECT_NAME}-tests)