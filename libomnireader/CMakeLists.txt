set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

find_package(ZLIB REQUIRED)
find_package(BZip2 REQUIRED)

add_library(omnireader SHARED)
target_sources(omnireader PRIVATE "src/omnireader.cpp")
target_include_directories(omnireader PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}
        "${CMAKE_CURRENT_LIST_DIR}/include")

target_link_libraries(omnireader ${BZIP2_LIBRARIES})
target_include_directories(omnireader PRIVATE ${BZIP2_INCLUDE_DIRS})
target_link_libraries(omnireader ${ZLIB_LIBRARIES})
target_include_directories(omnireader PRIVATE ${ZLIB_INCLUDE_DIRS})

set_target_properties(omnireader
        PROPERTIES PUBLIC_HEADER "include/omnireader.h")

install(TARGETS omnireader
        DESTINATION omnireader
        PUBLIC_HEADER DESTINATION include
        )

add_executable(test_lines test/test_lines.cpp)
target_link_libraries(test_lines omnireader)

add_executable(test_seekntell test/test_seekntell.cpp)
target_link_libraries(test_seekntell omnireader)
