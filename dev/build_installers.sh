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

# 2. Instalar dependencias Python si faltan
status "Instalando dependencias Python..."
pip install requests tqdm pyinstaller --quiet 2>/dev/null
if [ $? -eq 0 ]; then
    success "Dependencias Python instaladas"
else
    warning "No se pudieron instalar todas las dependencias Python"
fi

# 3. Construir instaladores con el script Python
status "Construyendo instaladores..."
cd "$(dirname "$0")"
python3 create_patches.py build

# 4. Verificar archivos generados
status "Verificando archivos generados..."

generated_files=0

if [ -f "../AtlasInstaller.exe" ]; then
    success "AtlasInstaller.exe generado"
    generated_files=$((generated_files + 1))
else
    warning "AtlasInstaller.exe no generado (necesita compilación C#)"
fi

if [ -f "../AtlasInstaller.AppImage" ]; then
    success "AtlasInstaller.AppImage generado"
    generated_files=$((generated_files + 1))
elif [ -f "dist/AtlasInstaller" ]; then
    success "AtlasInstaller (binario Linux) generado en dist/"
    generated_files=$((generated_files + 1))
fi

# 5. Crear estructura para Drive
status "Preparando estructura para Google Drive..."
DRIVE_DIR="../drive_files_for_upload"
mkdir -p "$DRIVE_DIR"
mkdir -p "$DRIVE_DIR/patches/windows"
mkdir -p "$DRIVE_DIR/patches/linux"

# Mover instaladores si existen
[ -f "../AtlasInstaller.exe" ] && mv "../AtlasInstaller.exe" "$DRIVE_DIR/"
[ -f "../AtlasInstaller.AppImage" ] && mv "../AtlasInstaller.AppImage" "$DRIVE_DIR/"

# Copiar archivos base (simulado - en realidad los tendrías)
if [ -f "../drive_files/Atlas_Windows_v1.0.0.zip" ]; then
    cp "../drive_files/Atlas_Windows_v1.0.0.zip" "$DRIVE_DIR/"
fi

if [ -f "../drive_files/Atlas_Linux_v1.0.0.tar.gz" ]; then
    cp "../drive_files/Atlas_Linux_v1.0.0.tar.gz" "$DRIVE_DIR/"
fi

# 6. Generar README para Drive
cat > "$DRIVE_DIR/README.txt" << 'EOF'
📦 ARCHIVOS PARA DISTRIBUCIÓN ATLAS

Subir TODOS estos archivos a Google Drive en una carpeta pública:

ARCHIVOS PRINCIPALES:
1. AtlasInstaller.exe - Instalador para Windows
2. AtlasInstaller.AppImage - Instalador para Linux
3. Atlas_Windows_v1.0.0.zip - Juego completo Windows (20GB)
4. Atlas_Linux_v1.0.0.tar.gz - Juego completo Linux (13GB)

ESTRUCTURA EN DRIVE:
- Todos los archivos en la MISMA carpeta
- La carpeta debe tener enlace público
- Obtener ID de cada archivo para los instaladores

ACTUALIZACIONES FUTURAS:
1. Crear parches con: python create_patches.py [windows|linux]
2. Subir archivos .zip/.tar.gz a carpeta patches/
3. Actualizar patch_index.json
4. Los usuarios recibirán actualizaciones automáticas

ENLACES NECESARIOS:
Obtener de cada archivo en Drive:
- ID del archivo (de la URL: /d/[ID]/view)
- Enlace de descarga directa
EOF

success "Estructura preparada en: $DRIVE_DIR"

# 7. Mostrar resumen
echo ""
echo "============================================="
echo "✅ CONSTRUCCIÓN COMPLETADA"
echo "============================================="
echo ""
echo "ARCHIVOS GENERADOS: $generated_files/2"
echo ""
echo "📁 CARPETA PARA SUBIR A DRIVE:"
ls -la "$DRIVE_DIR/"
echo ""
echo "📋 PRÓXIMOS PASOS:"
echo "1. Subir todo en '$DRIVE_DIR/' a Google Drive"
echo "2. Hacer la carpeta pública (cualquiera con enlace puede ver)"
echo "3. Obtener IDs de archivos de Drive"
echo "4. Actualizar los IDs en AtlasInstaller.cs y AtlasInstaller.py"
echo "5. Actualizar tu página web con los nuevos enlaces"
echo ""
echo "🔗 Para actualizaciones futuras, usa:"
echo "   python create_patches.py windows  (para parche Windows)"
echo "   python create_patches.py linux    (para parche Linux)"
echo ""