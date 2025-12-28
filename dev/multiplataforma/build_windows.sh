#!/bin/bash
# Script para construir instalador Qt para Windows desde Linux

echo "🪟 Construyendo instalador para Windows..."

# Instalar dependencias necesarias (si usas MXE)
sudo apt-get update
sudo apt-get install -y mxe-i686-w64-mingw32.static-qtbase \
                       mxe-i686-w64-mingw32.static-qttools

# Limpiar
rm -rf build_windows
mkdir -p build_windows
cd build_windows

# Configurar para Windows usando MXE
/usr/lib/mxe/usr/bin/i686-w64-mingw32.static-qmake-qt5 ../AtlasInstaller.pro

# Compilar
make -j$(nproc)

if [ -f "release/AtlasInstaller.exe" ]; then
    echo "✅ Compilación para Windows exitosa!"
    
    # Crear instalador NSIS (opcional pero recomendado)
    echo "📦 Creando instalador NSIS..."
    
    cat > AtlasInstaller.nsi << 'EOF'
Unicode true
Name "Atlas Interactivo"
OutFile "AtlasInteractivo_Setup.exe"
InstallDir "$PROGRAMFILES\Atlas Interactivo"
RequestExecutionLevel admin

!include MUI2.nsh

!define MUI_ICON "icons/windows_icon.ico"
!define MUI_UNICON "icons/windows_icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "header.bmp"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "Spanish"

Section "Instalar Atlas Interactivo"
    SetOutPath "$INSTDIR"
    
    # Copiar archivos
    File "release\AtlasInstaller.exe"
    File "LICENSE.txt"
    File "README.txt"
    
    # Crear acceso directo
    CreateDirectory "$SMPROGRAMS\Atlas Interactivo"
    CreateShortCut "$SMPROGRAMS\Atlas Interactivo\Atlas Interactivo.lnk" "$INSTDIR\AtlasInstaller.exe"
    CreateShortCut "$DESKTOP\Atlas Interactivo.lnk" "$INSTDIR\AtlasInstaller.exe"
    
    # Escribir entrada en registro para desinstalador
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\AtlasInteractivo" \
        "DisplayName" "Atlas Interactivo"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\AtlasInteractivo" \
        "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\AtlasInteractivo" \
        "DisplayIcon" "$INSTDIR\AtlasInstaller.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\AtlasInteractivo" \
        "Publisher" "Atlas Interactivo Team"
    
    # Crear desinstalador
    WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
    Delete "$INSTDIR\AtlasInstaller.exe"
    Delete "$INSTDIR\LICENSE.txt"
    Delete "$INSTDIR\README.txt"
    Delete "$INSTDIR\uninstall.exe"
    
    # Eliminar accesos directos
    Delete "$SMPROGRAMS\Atlas Interactivo\Atlas Interactivo.lnk"
    Delete "$DESKTOP\Atlas Interactivo.lnk"
    RMDir "$SMPROGRAMS\Atlas Interactivo"
    
    # Eliminar entrada del registro
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\AtlasInteractivo"
    
    # Eliminar directorio si está vacío
    RMDir "$INSTDIR"
SectionEnd
EOF

    # Crear instalador con NSIS (si está instalado)
    if command -v makensis >/dev/null 2>&1; then
        makensis AtlasInstaller.nsi
        echo "✅ Instalador Windows creado: AtlasInteractivo_Setup.exe"
    else
        echo "⚠️  NSIS no instalado. Solo se generó: release/AtlasInstaller.exe"
        echo "   Para crear instalador completo, instala: sudo apt install nsis"
    fi
    
else
    echo "❌ Error al compilar para Windows"
    exit 1
fi