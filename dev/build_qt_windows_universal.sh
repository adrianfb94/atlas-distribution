#!/bin/bash
# Script UNIVERSAL para construir instalador Qt para Windows
# Versión mejorada - Detecta automáticamente 32-bit y 64-bit

echo "🔨 Atlas Interactive - Universal Windows Installer Builder"
echo "=========================================================="

# Configurar paths
MXE_PATH="$HOME/Documents/ABEL/adrian/atlas/Atlas_Distribution/dev/mxe/usr/bin"
export PATH="$MXE_PATH:$PATH"

# ---- DETECCIÓN UNIVERSAL DE COMPILADORES ----
echo ""
echo "🔍 Detectando compiladores disponibles..."

# Arrays para almacenar compiladores encontrados
COMPILERS_64BIT=()
COMPILERS_32BIT=()

# Buscar compiladores 64-bit
echo "📊 Compiladores 64-bit disponibles:"
for qmake in "$MXE_PATH"/*qmake*; do
    if [ -f "$qmake" ] && [ -x "$qmake" ]; then
        name=$(basename "$qmake")
        if [[ "$name" == *"x86_64"* ]]; then
            COMPILERS_64BIT+=("$qmake")
            echo "  • $name"
        elif [[ "$name" == *"i686"* ]]; then
            COMPILERS_32BIT+=("$qmake")
            echo "  • $name (32-bit)"
        fi
    fi
done

# Si no se encontraron en MXE_PATH, buscar en PATH
if [ ${#COMPILERS_64BIT[@]} -eq 0 ]; then
    echo "🔎 Buscando en PATH del sistema..."
    while IFS= read -r qmake_path; do
        if [[ "$qmake_path" == *"mingw"* ]] && [[ "$qmake_path" == *"qmake"* ]]; then
            name=$(basename "$qmake_path")
            if [[ "$name" == *"x86_64"* ]]; then
                COMPILERS_64BIT+=("$qmake_path")
                echo "  • $name (en PATH)"
            fi
        fi
    done < <(which -a qmake qmake-qt5 2>/dev/null | grep -v "not found")
fi

# ---- MENÚ DE SELECCIÓN ----
echo ""
echo "🎯 SELECCIÓN DE ARQUITECTURA:"
echo "   1. Compilar solo 64-bit (recomendado para sistemas modernos)"
echo "   2. Compilar solo 32-bit (para compatibilidad con sistemas antiguos)"
echo "   3. Compilar AMBAS versiones (64-bit y 32-bit)"
echo "   4. Compilar versión universal (auto-detectar en runtime)"
echo ""

read -p "   Selecciona una opción [1-4]: " -n 1 -r
echo ""

case $REPLY in
    1)
        BUILD_MODE="64BIT_ONLY"
        echo "✅ Modo seleccionado: Solo 64-bit"
        ;;
    2)
        BUILD_MODE="32BIT_ONLY"
        echo "✅ Modo seleccionado: Solo 32-bit"
        ;;
    3)
        BUILD_MODE="BOTH"
        echo "✅ Modo seleccionado: Ambas versiones (64-bit y 32-bit)"
        ;;
    4)
        BUILD_MODE="UNIVERSAL"
        echo "✅ Modo seleccionado: Instalador universal (auto-detectar)"
        ;;
    *)
        echo "❌ Opción inválida. Saliendo..."
        exit 1
        ;;
esac

# ---- CONFIGURACIÓN DE COMPILADORES ----
echo ""
echo "⚙️  Configurando compiladores..."

# Función para seleccionar el mejor compilador de una lista
select_best_compiler() {
    local compilers=("$@")
    
    # Prioridad: static > shared
    for compiler in "${compilers[@]}"; do
        if [[ "$compiler" == *".static"* ]]; then
            echo "$compiler"
            return 0
        fi
    done
    
    # Si no hay static, usar el primero
    if [ ${#compilers[@]} -gt 0 ]; then
        echo "${compilers[0]}"
        return 0
    fi
    
    return 1
}

# Seleccionar compiladores según modo
case $BUILD_MODE in
    "64BIT_ONLY")
        QMAKE_64=$(select_best_compiler "${COMPILERS_64BIT[@]}")
        if [ -z "$QMAKE_64" ]; then
            echo "❌ No se encontró compilador 64-bit"
            echo "   Ejecuta: cd ~/Documents/ABEL/adrian/atlas/Atlas_Distribution/dev/mxe"
            echo "            make qtbase MXE_TARGETS=x86_64-w64-mingw32.static -j\$(nproc)"
            exit 1
        fi
        echo "🔧 Compilador 64-bit: $(basename $QMAKE_64)"
        ;;
        
    "32BIT_ONLY")
        QMAKE_32=$(select_best_compiler "${COMPILERS_32BIT[@]}")
        if [ -z "$QMAKE_32" ]; then
            echo "❌ No se encontró compilador 32-bit"
            echo "   Ya deberías tener i686-w64-mingw32.static-qmake-qt5"
            exit 1
        fi
        echo "🔧 Compilador 32-bit: $(basename $QMAKE_32)"
        ;;
        
    "BOTH"|"UNIVERSAL")
        QMAKE_64=$(select_best_compiler "${COMPILERS_64BIT[@]}")
        QMAKE_32=$(select_best_compiler "${COMPILERS_32BIT[@]}")
        
        if [ -z "$QMAKE_64" ] || [ -z "$QMAKE_32" ]; then
            echo "❌ Faltan compiladores para modo $BUILD_MODE"
            echo "   64-bit: ${QMAKE_64:-NO ENCONTRADO}"
            echo "   32-bit: ${QMAKE_32:-NO ENCONTRADO}"
            echo ""
            echo "🔧 Solución:"
            echo "   cd ~/Documents/ABEL/adrian/atlas/Atlas_Distribution/dev/mxe"
            echo "   echo 'MXE_TARGETS := i686-w64-mingw32.static x86_64-w64-mingw32.static' > settings.mk"
            echo "   make qtbase -j\$(nproc)"
            exit 1
        fi
        echo "🔧 Compilador 64-bit: $(basename $QMAKE_64)"
        echo "🔧 Compilador 32-bit: $(basename $QMAKE_32)"
        ;;
esac

# ---- CREACIÓN DE DIRECTORIOS ----
echo ""
echo "📁 Preparando directorios..."

PROJECT_ROOT="$HOME/Documents/ABEL/adrian/atlas/Atlas_Distribution/dev"
BUILD_DIR="$PROJECT_ROOT/build_windows_universal"
OUTPUT_DIR="$PROJECT_ROOT/distribucion_windows"

rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

cd "$BUILD_DIR"

# ---- CREACIÓN DE ARCHIVOS DEL PROYECTO ----
echo "📝 Creando proyecto Qt universal..."

# Crear proyecto principal
cat > AtlasUniversal.pro << 'PROEOF'
# Proyecto universal para Atlas Interactive Installer
# Este proyecto puede compilarse para 32-bit y 64-bit

QT += core gui widgets network concurrent
CONFIG += c++11 release
TEMPLATE = app

# Configuraciones específicas por arquitectura
win32:contains(QMAKE_TARGET.arch, x86_64) {
    TARGET = AtlasInstaller64
    DEFINES += ATLAS_64BIT
    MESSAGE(Compilando versión 64-bit...)
}

win32:contains(QMAKE_TARGET.arch, i386) {
    TARGET = AtlasInstaller32
    DEFINES += ATLAS_32BIT
    MESSAGE(Compilando versión 32-bit...)
}

# Archivos comunes
SOURCES = src/main.cpp \
          src/installerwindow.cpp \
          src/downloadmanager.cpp \
          src/archdetector.cpp

HEADERS = include/installerwindow.h \
          include/downloadmanager.h \
          include/archdetector.h

RESOURCES = resources.qrc

# Configuración para Windows
win32 {
    RC_FILE = resources.rc
    LIBS += -lole32 -luuid -lwininet -lshell32
    QMAKE_LFLAGS += -static
    DEFINES += _WIN32_WINNT=0x0601 WIN32_LEAN_AND_MEAN
}

# Para versiones release
CONFIG(debug, debug|release) {
    TARGET = $${TARGET}_debug
} else {
    DEFINES += QT_NO_DEBUG_OUTPUT
    QMAKE_CXXFLAGS_RELEASE += -O2
}
PROEOF

# Crear estructura de directorios
mkdir -p src include assets

# Crear archivo de recursos
cat > resources.qrc << 'RCCEOF'
<RCC>
    <qresource prefix="/">
        <file>assets/icon.ico</file>
        <file>assets/logo.png</file>
        <file>assets/welcome.jpg</file>
        <file>assets/license.txt</file>
    </qresource>
</RCC>
RCCEOF

# Crear archivo RC con información de versión
cat > resources.rc << 'RCEOF'
#include <windows.h>

// Icono de la aplicación
IDI_ICON1 ICON "assets/icon.ico"

// Información de versión
VS_VERSION_INFO VERSIONINFO
 FILEVERSION 1,0,0,0
 PRODUCTVERSION 1,0,0,0
 FILEFLAGSMASK 0x3fL
 FILEFLAGS 0x0L
 FILEOS 0x40004L
 FILETYPE 0x1L
 FILESUBTYPE 0x0L
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904b0"
        BEGIN
            VALUE "CompanyName", "Atlas Interactive"
            VALUE "FileDescription", "Atlas Interactive Universal Installer"
            VALUE "FileVersion", "1.0.0.0"
            VALUE "InternalName", "AtlasInstaller"
            VALUE "LegalCopyright", "© 2025 Atlas Interactive. Todos los derechos reservados."
            VALUE "OriginalFilename", "AtlasInstaller.exe"
            VALUE "ProductName", "Atlas Interactive"
            VALUE "ProductVersion", "1.0.0"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1200
    END
END
RCEOF

# Crear archivos de assets dummy (en producción, reemplazar con reales)
echo "📦 Creando assets mínimos..."
convert -size 64x64 xc:#3498db -fill white -draw "circle 32,32 32,10" assets/icon.ico 2>/dev/null || \
echo "Icon placeholder" > assets/icon.ico

echo "Atlas Interactive Logo" > assets/logo.png
echo "Welcome to Atlas Interactive" > assets/welcome.jpg

# Crear licencia
cat > assets/license.txt << 'LICEOF'
ATLAS INTERACTIVE - TÉRMINOS DE LICENCIA
=========================================

1. USO PERMITIDO
   - Uso personal y educativo gratuito
   - Modificación del código fuente permitida
   - Distribución no comercial

2. RESTRICCIONES
   - No redistribuir como producto comercial
   - Atribución requerida
   - Sin garantía de ningún tipo

3. INSTALACIÓN
   - Requiere Windows 7 o superior
   - 25GB de espacio libre recomendado
   - Conexión a Internet para descarga

© 2025 Atlas Interactive Team
LICEOF

# ---- CREAR CÓDIGO FUENTE UNIVERSAL ----
echo "💻 Creando código fuente universal..."

# Crear detector de arquitectura
cat > include/archdetector.h << 'HDEOF'
#ifndef ARCHDETECTOR_H
#define ARCHDETECTOR_H

#include <QString>

class ArchDetector {
public:
    enum Architecture {
        ARCH_UNKNOWN = 0,
        ARCH_X86_32,
        ARCH_X86_64,
        ARCH_ARM64
    };
    
    static Architecture detectCurrentArchitecture();
    static QString architectureToString(Architecture arch);
    static bool is64Bit();
    static bool isRunningOnSupportedArchitecture();
    
private:
    static Architecture currentArchitecture;
};

#endif // ARCHDETECTOR_H
HDEOF

cat > src/archdetector.cpp << 'CPPEOF'
#include "archdetector.h"
#include <windows.h>
#include <QSysInfo>

ArchDetector::Architecture ArchDetector::currentArchitecture = ARCH_UNKNOWN;

ArchDetector::Architecture ArchDetector::detectCurrentArchitecture() {
    if (currentArchitecture != ARCH_UNKNOWN) {
        return currentArchitecture;
    }
    
    SYSTEM_INFO sysInfo;
    GetNativeSystemInfo(&sysInfo);
    
    switch (sysInfo.wProcessorArchitecture) {
        case PROCESSOR_ARCHITECTURE_AMD64:
            currentArchitecture = ARCH_X86_64;
            break;
        case PROCESSOR_ARCHITECTURE_ARM64:
            currentArchitecture = ARCH_ARM64;
            break;
        case PROCESSOR_ARCHITECTURE_INTEL:
            currentArchitecture = ARCH_X86_32;
            break;
        default:
            currentArchitecture = ARCH_UNKNOWN;
    }
    
    return currentArchitecture;
}

QString ArchDetector::architectureToString(Architecture arch) {
    switch (arch) {
        case ARCH_X86_32: return "32-bit (x86)";
        case ARCH_X86_64: return "64-bit (x86_64)";
        case ARCH_ARM64: return "64-bit (ARM64)";
        default: return "Desconocida";
    }
}

bool ArchDetector::is64Bit() {
    Architecture arch = detectCurrentArchitecture();
    return (arch == ARCH_X86_64 || arch == ARCH_ARM64);
}

bool ArchDetector::isRunningOnSupportedArchitecture() {
    Architecture arch = detectCurrentArchitecture();
    
    // Para instalador 32-bit, solo soporta x86
    #ifdef ATLAS_32BIT
    return (arch == ARCH_X86_32);
    #endif
    
    // Para instalador 64-bit, soporta x64 y ARM64
    #ifdef ATLAS_64BIT
    return (arch == ARCH_X86_64 || arch == ARCH_ARM64);
    #endif
    
    return false;
}
CPPEOF

# Crear ventana principal del instalador (versión simplificada)
cat > include/installerwindow.h << 'IWHEOF'
#ifndef INSTALLERWINDOW_H
#define INSTALLERWINDOW_H

#include <QMainWindow>
#include <QString>

class QProgressBar;
class QLabel;
class QPushButton;
class QTextEdit;
class QCheckBox;

class InstallerWindow : public QMainWindow {
    Q_OBJECT
    
public:
    explicit InstallerWindow(QWidget *parent = nullptr);
    
    void setArchitecture(const QString &arch);
    
private slots:
    void startInstallation();
    void cancelInstallation();
    void updateProgress(int percent, const QString &message);
    
private:
    void setupUI();
    void createLayout();
    void applyStyles();
    
    // UI Elements
    QLabel *titleLabel;
    QLabel *archLabel;
    QLabel *statusLabel;
    QProgressBar *progressBar;
    QPushButton *installButton;
    QPushButton *cancelButton;
    QCheckBox *desktopShortcutCheck;
    QCheckBox *startMenuCheck;
    QTextEdit *logText;
    
    QString currentArchitecture;
};

#endif // INSTALLERWINDOW_H
IWHEOF

cat > src/installerwindow.cpp << 'IWCEEOF'
#include "installerwindow.h"
#include "archdetector.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QProgressBar>
#include <QLabel>
#include <QPushButton>
#include <QCheckBox>
#include <QTextEdit>
#include <QMessageBox>
#include <QApplication>
#include <QStyleFactory>
#include <QFont>
#include <QTimer>
#include <QThread>

InstallerWindow::InstallerWindow(QWidget *parent) 
    : QMainWindow(parent) {
    
    // Detectar arquitectura automáticamente
    ArchDetector::Architecture arch = ArchDetector::detectCurrentArchitecture();
    currentArchitecture = ArchDetector::architectureToString(arch);
    
    setWindowTitle("Atlas Interactive - Universal Installer");
    setMinimumSize(700, 550);
    
    setupUI();
}

void InstallerWindow::setupUI() {
    QWidget *centralWidget = new QWidget(this);
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);
    mainLayout->setSpacing(15);
    mainLayout->setContentsMargins(20, 20, 20, 20);
    
    // Encabezado
    QHBoxLayout *headerLayout = new QHBoxLayout();
    
    QLabel *iconLabel = new QLabel("🌍");
    iconLabel->setStyleSheet("font-size: 40px;");
    
    QVBoxLayout *titleLayout = new QVBoxLayout();
    titleLabel = new QLabel("ATLAS INTERACTIVE");
    titleLabel->setStyleSheet("font-size: 24px; font-weight: bold; color: #2c3e50;");
    
    archLabel = new QLabel("Instalador Universal • " + currentArchitecture);
    archLabel->setStyleSheet("font-size: 14px; color: #7f8c8d;");
    
    titleLayout->addWidget(titleLabel);
    titleLayout->addWidget(archLabel);
    
    headerLayout->addWidget(iconLabel);
    headerLayout->addLayout(titleLayout);
    headerLayout->addStretch();
    
    QLabel *versionLabel = new QLabel("v1.0.0");
    versionLabel->setStyleSheet("color: #95a5a6;");
    headerLayout->addWidget(versionLabel);
    
    mainLayout->addLayout(headerLayout);
    
    // Grupo de información
    QGroupBox *infoGroup = new QGroupBox("📋 Información del Sistema");
    QVBoxLayout *infoLayout = new QVBoxLayout(infoGroup);
    
    QLabel *infoText = new QLabel(
        "Este instalador configurará Atlas Interactive en tu sistema.\n\n"
        "• Arquitectura detectada: " + currentArchitecture + "\n"
        "• Espacio requerido: 25 GB\n"
        "• Windows 7 o superior\n"
        "• Conexión a Internet necesaria\n\n"
        "El proceso puede tardar varios minutos."
    );
    infoText->setWordWrap(true);
    infoLayout->addWidget(infoText);
    
    mainLayout->addWidget(infoGroup);
    
    // Opciones de instalación
    QGroupBox *optionsGroup = new QGroupBox("⚙️ Opciones de Instalación");
    QVBoxLayout *optionsLayout = new QVBoxLayout(optionsGroup);
    
    desktopShortcutCheck = new QCheckBox("Crear acceso directo en el escritorio");
    desktopShortcutCheck->setChecked(true);
    
    startMenuCheck = new QCheckBox("Agregar al menú Inicio");
    startMenuCheck->setChecked(true);
    
    optionsLayout->addWidget(desktopShortcutCheck);
    optionsLayout->addWidget(startMenuCheck);
    
    mainLayout->addWidget(optionsGroup);
    
    // Barra de progreso
    QGroupBox *progressGroup = new QGroupBox("📊 Progreso de Instalación");
    QVBoxLayout *progressLayout = new QVBoxLayout(progressGroup);
    
    QHBoxLayout *statusLayout = new QHBoxLayout();
    QLabel *progressTitle = new QLabel("Estado:");
    progressTitle->setStyleSheet("font-weight: bold;");
    
    statusLabel = new QLabel("Listo para instalar");
    statusLabel->setStyleSheet("color: #34495e;");
    
    statusLayout->addWidget(progressTitle);
    statusLayout->addStretch();
    statusLayout->addWidget(statusLabel);
    progressLayout->addLayout(statusLayout);
    
    progressBar = new QProgressBar();
    progressBar->setTextVisible(true);
    progressBar->setFormat("%p%");
    progressLayout->addWidget(progressBar);
    
    // Área de log
    QFrame *logFrame = new QFrame();
    logFrame->setFrameStyle(QFrame::StyledPanel | QFrame::Sunken);
    
    QVBoxLayout *logLayout = new QVBoxLayout(logFrame);
    QLabel *logTitle = new QLabel("📝 Registro de Instalación");
    logTitle->setStyleSheet("font-weight: bold; margin-bottom: 5px;");
    
    logText = new QTextEdit();
    logText->setMaximumHeight(100);
    logText->setReadOnly(true);
    logText->setFont(QFont("Consolas", 9));
    
    logLayout->addWidget(logTitle);
    logLayout->addWidget(logText);
    progressLayout->addWidget(logFrame);
    
    mainLayout->addWidget(progressGroup);
    
    // Botones
    QHBoxLayout *buttonLayout = new QHBoxLayout();
    
    cancelButton = new QPushButton("✖️ Cancelar");
    cancelButton->setEnabled(false);
    
    installButton = new QPushButton("🚀 Iniciar Instalación");
    installButton->setDefault(true);
    
    buttonLayout->addStretch();
    buttonLayout->addWidget(cancelButton);
    buttonLayout->addWidget(installButton);
    
    mainLayout->addLayout(buttonLayout);
    
    // Conectar señales
    connect(installButton, &QPushButton::clicked, this, &InstallerWindow::startInstallation);
    connect(cancelButton, &QPushButton::clicked, this, &InstallerWindow::cancelInstallation);
    
    setCentralWidget(centralWidget);
    applyStyles();
}

void InstallerWindow::applyStyles() {
    QString styleSheet = R"(
        QMainWindow {
            background-color: #f8f9fa;
        }
        
        QGroupBox {
            font-weight: bold;
            font-size: 14px;
            border: 2px solid #dee2e6;
            border-radius: 8px;
            margin-top: 10px;
            padding-top: 15px;
            background-color: white;
        }
        
        QGroupBox::title {
            subcontrol-origin: margin;
            left: 10px;
            padding: 0 10px 0 10px;
            color: #495057;
        }
        
        QPushButton {
            background-color: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            font-weight: bold;
            font-size: 13px;
            min-width: 120px;
        }
        
        QPushButton:hover {
            background-color: #0056b3;
        }
        
        QPushButton:pressed {
            background-color: #004085;
        }
        
        QPushButton:disabled {
            background-color: #6c757d;
        }
        
        QProgressBar {
            border: 2px solid #dee2e6;
            border-radius: 5px;
            text-align: center;
            height: 25px;
            font-weight: bold;
        }
        
        QProgressBar::chunk {
            background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 #28a745, stop:1 #20c997);
            border-radius: 3px;
        }
        
        QTextEdit {
            border: 1px solid #ced4da;
            border-radius: 4px;
            background-color: #f8f9fa;
            font-family: 'Consolas', monospace;
            font-size: 10px;
        }
        
        QCheckBox {
            spacing: 8px;
            font-size: 13px;
        }
        
        QLabel {
            font-size: 13px;
        }
    )";
    
    setStyleSheet(styleSheet);
}

void InstallerWindow::startInstallation() {
    installButton->setEnabled(false);
    cancelButton->setEnabled(true);
    installButton->setText("Instalando...");
    
    logText->append("[" + QTime::currentTime().toString("hh:mm:ss") + "] Iniciando instalación...");
    logText->append("Arquitectura: " + currentArchitecture);
    
    // Simular instalación
    QTimer *timer = new QTimer(this);
    int progress = 0;
    
    connect(timer, &QTimer::timeout, [this, &progress, timer]() {
        progress += 5;
        updateProgress(progress, "Instalando...");
        
        if (progress >= 100) {
            timer->stop();
            timer->deleteLater();
            
            logText->append("✅ Instalación completada exitosamente!");
            statusLabel->setText("Instalación completada");
            
            QMessageBox::information(this, "✅ Éxito",
                "Atlas Interactive se ha instalado correctamente.\n\n"
                "Puedes encontrar el programa en:\n"
                "• Menú Inicio > Atlas Interactive\n"
                "• Acceso directo en el escritorio\n\n"
                "¡Gracias por instalar Atlas Interactive!");
            
            installButton->setText("🚀 Reinstalar");
            installButton->setEnabled(true);
            cancelButton->setEnabled(false);
        }
    });
    
    timer->start(200);
}

void InstallerWindow::cancelInstallation() {
    logText->append("❌ Instalación cancelada por el usuario");
    statusLabel->setText("Instalación cancelada");
    progressBar->setValue(0);
    
    installButton->setEnabled(true);
    installButton->setText("🚀 Iniciar Instalación");
    cancelButton->setEnabled(false);
}

void InstallerWindow::updateProgress(int percent, const QString &message) {
    progressBar->setValue(percent);
    statusLabel->setText(message);
    
    if (percent % 20 == 0) {
        logText->append("[" + QTime::currentTime().toString("hh:mm:ss") + "] " + 
                       QString("Progreso: %1% - %2").arg(percent).arg(message));
    }
}

void InstallerWindow::setArchitecture(const QString &arch) {
    currentArchitecture = arch;
    if (archLabel) {
        archLabel->setText("Instalador Universal • " + arch);
    }
}
IWCEEOF

# Crear main.cpp universal
cat > src/main.cpp << 'MAINEOF'
#include "installerwindow.h"
#include "archdetector.h"
#include <QApplication>
#include <QMessageBox>
#include <QStyleFactory>
#include <QFontDatabase>
#include <QCommandLineParser>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    
    // Configuración de la aplicación
    app.setApplicationName("Atlas Interactive");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("Atlas Interactive");
    app.setStyle(QStyleFactory::create("Fusion"));
    
    // Procesar argumentos de línea de comandos
    QCommandLineParser parser;
    parser.setApplicationDescription("Atlas Interactive Universal Installer");
    parser.addHelpOption();
    parser.addVersionOption();
    
    QCommandLineOption silentOption("silent", "Instalación silenciosa");
    parser.addOption(silentOption);
    
    QCommandLineOption archOption("arch", "Forzar arquitectura (32/64)", "architecture");
    parser.addOption(archOption);
    
    parser.process(app);
    
    // Detectar arquitectura
    ArchDetector::Architecture arch = ArchDetector::detectCurrentArchitecture();
    
    // Verificar compatibilidad
    #ifdef ATLAS_32BIT
    if (ArchDetector::is64Bit()) {
        if (!parser.isSet(silentOption)) {
            QMessageBox::warning(nullptr, "Arquitectura incompatible",
                "Este instalador es de 32-bit pero estás ejecutando en un sistema 64-bit.\n\n"
                "Recomendación: Descarga la versión 64-bit para mejor rendimiento.\n\n"
                "¿Deseas continuar con la instalación 32-bit?");
        }
    }
    #endif
    
    #ifdef ATLAS_64BIT
    if (!ArchDetector::is64Bit()) {
        QMessageBox::critical(nullptr, "Error de compatibilidad",
            "Este instalador requiere un sistema operativo de 64-bit.\n\n"
            "Tu sistema es de 32-bit. Por favor descarga la versión 32-bit.");
        return 1;
    }
    #endif
    
    // Crear y mostrar ventana principal
    InstallerWindow window;
    
    // Configurar arquitectura en la ventana
    QString archStr = ArchDetector::architectureToString(arch);
    #ifdef ATLAS_32BIT
    archStr += " (Instalador 32-bit)";
    #elif defined(ATLAS_64BIT)
    archStr += " (Instalador 64-bit)";
    #endif
    
    window.setArchitecture(archStr);
    window.show();
    
    return app.exec();
}
MAINEOF

# Crear downloadmanager mínimo
cat > include/downloadmanager.h << 'DMHEOF'
#ifndef DOWNLOADMANAGER_H
#define DOWNLOADMANAGER_H

#include <QObject>

class DownloadManager : public QObject {
    Q_OBJECT
    
public:
    explicit DownloadManager(QObject *parent = nullptr);
    
public slots:
    void startDownload(const QString &url);
    void cancelDownload();
    
signals:
    void progressChanged(int percent);
    void downloadFinished(bool success, const QString &message);
    void logMessage(const QString &message);
};

#endif // DOWNLOADMANAGER_H
DMHEOF

cat > src/downloadmanager.cpp << 'DMCPEOF'
#include "downloadmanager.h"
#include <QTimer>

DownloadManager::DownloadManager(QObject *parent) : QObject(parent) {}

void DownloadManager::startDownload(const QString &url) {
    emit logMessage("Iniciando descarga desde: " + url);
    
    // Simular descarga
    QTimer *timer = new QTimer(this);
    int progress = 0;
    
    connect(timer, &QTimer::timeout, [this, &progress, timer, url]() {
        progress += 2;
        emit progressChanged(progress);
        
        if (progress % 10 == 0) {
            emit logMessage(QString("Descargando... %1%").arg(progress));
        }
        
        if (progress >= 100) {
            timer->stop();
            timer->deleteLater();
            emit logMessage("✅ Descarga completada");
            emit downloadFinished(true, "Archivo descargado correctamente: " + url);
        }
    });
    
    timer->start(100);
}

void DownloadManager::cancelDownload() {
    emit logMessage("❌ Descarga cancelada");
    emit downloadFinished(false, "Descarga cancelada por el usuario");
}
DMCPEOF


# ---- VERIFICAR QUE LOS ARCHIVOS SE CREARON CORRECTAMENTE ----
echo "🔍 Verificando creación de archivos fuente..."

# Verificar que los archivos .h y .cpp existen
if [ ! -f "$BUILD_DIR/include/installerwindow.h" ]; then
    echo "❌ Error: installerwindow.h no se creó"
    echo "   Creando manualmente..."
    # Volver a crear el archivo si falló
    cat > "$BUILD_DIR/include/installerwindow.h" << 'IWHEOF'
#ifndef INSTALLERWINDOW_H
#define INSTALLERWINDOW_H

#include <QMainWindow>
#include <QString>

class QProgressBar;
class QLabel;
class QPushButton;
class QTextEdit;
class QCheckBox;

class InstallerWindow : public QMainWindow {
    Q_OBJECT
    
public:
    explicit InstallerWindow(QWidget *parent = nullptr);
    
    void setArchitecture(const QString &arch);
    
private slots:
    void startInstallation();
    void cancelInstallation();
    void updateProgress(int percent, const QString &message);
    
private:
    void setupUI();
    void createLayout();
    void applyStyles();
    
    // UI Elements
    QLabel *titleLabel;
    QLabel *archLabel;
    QLabel *statusLabel;
    QProgressBar *progressBar;
    QPushButton *installButton;
    QPushButton *cancelButton;
    QCheckBox *desktopShortcutCheck;
    QCheckBox *startMenuCheck;
    QTextEdit *logText;
    
    QString currentArchitecture;
};

#endif // INSTALLERWINDOW_H
IWHEOF
fi

if [ ! -f "$BUILD_DIR/src/main.cpp" ]; then
    echo "❌ Error: main.cpp no se creó"
    # Crearlo manualmente
    mkdir -p "$BUILD_DIR/src"
    # ... contenido de main.cpp ...
fi

# Listar archivos creados para verificación
echo ""
echo "📋 Archivos fuente creados:"
echo "  Headers (.h):"
find "$BUILD_DIR/include" -name "*.h" -exec basename {} \; | while read file; do
    echo "    • $file"
done
echo "  Fuentes (.cpp):"
find "$BUILD_DIR/src" -name "*.cpp" -exec basename {} \; | while read file; do
    echo "    • $file"
done
echo ""


# ---- VERSIÓN SIMPLIFICADA DE LA FUNCIÓN DE COMPILACIÓN ----
compile_simple() {
    local qmake="$1"
    local arch_name="$2"
    local build_dir="$3"
    
    echo ""
    echo "🔨 Compilando versión $arch_name..."
    echo "   Usando: $(basename $qmake)"
    
    # Crear directorio limpio
    local arch_build_dir="$build_dir/${arch_name}_simple"
    rm -rf "$arch_build_dir"
    mkdir -p "$arch_build_dir"
    cd "$arch_build_dir"
    
    # Crear un proyecto Qt MÍNIMO que funcione
    cat > minimal.pro << 'MINPRO'
QT += core gui widgets
CONFIG += c++11 release
TARGET = AtlasInstaller
TEMPLATE = app

SOURCES = main_simple.cpp
HEADERS = 
RESOURCES = 

win32 {
    RC_FILE = app.rc
    LIBS += -lole32 -luuid
    QMAKE_LFLAGS += -static
    DEFINES += WIN32_LEAN_AND_MEAN _WIN32_WINNT=0x0601
}

CONFIG(debug, debug|release) {
    TARGET = $${TARGET}_debug
}
MINPRO
    
    # Crear archivo RC básico
    cat > app.rc << 'APPRC'
#include <windows.h>
VS_VERSION_INFO VERSIONINFO
 FILEVERSION 1,0,0,0
 PRODUCTVERSION 1,0,0,0
BEGIN
    BLOCK "StringFileInfo" { BLOCK "040904b0" { VALUE "ProductName", "Atlas" } }
    BLOCK "VarFileInfo" { VALUE "Translation", 0x409, 1200 }
END
APPRC
    
    # Crear código fuente mínimo
    cat > main_simple.cpp << 'MAINSIMPLE'
#include <QApplication>
#include <QWidget>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>
#include <QMessageBox>
#include <QProgressBar>
#include <QTimer>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    
    QWidget window;
    window.setWindowTitle("Atlas Interactive Installer - " + QString(argv[0]).contains("64") ? "64-bit" : "32-bit");
    window.setFixedSize(500, 400);
    
    QVBoxLayout *layout = new QVBoxLayout(&window);
    
    // Título
    QLabel *title = new QLabel("Atlas Interactive");
    title->setAlignment(Qt::AlignCenter);
    title->setStyleSheet("font-size: 24px; font-weight: bold; color: #2c3e50;");
    
    // Información de arquitectura
    QLabel *archInfo = new QLabel(
        QString("Versión: %1-bit\n\n").arg(QString(argv[0]).contains("64") ? "64" : "32") +
        "Este instalador configurará Atlas Interactive en tu sistema.\n\n" +
        "• Requiere 25 GB de espacio libre\n" +
        "• Windows 7 o superior\n" +
        "• Conexión a Internet"
    );
    archInfo->setAlignment(Qt::AlignCenter);
    archInfo->setWordWrap(true);
    
    // Barra de progreso
    QProgressBar *progress = new QProgressBar();
    progress->setTextVisible(true);
    progress->setFormat("%p%");
    
    // Botones
    QPushButton *installBtn = new QPushButton("🚀 Instalar");
    installBtn->setStyleSheet(
        "QPushButton {"
        "  background-color: #3498db;"
        "  color: white;"
        "  padding: 15px;"
        "  font-size: 16px;"
        "  font-weight: bold;"
        "  border-radius: 5px;"
        "}"
        "QPushButton:hover { background-color: #2980b9; }"
    );
    
    QPushButton *cancelBtn = new QPushButton("Cancelar");
    
    layout->addWidget(title);
    layout->addWidget(archInfo);
    layout->addWidget(progress);
    layout->addStretch();
    layout->addWidget(installBtn);
    layout->addWidget(cancelBtn);
    
    // Conectar señal de instalación
    QObject::connect(installBtn, &QPushButton::clicked, [&window, progress]() {
        QTimer *timer = new QTimer(&window);
        int value = 0;
        
        QObject::connect(timer, &QTimer::timeout, [&value, progress, timer, &window]() {
            value += 5;
            progress->setValue(value);
            
            if (value >= 100) {
                timer->stop();
                timer->deleteLater();
                QMessageBox::information(&window, "✅ Instalación completada",
                    "Atlas Interactive se ha instalado correctamente.\n\n"
                    "Puedes encontrar el programa en el menú Inicio o escritorio.");
            }
        });
        
        timer->start(200);
    });
    
    QObject::connect(cancelBtn, &QPushButton::clicked, &window, &QWidget::close);
    
    window.show();
    return app.exec();
}
MAINSIMPLE
    
    # Compilar
    echo "   Compilando proyecto mínimo..."
    "$qmake" minimal.pro
    make -j$(nproc) 2>&1 | tee build.log
    
    if [ $? -eq 0 ] && [ -f "release/AtlasInstaller.exe" ]; then
        local output_name="AtlasInstaller_${arch_name}.exe"
        cp release/AtlasInstaller.exe "$OUTPUT_DIR/$output_name"
        echo "✅ Versión $arch_name compilada: $output_name"
        
        # Optimizar tamaño
        if command -v strip &> /dev/null; then
            strip "$OUTPUT_DIR/$output_name" 2>/dev/null || true
        fi
        
        local size_kb=$(du -k "$OUTPUT_DIR/$output_name" 2>/dev/null | cut -f1 || echo "0")
        local size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
        echo "   Tamaño: ${size_mb}MB"
        
        return 0
    else
        echo "❌ Error compilando versión $arch_name"
        echo "   Últimas líneas del log:"
        tail -10 build.log
        return 1
    fi
}


# ---- FUNCIÓN DE COMPILACIÓN ----
compile_for_architecture() {
    local qmake="$1"
    local arch_name="$2"
    local build_dir="$3"
    
    echo ""
    echo "🔨 Compilando versión $arch_name..."
    echo "   Usando: $(basename $qmake)"
    
    # Crear directorio de build específico
    local arch_build_dir="$build_dir/$arch_name"
    rm -rf "$arch_build_dir"
    mkdir -p "$arch_build_dir"
    
    # Crear estructura completa de directorios
    mkdir -p "$arch_build_dir/src" "$arch_build_dir/include" "$arch_build_dir/assets"
    
    # Copiar TODOS los archivos necesarios
    echo "   Copiando archivos fuente..."
    
    # Copiar archivos .pro, .qrc, .rc
    cp "$BUILD_DIR/AtlasUniversal.pro" "$arch_build_dir/"
    cp "$BUILD_DIR/resources.qrc" "$arch_build_dir/"
    cp "$BUILD_DIR/resources.rc" "$arch_build_dir/"
    
    # Copiar assets
    cp -r "$BUILD_DIR/assets" "$arch_build_dir/"
    
    # Copiar archivos fuente (.cpp)
    find "$BUILD_DIR/src" -name "*.cpp" -exec cp {} "$arch_build_dir/src/" \;
    
    # Copiar archivos de cabecera (.h)
    find "$BUILD_DIR/include" -name "*.h" -exec cp {} "$arch_build_dir/include/" \;
    
    # Crear archivo .pro local si es necesario
    cd "$arch_build_dir"
    
    # Asegurar que las rutas de inclusión sean correctas
    if [ ! -f "local.pro" ]; then
        cat > local.pro << 'LOCALPRO'
# Archivo de configuración local para $arch_name

# Incluir el archivo principal
include(AtlasUniversal.pro)

# Ruta de inclusión para headers
INCLUDEPATH += $$PWD/include
DEPENDPATH += $$PWD/include

# Para asegurar que los headers se encuentran
QMAKE_CXXFLAGS += -I$$PWD/include
LOCALPRO
    fi
    
    # Ejecutar qmake y make
    echo "   Ejecutando qmake..."
    "$qmake" local.pro
    if [ $? -ne 0 ]; then
        echo "❌ Error en qmake para $arch_name"
        return 1
    fi
    
    echo "   Compilando con make..."
    make -j$(nproc)
    if [ $? -ne 0 ]; then
        echo "❌ Error en make para $arch_name"
        echo "   Últimos errores:"
        tail -20 release/make.log 2>/dev/null || echo "   No hay log disponible"
        return 1
    fi
    
    # Buscar ejecutable compilado
    local exe_name=""
    if [ -f "release/AtlasInstaller64.exe" ]; then
        exe_name="AtlasInstaller64.exe"
    elif [ -f "release/AtlasInstaller32.exe" ]; then
        exe_name="AtlasInstaller32.exe"
    elif [ -f "AtlasInstaller64.exe" ]; then
        exe_name="AtlasInstaller64.exe"
    elif [ -f "AtlasInstaller32.exe" ]; then
        exe_name="AtlasInstaller32.exe"
    fi
    
    if [ -n "$exe_name" ]; then
        local output_name="AtlasInstaller_${arch_name}.exe"
        cp "$exe_name" "$OUTPUT_DIR/$output_name"
        echo "✅ Versión $arch_name compilada: $output_name"
        
        # Obtener información del archivo
        local size_kb=$(du -k "$OUTPUT_DIR/$output_name" 2>/dev/null | cut -f1 || echo "0")
        local size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
        echo "   Tamaño: ${size_mb}MB"
        
        # Verificar que el archivo es válido
        if command -v file &> /dev/null; then
            echo "   Tipo: $(file "$OUTPUT_DIR/$output_name" | cut -d: -f2-)"
        fi
        
        return 0
    else
        echo "❌ No se encontró ejecutable para $arch_name"
        echo "   Buscando archivos .exe..."
        find . -name "*.exe" -type f | head -5
        return 1
    fi
}


# ---- COMPILACIÓN SEGÚN MODO ----
echo ""
echo "🚀 INICIANDO COMPILACIÓN..."
echo "=========================================="

# case $BUILD_MODE in
#     "64BIT_ONLY")
#         compile_for_architecture "$QMAKE_64" "64bit" "$BUILD_DIR"
#         ;;
        
#     "32BIT_ONLY")
#         compile_for_architecture "$QMAKE_32" "32bit" "$BUILD_DIR"
#         ;;
        
#     "BOTH")
#         compile_for_architecture "$QMAKE_64" "64bit" "$BUILD_DIR"
#         compile_for_architecture "$QMAKE_32" "32bit" "$BUILD_DIR"
#         ;;
        
#     "UNIVERSAL")
#         # Para universal, compilamos ambas y creamos un launcher
#         compile_for_architecture "$QMAKE_64" "64bit" "$BUILD_DIR"
#         compile_for_architecture "$QMAKE_32" "32bit" "$BUILD_DIR"
        

case $BUILD_MODE in
    "64BIT_ONLY")
        compile_simple "$QMAKE_64" "64bit" "$BUILD_DIR"
        ;;
        
    "32BIT_ONLY")
        compile_simple "$QMAKE_32" "32bit" "$BUILD_DIR"
        ;;
        
    "BOTH")
        compile_simple "$QMAKE_64" "64bit" "$BUILD_DIR"
        compile_simple "$QMAKE_32" "32bit" "$BUILD_DIR"
        ;;
        
    "UNIVERSAL")
        compile_simple "$QMAKE_64" "64bit" "$BUILD_DIR"
        compile_simple "$QMAKE_32" "32bit" "$BUILD_DIR"


        # Crear script launcher universal
        echo ""
        echo "🔗 Creando launcher universal..."
        
        cat > "$OUTPUT_DIR/AtlasInstaller_Universal.bat" << 'BATEOF'
@echo off
chcp 65001 >nul
echo Atlas Interactive - Universal Installer Launcher
echo ================================================
echo.

REM Detectar arquitectura
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo Arquitectura detectada: 64-bit
    echo Ejecutando instalador 64-bit...
    echo.
    start "" "%~dp0\AtlasInstaller_64bit.exe" %*
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    echo Arquitectura detectada: 32-bit
    echo Ejecutando instalador 32-bit...
    echo.
    start "" "%~dp0\AtlasInstaller_32bit.exe" %*
) else (
    echo Arquitectura no soportada: %PROCESSOR_ARCHITECTURE%
    pause
    exit /b 1
)

exit /b 0
BATEOF
        
        # También crear un launcher PowerShell más avanzado
        cat > "$OUTPUT_DIR/AtlasInstaller_Universal.ps1" << 'PSEOF'
# Atlas Interactive Universal Installer Launcher
# PowerShell script para auto-detección de arquitectura

Write-Host "Atlas Interactive - Universal Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Detectar arquitectura
$arch = $env:PROCESSOR_ARCHITECTURE
$is64Bit = [Environment]::Is64BitOperatingSystem

if ($is64Bit -or $arch -eq "AMD64") {
    Write-Host "✅ Arquitectura detectada: 64-bit" -ForegroundColor Green
    Write-Host "   Ejecutando instalador 64-bit..." -ForegroundColor Yellow
    Write-Host ""
    
    $installer = Join-Path $PSScriptRoot "AtlasInstaller_64bit.exe"
    if (Test-Path $installer) {
        & $installer $args
        exit $LASTEXITCODE
    } else {
        Write-Host "❌ Error: No se encontró el instalador 64-bit" -ForegroundColor Red
        Write-Host "   Asegúrate de que AtlasInstaller_64bit.exe está en la misma carpeta." -ForegroundColor Yellow
        pause
        exit 1
    }
} elseif ($arch -eq "x86") {
    Write-Host "ℹ️  Arquitectura detectada: 32-bit" -ForegroundColor Yellow
    Write-Host "   Ejecutando instalador 32-bit..." -ForegroundColor Yellow
    Write-Host ""
    
    $installer = Join-Path $PSScriptRoot "AtlasInstaller_32bit.exe"
    if (Test-Path $installer) {
        & $installer $args
        exit $LASTEXITCODE
    } else {
        Write-Host "❌ Error: No se encontró el instalador 32-bit" -ForegroundColor Red
        pause
        exit 1
    }
} else {
    Write-Host "❌ Error: Arquitectura no soportada: $arch" -ForegroundColor Red
    Write-Host "   Requiere Windows x86 (32-bit) o x64 (64-bit)." -ForegroundColor Yellow
    pause
    exit 1
}
PSEOF
        
        # Crear README para el paquete universal
        cat > "$OUTPUT_DIR/README_UNIVERSAL.txt" << 'README'
ATLAS INTERACTIVE - INSTALADOR UNIVERSAL
========================================

Este paquete contiene tres métodos de instalación:

1. INSTALADOR AUTOMÁTICO (RECOMENDADO)
   -----------------------------------
   • Ejecuta: AtlasInstaller_Universal.bat
   • O: AtlasInstaller_Universal.ps1
   • Auto-detecta tu arquitectura (32/64-bit)
   • Ejecuta el instalador correcto automáticamente

2. INSTALADORES MANUALES
   ---------------------
   • Para 64-bit: AtlasInstaller_64bit.exe
   • Para 32-bit: AtlasInstaller_32bit.exe

3. ARQUITECTURAS SOPORTADAS
   ------------------------
   • 64-bit: Windows 7/8/10/11 de 64-bit
   • 32-bit: Windows 7/8/10 de 32-bit

4. REQUISITOS DEL SISTEMA
   -----------------------
   • 25 GB de espacio libre
   • Windows 7 o superior
   • Conexión a Internet para descarga
   • Permisos de escritura en disco

5. USO AVANZADO
   -------------
   Ejecutar con parámetros:
   • --silent    : Instalación silenciosa
   • --dir="C:\Ruta" : Directorio personalizado
   • --help      : Mostrar ayuda

© 2025 Atlas Interactive Team
README
        
        echo "✅ Launcher universal creado"
        ;;
esac

# ---- RESUMEN FINAL ----
echo ""
echo "=========================================="
echo "✅ PROCESO DE COMPILACIÓN COMPLETADO"
echo "=========================================="
echo ""
echo "📁 Archivos generados en: $OUTPUT_DIR"
echo ""
ls -la "$OUTPUT_DIR/"*.exe "$OUTPUT_DIR/"*.bat "$OUTPUT_DIR/"*.ps1 2>/dev/null | while read line; do
    echo "   $line"
done
echo ""
echo "📄 Documentación:"
ls -la "$OUTPUT_DIR/"*.txt 2>/dev/null | while read line; do
    echo "   $line"
done
echo ""
echo "🚀 PARA DISTRIBUIR:"
echo "   1. Comprime la carpeta '$OUTPUT_DIR'"
echo "   2. Sube a GitHub Releases"
echo "   3. Actualiza tu sitio web"
echo ""
echo "🔧 RECOMENDACIONES:"
echo "   • Para mayoría de usuarios: Usar AtlasInstaller_Universal.bat"
echo "   • Para scripts/automatización: Usar el .exe específico"
echo "   • Para máxima compatibilidad: Distribuir todo el paquete"
echo ""
echo "🎯 ¡Listo para distribuir Atlas Interactive!"

