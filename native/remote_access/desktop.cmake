find_program(OPENPLAYX_GO go REQUIRED)
set(REMOTE_CORE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native/remote_access")
if(WIN32)
  set(REMOTE_CORE_LIBRARY "${CMAKE_CURRENT_BINARY_DIR}/openplayx_remote.dll")
else()
  set(REMOTE_CORE_LIBRARY "${CMAKE_CURRENT_BINARY_DIR}/libopenplayx_remote.so")
endif()
file(GLOB REMOTE_CORE_SOURCES "${REMOTE_CORE_DIR}/*.go")
add_custom_command(OUTPUT "${REMOTE_CORE_LIBRARY}"
  COMMAND ${CMAKE_COMMAND} -E env CGO_ENABLED=1 ${OPENPLAYX_GO} build
    -trimpath -tags with_reality,with_utls -buildmode=c-shared -o "${REMOTE_CORE_LIBRARY}" .
  WORKING_DIRECTORY "${REMOTE_CORE_DIR}"
  DEPENDS ${REMOTE_CORE_SOURCES} "${REMOTE_CORE_DIR}/go.mod" "${REMOTE_CORE_DIR}/go.sum"
  VERBATIM)
add_custom_target(openplayx_remote_core ALL DEPENDS "${REMOTE_CORE_LIBRARY}")
add_dependencies(${BINARY_NAME} openplayx_remote_core)
install(FILES "${REMOTE_CORE_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
