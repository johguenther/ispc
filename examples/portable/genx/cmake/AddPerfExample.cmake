#
#  Copyright (c) 2019-2020, Intel Corporation
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are
#  met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#
#    * Neither the name of Intel Corporation nor the names of its
#      contributors may be used to endorse or promote products derived from
#      this software without specific prior written permission.
#
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
#   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
#   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
#   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
#   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
#   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

function(add_perf_example)
    set(options CM_TEST)
    set(oneValueArgs ISPC_SRC_NAME ISPC_TARGET CM_SRC_NAME CM_OBJ_NAME TEST_NAME CM_TEST_NAME)
    set(multiValueArgs ISPC_FLAGS HOST_SOURCES CM_HOST_SOURCES CM_HOST_FLAGS)
    cmake_parse_arguments("parsed" "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    # Compile host code
    if (NOT HOST_SOURCES)
        return()
    endif()
    set(HOST_EXECUTABLE "host_${parsed_TEST_NAME}")

    set(CMAKE_POSITION_INDEPENDENT_CODE ON)

    add_executable(${HOST_EXECUTABLE} ${parsed_HOST_SOURCES})

    # Compile device code
    set(ISPC_EXECUTABLE_GPU ${ISPC_EXECUTABLE})
    set(ISPC_TARGET_GEN ${parsed_ISPC_TARGET})
    set(ISPC_TARGET_DIR ${CMAKE_CURRENT_BINARY_DIR})
    add_ispc_kernel(${parsed_TEST_NAME} ${parsed_ISPC_SRC_NAME} "")

    # Show ispc source in VS solution:
    if (WIN32)
        set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/${parsed_ISPC_SRC_NAME}" PROPERTIES HEADER_FILE_ONLY TRUE)
    endif()

    if (WIN32)
        message(WARNING "Gen examples are not supported on Windows")
        set_target_properties(${HOST_EXECUTABLE} PROPERTIES FOLDER "GEN_Examples")
    else()
        target_compile_definitions(${HOST_EXECUTABLE} PRIVATE ISPCRT)
        target_include_directories(${HOST_EXECUTABLE} PRIVATE ${COMMON_PATH})
        if (ISPC_BUILD)
            target_link_libraries(${HOST_EXECUTABLE} ispcrt)
        else()
            target_link_libraries(${HOST_EXECUTABLE} PRIVATE ispcrt::ispcrt)
        endif()
        set_target_properties(${HOST_EXECUTABLE} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    endif()

    # Compile CM kernel if present
    if (parsed_CM_TEST AND CMC_EXECUTABLE)
        set(parsed_TEST_NAME "${parsed_TEST_NAME}_cm")
        set(CM_TEST_NAME "${parsed_TEST_NAME}")
        set(CM_HOST_BINARY "host_${parsed_TEST_NAME}")
        list(APPEND CM_BUILD_OUTPUT ${parsed_CM_OBJ_NAME})
        add_executable(${CM_HOST_BINARY} ${parsed_CM_HOST_SOURCES} ${parsed_CM_OBJ_NAME})
        if (WIN32)
            message(WARNING "GEN examples are not supported on Windows")
            set_target_properties(${CM_HOST_BINARY} PROPERTIES FOLDER "GEN_Examples")
        else()
            add_custom_command(
               OUTPUT ${parsed_CM_OBJ_NAME}
               COMMAND ${CMC_EXECUTABLE} -march=SKL -fcmocl "-DCM_PTRSIZE=64" -emit-spirv -o ${parsed_CM_OBJ_NAME} ${CMAKE_CURRENT_SOURCE_DIR}/${parsed_CM_SRC_NAME}.cpp
               VERBATIM
               DEPENDS ${CMC_EXECUTABLE}
            )
            target_compile_definitions(${CM_HOST_BINARY} PRIVATE ISPCRT CMKERNEL)
            target_include_directories(${CM_HOST_BINARY} PRIVATE ${COMMON_PATH})
            target_link_libraries(${CM_HOST_BINARY} ze_loader)
            set_target_properties(${CM_HOST_BINARY} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
        endif()
    endif()
endfunction()
