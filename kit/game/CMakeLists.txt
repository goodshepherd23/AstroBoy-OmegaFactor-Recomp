# Astro Boy: Omega Factor on gbarecomp. kit\setup.ps1 configures this with the
# downloaded gbarecomp source (GBARECOMP_ROOT), SDL2 (GBARECOMP_MINGW_PREFIX_UNIX)
# and toml++ (GBARECOMP_TOMLPP_INCLUDE_DIR); generated\ is translated from the
# player's ROM by gba_recompile before the game target is built.
cmake_minimum_required(VERSION 3.20)
project(AstroBoyRecomp C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(GBARECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/gbarecomp"
    CACHE PATH "Path to the gbarecomp source (commit c1a5fda, tag v0.4.1)")
set(GBARECOMP_GENERATED_BIOS_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated_bios"
    CACHE PATH "")

if(NOT EXISTS "${GBARECOMP_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "GBARECOMP_ROOT is not a gbarecomp source tree: ${GBARECOMP_ROOT}")
endif()

add_subdirectory("${GBARECOMP_ROOT}" gbarecomp_build EXCLUDE_FROM_ALL)

file(GLOB GAME_GENERATED_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/generated/*.cpp")

add_executable(AstroBoyRecomp
    src/main.cpp
    ${GAME_GENERATED_SOURCES}
)

# The translated game code is ~90 MB of C++; -O2 without debug info keeps the
# compile within a laptop's memory.
set(GAME_RECOMPILED_SOURCES ${GAME_GENERATED_SOURCES})
list(FILTER GAME_RECOMPILED_SOURCES INCLUDE REGEX "/recompiled_[0-9]+\\.cpp$")
if(GAME_RECOMPILED_SOURCES)
    set_source_files_properties(${GAME_RECOMPILED_SOURCES} PROPERTIES
        COMPILE_OPTIONS "-O2;-g0")
endif()

target_include_directories(AstroBoyRecomp PRIVATE
    "${GBARECOMP_ROOT}/src/armv4t"
    "${GBARECOMP_ROOT}/src/gba"
    "${GBARECOMP_ROOT}/src/runtime"
    "${GBARECOMP_ROOT}/src/debug"
    "${CMAKE_CURRENT_SOURCE_DIR}/generated")

target_link_libraries(AstroBoyRecomp PRIVATE
    "-Wl,--start-group"
    gbarecomp_runtime
    gbarecomp_debug
    gbarecomp_gba
    gbarecomp_armv4t
    "-Wl,--end-group")

target_compile_definitions(AstroBoyRecomp PRIVATE
    GBARECOMP_DEFAULT_DEBUG_PORT=19863
    GBARECOMP_WINDOW_TITLE="AstroBoyRecomp"
    GBARECOMP_DEFAULT_GAME_CONFIG="game.toml")

target_link_options(AstroBoyRecomp PRIVATE -Wl,--stack,16777216)
