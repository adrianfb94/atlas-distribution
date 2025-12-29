#!/bin/bash
# Script simple para subir archivos a GitHub Releases

echo "📤 SUBIDOR A GITHUB RELEASES"
echo "=============================="

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuración
VERSION="1.0.0"
REPO="adrianfb94/atlas-distribution"
FILES=("AtlasInstaller.exe" "AtlasInstallerQt")

echo "🚀 Subiendo a GitHub Releases..."

# Verificar gh
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) no instalado${NC}"
    echo "Instalar con:"
    echo "  sudo apt install gh    # Ubuntu/Debian"
    echo "  brew install gh        # macOS"
    exit 1
fi

# Verificar autenticación
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  No autenticado. Autenticando...${NC}"
    gh auth login
fi

# Verificar archivos
VALID_FILES=()
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        VALID_FILES+=("$file")
        echo -e "${GREEN}✓${NC} $file encontrado"
    else
        echo -e "${YELLOW}⚠${NC} $file no encontrado (omitido)"
    fi
done

if [ ${#VALID_FILES[@]} -eq 0 ]; then
    echo -e "${RED}❌ No hay archivos válidos para subir${NC}"
    exit 1
fi

# Preguntar versión
read -p "Versión (ej: v1.0.0) [v$VERSION]: " input_version
if [ -n "$input_version" ]; then
    VERSION="$input_version"
fi

# Asegurar formato vX.X.X
if [[ ! "$VERSION" =~ ^v ]]; then
    VERSION="v$VERSION"
fi

# Mostrar resumen
echo ""
echo "📋 RESUMEN:"
echo "  Versión: $VERSION"
echo "  Repo: $REPO"
echo "  Archivos:"
for file in "${VALID_FILES[@]}"; do
    size=$(du -h "$file" | cut -f1)
    echo "    - $file ($size)"
done

# Confirmar
echo ""
read -p "¿Continuar? (s/N): " confirm
if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    echo "Cancelado"
    exit 0
fi

# Subir
echo "⬆️  Subiendo..."
gh release create "$VERSION" \
    --title "Atlas Interactivo $VERSION" \
    --notes "Instalador oficial" \
    "${VALID_FILES[@]}" \
    --repo "$REPO"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ¡Listo! Los instaladores están en:${NC}"
    echo "   https://github.com/$REPO/releases"
    
    # Mostrar URLs directas
    echo ""
    echo "🔗 URLs de descarga directa:"
    for file in "${VALID_FILES[@]}"; do
        filename=$(basename "$file")
        echo "  $filename:"
        echo "    https://github.com/$REPO/releases/latest/download/$filename"
        echo "    https://github.com/$REPO/releases/download/$VERSION/$filename"
    done
else
    echo -e "${RED}❌ Error al crear release${NC}"
    exit 1
fi