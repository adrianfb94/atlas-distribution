#!/bin/bash
# Atlas_Distribution/dev/build_installers.sh
# Script para construir todos los instaladores (usando create_patches.py)

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

# Windows C#
if [ -f "../AtlasInstaller.exe" ]; then
    size_kb=$(du -k "../AtlasInstaller.exe" 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    success "AtlasInstaller.exe generado (${size_mb}MB) - C# GUI"
    generated_files=$((generated_files + 1))
elif [ -f "../AtlasInstaller_dotnet.exe" ]; then
    # Si se creó con dotnet SDK
    size_kb=$(du -k "../AtlasInstaller_dotnet.exe" 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    success "AtlasInstaller_dotnet.exe generado (${size_mb}MB) - C# .NET"
    generated_files=$((generated_files + 1))
    
    # Crear enlace simbólico si no existe
    if [ ! -f "../AtlasInstaller.exe" ]; then
        cp "../AtlasInstaller_dotnet.exe" "../AtlasInstaller.exe"
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
    size_kb=$(du -k "../AtlasInstallerQt" 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    success "AtlasInstallerQt generado (${size_mb}MB) - Qt GUI"
    generated_files=$((generated_files + 1))
    
    # Asegurar permisos de ejecución
    chmod +x "../AtlasInstallerQt" 2>/dev/null
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
if [ -f "../AtlasInstaller.exe" ]; then
    cp "../AtlasInstaller.exe" "$DRIVE_DIR/"
    success "  AtlasInstaller.exe → upload2github/"
elif [ -f "../AtlasInstaller_dotnet.exe" ]; then
    cp "../AtlasInstaller_dotnet.exe" "$DRIVE_DIR/AtlasInstaller.exe"
    success "  AtlasInstaller_dotnet.exe → upload2github/AtlasInstaller.exe"
fi

# Linux
if [ -f "../AtlasInstallerQt" ]; then
    cp "../AtlasInstallerQt" "$DRIVE_DIR/"
    chmod +x "$DRIVE_DIR/AtlasInstallerQt"
    success "  AtlasInstallerQt → upload2github/"
fi

# 6. Generar README actualizado
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
EOF

success "README generado en: $DRIVE_DIR/README.txt"

# 7. Mostrar resumen
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
    echo "2. 📤 Subir a GitHub Releases"
    echo "   git tag v1.0.0"
    echo "   git push origin v1.0.0"
    echo "   Subir archivos en GitHub Releases"
    echo "3. ☁️  Verificar archivos de datos en Google Drive"
    echo "4. 🔗 Actualizar docs/download.js con URLs"
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
echo "   Solo parches Windows: python dev/create_patches.py windows"
echo "   Solo parches Linux:   python dev/create_patches.py linux"
echo ""
echo "💡 CONSEJO:"
echo "   Si hay problemas con Qt, instala:"
echo "   sudo apt install qt5-default qttools5-dev-tools g++"
echo ""
echo "============================================="