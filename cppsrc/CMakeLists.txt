project(omnireader)

cmake_minimum_required(VERSION 3.16)

find_package(ZLIB REQUIRED)
find_package(BZip2 REQUIRED)

set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS_RELEASE})

add_library(omnireader SHARED omnireader.h omnireader.cpp)

target_link_libraries(omnireader ${BZIP2_LIBRARIES})
target_include_directories(omnireader PRIVATE ${BZIP2_INCLUDE_DIRS})
target_link_libraries(omnireader ${ZLIB_LIBRARIES})
target_include_directories(omnireader PRIVATE ${ZLIB_INCLUDE_DIRS})

set_target_properties(omnireader
        PROPERTIES PUBLIC_HEADER "omnireader.h")

install(TARGETS omnireader
        DESTINATION lib
        PUBLIC_HEADER DESTINATION include
        )

add_executable(test_lines test_lines.cpp)
target_link_libraries(test_lines omnireader)

add_executable(test_seekntell test_seekntell.cpp)
target_link_libraries(test_seekntell omnireader)
