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

# ========== FUNCIÓN DE LIMPIEZA ==========
clean_qt_files() {
    echo "🧹 Limpiando archivos Qt residuales..."
    
    CURRENT_DIR="$(dirname "$0")"
    PARENT_DIR="$(dirname "$CURRENT_DIR")"
    
    # Solo limpiar archivos de compilación, NO los binarios finales
    find "$CURRENT_DIR" -name "moc_*" -delete 2>/dev/null || true
    find "$CURRENT_DIR" -name "*.o" -delete 2>/dev/null || true
    find "$CURRENT_DIR" -name "*.so" -delete 2>/dev/null || true
    find "$CURRENT_DIR" -name "*.moc" -delete 2>/dev/null || true
    find "$CURRENT_DIR" -name "ui_*" -delete 2>/dev/null || true
    find "$CURRENT_DIR" -name "Makefile*" -delete 2>/dev/null || true
    
    find "$PARENT_DIR" -name "moc_*" -delete 2>/dev/null || true
    find "$PARENT_DIR" -name "*.o" -delete 2>/dev/null || true
    find "$PARENT_DIR" -name "*.so" -delete 2>/dev/null || true
    find "$PARENT_DIR" -name "*.moc" -delete 2>/dev/null || true
    find "$PARENT_DIR" -name "ui_*" -delete 2>/dev/null || true
    find "$PARENT_DIR" -name "Makefile*" -delete 2>/dev/null || true
    
    # NO borrar directorios de compilación para no perder configuraciones
    # rm -rf "$CURRENT_DIR/build_qt" 2>/dev/null || true
    # rm -rf "$PARENT_DIR/build_qt" 2>/dev/null || true
    
    # NO borrar binarios finales
    # rm -f "$PARENT_DIR/AtlasInstallerQt" 2>/dev/null || true
    # rm -f "$PARENT_DIR/AtlasInstaller.exe" 2>/dev/null || true
    # rm -f "$PARENT_DIR/AtlasInstaller_dotnet.exe" 2>/dev/null || true
    
    echo "✅ Limpieza completada (solo archivos temporales)"
}

# ========== FUNCIONES DE LOG ==========
status() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

check_dependency() {
    if command -v $1 &> /dev/null; then
        success "$1 encontrado"
        return 0
    else
        error "$1 no encontrado"
        return 1
    fi
}

# ========== 1. VERIFICAR DEPENDENCIAS ==========
status "Verificando dependencias..."

check_dependency python3
check_dependency pip
check_dependency tar
check_dependency zip

# Verificar compiladores
status "Verificando compiladores necesarios..."

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

if command -v qmake &> /dev/null; then
    success "qmake encontrado - para Linux Qt"
    check_dependency g++
else
    warning "qmake no encontrado - no se puede construir Qt"
    warning "  Instalar: sudo apt install qt5-default qttools5-dev-tools"
fi

# ========== 2. LIMPIAR ARCHIVOS ==========
clean_qt_files

# ========== 3. CONSTRUIR INSTALADORES ==========
status "Construyendo todos los instaladores..."
echo ""
cd "$(dirname "$0")"

# Usar create_patches.py para construir ambos
python3 create_patches.py build

# ========== 4. VERIFICAR ARCHIVOS GENERADOS ==========
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
    windows_file="../AtlasInstaller_dotnet.exe"
    size_kb=$(du -k "$windows_file" 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    success "AtlasInstaller_dotnet.exe generado (${size_mb}MB) - C# .NET"
    generated_files=$((generated_files + 1))
    
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
    
    chmod +x "$linux_file" 2>/dev/null
else
    warning "AtlasInstallerQt no generado"
fi

# ========== 5. CREAR INSTALADOR UNIVERSAL ==========
status "Creando instalador universal..."

# Crear el instalador universal como AtlasInstallerQt_plus
cat > "AtlasInstallerQt_plus" << 'EOF'
#!/bin/bash
#!/usr/bin/env bash
# =============================================================================
# ATLAS INTERACTIVO - INSTALADOR UNIVERSAL PARA LINUX
# =============================================================================
# Este es un ÚNICO archivo que descarga y ejecuta AtlasInstallerQt
# =============================================================================

set -e  # Detener en primer error

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
VERSION="1.0.0"
APP_NAME="Atlas Interactivo"
INSTALL_DIR="$HOME/Atlas_Interactivo"
REQUIRED_SPACE_GB=25
TEMP_DIR="/tmp/atlas_installer_$(date +%s)"

# URLs de descarga
DOWNLOAD_URL_QT="https://github.com/adrianfb94/atlas-distribution/releases/latest/download/AtlasInstallerQt"

# =============================================================================
# COLORES Y FORMATO
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

BOLD='\033[1m'
UNDERLINE='\033[4m'

# =============================================================================
# FUNCIONES DE LOG
# =============================================================================
log() { echo -e "${BLUE}[*]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
title() { echo -e "${BOLD}${MAGENTA}$1${NC}"; }
separator() { echo "=================================================================="; }

# =============================================================================
# FUNCIONES DEL SISTEMA
# =============================================================================

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_qt_dependencies() {
    log "Verificando bibliotecas Qt..."
    
    local missing_libs=()
    local qt_libs=("libQt5Widgets.so.5" "libQt5Gui.so.5" "libQt5Core.so.5" "libQt5Network.so.5")
    
    for lib in "${qt_libs[@]}"; do
        if ! ldconfig -p 2>/dev/null | grep -q "$lib" && \
           [ ! -f "/usr/lib/x86_64-linux-gnu/$lib" ] && \
           [ ! -f "/usr/lib/$lib" ]; then
            missing_libs+=("$lib")
        fi
    done
    
    if [ ${#missing_libs[@]} -eq 0 ]; then
        success "Qt5 está instalado correctamente"
        return 0
    else
        warning "Faltan bibliotecas Qt: ${missing_libs[*]}"
        return 1
    fi
}

check_system_tools() {
    log "Verificando herramientas del sistema..."
    
    local missing_tools=()
    local required_tools=("tar" "wget" "curl")
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        success "Herramientas del sistema disponibles"
        return 0
    else
        warning "Faltan herramientas: ${missing_tools[*]}"
        return 1
    fi
}

install_dependencies_debian() {
    log "Instalando dependencias para Debian/Ubuntu..."
    
    echo "Actualizando repositorios..."
    if ! sudo apt update; then
        error "Error al actualizar repositorios"
        return 1
    fi
    
    echo "Instalando paquetes..."
    if ! sudo apt install -y \
        tar wget curl \
        libqt5widgets5 libqt5gui5 libqt5core5a libqt5network5 \
        qt5-qmake qtbase5-dev libxcb-xinerama0; then
        error "Error instalando paquetes"
        return 1
    fi
    
    return 0
}

download_installer() {
    local output_file="$TEMP_DIR/AtlasInstallerQt"
    
    # Limpiar archivo anterior si existe
    rm -f "$output_file" 2>/dev/null
    
    log "Descargando instalador desde GitHub..."
    
    if command_exists wget; then
        info "Usando wget..."
        if wget --show-progress -q -O "$output_file" "$DOWNLOAD_URL_QT"; then
            if [ -s "$output_file" ]; then
                chmod +x "$output_file"
                success "Instalador descargado"
                return 0
            else
                error "El archivo descargado está vacío"
                return 1
            fi
        else
            error "Error al descargar con wget"
            return 1
        fi
    elif command_exists curl; then
        info "Usando curl..."
        if curl -# -L -o "$output_file" "$DOWNLOAD_URL_QT"; then
            if [ -s "$output_file" ]; then
                chmod +x "$output_file"
                success "Instalador descargado"
                return 0
            else
                error "El archivo descargado está vacío"
                return 1
            fi
        else
            error "Error al descargar con curl"
            return 1
        fi
    else
        error "No se encontró wget ni curl"
        return 1
    fi
}

# =============================================================================
# FLUJO PRINCIPAL
# =============================================================================

main_installation_flow() {
    clear
    separator
    title "ATLAS INTERACTIVO - INSTALACIÓN UNIVERSAL"
    separator
    echo ""
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    info "Directorio temporal: $TEMP_DIR"
    
    local qt_binary=""
    
    # Verificar Internet
    info "Verificando conexión a Internet..."
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 2 google.com >/dev/null 2>&1; then
        success "✓ Internet disponible"
        
        # Descargar automáticamente
        info "Descargando instalador automáticamente..."
        if download_installer; then
            qt_binary="$TEMP_DIR/AtlasInstallerQt"
            success "✓ Instalador descargado exitosamente"
        else
            error "✗ No se pudo descargar el instalador"
            echo ""
            echo "Soluciones posibles:"
            echo "1. Verifica tu conexión a Internet"
            echo "2. Descarga manualmente desde:"
            echo "   $DOWNLOAD_URL_QT"
            echo "3. Contacta con soporte técnico"
            exit 1
        fi
    else
        error "✗ Sin conexión a Internet"
        echo "No se puede descargar el instalador."
        echo "Por favor, conecta a Internet y vuelve a intentar."
        exit 1
    fi
    
    # Verificar que tenemos un binario válido
    if [ ! -f "$qt_binary" ] || [ ! -x "$qt_binary" ]; then
        error "No se pudo obtener un instalador válido"
        exit 1
    fi
    
    info "Instalador listo: $(basename "$qt_binary")"
    
    # Verificar dependencias automáticamente
    info "Verificando dependencias del sistema..."
    
    local need_deps=false
    if ! check_qt_dependencies || ! check_system_tools; then
        need_deps=true
    fi
    
    if [ "$need_deps" = true ]; then
        info "Se necesitan instalar algunas dependencias"
        
        # Detectar distribución
        distro=$(detect_distro)
        info "Distribución detectada: $distro"
        
        # Solo instalar si es Ubuntu/Debian
        if [[ "$distro" == "ubuntu" || "$distro" == "debian" ]]; then
            echo ""
            read -p "¿Instalar dependencias automáticamente ahora? (S/n): " install_deps
            install_deps=${install_deps:-S}
            
            if [[ "$install_deps" =~ ^[Ss]$ ]]; then
                if install_dependencies_debian; then
                    success "✓ Dependencias instaladas correctamente"
                else
                    warning "✗ Error instalando dependencias"
                    echo "Puedes instalarlas manualmente con:"
                    echo "  sudo apt install tar wget curl libqt5widgets5 libqt5gui5 libqt5core5a"
                    echo ""
                    read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                        exit 1
                    fi
                fi
            fi
        else
            info "Para $distro, instala manualmente:"
            echo "  • tar, wget, curl"
            echo "  • Bibliotecas Qt5"
            echo ""
            read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                exit 1
            fi
        fi
    else
        success "✓ Todas las dependencias están instaladas"
    fi
    
    # Verificar espacio en disco
    info "Verificando espacio en disco..."
    if command_exists df; then
        available_kb=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
        available_gb=$(echo "scale=2; $available_kb / 1024 / 1024" | bc 2>/dev/null || echo "0")
        
        if (( $(echo "$available_gb >= $REQUIRED_SPACE_GB" | bc -l 2>/dev/null) )); then
            success "✓ Espacio suficiente: $available_gb GB"
        else
            warning "⚠ Espacio limitado: $available_gb GB (se recomiendan $REQUIRED_SPACE_GB GB)"
            echo ""
            read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    # Ejecutar el instalador Qt
    echo ""
    separator
    title "INICIANDO INSTALADOR GRÁFICO"
    separator
    echo ""
    info "Ejecutando instalador Qt..."
    echo ""
    
    # Configurar entorno para Qt
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export QT_SCALE_FACTOR=1
    export QT_QPA_PLATFORM="xcb"
    
    # Mostrar información final
    echo "──────────────────────────────────────────────────"
    echo "✅ Instalador preparado correctamente"
    echo "📂 Archivo: $qt_binary"
    echo "💾 Tamaño: $(du -h "$qt_binary" | cut -f1)"
    echo "📦 Dependencias: Verificadas"
    echo "💿 Espacio: Disponible"
    echo "──────────────────────────────────────────────────"
    
    # Ejecutar el instalador Qt
    exec "$qt_binary" "$@"
}

# =============================================================================
# MANEJO DE ARGUMENTOS
# =============================================================================

# Argumentos simples
case "${1:-}" in
    -h|--help)
        echo "Atlas Interactivo - Instalador Universal v$VERSION"
        echo "Uso: ./$(basename "$0") [opciones]"
        echo ""
        echo "Opciones:"
        echo "  -h, --help      Mostrar esta ayuda"
        echo "  -v, --version   Mostrar versión"
        echo ""
        echo "Este instalador descarga y ejecuta AtlasInstallerQt automáticamente."
        exit 0
        ;;
    -v|--version)
        echo "Atlas Interactivo Installer v$VERSION"
        exit 0
        ;;
esac

# =============================================================================
# EJECUCIÓN PRINCIPAL
# =============================================================================

# Limpieza al salir
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Ejecutar flujo principal
main_installation_flow "$@"

exit 0
EOF

chmod +x "AtlasInstallerQt_plus"

if [ -f "AtlasInstallerQt_plus" ]; then
    universal_size=$(du -h "AtlasInstallerQt_plus" | cut -f1)
    success "Instalador universal creado: AtlasInstallerQt_plus (${universal_size})"
else
    warning "No se creó el instalador universal"
fi

# ========== 6. PREPARAR PARA DISTRIBUCIÓN ==========
status "Preparando para distribución..."
DRIVE_DIR="../upload2github"
mkdir -p "$DRIVE_DIR"

echo "📦 Copiando instaladores a $DRIVE_DIR/"

# Windows
if [ -n "$windows_file" ] && [ -f "$windows_file" ]; then
    cp "$windows_file" "$DRIVE_DIR/AtlasInstaller.exe"
    success "  $windows_file → upload2github/AtlasInstaller.exe"
fi

# Linux Qt
if [ -n "$linux_file" ] && [ -f "$linux_file" ]; then
    cp "$linux_file" "$DRIVE_DIR/AtlasInstallerQt"
    chmod +x "$DRIVE_DIR/AtlasInstallerQt"
    success "  $linux_file → upload2github/AtlasInstallerQt"
fi

# Instalador Universal
if [ -f "AtlasInstallerQt_plus" ]; then
    cp "AtlasInstallerQt_plus" "$DRIVE_DIR/AtlasInstallerQt_plus"
    chmod +x "$DRIVE_DIR/AtlasInstallerQt_plus"
    universal_size=$(du -h "AtlasInstallerQt_plus" | cut -f1)
    success "  AtlasInstallerQt_plus → upload2github/ (${universal_size})"
fi

# ========== 7. SUBIR A GITHUB RELEASES ==========
echo ""
echo "============================================="
echo "📤 SUBIR A GITHUB RELEASES"
echo "============================================="

upload_to_github() {
    VERSION="1.0.0"
    REPO="adrianfb94/atlas-distribution"
    
    echo "🚀 Subiendo a GitHub Releases..."
    
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) no está instalado"
        echo "Para instalar:"
        echo "  Ubuntu/Debian: sudo apt install gh"
        return 1
    fi
    
    if ! gh auth status &> /dev/null; then
        warning "No autenticado con GitHub CLI"
        echo "Autenticando con GitHub..."
        gh auth login
    fi
    
    FILES_TO_UPLOAD=()
    
    # Windows
    if [ -f "$DRIVE_DIR/AtlasInstaller.exe" ]; then
        FILES_TO_UPLOAD+=("$DRIVE_DIR/AtlasInstaller.exe")
        echo "📦 Windows: AtlasInstaller.exe"
    fi
    
    # Linux Qt
    if [ -f "$DRIVE_DIR/AtlasInstallerQt" ]; then
        FILES_TO_UPLOAD+=("$DRIVE_DIR/AtlasInstallerQt")
        echo "🐧 Linux Qt: AtlasInstallerQt"
    fi
    
    # Instalador Universal
    if [ -f "$DRIVE_DIR/AtlasInstallerQt_plus" ]; then
        FILES_TO_UPLOAD+=("$DRIVE_DIR/AtlasInstallerQt_plus")
        echo "🌍 Universal: AtlasInstallerQt_plus"
    fi
    
    if [ ${#FILES_TO_UPLOAD[@]} -eq 0 ]; then
        error "No hay archivos para subir"
        return 1
    fi
    
    echo ""
    echo "📋 Archivos a subir: ${#FILES_TO_UPLOAD[@]}"
    
    read -p "Versión a publicar [v$VERSION]: " input_version
    if [ -n "$input_version" ]; then
        VERSION="$input_version"
    fi
    
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    echo ""
    echo "⚠️  ¿Publicar release $VERSION en GitHub?"
    echo "   Repositorio: $REPO"
    read -p "¿Continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        warning "Cancelado por el usuario"
        return 0
    fi
    
    echo "⬆️  Subiendo archivos..."
    
    if gh release view "$VERSION" --repo "$REPO" &> /dev/null; then
        echo "🔄 Release $VERSION ya existe. Actualizando..."
        
        for file in "${FILES_TO_UPLOAD[@]}"; do
            filename=$(basename "$file")
            echo "  📤 Subiendo $filename..."
            gh release upload "$VERSION" "$file" --repo "$REPO" --clobber
        done
        
        echo "✅ Release $VERSION actualizado"
    else
        echo "🆕 Creando nuevo release $VERSION..."
        
        gh release create "$VERSION" \
            --title "Atlas Interactivo $VERSION" \
            --notes "Instalador multiplataforma" \
            "${FILES_TO_UPLOAD[@]}" \
            --repo "$REPO"
        
        echo "✅ Release $VERSION creado"
    fi
    
    echo ""
    echo "🔗 URLs de descarga:"
    if [ -f "$DRIVE_DIR/AtlasInstaller.exe" ]; then
        echo "  Windows: https://github.com/$REPO/releases/latest/download/AtlasInstaller.exe"
    fi
    if [ -f "$DRIVE_DIR/AtlasInstallerQt" ]; then
        echo "  Linux Qt: https://github.com/$REPO/releases/latest/download/AtlasInstallerQt"
    fi
    if [ -f "$DRIVE_DIR/AtlasInstallerQt_plus" ]; then
        echo "  Universal: https://github.com/$REPO/releases/latest/download/AtlasInstallerQt_plus"
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

# ========== 8. GENERAR README ==========
echo ""
read -p "¿Generar README.txt en $DRIVE_DIR/? (s/N): " readme_choice

if [[ "$readme_choice" =~ ^[Ss]$ ]]; then
    cat > "$DRIVE_DIR/README.txt" << 'EOF'
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
EOF
    success "README generado en: $DRIVE_DIR/README.txt"
fi

# ========== 9. RESUMEN FINAL ==========
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
    
    # Mostrar instalador universal si existe
    if [ -f "$DRIVE_DIR/AtlasInstallerQt_plus" ]; then
        echo ""
        echo "🌍 INSTALADOR UNIVERSAL CREADO:"
        echo "   AtlasInstallerQt_plus - Auto-instala dependencias"
    fi
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
    echo "4. 🚀 Actualizar docs/index.html con enlaces"
else
    echo "1. 🔧 Verificar dependencias faltantes"
    echo "2. 🛠️  Intentar construir manualmente"
fi

echo ""
echo "🔧 COMANDOS ÚTILES:"
echo "   Para reconstruir todo: ./dev/build_installers.sh"
echo "   Para subir a GitHub: gh release create vX.X.X upload2github/*"
echo ""
echo "============================================="