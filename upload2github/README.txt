📦 ARCHIVOS PARA DISTRIBUCIÓN ATLAS

ARCHIVOS PRINCIPALES:
1. AtlasInstaller.exe           - Instalador Windows GUI (C# .NET/WinForms)
2. AtlasInstallerQt             - Instalador Linux GUI (Qt5)
3. AtlasInstallerQt_plus  - Instalador Universal Linux (auto-dependencias)

REQUISITOS:

WINDOWS:
- Windows 10/11
- .NET 8 Runtime o Windows Runtime incluido

LINUX (AtlasInstallerQt):
- Qt5 libraries: sudo apt install libqt5widgets5 libqt5gui5 libqt5core5a
- tar, wget/curl

LINUX (Universal):
- Solo requiere bash, auto-instala dependencias

INSTALACIÓN:

WINDOWS:
1. Descargar AtlasInstaller.exe
2. Ejecutar como administrador
3. Seguir instrucciones en pantalla

LINUX Qt:
1. Descargar AtlasInstallerQt
2. chmod +x AtlasInstallerQt
3. ./AtlasInstallerQt

LINUX Universal (RECOMENDADO):
1. Descargar AtlasInstallerQt_plus
2. chmod +x AtlasInstallerQt_plus  
3. ./AtlasInstallerQt_plus
   (Auto-instala dependencias y ejecuta)

ARCHIVOS DE DATOS:
- Atlas_Windows_v1.0.0.zip (~20GB)
- Atlas_Linux_v1.0.0.tar (~13GB)

CONTACTO:
- GitHub: https://github.com/adrianfb94/atlas-distribution
- Documentación: docs/index.html
