cmake_minimum_required(VERSION 3.21)
project(caj2pdf-native LANGUAGES C CXX)

# JBIG2 backend selection
set(JBIG2_BACKEND "poppler" CACHE STRING "JBIG2 backend: poppler or jbig2dec")
set_property(CACHE JBIG2_BACKEND PROPERTY STRINGS poppler jbig2dec)

find_package(PkgConfig REQUIRED)

# --- libjbigdec ---
# Self-contained JBIG decoder; no external dependencies.
add_library(jbigdec SHARED lib/jbigdec.cc lib/JBigDecode.cc)
target_include_directories(jbigdec PRIVATE lib)
set_target_properties(jbigdec PROPERTIES POSITION_INDEPENDENT_CODE ON)
set_target_properties(jbigdec PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")

if(WIN32)
    math(EXPR BITNESS "8 * ${CMAKE_SIZEOF_VOID_P}")
    set_target_properties(jbigdec PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "jbigdec-w${BITNESS}"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin")
endif()

# --- libjbig2codec ---
# Backend chosen at configure time via -DJBIG2_BACKEND=poppler|jbig2dec
if(JBIG2_BACKEND STREQUAL "poppler")
    pkg_check_modules(POPPLER REQUIRED poppler)
    add_library(jbig2codec SHARED lib/decode_jbig2data.cc)
    target_include_directories(jbig2codec PRIVATE ${POPPLER_INCLUDE_DIRS})
    target_link_libraries(jbig2codec PRIVATE ${POPPLER_LIBRARIES})
    target_compile_options(jbig2codec PRIVATE ${POPPLER_CFLAGS_OTHER})
elseif(JBIG2_BACKEND STREQUAL "jbig2dec")
    pkg_check_modules(JBIG2DEC REQUIRED jbig2dec)
    add_library(jbig2codec SHARED lib/decode_jbig2data_x.cc)
    target_include_directories(jbig2codec PRIVATE ${JBIG2DEC_INCLUDE_DIRS})
    target_link_libraries(jbig2codec PRIVATE ${JBIG2DEC_LIBRARIES})
    target_compile_options(jbig2codec PRIVATE ${JBIG2DEC_CFLAGS_OTHER})
else()
    message(FATAL_ERROR "JBIG2_BACKEND must be 'poppler' or 'jbig2dec' (got: ${JBIG2_BACKEND})")
endif()

set_target_properties(jbig2codec PROPERTIES POSITION_INDEPENDENT_CODE ON)
set_target_properties(jbig2codec PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")

if(WIN32)
    math(EXPR BITNESS "8 * ${CMAKE_SIZEOF_VOID_P}")
    set_target_properties(jbig2codec PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "jbig2codec-w${BITNESS}"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin")
endif()
