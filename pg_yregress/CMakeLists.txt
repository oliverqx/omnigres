cmake_minimum_required(VERSION 3.25.1)
project(pg_yregress)

if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    # Top-level
    list(PREPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
else()
    list(PREPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/../cmake)
endif()

find_package(PostgreSQL REQUIRED)
find_program(PG_CONFIG pg_config REQUIRED)

include(CPM)
include(../cmake/dependencies/versions.cmake)
CPMAddPackage(NAME libfyaml SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/../deps/libfyaml VERSION ${VERSION_libfyaml}
        EXCLUDE_FROM_ALL YES OPTIONS "BUILD_SHARED_LIBS OFF")

include(CTest)

add_executable(pg_yregress pg_yregress.c instance.c test.c sighandler.c str.c yaml.c)
target_link_libraries(pg_yregress PRIVATE fyaml pq)

# Enable GNU extensions for `asprintf`, `nftw`, etc.
if(NOT APPLE)
    target_compile_definitions(pg_yregress PUBLIC _GNU_SOURCE)
endif()

target_include_directories(pg_yregress PRIVATE ${PostgreSQL_INCLUDE_DIRS})
target_link_directories(pg_yregress PRIVATE ${PostgreSQL_LIBRARY_DIRS})

enable_testing()
add_test(NAME pg_yregress COMMAND "$<TARGET_FILE:pg_yregress>" "${CMAKE_CURRENT_LIST_DIR}/test.yml")
set_property(TEST pg_yregress PROPERTY ENVIRONMENT "PGCONFIG=${PG_CONFIG}")

install(TARGETS pg_yregress)