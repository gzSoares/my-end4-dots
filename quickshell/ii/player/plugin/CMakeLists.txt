cmake_minimum_required(VERSION 3.21)
project(MpvPlayer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick OpenGL)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)

qt_policy(SET QTP0001 NEW)
qt_add_qml_module(mpvplayer
    URI MpvPlayer
    VERSION 1.0
    PLUGIN_TARGET mpvplayer
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/MpvPlayer
    SOURCES mpvitem.h mpvitem.cpp
)
target_link_libraries(mpvplayer PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::OpenGL PkgConfig::MPV)
