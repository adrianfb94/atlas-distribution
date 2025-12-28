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

CONFIGURACIÓN TÉCNICA:

PARA ACTUALIZAR LOS INSTALADORES:
1. Editar código fuente:
   - Windows: Windows_Installer_CSharp/MainWindow.xaml.cs
   - Linux: dev/build_qt_final.sh (installerwindow.cpp)

2. Reconstruir:
   - Opción A: python dev/create_patches.py build
   - Opción B: ./dev/build_installers.sh

3. Actualizar URLs en docs/download.js

PARA CREAR PARCHES DE DATOS:
1. python dev/create_patches.py windows  # Crear parche Windows
2. python dev/create_patches.py linux    # Crear parche Linux
3. Subir parches a Google Drive (carpeta patches/)
4. Actualizar patch_index.json en Drive

VERIFICACIÓN POST-CONSTRUCCIÓN:
✓ Probar instaladores en sistemas limpios
✓ Verificar que descargan correctamente
✓ Comprobar extracción y instalación
✓ Validar accesos directos/entradas .desktop

CONTACTO Y SOPORTE:
- Issues en GitHub: https://github.com/tu-usuario/Atlas_Interactivo
- Documentación: docs/README.md
