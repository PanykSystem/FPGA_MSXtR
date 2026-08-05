cmake_minimum_required(VERSION 3.15)
project(FpgaMsxUpdater LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(FpgaMsxUpdater WIN32 main.cpp)

if(MSVC)
    target_compile_definitions(FpgaMsxUpdater PRIVATE UNICODE _UNICODE)
    target_compile_options(FpgaMsxUpdater PRIVATE /W3 /utf-8)
endif()

target_link_libraries(FpgaMsxUpdater PRIVATE
    comctl32
    setupapi
    shlwapi
    comdlg32
)
