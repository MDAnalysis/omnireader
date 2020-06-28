cmake_minimum_required(VERSION 3.16)
project(omnireader)

set(CMAKE_CXX_STANDARD 98)

add_library(omnireader SHARED omnireader.h
        omnibase.cpp omnibase.h
        PlainTextReader.cpp PlainTextReader.h)

add_executable(test_lines test_lines.cpp)
target_link_libraries(test_lines omnireader)