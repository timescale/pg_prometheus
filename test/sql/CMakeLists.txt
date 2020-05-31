set(TEST_FILES
  construct.sql
  normalized.sql
  raw.sql
)

list(SORT TEST_FILES)
file(REMOVE ${TEST_SCHEDULE})

if(NOT TEST_GROUP_SIZE)
  set(PARALLEL_GROUP_SIZE 20)
else()
  set(PARALLEL_GROUP_SIZE ${TEST_GROUP_SIZE})
endif()

# append solo tests to schedule first
foreach(SOLO_TEST_NAME ${SOLO_TESTS})
  string(REGEX REPLACE "(.+)" "\\1.sql" TEST_FILE ${SOLO_TEST_NAME})
  if(TEST_FILE IN_LIST TEST_FILES)
    file(APPEND ${TEST_SCHEDULE} "test: ${SOLO_TEST_NAME}\n")
  endif ()
endforeach(SOLO_TEST_NAME)

set(GROUP_MEMBERS 0)
foreach(TEST_FILE ${TEST_FILES})
  string(REGEX REPLACE "(.+)\.sql" "\\1" TESTS_TO_RUN ${TEST_FILE})
  if(NOT (TESTS_TO_RUN IN_LIST SOLO_TESTS))
    if(GROUP_MEMBERS EQUAL 0)
      file(APPEND ${TEST_SCHEDULE} "\ntest: ")
    endif()
    file(APPEND ${TEST_SCHEDULE} "${TESTS_TO_RUN} ")
    MATH(EXPR GROUP_MEMBERS "(${GROUP_MEMBERS}+1)%${PARALLEL_GROUP_SIZE}")
  endif()
endforeach(TEST_FILE)
file(APPEND ${TEST_SCHEDULE} "\n")
