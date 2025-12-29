📦 ARCHIVOS PARA DISTRIBUCIÓN ATLAS

ARCHIVOS PRINCIPALES:
1. AtlasInstaller.exe     - Instalador Windows GUI (C# .NET/WinForms)
2. AtlasInstallerQt       - Instalador Linux GUI (Qt5)

REQUISITOS DE EJECUCIÓN:

WINDOWS:
- Windows 10/11
- .NET 8 Runtime (si se compiló con .NET SDK)
- O Windows Runtime incluido (si se compiló con Mono)

LINUX:
- Distribución basada en Debian/Ubuntu recomendada
- Qt5 libraries: sudo apt install libqt5widgets5 libqt5gui5 libqt5core5a
- tar: sudo apt install tar
- wget o curl: sudo apt install wget

ARCHIVOS DE DATOS EN GOOGLE DRIVE:
3. Atlas_Windows_v1.0.0.zip  - Datos Windows completo (~20GB)
4. Atlas_Linux_v1.0.0.tar    - Datos Linux completo (~13GB) - NOTA: Formato .tar

INSTALACIÓN:

WINDOWS:
1. Descargar AtlasInstaller.exe
2. Ejecutar como administrador (si es necesario)
3. Seguir instrucciones en pantalla

LINUX:
1. Descargar AtlasInstallerQt
2. Terminal: chmod +x AtlasInstallerQt
3. Terminal: ./AtlasInstallerQt
4. Seguir instrucciones en pantalla

PARA ACTUALIZAR:
- Los instaladores verifican actualizaciones automáticamente
- Se descargan solo los archivos modificados (MBs, no GBs)

CONTACTO Y SOPORTE:
- Issues en GitHub: https://github.com/adrianfb94/atlas-distribution
- Documentación: docs/index.html
