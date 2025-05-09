cmake_minimum_required(VERSION 3.25.1)
project(omni_types)

list(PREPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/../../cmake)

include(CPM)
include(CTest)

enable_testing()

find_package(PostgreSQL REQUIRED)

if (${PostgreSQL_VERSION_STRING} MATCHES "PostgreSQL 13.*")
    set(requirements omni_polyfill) # for trim_array
endif ()

add_postgresql_extension(
        omni_types
        COMMENT "Advanced types"
        SCHEMA omni_types
        RELOCATABLE false
        SOURCES omni_types.c unit.c sum_type.c funsig_type.c
        REQUIRES ${requirements}
        TESTS_REQUIRE dblink
)

add_library(libomnitypes INTERFACE)
target_include_directories(libomnitypes INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
