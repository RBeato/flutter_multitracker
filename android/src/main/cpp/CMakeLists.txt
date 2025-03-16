cmake_minimum_required(VERSION 3.4.1)

# Set C++17 as the standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set sfizz build options
set(SFIZZ_JACK OFF CACHE BOOL "Disable JACK support" FORCE)
set(SFIZZ_RENDER OFF CACHE BOOL "Disable offline render" FORCE)
set(SFIZZ_LV2 OFF CACHE BOOL "Disable LV2 plugin" FORCE)
set(SFIZZ_VST OFF CACHE BOOL "Disable VST plugin" FORCE)
set(SFIZZ_AU OFF CACHE BOOL "Disable AU plugin" FORCE)
set(SFIZZ_TESTS OFF CACHE BOOL "Disable tests" FORCE)
set(SFIZZ_DEVTOOLS OFF CACHE BOOL "Disable developer tools" FORCE)
set(SFIZZ_SHARED OFF CACHE BOOL "Build static library" FORCE)
set(SFIZZ_USE_SNDFILE OFF CACHE BOOL "Disable libsndfile" FORCE)

# Include sfizz root
add_subdirectory(external/sfizz)

# Define the library name
add_library(flutter_multitracker SHARED
    # Main JNI interface
    multitracker_jni.cpp
    
    # Audio engine
    audio_engine.cpp
    audio_engine.h
    
    # Instrument manager
    instrument_manager.cpp
    instrument_manager.h
    
    # Sequence manager
    sequence_manager.cpp
    sequence_manager.h
)

# Find required Android libraries
find_library(log-lib log)
find_library(android-lib android)
find_library(opensles-lib OpenSLES)

# Include directories
target_include_directories(flutter_multitracker PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/external/sfizz/src
    ${CMAKE_CURRENT_SOURCE_DIR}/external/sfizz/include
)

# Link against required libraries
target_link_libraries(flutter_multitracker
    # Android libraries
    ${log-lib}
    ${android-lib}
    ${opensles-lib}
    
    # sfizz library
    sfizz::sfizz
)

# Set compile options
target_compile_options(flutter_multitracker PRIVATE
    -Wall
    -Wextra
    -fexceptions
    -frtti
    -std=c++17
)

include_directories(${ANDROID_NDK}/sources/android/native_app_glue)
include_directories(${ANDROID_NDK}/sources/cxx-stl/llvm-libc++/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}) 