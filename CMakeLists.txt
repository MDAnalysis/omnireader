cmake_minimum_required(VERSION 3.16)
project(omnireader)

set(CMAKE_CXX_STANDARD 98)

add_library(omnireader SHARED omnireader.h
        omnibase.cpp omnibase.h
        PlainTextReader.cpp PlainTextReader.h
        BZ2Reader.h)
target_include_directories(omnireader PUBLIC /home/richard/miniconda3/envs/mda/include)
target_link_libraries(omnireader /home/richard/miniconda3/envs/mda/lib/libbz2.so)

add_executable(test_lines test_lines.cpp)
target_include_directories(test_lines PUBLIC /home/richard/miniconda3/envs/mda/include)
target_link_libraries(test_lines omnireader)