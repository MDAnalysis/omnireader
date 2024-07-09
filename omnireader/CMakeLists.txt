add_cython_target(groreader CXX PY3 groreader.pyx)
add_library(groreader MODULE ${groreader})
python_extension_module(groreader)
target_link_libraries(groreader omnireader)

add_cython_target(xyzreader CXX PY3 xyzreader.pyx)
add_library(xyzreader MODULE ${xyzreader})
python_extension_module(xyzreader)
target_link_libraries(xyzreader omnireader)

if(APPLE)
    set_target_properties(groreader PROPERTIES INSTALL_RPATH "@loader_path")
else()
    set_target_properties(groreader PROPERTIES INSTALL_RPATH "\$ORIGIN")
    set_target_properties(xyzreader PROPERTIES INSTALL_RPATH "\$ORIGIN")
endif()

install(TARGETS groreader xyzreader
     LIBRARY DESTINATION omnireader)
