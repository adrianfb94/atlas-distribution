# #!/bin/bash
# # Atlas_Distribution/dev/build_installers.sh
# # Script completo para construir todos los instaladores

# echo "🚀 CONSTRUYENDO SISTEMA DE DISTRIBUCIÓN ATLAS"
# echo "============================================="

# # Colores para output
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# BLUE='\033[0;34m'
# NC='\033[0m' # No Color

# # Función para mostrar estado
# status() {
#     echo -e "${BLUE}[*]${NC} $1"
# }

# success() {
#     echo -e "${GREEN}[✓]${NC} $1"
# }

# warning() {
#     echo -e "${YELLOW}[!]${NC} $1"
# }

# error() {
#     echo -e "${RED}[✗]${NC} $1"
# }

# # 1. Verificar dependencias
# status "Verificando dependencias..."

# check_dependency() {
#     if command -v $1 &> /dev/null; then
#         success "$1 encontrado"
#         return 0
#     else
#         error "$1 no encontrado"
#         return 1
#     fi
# }

# check_dependency python3
# check_dependency pip
# check_dependency tar
# check_dependency zip
# check_dependency g++

# # 2. Instalar dependencias Python si faltan
# status "Instalando dependencias Python..."
# pip install requests tqdm pyinstaller --quiet 2>/dev/null
# if [ $? -eq 0 ]; then
#     success "Dependencias Python instaladas"
# else
#     warning "No se pudieron instalar todas las dependencias Python"
# fi

# # 3. Construir instalador Windows
# status "Construyendo instalador Windows..."
# cd "$(dirname "$0")"
# python3 create_patches.py build

# # 4. Construir instalador Linux C++
# status "Construyendo instalador Linux (C++)..."
# if [ -f "build_linux_installer.sh" ]; then
#     chmod +x build_linux_installer.sh
#     ./build_linux_installer.sh
# else
#     # Si no existe el script, compilar directamente
#     if [ -f "AtlasInstaller.cpp" ]; then
#         echo "Compilando AtlasInstaller.cpp..."
#         g++ -static -O2 -s -DNDEBUG -std=c++11 \
#             AtlasInstaller.cpp \
#             -o ../AtlasInstaller \
#             -lstdc++ -lm
        
#         size_mb=$(du -m ../AtlasInstaller 2>/dev/null | cut -f1 || echo "0")
#         success "Instalador Linux compilado (${size_mb}MB)"
#     else
#         warning "No se encontró AtlasInstaller.cpp"
#     fi
# fi


# status "Construyendo instalador Linux con GUI..."
# if [ -f "build_linux_gui.sh" ]; then
#     chmod +x build_linux_gui.sh
#     ./build_linux_gui.sh
# fi


# # 5. Verificar archivos generados
# status "Verificando archivos generados..."

# generated_files=0

# if [ -f "../AtlasInstaller.exe" ]; then
#     size_kb=$(du -k ../AtlasInstaller.exe | cut -f1)
#     size_mb=$(echo "scale=2; $size_kb/1024" | bc)
#     success "AtlasInstaller.exe generado (${size_mb}MB)"
#     generated_files=$((generated_files + 1))
# else
#     warning "AtlasInstaller.exe no generado (necesita compilación C#)"
# fi

# if [ -f "../AtlasInstaller" ]; then
#     size_kb=$(du -k ../AtlasInstaller | cut -f1)
#     size_mb=$(echo "scale=2; $size_kb/1024" | bc)
#     success "AtlasInstaller (Linux) generado (${size_mb}MB)"
#     generated_files=$((generated_files + 1))
# elif [ -f "../AtlasInstaller.AppImage" ]; then
#     size_kb=$(du -k ../AtlasInstaller.AppImage | cut -f1)
#     size_mb=$(echo "scale=2; $size_kb/1024" | bc)
#     success "AtlasInstaller.AppImage generado (${size_mb}MB)"
#     generated_files=$((generated_files + 1))
# else
#     warning "Instalador Linux no generado"
# fi

# # 6. Crear estructura para Drive
# status "Preparando estructura para Google Drive..."
# DRIVE_DIR="../drive_files_for_upload"
# mkdir -p "$DRIVE_DIR"
# mkdir -p "$DRIVE_DIR/patches/windows"
# mkdir -p "$DRIVE_DIR/patches/linux"

# # Mover instaladores si existen
# [ -f "../AtlasInstaller.exe" ] && cp "../AtlasInstaller.exe" "$DRIVE_DIR/"
# [ -f "../AtlasInstaller" ] && cp "../AtlasInstaller" "$DRIVE_DIR/"
# [ -f "../AtlasInstaller.AppImage" ] && cp "../AtlasInstaller.AppImage" "$DRIVE_DIR/"

# # 7. Generar README para Drive
# cat > "$DRIVE_DIR/README.txt" << 'EOF'
# 📦 ARCHIVOS PARA DISTRIBUCIÓN ATLAS

# ARCHIVOS PRINCIPALES:
# 1. AtlasInstaller.exe - Instalador para Windows (~20KB)
# 2. AtlasInstaller - Instalador para Linux (~2MB, binario C++)

# ARCHIVOS DE DATOS (subir a otra carpeta):
# 3. Atlas_Windows_v1.0.0.zip - Juego completo Windows (20GB)
# 4. Atlas_Linux_v1.0.0.tar.gz - Juego completo Linux (13GB)

# USO DEL INSTALADOR LINUX (C++):
# - Es un binario nativo, no necesita Python
# - Ejecutar en terminal: ./AtlasInstaller
# - Menú interactivo con verificación de espacio
# - Descarga automática desde Google Drive

# ACTUALIZACIONES:
# 1. Crear parches con: python create_patches.py [windows|linux]
# 2. Subir archivos .zip/.tar.gz a carpeta patches/
# 3. Actualizar patch_index.json
# EOF

# success "Estructura preparada en: $DRIVE_DIR"

# # 8. Mostrar resumen
# echo ""
# echo "============================================="
# echo "✅ CONSTRUCCIÓN COMPLETADA"
# echo "============================================="
# echo ""
# echo "ARCHIVOS GENERADOS: $generated_files/2"
# echo ""
# echo "📁 CARPETA PARA SUBIR A DRIVE:"
# ls -lh "$DRIVE_DIR/" 2>/dev/null || ls -la "$DRIVE_DIR/"
# echo ""
# echo "📋 PRÓXIMOS PASOS:"
# echo "1. Subir AtlasInstaller.exe y AtlasInstaller a GitHub"
# echo "2. Subir los archivos grandes (ZIP/TAR) a Google Drive"
# echo "3. Actualizar los IDs en docs/download.js"
# echo "4. Actualizar tu página web con los nuevos enlaces"
# echo ""
# echo "🔗 Para actualizaciones futuras:"
# echo "   python create_patches.py windows  (para parche Windows)"
# echo "   python create_patches.py linux    (para parche Linux)"
# echo ""







# #!/bin/bash
# # Atlas_Distribution/dev/build_installers.sh
# # Script completo para construir todos los instaladores

# echo "🚀 CONSTRUYENDO SISTEMA DE DISTRIBUCIÓN ATLAS"
# echo "============================================="

# # Colores para output
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# BLUE='\033[0;34m'
# NC='\033[0m' # No Color

# # Función para mostrar estado
# status() {
#     echo -e "${BLUE}[*]${NC} $1"
# }

# success() {
#     echo -e "${GREEN}[✓]${NC} $1"
# }

# warning() {
#     echo -e "${YELLOW}[!]${NC} $1"
# }

# error() {
#     echo -e "${RED}[✗]${NC} $1"
# }

# # 1. Verificar dependencias
# status "Verificando dependencias..."

# check_dependency() {
#     if command -v $1 &> /dev/null; then
#         success "$1 encontrado"
#         return 0
#     else
#         error "$1 no encontrado"
#         return 1
#     fi
# }

# check_dependency python3
# check_dependency pip
# check_dependency tar
# check_dependency zip
# check_dependency g++

# # 2. Instalar dependencias Python si faltan
# status "Instalando dependencias Python..."
# pip install requests tqdm pyinstaller --quiet 2>/dev/null
# if [ $? -eq 0 ]; then
#     success "Dependencias Python instaladas"
# else
#     warning "No se pudieron instalar todas las dependencias Python"
# fi

# # 3. Construir instalador Windows
# status "Construyendo instalador Windows..."
# cd "$(dirname "$0")"
# python3 create_patches.py build

# # 4. Construir instalador Linux Qt
# status "Construyendo instalador Linux Qt..."
# if [ -f "build_qt_final.sh" ]; then
#     chmod +x build_qt_final.sh
#     ./build_qt_final.sh
# elif [ -f "AtlasInstallerQt" ]; then
#     success "Instalador Qt ya existe"
# else
#     warning "No se encontró script de construcción Qt"
#     # Intentar construir instalador consola C++ como fallback
#     if [ -f "AtlasInstaller.cpp" ]; then
#         status "Construyendo instalador consola C++ como fallback..."
#         g++ -static -O2 -s -DNDEBUG -std=c++11 \
#             AtlasInstaller.cpp \
#             -o ../AtlasInstaller \
#             -lstdc++ -lm
#     fi
# fi

# # 5. Verificar archivos generados
# status "Verificando archivos generados..."

# generated_files=0

# if [ -f "../AtlasInstaller.exe" ]; then
#     size_kb=$(du -k ../AtlasInstaller.exe | cut -f1)
#     size_mb=$(echo "scale=2; $size_kb/1024" | bc)
#     success "AtlasInstaller.exe generado (${size_mb}MB)"
#     generated_files=$((generated_files + 1))
# else
#     warning "AtlasInstaller.exe no generado (necesita compilación C#)"
# fi

# if [ -f "../AtlasInstallerQt" ]; then
#     size_kb=$(du -k ../AtlasInstallerQt | cut -f1)
#     size_mb=$(echo "scale=2; $size_kb/1024" | bc)
#     success "AtlasInstallerQt generado (${size_mb}MB)"
#     generated_files=$((generated_files + 1))
# elif [ -f "../AtlasInstaller" ]; then
#     size_kb=$(du -k ../AtlasInstaller | cut -f1)
#     size_mb=$(echo "scale=2; $size_kb/1024" | bc)
#     success "AtlasInstaller (consola) generado (${size_mb}MB)"
#     generated_files=$((generated_files + 1))
# elif [ -f "../AtlasInstaller.AppImage" ]; then
#     size_kb=$(du -k ../AtlasInstaller.AppImage | cut -f1)
#     size_mb=$(echo "scale=2; $size_kb/1024" | bc)
#     success "AtlasInstaller.AppImage generado (${size_mb}MB)"
#     generated_files=$((generated_files + 1))
# else
#     warning "Instalador Linux no generado"
# fi

# # 6. Preparar para distribución
# status "Preparando para distribución..."
# DRIVE_DIR="../drive_files_for_upload"
# mkdir -p "$DRIVE_DIR"

# # Copiar instaladores
# [ -f "../AtlasInstaller.exe" ] && cp "../AtlasInstaller.exe" "$DRIVE_DIR/"
# [ -f "../AtlasInstallerQt" ] && cp "../AtlasInstallerQt" "$DRIVE_DIR/"
# [ -f "../AtlasInstaller" ] && cp "../AtlasInstaller" "$DRIVE_DIR/"

# # Generar README
# cat > "$DRIVE_DIR/README.txt" << 'EOF'
# 📦 ARCHIVOS PARA DISTRIBUCIÓN ATLAS

# ARCHIVOS PRINCIPALES:
# 1. AtlasInstaller.exe - Instalador Windows GUI (~20KB)
# 2. AtlasInstallerQt - Instalador Linux Qt GUI (~5-10MB)
# 3. AtlasInstaller - Instalador Linux consola (~2MB)

# ARCHIVOS DE DATOS EN GOOGLE DRIVE:
# 4. Atlas_Windows_v1.0.0.zip - Windows completo (20GB)
# 5. Atlas_Linux_v1.0.0.tar.gz - Linux completo (13GB)

# CONFIGURACIÓN DEL INSTALADOR QT:
# - El instalador Qt descarga automáticamente desde Google Drive
# - ID de Drive configurado en: installerwindow.cpp (línea con driveId)
# - Actualizar ese ID si cambia la ubicación del archivo

# PARA ACTUALIZAR:
# 1. python create_patches.py windows  # Crear parche Windows
# 2. python create_patches.py linux    # Crear parche Linux
# 3. Subir parches a carpeta patches/ en Drive
# 4. Actualizar patch_index.json
# EOF

# success "Preparado en: $DRIVE_DIR"

# # 7. Mostrar resumen
# echo ""
# echo "============================================="
# echo "✅ CONSTRUCCIÓN COMPLETADA"
# echo "============================================="
# echo ""
# echo "ARCHIVOS GENERADOS: $generated_files/2"
# echo ""
# echo "📁 CARPETA PARA DISTRIBUCIÓN:"
# ls -lh "$DRIVE_DIR/" 2>/dev/null || ls -la "$DRIVE_DIR/"
# echo ""
# echo "📋 PRÓXIMOS PASOS:"
# echo "1. Subir AtlasInstaller.exe a GitHub/Drive"
# echo "2. Subir AtlasInstallerQt a GitHub/Drive"
# echo "3. Verificar ID de Google Drive en installerwindow.cpp"
# echo "4. Actualizar docs/download.js con URLs correctas"
# echo ""
# echo "🔗 Para crear parches:"
# echo "   python create_patches.py windows"
# echo "   python create_patches.py linux"
# echo ""



#!/bin/bash
# Atlas_Distribution/dev/build_installers.sh
# Script completo para construir todos los instaladores

echo "🚀 CONSTRUYENDO SISTEMA DE DISTRIBUCIÓN ATLAS"
echo "============================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar estado
status() {
    echo -e "${BLUE}[*]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 1. Verificar dependencias
status "Verificando dependencias..."

check_dependency() {
    if command -v $1 &> /dev/null; then
        success "$1 encontrado"
        return 0
    else
        error "$1 no encontrado"
        return 1
    fi
}

check_dependency python3
check_dependency pip
check_dependency tar
check_dependency zip
check_dependency g++

# 2. Instalar dependencias Python si faltan
status "Instalando dependencias Python..."
pip install requests tqdm pyinstaller --quiet 2>/dev/null
if [ $? -eq 0 ]; then
    success "Dependencias Python instaladas"
else
    warning "No se pudieron instalar todas las dependencias Python"
fi

# 3. Construir instalador Windows
status "Construyendo instalador Windows..."
cd "$(dirname "$0")"
python3 create_patches.py build

# 4. Construir instalador Linux Qt
status "Construyendo instalador Linux Qt..."
if [ -f "build_qt_final.sh" ]; then
    chmod +x build_qt_final.sh
    ./build_qt_final.sh
elif [ -f "AtlasInstallerQt" ]; then
    success "Instalador Qt ya existe"
else
    warning "No se encontró script de construcción Qt"
    # NOTA: Se eliminó el fallback de C++ consola
fi

# 5. Verificar archivos generados
status "Verificando archivos generados..."

generated_files=0

if [ -f "../AtlasInstaller.exe" ]; then
    size_kb=$(du -k ../AtlasInstaller.exe | cut -f1)
    size_mb=$(echo "scale=2; $size_kb/1024" | bc)
    success "AtlasInstaller.exe generado (${size_mb}MB)"
    generated_files=$((generated_files + 1))
else
    warning "AtlasInstaller.exe no generado (necesita compilación C#)"
fi

if [ -f "../AtlasInstallerQt" ]; then
    size_kb=$(du -k ../AtlasInstallerQt | cut -f1)
    size_mb=$(echo "scale=2; $size_kb/1024" | bc)
    success "AtlasInstallerQt generado (${size_mb}MB)"
    generated_files=$((generated_files + 1))
else
    warning "Instalador Linux Qt no generado"
fi

# 6. Preparar para distribución
status "Preparando para distribución..."
DRIVE_DIR="../upload2github"
mkdir -p "$DRIVE_DIR"

# Copiar instaladores (solo los dos principales)
[ -f "../AtlasInstaller.exe" ] && cp "../AtlasInstaller.exe" "$DRIVE_DIR/"
[ -f "../AtlasInstallerQt" ] && cp "../AtlasInstallerQt" "$DRIVE_DIR/"

# Generar README actualizado
cat > "$DRIVE_DIR/README.txt" << 'EOF'
📦 ARCHIVOS PARA DISTRIBUCIÓN ATLAS

ARCHIVOS PRINCIPALES:
1. AtlasInstaller.exe - Instalador Windows GUI (C# .NET)
2. AtlasInstallerQt - Instalador Linux GUI (Qt5)

ARCHIVOS DE DATOS EN GOOGLE DRIVE:
3. Atlas_Windows_v1.0.0.zip - Windows completo (20GB)
4. Atlas_Linux_v1.0.0.tar - Linux completo (13GB) - NOTA: es .tar, NO .tar.gz

CONFIGURACIÓN DE LOS INSTALADORES:

WINDOWS (C#):
- El instalador Windows se compila con Visual Studio o .NET SDK
- Archivo principal: Windows_Installer_CSharp/AtlasInstaller.sln
- Actualizar URL de descarga en MainWindow.xaml.cs

LINUX (Qt):
- El instalador Qt descarga automáticamente desde Google Drive
- ID de Drive configurado en: installerwindow.cpp (línea con driveId)
- Formato del archivo debe ser .tar (sin compresión)
- Actualizar ID si cambia la ubicación del archivo

PARA ACTUALIZAR DATOS:
1. python create_patches.py windows  # Crear parche Windows
2. python create_patches.py linux    # Crear parche Linux
3. Subir parches a carpeta patches/ en Drive
4. Actualizar patch_index.json
EOF

success "Preparado en: $DRIVE_DIR"

# 7. Mostrar resumen
echo ""
echo "============================================="
echo "✅ CONSTRUCCIÓN COMPLETADA"
echo "============================================="
echo ""
echo "ARCHIVOS GENERADOS: $generated_files/2"
echo ""
echo "📁 CARPETA PARA DISTRIBUCIÓN:"
ls -lh "$DRIVE_DIR/" 2>/dev/null || ls -la "$DRIVE_DIR/"
echo ""
echo "📋 PRÓXIMOS PASOS:"
echo "1. Subir AtlasInstaller.exe a GitHub/Drive"
echo "2. Subir AtlasInstallerQt a GitHub/Drive"
echo "3. Verificar que el archivo Linux en Drive sea .tar (NO .tar.gz)"
echo "4. Actualizar docs/download.js con URLs correctas"
echo ""
echo "🔗 Para crear parches:"
echo "   python create_patches.py windows"
echo "   python create_patches.py linux"
echo ""