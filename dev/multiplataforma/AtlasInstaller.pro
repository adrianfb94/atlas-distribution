# AtlasInstaller.pro - MULTIPLATAFORMA
QT += core gui widgets network
CONFIG += c++11

TARGET = AtlasInstaller
TEMPLATE = app

# Configuración específica por plataforma
win32 {
    RC_FILE = atlas_installer.rc
    ICON = icons/windows_icon.ico
    TARGET = AtlasInstaller.exe
    CONFIG += console  # Para ver logs en consola si es necesario
}

unix {
    TARGET = AtlasInstallerQt
}

SOURCES = main.cpp installerwindow.cpp
HEADERS = installerwindow.h