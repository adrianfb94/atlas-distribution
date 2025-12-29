#!/bin/bash
# Atlas_Distribution/dev/build_installers.sh
# Script para construir todos los instaladores y subir a GitHub Releases

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

# 1. Verificar dependencias básicas
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

# Dependencias principales
check_dependency python3
check_dependency pip
check_dependency tar
check_dependency zip

# 2. Verificar dependencias según lo que se va a construir
status "Verificando compiladores necesarios..."

# Para Windows C#: verificar Mono o .NET
windows_compiler_found=false
if command -v mcs &> /dev/null; then
    success "Mono (mcs) encontrado - para Windows C#"
    windows_compiler_found=true
elif command -v dotnet &> /dev/null; then
    success ".NET SDK encontrado - para Windows C#"
    windows_compiler_found=true
else
    warning "No se encontró compilador C# (Mono o .NET)"
    warning "  Para Mono: sudo apt install mono-devel"
    warning "  Para .NET: sudo apt install dotnet-sdk-8.0"
fi

# Para Linux Qt: verificar qmake
if command -v qmake &> /dev/null; then
    success "qmake encontrado - para Linux Qt"
    check_dependency g++
else
    warning "qmake no encontrado - no se puede construir Qt"
    warning "  Instalar: sudo apt install qt5-default qttools5-dev-tools"
fi

# 3. Construir AMBOS instaladores con create_patches.py
status "Construyendo todos los instaladores..."
echo ""
cd "$(dirname "$0")"


# Usar create_patches.py build para construir ambos
python3 create_patches.py build

# 4. Verificar archivos generados
status "Verificando archivos generados..."

generated_files=0
windows_file=""
linux_file=""

# Windows C#
if [ -f "../AtlasInstaller.exe" ]; then
    windows_file="../AtlasInstaller.exe"
    size_kb=$(du -k "$windows_file" 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    success "AtlasInstaller.exe generado (${size_mb}MB) - C# GUI"
    generated_files=$((generated_files + 1))
elif [ -f "../AtlasInstaller_dotnet.exe" ]; then
    # Si se creó con dotnet SDK
    windows_file="../AtlasInstaller_dotnet.exe"
    size_kb=$(du -k "$windows_file" 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    success "AtlasInstaller_dotnet.exe generado (${size_mb}MB) - C# .NET"
    generated_files=$((generated_files + 1))
    
    # Crear enlace simbólico si no existe
    if [ ! -f "../AtlasInstaller.exe" ]; then
        cp "$windows_file" "../AtlasInstaller.exe"
        windows_file="../AtlasInstaller.exe"
        success "  También copiado como AtlasInstaller.exe"
    fi
else
    if [ "$windows_compiler_found" = true ]; then
        error "AtlasInstaller.exe no generado (error en compilación C#)"
    else
        warning "AtlasInstaller.exe no generado (sin compilador C#)"
    fi
fi

# Linux Qt
if [ -f "../AtlasInstallerQt" ]; then
    linux_file="../AtlasInstallerQt"
    size_kb=$(du -k "$linux_file" 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    success "AtlasInstallerQt generado (${size_mb}MB) - Qt GUI"
    generated_files=$((generated_files + 1))
    
    # Asegurar permisos de ejecución
    chmod +x "$linux_file" 2>/dev/null
else
    warning "AtlasInstallerQt no generado"
fi

# 5. Preparar para distribución
status "Preparando para distribución..."
DRIVE_DIR="../upload2github"
mkdir -p "$DRIVE_DIR"

# Copiar instaladores
echo "📦 Copiando instaladores a $DRIVE_DIR/"

# Windows
if [ -n "$windows_file" ] && [ -f "$windows_file" ]; then
    cp "$windows_file" "$DRIVE_DIR/AtlasInstaller.exe"
    success "  $windows_file → upload2github/AtlasInstaller.exe"
fi

# Linux
if [ -n "$linux_file" ] && [ -f "$linux_file" ]; then
    cp "$linux_file" "$DRIVE_DIR/AtlasInstallerQt"
    chmod +x "$DRIVE_DIR/AtlasInstallerQt"
    success "  $linux_file → upload2github/AtlasInstallerQt"
fi

# 6. Preguntar si subir a GitHub Releases
echo ""
echo "============================================="
echo "📤 SUBIR A GITHUB RELEASES"
echo "============================================="

upload_to_github() {
    # Configuración
    VERSION="1.0.0"
    REPO="adrianfb94/atlas-distribution"
    
    echo "🚀 Subiendo a GitHub Releases..."
    
    # Verificar que gh está instalado
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) no está instalado"
        echo "Para instalar:"
        echo "  Ubuntu/Debian: sudo apt install gh"
        echo "  macOS: brew install gh"
        echo "  Otros: https://cli.github.com/"
        return 1
    fi
    
    # Verificar autenticación
    if ! gh auth status &> /dev/null; then
        warning "No autenticado con GitHub CLI"
        echo "Autenticando con GitHub..."
        gh auth login
    fi
    
    # Array de archivos a subir
    FILES_TO_UPLOAD=()
    
    # Windows
    if [ -f "$DRIVE_DIR/AtlasInstaller.exe" ]; then
        FILES_TO_UPLOAD+=("$DRIVE_DIR/AtlasInstaller.exe")
        echo "📦 Windows: $DRIVE_DIR/AtlasInstaller.exe"
    fi
    
    # Linux
    if [ -f "$DRIVE_DIR/AtlasInstallerQt" ]; then
        FILES_TO_UPLOAD+=("$DRIVE_DIR/AtlasInstallerQt")
        echo "🐧 Linux: $DRIVE_DIR/AtlasInstallerQt"
    fi
    
    # Verificar que hay archivos para subir
    if [ ${#FILES_TO_UPLOAD[@]} -eq 0 ]; then
        error "No hay archivos para subir"
        return 1
    fi
    
    echo ""
    echo "📋 Archivos a subir: ${#FILES_TO_UPLOAD[@]}"
    
    # Preguntar por la versión
    read -p "Versión a publicar [v$VERSION]: " input_version
    if [ -n "$input_version" ]; then
        VERSION="$input_version"
    fi
    
    # Asegurar que la versión empiece con 'v'
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    # Preguntar por confirmación
    echo ""
    echo "⚠️  ¿Publicar release $VERSION en GitHub?"
    echo "   Repositorio: $REPO"
    echo "   Archivos: ${FILES_TO_UPLOAD[@]}"
    read -p "¿Continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        warning "Cancelado por el usuario"
        return 0
    fi
    
    # Intentar crear/actualizar el release
    echo "⬆️  Subiendo archivos..."
    
    # Verificar si el release ya existe
    if gh release view "$VERSION" --repo "$REPO" &> /dev/null; then
        echo "🔄 Release $VERSION ya existe. Actualizando..."
        
        # Subir cada archivo
        for file in "${FILES_TO_UPLOAD[@]}"; do
            filename=$(basename "$file")
            echo "  📤 Subiendo $filename..."
            gh release upload "$VERSION" "$file" --repo "$REPO" --clobber
        done
        
        echo "✅ Release $VERSION actualizado"
    else
        echo "🆕 Creando nuevo release $VERSION..."
        
        # Crear nuevo release
        gh release create "$VERSION" \
            --title "Atlas Interactivo $VERSION" \
            --notes "Instalador multiplataforma" \
            "${FILES_TO_UPLOAD[@]}" \
            --repo "$REPO"
        
        echo "✅ Release $VERSION creado"
    fi
    
    # Mostrar URLs
    echo ""
    echo "🔗 URLs de descarga:"
    if [ -f "$DRIVE_DIR/AtlasInstaller.exe" ]; then
        echo "  Windows: https://github.com/$REPO/releases/latest/download/AtlasInstaller.exe"
        echo "           https://github.com/$REPO/releases/download/$VERSION/AtlasInstaller.exe"
    fi
    if [ -f "$DRIVE_DIR/AtlasInstallerQt" ]; then
        echo "  Linux:   https://github.com/$REPO/releases/latest/download/AtlasInstallerQt"
        echo "           https://github.com/$REPO/releases/download/$VERSION/AtlasInstallerQt"
    fi
    
    return 0
}

# Preguntar si subir a GitHub
echo ""
read -p "¿Subir instaladores a GitHub Releases? (s/N): " upload_choice

if [[ "$upload_choice" =~ ^[Ss]$ ]]; then
    upload_to_github
else
    echo "✅ Instaladores listos en $DRIVE_DIR/"
    echo "   Puedes subirlos manualmente cuando quieras con:"
    echo "   gh release create vX.X.X upload2github/* --title 'Atlas Interactivo vX.X.X'"
fi

# 7. Generar README actualizado (opcional)
echo ""
read -p "¿Generar README.txt en $DRIVE_DIR/? (s/N): " readme_choice

if [[ "$readme_choice" =~ ^[Ss]$ ]]; then
    cat > "$DRIVE_DIR/README.txt" << 'EOF'
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
EOF
    success "README generado en: $DRIVE_DIR/README.txt"
fi

# 8. Mostrar resumen
echo ""
echo "============================================="
echo "✅ CONSTRUCCIÓN COMPLETADA"
echo "============================================="
echo ""
echo "📊 RESUMEN:"
echo "   Instaladores generados: $generated_files/2"

if [ $generated_files -eq 2 ]; then
    echo ""
    echo "🎉 ¡AMBOS INSTALADORES CONSTRUIDOS EXITOSAMENTE!"
    echo ""
    echo "📁 CARPETA DE DISTRIBUCIÓN: $DRIVE_DIR/"
    echo ""
    echo "📦 Contenido de $DRIVE_DIR/:"
    ls -lh "$DRIVE_DIR/" 2>/dev/null || ls -la "$DRIVE_DIR/"
elif [ $generated_files -eq 1 ]; then
    echo ""
    echo "⚠️  Solo un instalador fue generado"
    echo "   Revisa los mensajes de error arriba"
    echo ""
    echo "📁 Contenido de $DRIVE_DIR/:"
    ls -la "$DRIVE_DIR/" 2>/dev/null || echo "   (vacío)"
else
    echo ""
    echo "❌ No se generaron instaladores"
    echo "   Revisa las dependencias y errores"
fi

echo ""
echo "📋 PRÓXIMOS PASOS:"
if [ $generated_files -gt 0 ]; then
    echo "1. ✅ Instaladores listos en $DRIVE_DIR/"
    echo "2. ☁️  Verificar archivos de datos en Google Drive"
    echo "3. 🔗 Actualizar docs/download.js con URLs GitHub"
    echo "4. 🚀 Actualizar docs/index.html con enlaces actualizados"
else
    echo "1. 🔧 Verificar dependencias faltantes"
    echo "2. 🛠️  Intentar construir manualmente:"
    echo "   python dev/create_patches.py build-dotnet"
    echo "   python dev/create_patches.py build-mono"
    echo "3. 📚 Revisar documentación en dev/README.md"
fi

echo ""
echo "🔧 COMANDOS ÚTILES:"
echo "   Para reconstruir todo: ./dev/build_installers.sh"
echo "   Para subir a GitHub: gh release create vX.X.X upload2github/*"
echo "   Solo Qt: ./dev/build_qt_linux.sh"
echo ""
echo "💡 CONSEJO:"
echo "   Si hay problemas con Qt, instala:"
echo "   sudo apt install qt5-default qttools5-dev-tools g++"
echo ""
echo "============================================="