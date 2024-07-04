add_cython_target(groreader CXX PY3 groreader.pyx)

add_library(groreader MODULE ${groreader})
python_extension_module(groreader)
target_link_libraries(groreader omnireader)

if(APPLE)
    set_target_properties(groreader PROPERTIES INSTALL_RPATH "@loader_path")
else()
    set_target_properties(groreader PROPERTIES INSTALL_RPATH "\$ORIGIN")
endif()

# install(TARGETS groreader LIBRARY DESTINATION omnireader)
