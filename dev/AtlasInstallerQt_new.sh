#!/bin/bash
# Script para construir el instalador Qt - VERSIÓN CON SELECCIÓN DE MÉTODO DE DESCARGA

echo "🔨 Construyendo instalador Qt con selección de método de descarga..."
echo "🖥️  Configuración optimizada para pantallas de alta resolución"
echo "📦 Usando Qt 5 (compatible con Ubuntu/Debian)"
echo "🌐 Método de descarga: FTP por defecto, Google Drive con flag --use-drive"

# ========== VERIFICAR VERSIÓN DE Qt ==========
echo "🔍 Verificando versión de Qt..."
QT_VERSION=$(qmake -query QT_VERSION 2>/dev/null || echo "0")
echo "   Versión Qt detectada: $QT_VERSION"

# ========== LIMPIAR ARCHIVOS ANTERIORES ==========
echo "🧹 Limpiando archivos anteriores..."
rm -rf build_qt 2>/dev/null
rm -f ../AtlasInstallerQt 2>/dev/null
rm -f ../AtlasInstallerQt_dpi 2>/dev/null
rm -f moc_* *.o *.so *.moc ui_* Makefile* .qmake.stash 2>/dev/null || true

# ========== CREAR DIRECTORIO DE CONSTRUCCIÓN ==========
mkdir -p build_qt
cd build_qt

# ========== CREAR ARCHIVO .pro COMPATIBLE CON Qt 5 ==========
echo "📝 Creando proyecto Qt compatible con Qt 5..."
cat > AtlasInstaller.pro << 'EOF'
QT += core gui widgets network
CONFIG += c++11
TARGET = AtlasInstaller
TEMPLATE = app
SOURCES = main.cpp installerwindow.cpp
HEADERS = installerwindow.h

# Optimizaciones
CONFIG += release
QMAKE_CXXFLAGS += -O2 -pipe
QMAKE_LFLAGS += -Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now

# Soporte DPI mejorado (compatible con Qt 5.6+)
DEFINES += QT_AUTO_SCREEN_SCALE_FACTOR=1

# Requerir Qt 5.6+ para DPI
greaterThan(QT_MAJOR_VERSION, 5) {
    # Qt 6 o superior
    QT += widgets
    DEFINES += QT_VERSION_6_PLUS
} else:equals(QT_MAJOR_VERSION, 5) {
    # Qt 5
    QT += widgets
    
    # Verificar versión menor para DPI
    QT_MINOR_VERSION = $$system(qmake -query QT_VERSION | cut -d. -f2)
    greaterThan(QT_MINOR_VERSION, 5) {
        # Qt 5.6 o superior
        DEFINES += QT_VERSION_5_6_PLUS
        message("Compilando con Qt 5.6+ - Soporte DPI completo")
    } else {
        # Qt 5.5 o inferior
        message("Compilando con Qt 5.5 o inferior - Soporte DPI limitado")
    }
}

# Deshabilitar advertencias específicas
QMAKE_CXXFLAGS += -Wno-deprecated-declarations
EOF

# ========== CREAR main.cpp ==========
echo "📝 Creando main.cpp con soporte para selección de método de descarga..."
cat > main.cpp << 'EOF'
#include "installerwindow.h"
#include <QApplication>
#include <QDir>
#include <QDebug>
#include <QStyleFactory>
#include <QFont>
#include <QScreen>
#include <QMessageBox>
#include <QTimer>

// Función para mostrar advertencia DPI (opcional)
void showDPIInfo(QScreen* screen) {
    qDebug() << "🖥️  Información de pantalla:";
    qDebug() << "   - DPI lógico:" << screen->logicalDotsPerInch();
    qDebug() << "   - DPI físico:" << screen->physicalDotsPerInch();
    qDebug() << "   - Ratio:" << screen->devicePixelRatio();
    qDebug() << "   - Tamaño:" << screen->size();
    qDebug() << "   - Tamaño disponible:" << screen->availableSize();
}

int main(int argc, char *argv[])
{
    // ========== CONFIGURACIÓN DE DPI ==========
    
    // Configurar variables de entorno para DPI
    qputenv("QT_AUTO_SCREEN_SCALE_FACTOR", "1");
    qputenv("QT_SCALE_FACTOR", "1");
    
    // Procesar argumentos de DPI desde línea de comandos
    bool disableDPIScaling = false;
    QString customScaleFactor = "";
    bool forceX11 = false;
    bool forceWayland = false;
    
    // ========== NUEVO: CONFIGURACIÓN MÉTODO DE DESCARGA ==========
    bool useFTP = true; // Por defecto usa FTP
    bool useDrive = false;

    for (int i = 1; i < argc; ++i) {
        QString arg = QString(argv[i]);
        
        if (arg == "--no-dpi-scaling") {
            disableDPIScaling = true;
            qputenv("QT_AUTO_SCREEN_SCALE_FACTOR", "0");
        }
        
        if (arg == "--scale-factor" && i + 1 < argc) {
            customScaleFactor = QString(argv[i + 1]);
            i++;
            qputenv("QT_SCALE_FACTOR", customScaleFactor.toUtf8());
            qDebug() << "🔧 Factor de escala personalizado:" << customScaleFactor;
        }
        
        if (arg == "--force-x11") {
            forceX11 = true;
            qputenv("QT_QPA_PLATFORM", "xcb");
        }
        
        if (arg == "--force-wayland") {
            forceWayland = true;
            qputenv("QT_QPA_PLATFORM", "wayland");
        }
        
        // ========== NUEVOS ARGUMENTOS PARA MÉTODO DE DESCARGA ==========
        if (arg == "--use-ftp") {
            useFTP = true;
            useDrive = false;
            qDebug() << "🔧 Usando FTP para descarga (configuración por defecto)";
        }
        
        if (arg == "--use-drive") {
            useFTP = false;
            useDrive = true;
            qDebug() << "🔧 Usando Google Drive para descarga";
        }
        
        if (arg == "--dpi-info") {
            // Mostrar información DPI después de crear QApplication
            QTimer::singleShot(100, []() {
                QScreen* screen = QGuiApplication::primaryScreen();
                if (screen) {
                    QMessageBox::information(nullptr, "Información DPI",
                        QString("Información de pantalla:\n\n"
                               "• DPI lógico: %1\n"
                               "• DPI físico: %2\n"
                               "• Ratio de píxeles: %3\n"
                               "• Resolución: %4×%5\n"
                               "• Tamaño disponible: %6×%7\n\n"
                               "Variables DPI activas:\n"
                               "• QT_AUTO_SCREEN_SCALE_FACTOR: %8\n"
                               "• QT_SCALE_FACTOR: %9")
                        .arg(screen->logicalDotsPerInch())
                        .arg(screen->physicalDotsPerInch())
                        .arg(screen->devicePixelRatio())
                        .arg(screen->size().width())
                        .arg(screen->size().height())
                        .arg(screen->availableSize().width())
                        .arg(screen->availableSize().height())
                        .arg(qgetenv("QT_AUTO_SCREEN_SCALE_FACTOR").constData())
                        .arg(qgetenv("QT_SCALE_FACTOR").constData()));
                }
            });
        }
        
        if (arg == "--help" || arg == "-h") {
            qInfo() << "AtlasInstallerQt - Instalador para Linux";
            qInfo() << "Uso: ./AtlasInstallerQt [OPCIONES]";
            qInfo() << "";
            qInfo() << "Opciones generales:";
            qInfo() << "  --help, -h          Mostrar esta ayuda";
            qInfo() << "  --version, -v       Mostrar versión";
            qInfo() << "  --install-dir PATH  Directorio de instalación";
            qInfo() << "  --skip-desktop      No crear accesos directos";
            qInfo() << "  --check-updates     Verificar actualizaciones";
            qInfo() << "";
            qInfo() << "Opciones de descarga:";
            qInfo() << "  --use-ftp           Usar FTP para descarga (POR DEFECTO)";
            qInfo() << "  --use-drive         Usar Google Drive para descarga";
            qInfo() << "";
            qInfo() << "Opciones de DPI/Pantalla:";
            qInfo() << "  --no-dpi-scaling    Deshabilitar escalado DPI (no recomendado)";
            qInfo() << "  --scale-factor NUM  Factor de escala personalizado (ej: 1.5)";
            qInfo() << "  --force-x11         Forzar modo X11";
            qInfo() << "  --force-wayland     Forzar modo Wayland";
            qInfo() << "  --dpi-info          Mostrar información de pantalla";
            qInfo() << "";
            qInfo() << "Ejemplos:";
            qInfo() << "  ./AtlasInstallerQt                     # Normal con FTP (default)";
            qInfo() << "  ./AtlasInstallerQt --use-drive         # Usar Google Drive";
            qInfo() << "  ./AtlasInstallerQt --use-ftp           # Forzar FTP";
            qInfo() << "  ./AtlasInstallerQt --scale-factor 1.5  # Escala 150%";
            qInfo() << "  ./AtlasInstallerQt --force-x11         # Forzar X11";
            qInfo() << "  ./AtlasInstallerQt --dpi-info          # Mostrar info técnica";
            return 0;
        }
        
        if (arg == "--version" || arg == "-v") {
            qInfo() << "AtlasInstallerQt v2.0.0";
            qInfo() << "Compilado con Qt" << QT_VERSION_STR;
            qInfo() << "Soporte DPI: ACTIVADO (variables de entorno)";
            qInfo() << "Método de descarga por defecto: FTP";
            qInfo() << "Plataforma: Qt Widgets";
            return 0;
        }
    }
    
    // Crear la aplicación
    QApplication app(argc, argv);
    
    // Configurar estilo de aplicación
    app.setStyle(QStyleFactory::create("Fusion"));
    
    // Configurar información de aplicación
    app.setApplicationName("Atlas Installer");
    app.setApplicationDisplayName("Atlas Interactivo Installer");
    app.setOrganizationName("Atlas Interactive");
    
    // Configurar paleta y fuente por defecto
    QFont defaultFont = QApplication::font();
    
    // Ajustar tamaño de fuente basado en DPI
    QScreen* primaryScreen = QGuiApplication::primaryScreen();
    if (primaryScreen) {
        showDPIInfo(primaryScreen);
        
        double dpiScale = primaryScreen->logicalDotsPerInch() / 96.0;
        if (dpiScale > 1.0 && !disableDPIScaling) {
            int newSize = qRound(defaultFont.pointSize() * dpiScale * 0.9);
            if (newSize > 8 && newSize < 16) {
                defaultFont.setPointSize(newSize);
                qDebug() << "🔍 Ajustando fuente a:" << newSize << "pt (DPI:" << dpiScale << ")";
            }
        }
    }
    
    QApplication::setFont(defaultFont);
    
    // Mostrar información de DPI en log
    if (!disableDPIScaling) {
        qDebug() << "✅ Escalado DPI automático: ACTIVADO";
        qDebug() << "   Configuración DPI:";
        qDebug() << "   - QT_AUTO_SCREEN_SCALE_FACTOR:" << qgetenv("QT_AUTO_SCREEN_SCALE_FACTOR").constData();
        qDebug() << "   - QT_SCALE_FACTOR:" << qgetenv("QT_SCALE_FACTOR").constData();
    } else {
        qDebug() << "⚠️  Escalado DPI automático: DESACTIVADO (--no-dpi-scaling)";
    }
    
    // Mostrar información de método de descarga
    if (useFTP) {
        qDebug() << "🌐 Método de descarga: FTP (por defecto)";
    } else if (useDrive) {
        qDebug() << "🌐 Método de descarga: Google Drive";
    }
    
    // ========== PROCESAR ARGUMENTOS RESTANTES ==========
    
    QString installDir = QDir::homePath() + "/Atlas_Interactivo";
    bool skipDesktop = false;
    
    // Procesar argumentos de instalación (manejar aquí los no-DPI)
    for (int i = 1; i < argc; ++i) {
        QString arg = QString(argv[i]);
        
        // Saltar argumentos DPI que ya procesamos
        if (arg == "--no-dpi-scaling" || arg == "--scale-factor" || 
            arg == "--force-x11" || arg == "--force-wayland" || 
            arg == "--dpi-info" || arg == "--use-ftp" || arg == "--use-drive") {
            // Si era --scale-factor, saltar el valor también
            if (arg == "--scale-factor") i++;
            continue;
        }
        
        if (arg == "--install-dir" && i + 1 < argc) {
            installDir = QString(argv[i + 1]);
            i++; // Saltar al siguiente argumento
        }

        if (arg == "--check-updates") {
            QString installedPath = QDir::homePath() + "/Atlas_Interactivo/.atlas_version.json";
            if (QFile::exists(installedPath)) {
                qInfo() << "✅ Atlas Interactivo está instalado.";
                qInfo() << "   Para actualizaciones, ejecuta el instalador normalmente.";
                qInfo() << "   Se detectarán y aplicarán automáticamente.";
            } else {
                qInfo() << "ℹ️  Atlas Interactivo no está instalado.";
                qInfo() << "   Ejecuta sin argumentos para instalar.";
            }
            return 0;
        }

        if (arg == "--skip-desktop") {
            skipDesktop = true;
        }
    }
    

    // Verificar que el directorio de instalación sea válido
    if (installDir.isEmpty()) {
        installDir = QDir::homePath() + "/Atlas_Interactivo";
        qWarning() << "⚠️  Directorio de instalación estaba vacío, usando:" << installDir;
    }

    // Verificar que no haya rutas con caracteres especiales
    if (installDir.contains("//") || installDir.endsWith("/")) {
        installDir = QDir::cleanPath(installDir);
    }


    // ========== CREAR VENTANA PRINCIPAL ==========
    
    qDebug() << "🚀 Creando ventana principal...";
    InstallerWindow window;
    
    // Configurar método de descarga
    window.setDownloadMethod(useFTP, useDrive);
    
    // Configurar directorio si se especificó
    if (installDir != QDir::homePath() + "/Atlas_Interactivo") {
        window.setInstallDir(installDir);
    }
    
    // Configurar opciones de acceso directo
    if (skipDesktop) {
        window.setSkipDesktopShortcuts(true);
    }
    
    // Mostrar ventana
    window.show();
    
    qDebug() << "✅ Aplicación iniciada correctamente con soporte DPI";
    
    return app.exec();
}
EOF

# ========== CREAR installerwindow.h CORREGIDO ==========
echo "📝 Creando installerwindow.h con soporte para método de descarga..."
cat > installerwindow.h << 'EOF'
#ifndef INSTALLERWINDOW_H
#define INSTALLERWINDOW_H

#include <QMainWindow>
#include <QProgressBar>
#include <QLabel>
#include <QPushButton>
#include <QLineEdit>
#include <QCheckBox>
#include <QTextEdit>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QScrollArea>
#include <QTimer>

// Solo declaraciones forward
class InstallWorker;
class QNetworkAccessManager;
class QThread;

class InstallerWindow : public QMainWindow
{
    Q_OBJECT
    
public:
    explicit InstallerWindow(QWidget *parent = nullptr);
    
    // Métodos para configuración desde CLI
    void setInstallDir(const QString &dir);
    void setSkipDesktopShortcuts(bool skip);
    
    // ========== NUEVO MÉTODO PARA MÉTODO DE DESCARGA ==========
    void setDownloadMethod(bool useFTP, bool useDrive);
    
    bool isInstalling() const { return m_isInstalling; }
    
    // ========== NUEVO MÉTODO PARA ACTUALIZACIÓN PERIÓDICA ==========
    void updateDiskSpacePeriodic();

private slots:
    void browseDirectory();
    void startInstallation();
    void updateProgress(int value, const QString &message);
    void installationFinished(bool success, const QString &message);
    void clearLog();
    void updateDiskSpace();
    void cancelCurrentInstallation();

protected:
    void closeEvent(QCloseEvent *event) override;

private:
    void setupUI();
    bool checkDiskSpace();
    bool hasSufficientDiskSpace(qint64 requiredGB);
    void createDesktopEntry();
    bool extractArchive(const QString &archivePath, const QString &outputDir);
    QFont getScaledFont(int baseSize);
    qint64 getAvailableDiskSpace(const QString &path);
    qint64 getAvailableDiskSpacePrecise(const QString &path);
    QString formatBytes(qint64 bytes);
    
    // Componentes de UI
    QWidget *centralWidget;
    QLabel *titleLabel;
    QLabel *subtitleLabel;
    QLabel *statusLabel;
    QLabel *diskSpaceLabel;
    QLabel *spaceWarningLabel;
    QLabel *downloadMethodLabel; // ========== NUEVO ==========
    QProgressBar *progressBar;
    QLineEdit *directoryEdit;
    QPushButton *browseButton;
    QPushButton *installButton;
    QPushButton *exitButton;
    QPushButton *aboutButton;
    QPushButton *clearLogButton;
    QCheckBox *desktopShortcutCheck;
    QCheckBox *menuShortcutCheck;
    QTextEdit *logText;
    
    // Variables de estado
    QString installDir;
    QNetworkAccessManager *networkManager;
    bool m_skipDesktopShortcuts;
    double dpiScale;
    bool m_hasSufficientSpace;
    
    // ========== NUEVAS VARIABLES PARA MÉTODO DE DESCARGA ==========
    QString downloadMethod; // "ftp" o "drive"
    QString ftpUrl;
    QString driveId;
    
    // Variables para controlar la instalación
    InstallWorker *currentWorker;
    QThread *currentThread;
    bool m_isInstalling;
    
    // Timer para actualizar espacio en disco
    QTimer *diskSpaceTimer;
};

#endif
EOF

# ========== CREAR installerwindow.cpp CORREGIDO ==========
echo "📝 Creando installerwindow.cpp con soporte para método de descarga..."
cat > installerwindow.cpp << 'EOF'
#include <QUuid>
#include "installerwindow.h"
#include <QFileDialog>
#include <QMessageBox>
#include <QDir>
#include <QDateTime>
#include <QThread>
#include <QMetaObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QProcess>
#include <QEventLoop>
#include <QTimer>
#include <QRegularExpression>
#include <QTextStream>
#include <QTemporaryFile>
#include <QStandardPaths>
#include <QUuid>
#include <QGuiApplication>
#include <QScreen>
#include <QFont>
#include <QSpacerItem>
#include <QApplication>
#include <QDesktopWidget>
#include <QLocale>
#include <QResizeEvent>

#include <sys/statvfs.h>

// Clase Worker
class InstallWorker : public QObject {
    Q_OBJECT
    
public:
    explicit InstallWorker(const QString &installDir, const QString &downloadMethod, 
                         const QString &ftpUrl, const QString &driveId) 
        : m_installDir(installDir), m_downloadMethod(downloadMethod), 
          m_ftpUrl(ftpUrl), m_driveId(driveId), 
          m_canceled(false), m_downloadAttempts(0) {}
    
    ~InstallWorker() {
        // Marcar como cancelado para evitar nuevos procesos
        m_canceled = true;
        
        // Esperar un momento para que cualquier proceso termine
        QThread::msleep(100);
        
        // Limpiar archivo temporal si existe
        if (!m_tempArchive.isEmpty() && QFile::exists(m_tempArchive)) {
            QFile::remove(m_tempArchive);
        }
        
        // Limpiar otros archivos temporales de manera segura
        QString tempDir = QDir::tempPath();
        if (!tempDir.isEmpty()) {
            QDir temp(tempDir);
            // Solo limpiar archivos específicos que creamos
            QStringList ourFiles = temp.entryList(QStringList() 
                << "gdrive_" + QUuid::createUuid().toString().mid(1, 8) + "*"
                << "tar_list_" + QUuid::createUuid().toString().mid(1, 8) + "*",
                QDir::Files);
            
            foreach (const QString &file, ourFiles) {
                QString filePath = tempDir + "/" + file;
                if (!filePath.isEmpty() && QFile::exists(filePath)) {
                    QFile::remove(filePath);
                }
            }
        }
    }

public slots:
    void cleanupProcesses() {
        if (!m_canceled) {
            m_canceled = true;
            
            qDebug() << "Worker: Iniciando limpieza de procesos...";
            
            // Terminar cualquier proceso pendiente de manera segura
            QProcess killProcess;
            
            // Lista de comandos para matar procesos
            QStringList killCommands = {
                "pkill -f \"wget.*google\"",
                "pkill -f \"curl.*google\"",
                "pkill -f \"tar.*atlas\"",
                "killall -9 wget 2>/dev/null",
                "killall -9 curl 2>/dev/null"
            };
            
            foreach (const QString &cmd, killCommands) {
                killProcess.start("bash", QStringList() << "-c" << cmd);
                if (killProcess.waitForStarted(500)) {
                    killProcess.waitForFinished(1000);
                }
            }
            
            // Limpiar archivos temporales
            if (!m_tempArchive.isEmpty() && QFile::exists(m_tempArchive)) {
                for (int attempt = 0; attempt < 3; attempt++) {
                    if (QFile::remove(m_tempArchive)) {
                        qDebug() << "Worker: Archivo temporal eliminado:" << m_tempArchive;
                        break;
                    }
                    QThread::msleep(100);
                }
                m_tempArchive.clear();
            }
            
            // Sincronizar disco
            QProcess syncProcess;
            syncProcess.start("sync", QStringList());
            syncProcess.waitForFinished(500);
            
            qDebug() << "Worker: Limpieza completada";
            
            emit logMessage("🧹 Procesos y archivos temporales limpiados");
        }
    }

    void doWork() {
        emit logMessage("Iniciando descarga de Atlas Interactivo...");
        emit logMessage("Esto puede tomar tiempo dependiendo de tu conexión.");
        
        // ========== INFORMAR MÉTODO DE DESCARGA ==========
        if (m_downloadMethod == "ftp") {
            emit logMessage("🌐 Método de descarga: FTP");
            emit logMessage("📁 URL FTP: " + m_ftpUrl);
        } else if (m_downloadMethod == "drive") {
            emit logMessage("🌐 Método de descarga: Google Drive");
            emit logMessage("📁 ID de Google Drive: " + m_driveId);
        }
        
        // Crear archivo temporal para la descarga (.tar)
        QTemporaryFile tempFile(QDir::tempPath() + "/atlas_XXXXXX.tar");
        tempFile.setAutoRemove(false);
        if (!tempFile.open()) {
            emit logMessage("❌ No se pudo crear archivo temporal");
            emit workFinished(false, "Error al crear archivo temporal");
            return;
        }
        m_tempArchive = tempFile.fileName();
        tempFile.close();
        
        emit progressUpdated(5, "Preparando descarga...");
        emit logMessage("Archivo temporal: " + m_tempArchive);
        
        // ========== OBTENER URL DE DESCARGA SEGÚN MÉTODO ==========
        QString downloadUrl;
        if (m_downloadMethod == "ftp") {
            downloadUrl = m_ftpUrl;
            emit logMessage("🔄 Usando FTP para descarga...");
        } else if (m_downloadMethod == "drive") {
            downloadUrl = getDirectDownloadUrl();
            emit logMessage("🔄 Usando Google Drive para descarga...");
        } else {
            emit logMessage("❌ Método de descarga desconocido: " + m_downloadMethod);
            emit workFinished(false, "Método de descarga no válido");
            return;
        }
        
        // Descarga con reintentos y resumible
        if (!downloadWithRetries(downloadUrl, m_tempArchive, 3)) {
            emit logMessage("❌ Falló la descarga después de varios intentos");
            emit workFinished(false, "No se pudo descargar el archivo. Verifica tu conexión a internet.");
            return;
        }
        
        // Verificar que el archivo existe y no está vacío
        QFileInfo fileInfo(m_tempArchive);
        if (!fileInfo.exists() || fileInfo.size() == 0) {
            emit logMessage("❌ Archivo descargado está vacío o no existe");
            emit workFinished(false, "El archivo descargado está vacío. Verifica la URL.");
            return;
        }
        
        emit logMessage(QString("✅ Descarga completada: %1 bytes").arg(fileInfo.size()));
        emit progressUpdated(50, "Descarga completada");
        
        // Extraer archivos
        emit progressUpdated(60, "Extrayendo archivos...");
        emit logMessage("Extrayendo archivo .tar en grupos...");
        
        bool extractionSuccess = false;
        
        // Primero intentar extracción incremental
        if (extractArchiveIncremental(m_tempArchive, m_installDir)) {
            extractionSuccess = true;
        } else {
            emit logMessage("⚠️  Extracción incremental falló, intentando método simple...");
            emit logMessage("📊 Tamaño del archivo: " + formatBytes(QFileInfo(m_tempArchive).size()));
            
            // Intentar método simple
            if (extractArchiveSimple(m_tempArchive, m_installDir)) {
                extractionSuccess = true;
            } else {
                emit logMessage("❌ Ambos métodos de extracción fallaron");
                emit workFinished(false, "No se pudo extraer el archivo. Verifica que 'tar' esté instalado y que el archivo no esté corrupto.");
                return;
            }
        }

        // Verificar que se extrajeron archivos
        QDir installDir(m_installDir);
        QStringList extractedFiles = installDir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        
        if (extractedFiles.isEmpty()) {
            emit logMessage("❌ No se extrajeron archivos");
            emit workFinished(false, "El archivo no contenía datos o está corrupto.");
            return;
        }
        
        emit logMessage(QString("✅ Extraídos %1 archivos/directorios").arg(extractedFiles.size()));
        
        // Hacer ejecutable el binario principal si existe
        QString executable = m_installDir + "/Atlas_Interactivo";
        if (QFile::exists(executable)) {
            QProcess chmodProcess;
            chmodProcess.start("chmod", QStringList() << "+x" << executable);
            chmodProcess.waitForFinished();
            emit logMessage("✅ Binario hecho ejecutable");
        }
        
        // Crear archivo de versión
        createVersionFile();
        
        // Limpiar archivo temporal
        QFile::remove(m_tempArchive);
        m_tempArchive.clear();
        
        // Sincronizar para liberar espacio
        QProcess syncProcess;
        syncProcess.start("sync", QStringList());
        syncProcess.waitForFinished();
        
        emit progressUpdated(100, "Instalación completada");
        emit logMessage("✅ Instalación completada exitosamente");
        
        emit workFinished(true, "Atlas Interactivo instalado exitosamente");
    }
    
    void cancel() {
        cleanupProcesses();
    }
    
private:
    QString getDirectDownloadUrl() {
        bool useLocal = false; // Cambiar a false para usar Google Drive real
        
        if (useLocal) {
            emit logMessage("🔧 USANDO SERVIDOR LOCAL para pruebas");
            return "http://localhost:8000/Atlas_Interactivo_Linux.tar";
        } else {
            emit logMessage("🌐 Descargando desde Google Drive...");
            QString baseUrl = QString("https://drive.google.com/uc?id=%1&export=download").arg(m_driveId);
            
            // Intentar obtener el token de confirmación para archivos grandes
            QProcess wgetProcess;
            QStringList wgetArgs;
            wgetArgs << "--no-check-certificate";
            wgetArgs << "--save-cookies" << "/tmp/cookies.txt";
            wgetArgs << "--keep-session-cookies";
            wgetArgs << "-O" << "/tmp/gdrive_response.html";
            wgetArgs << baseUrl;
            
            wgetProcess.start("wget", wgetArgs);
            wgetProcess.waitForFinished(10000);
            
            // Leer la respuesta para buscar el token confirm
            QFile responseFile("/tmp/gdrive_response.html");
            QString confirmToken;
            
            if (responseFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream in(&responseFile);
                QString content = in.readAll();
                responseFile.close();
                
                // Buscar el token de confirmación
                QRegularExpression re("confirm=([0-9A-Za-z_-]+)");
                QRegularExpressionMatch match = re.match(content);
                if (match.hasMatch()) {
                    confirmToken = match.captured(1);
                    emit logMessage("✅ Token de confirmación obtenido: " + confirmToken);
                } else {
                    confirmToken = "t";
                    emit logMessage("⚠️  Usando token de confirmación por defecto");
                }
            } else {
                confirmToken = "t"; // Fallback
            }
            
            // Construir URL con token de confirmación
            QString finalUrl = QString("https://drive.google.com/uc?id=%1&export=download&confirm=%2")
                                .arg(m_driveId).arg(confirmToken);
            
            // Limpiar archivos temporales
            QFile::remove("/tmp/cookies.txt");
            QFile::remove("/tmp/gdrive_response.html");
            
            return finalUrl;
        }
    }

    bool extractArchiveSimple(const QString &archivePath, const QString &outputDir) {
        emit logMessage("🔄 Extrayendo archivo completo (método simple)...");
        
        QProcess tarProcess;
        QStringList tarArgs;
        tarArgs << "-xf" << archivePath;
        tarArgs << "-C" << outputDir;
        
        // Intentar con strip-components primero
        tarArgs << "--strip-components=0";
        
        emit logMessage("💻 Comando: tar " + tarArgs.join(" "));
        
        QElapsedTimer timer;
        timer.start();
        
        tarProcess.start("tar", tarArgs);
        
        if (!tarProcess.waitForFinished(300000)) { // 5 minutos timeout
            emit logMessage("❌ Timeout extrayendo archivo");
            return false;
        }
        
        if (tarProcess.exitCode() != 0) {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            emit logMessage("❌ Error en tar (método simple):");
            emit logMessage("   " + error.left(200));
            
            // Intentar método alternativo sin strip-components
            emit logMessage("🔄 Intentando método alternativo...");
            QProcess tarProcess2;
            tarProcess2.start("tar", QStringList() 
                << "-xf" << archivePath
                << "-C" << outputDir);
            
            if (!tarProcess2.waitForFinished(300000)) {
                emit logMessage("❌ Falló método alternativo también");
                return false;
            }
            
            if (tarProcess2.exitCode() != 0) {
                QString error2 = QString::fromUtf8(tarProcess2.readAllStandardError());
                emit logMessage("❌ Error método alternativo: " + error2.left(200));
                return false;
            }
            
            emit logMessage("✅ Extracción exitosa con método alternativo");
        } else {
            emit logMessage(QString("✅ Extracción completada en %1 ms").arg(timer.elapsed()));
        }
        
        // Verificar contenido extraído
        QDir outputDirObj(outputDir);
        QStringList extractedItems = outputDirObj.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        
        if (extractedItems.isEmpty()) {
            emit logMessage("⚠️  No se encontraron archivos extraídos");
            return false;
        }
        
        emit logMessage(QString("📊 Total extraído: %1 archivos/directorios").arg(extractedItems.size()));
        
        // Reorganizar si es necesario
        QStringList possibleDirs = {"Atlas_Interactivo-1.0.0-linux-x64", "Atlas_Interactivo"};
        foreach (const QString &dirName, possibleDirs) {
            QString dirPath = outputDir + "/" + dirName;
            if (QDir(dirPath).exists()) {
                emit logMessage("🔄 Reorganizando desde: " + dirName);
                if (reorganizeExtractedFiles(outputDir, dirName)) {
                    emit logMessage("✅ Reorganización completada");
                }
                break;
            }
        }
        
        return true;
    }

    bool downloadWithRetries(const QString &url, const QString &outputPath, int maxAttempts) {
        m_downloadAttempts = 0;
        
        // ========== MOSTRAR INFORMACIÓN SEGÚN MÉTODO ==========
        if (m_downloadMethod == "drive" && url.contains("drive.google.com")) {
            emit logMessage("🔍 Detectado archivo grande de Google Drive");
            emit logMessage("🔄 Usando método especial con confirmación");
        } else if (m_downloadMethod == "ftp") {
            emit logMessage("🔍 Usando FTP estándar para descarga");
        }
        
        while (m_downloadAttempts < maxAttempts && !m_canceled) {
            m_downloadAttempts++;
            emit logMessage(QString("🔄 Intento de descarga %1/%2...").arg(m_downloadAttempts).arg(maxAttempts));
            
            // ========== USAR MÉTODO ADECUADO ==========
            bool success = false;
            if (m_downloadMethod == "ftp") {
                success = downloadWithFtp(url, outputPath);
            } else {
                success = downloadWithWgetResumable(url, outputPath);
            }
            
            if (success) {
                return true;
            }
            
            // ========== INTENTAR MÉTODO ALTERNATIVO ==========
            emit logMessage("❌ Método principal falló, intentando con curl...");
            
            if (downloadWithCurlResumable(url, outputPath)) {
                return true;
            }
            
            if (m_downloadAttempts < maxAttempts && !m_canceled) {
                int waitTime = 10 * m_downloadAttempts;
                emit logMessage(QString("⏳ Esperando %1 segundos antes de reintentar...").arg(waitTime));
                QThread::sleep(waitTime);
            }
        }
        
        return false;
    }
    






    // ========== NUEVO MÉTODO PARA DESCARGA FTP ==========
    bool downloadWithFtp(const QString &url, const QString &outputPath) {
        emit logMessage("📥 Iniciando descarga FTP desde: " + url);
        
        QProcess wgetProcess;
        QStringList wgetArgs;
        // wgetArgs << "--no-check-certificate";  // ← ELIMINAR (innecesario para FTP)
        wgetArgs << "--no-passive-ftp";           // ← AÑADIR (mejor compatibilidad)
        wgetArgs << "--progress=bar:force:noscroll";
        wgetArgs << "-c";                         // ← AÑADIR CRÍTICO (reanudación)
        wgetArgs << "-O" << outputPath;
        wgetArgs << "--tries=3";
        wgetArgs << "--timeout=60";               // ← AUMENTAR a 60s
        wgetArgs << "--waitretry=10";             // ← AÑADIR
        // wgetArgs << "--user=usuario";           // Opcional si requiere login
        // wgetArgs << "--password=contraseña";    // Opcional si requiere login
        
        // Añadir credenciales FTP si están en la URL
        if (url.startsWith("ftp://") && url.contains("@")) {
            emit logMessage("🔐 Usando credenciales FTP incluidas en la URL");
        }
        
        wgetArgs << url;
        
        wgetProcess.start("wget", wgetArgs);
        
        if (!wgetProcess.waitForStarted()) {
            emit logMessage("❌ wget no pudo iniciarse para FTP");
            return false;
        }
        
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        
        connect(&wgetProcess, &QProcess::readyReadStandardError, this, [this, &wgetProcess, outputPath]() {
            QString output = QString::fromUtf8(wgetProcess.readAllStandardError());
            
            if (!output.trimmed().isEmpty()) {
                // Patrón para extraer porcentaje
                QRegularExpression percentRe(R"((\d+)%)");
                QRegularExpressionMatchIterator percentMatches = percentRe.globalMatch(output);
                
                while (percentMatches.hasNext()) {
                    QRegularExpressionMatch percentMatch = percentMatches.next();
                    int percent = percentMatch.captured(1).toInt();
                    int progress = 5 + (percent * 0.45);
                    
                    // Patrón para extraer tamaño y velocidad (formato wget)
                    QRegularExpression sizeRe(R"((\d+(?:\.\d+)?)([KM]?) +.*?(\d+(?:\.\d+)?)([KM]?)B/s.*?(\d+:\d+))");
                    QRegularExpressionMatch sizeMatch = sizeRe.match(output);
                    
                    QString statusMessage;
                    if (sizeMatch.hasMatch()) {
                        QString downloaded = sizeMatch.captured(1) + sizeMatch.captured(2);
                        QString speed = sizeMatch.captured(3) + sizeMatch.captured(4);
                        QString eta = sizeMatch.captured(5);
                        statusMessage = QString("Descargando FTP: %1% (%2 a %3/s) - ETA: %4").arg(percent).arg(downloaded).arg(speed).arg(eta);
                    } else {
                        // Patrón alternativo sin ETA
                        QRegularExpression simpleSizeRe(R"((\d+(?:\.\d+)?)([KM]?) +.*?(\d+(?:\.\d+)?)([KM]?)B/s)");
                        QRegularExpressionMatch simpleMatch = simpleSizeRe.match(output);
                        
                        if (simpleMatch.hasMatch()) {
                            QString downloaded = simpleMatch.captured(1) + simpleMatch.captured(2);
                            QString speed = simpleMatch.captured(3) + simpleMatch.captured(4);
                            statusMessage = QString("Descargando FTP: %1% (%2 a %3/s)").arg(percent).arg(downloaded).arg(speed);
                        } else {
                            statusMessage = QString("Descargando FTP: %1%").arg(percent);
                        }
                    }
                    
                    emit progressUpdated(progress, statusMessage);
                    
                    static int lastLoggedPercent = 0;
                    if (percent >= lastLoggedPercent + 10) {
                        emit logMessage(QString("📊 FTP: %1% descargado").arg(percent));
                        lastLoggedPercent = percent - (percent % 10);
                    }
                }
            }
        });

        connect(&wgetProcess, &QProcess::readyReadStandardOutput, this, [this, &wgetProcess]() {
            QString output = QString::fromUtf8(wgetProcess.readAllStandardOutput());
            if (!output.trimmed().isEmpty()) {
                QRegularExpression infoRe(R"(Length:\s+(\d+)\s+\((\d+)([KM]?)\))");
                QRegularExpressionMatch infoMatch = infoRe.match(output);
                if (infoMatch.hasMatch()) {
                    QString totalSize = infoMatch.captured(1);
                    QString humanSize = infoMatch.captured(2) + infoMatch.captured(3);
                    emit logMessage(QString("📏 Tamaño del archivo FTP: %1 (%2 bytes)").arg(humanSize).arg(totalSize));
                }
            }
        });
        
        connect(&wgetProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                &loop, &QEventLoop::quit);
        
        connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        timer.start(7200000);
        
        loop.exec();
        
        if (wgetProcess.exitCode() != 0 && !m_canceled) {
            emit logMessage(QString("❌ wget FTP falló con código: %1").arg(wgetProcess.exitCode()));
            return false;
        }
        
        if (QFile::exists(outputPath)) {
            QFileInfo fileInfo(outputPath);
            qint64 size = fileInfo.size();
            
            if (size > 0) {
                emit logMessage(QString("✅ Descarga FTP completada: %1 bytes").arg(size));
                return true;
            } else {
                emit logMessage("❌ Archivo FTP descargado está vacío");
                QFile::remove(outputPath);
                return false;
            }
        } else {
            emit logMessage("❌ No se pudo descargar el archivo FTP");
            return false;
        }
    }
    
    bool downloadWithWgetResumable(const QString &url, const QString &outputPath) {
        if (url.contains("localhost") || url.contains("127.0.0.1") || url.startsWith("file://")) {
            emit logMessage("🌐 Usando modo local - descarga directa");
            
            QProcess wgetProcess;
            QStringList wgetArgs;
            wgetArgs << "--no-check-certificate";
            wgetArgs << "--progress=bar:force:noscroll";
            wgetArgs << "-O" << outputPath;
            wgetArgs << "--tries=3";
            wgetArgs << "--timeout=30";
            wgetArgs << url;
            
            emit logMessage("📥 Iniciando descarga directa desde servidor local...");
            wgetProcess.start("wget", wgetArgs);
            
            if (!wgetProcess.waitForStarted()) {
                emit logMessage("❌ wget no pudo iniciarse para URL local");
                return false;
            }
            
            QEventLoop loop;
            QTimer timer;
            timer.setSingleShot(true);
            
            connect(&wgetProcess, &QProcess::readyReadStandardError, this, [this, &wgetProcess, outputPath]() {
                QString output = QString::fromUtf8(wgetProcess.readAllStandardError());
                
                if (!output.trimmed().isEmpty()) {
                    // Patrón para extraer porcentaje
                    QRegularExpression percentRe(R"((\d+)%)");
                    QRegularExpressionMatchIterator percentMatches = percentRe.globalMatch(output);
                    
                    while (percentMatches.hasNext()) {
                        QRegularExpressionMatch percentMatch = percentMatches.next();
                        int percent = percentMatch.captured(1).toInt();
                        int progress = 5 + (percent * 0.45);
                        
                        // Patrón para extraer tamaño y velocidad (formato wget)
                        QRegularExpression sizeRe(R"((\d+(?:\.\d+)?)([KM]?) +.*?(\d+(?:\.\d+)?)([KM]?)B/s.*?(\d+:\d+))");
                        QRegularExpressionMatch sizeMatch = sizeRe.match(output);
                        
                        QString statusMessage;
                        if (sizeMatch.hasMatch()) {
                            QString downloaded = sizeMatch.captured(1) + sizeMatch.captured(2);
                            QString speed = sizeMatch.captured(3) + sizeMatch.captured(4);
                            QString eta = sizeMatch.captured(5);
                            statusMessage = QString("Descargando: %1% (%2 a %3/s) - ETA: %4").arg(percent).arg(downloaded).arg(speed).arg(eta);
                        } else {
                            // Patrón alternativo sin ETA
                            QRegularExpression simpleSizeRe(R"((\d+(?:\.\d+)?)([KM]?) +.*?(\d+(?:\.\d+)?)([KM]?)B/s)");
                            QRegularExpressionMatch simpleMatch = simpleSizeRe.match(output);
                            
                            if (simpleMatch.hasMatch()) {
                                QString downloaded = simpleMatch.captured(1) + simpleMatch.captured(2);
                                QString speed = simpleMatch.captured(3) + simpleMatch.captured(4);
                                statusMessage = QString("Descargando: %1% (%2 a %3/s)").arg(percent).arg(downloaded).arg(speed);
                            } else {
                                statusMessage = QString("Descargando: %1%").arg(percent);
                            }
                        }
                        
                        emit progressUpdated(progress, statusMessage);
                        
                        static int lastLoggedPercent = 0;
                        if (percent >= lastLoggedPercent + 10) {
                            emit logMessage(QString("📊 %1% descargado").arg(percent));
                            lastLoggedPercent = percent - (percent % 10);
                        }
                    }
                }
            });

            connect(&wgetProcess, &QProcess::readyReadStandardOutput, this, [this, &wgetProcess]() {
                QString output = QString::fromUtf8(wgetProcess.readAllStandardOutput());
                if (!output.trimmed().isEmpty()) {
                    QRegularExpression infoRe(R"(Length:\s+(\d+)\s+\((\d+)([KM]?)\))");
                    QRegularExpressionMatch infoMatch = infoRe.match(output);
                    if (infoMatch.hasMatch()) {
                        QString totalSize = infoMatch.captured(1);
                        QString humanSize = infoMatch.captured(2) + infoMatch.captured(3);
                        emit logMessage(QString("📏 Tamaño del archivo local: %1 (%2 bytes)").arg(humanSize).arg(totalSize));
                    }
                }
            });
            
            connect(&wgetProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                    &loop, &QEventLoop::quit);
            
            connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
            timer.start(7200000);
            
            loop.exec();
            
            if (wgetProcess.exitCode() != 0 && !m_canceled) {
                emit logMessage(QString("❌ wget falló con código: %1").arg(wgetProcess.exitCode()));
                return false;
            }
            
            if (QFile::exists(outputPath)) {
                QFileInfo fileInfo(outputPath);
                qint64 size = fileInfo.size();
                
                if (size > 0) {
                    emit logMessage(QString("✅ Descarga local completada: %1 bytes").arg(size));
                    return true;
                } else {
                    emit logMessage("❌ Archivo local descargado está vacío");
                    QFile::remove(outputPath);
                    return false;
                }
            } else {
                emit logMessage("❌ No se pudo descargar el archivo local");
                return false;
            }
        }
        
        // Código para Google Drive...
        QRegularExpression idRe("id=([^&]+)");
        QRegularExpressionMatch match = idRe.match(url);
        
        if (!match.hasMatch()) {
            emit logMessage("❌ No se pudo extraer el ID del archivo");
            return false;
        }
        
        QString fileId = match.captured(1);
        emit logMessage("📁 ID del archivo: " + fileId);
        
        QString htmlFile = "/tmp/gdrive_" + fileId + ".html";
        QString cookiesFile = "/tmp/gdrive_cookies_" + fileId + ".txt";
        
        QProcess getPageProcess;
        QStringList getPageArgs;
        getPageArgs << "--no-check-certificate";
        getPageArgs << "--save-cookies" << cookiesFile;
        getPageArgs << "--keep-session-cookies";
        getPageArgs << "-O" << htmlFile;
        getPageArgs << QString("https://drive.google.com/uc?export=download&id=%1").arg(fileId);
        
        emit logMessage("🔍 Obteniendo formulario de confirmación...");
        getPageProcess.start("wget", getPageArgs);
        getPageProcess.waitForFinished(10000);
        
        QString uuid;
        QFile file(htmlFile);
        
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&file);
            QString content = in.readAll();
            file.close();
            
            QRegularExpression uuidRe("name=\"uuid\"\\s+value=\"([^\"]+)\"");
            QRegularExpressionMatch uuidMatch = uuidRe.match(content);
            
            if (uuidMatch.hasMatch()) {
                uuid = uuidMatch.captured(1);
                emit logMessage("✅ UUID obtenido: " + uuid);
            } else {
                uuid = QUuid::createUuid().toString().remove('{').remove('}');
                emit logMessage("⚠️  Generando UUID: " + uuid);
            }
        } else {
            uuid = QUuid::createUuid().toString().remove('{').remove('}');
            emit logMessage("⚠️  Usando UUID generado: " + uuid);
        }
        
        QString downloadUrl = QString("https://drive.usercontent.google.com/download?"
                                    "id=%1&"
                                    "export=download&"
                                    "confirm=t&"
                                    "uuid=%2")
                                .arg(fileId).arg(uuid);
        
        emit logMessage("🔗 URL final: " + downloadUrl);
        
        QProcess wgetProcess;
        QStringList wgetArgs;
        wgetArgs << "--no-check-certificate";
        wgetArgs << "--load-cookies" << cookiesFile;
        wgetArgs << "--progress=bar:force:noscroll";
        wgetArgs << "-c";
        wgetArgs << "-O" << outputPath;
        wgetArgs << "--tries=3";
        wgetArgs << "--timeout=30";
        wgetArgs << "--waitretry=5";
        wgetArgs << downloadUrl;
        
        wgetArgs << "--header=User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36";
        
        emit logMessage("📥 Iniciando descarga del archivo...");
        wgetProcess.start("wget", wgetArgs);
        
        if (!wgetProcess.waitForStarted()) {
            emit logMessage("❌ wget no pudo iniciarse");
            QFile::remove(cookiesFile);
            QFile::remove(htmlFile);
            return false;
        }
        
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        
        connect(&wgetProcess, &QProcess::readyReadStandardError, this, [this, &wgetProcess]() {
            QString output = QString::fromUtf8(wgetProcess.readAllStandardError());
            
            if (!output.trimmed().isEmpty()) {
                QRegularExpression percentRe(R"(\s+(\d+)%\[)");
                QRegularExpressionMatch percentMatch = percentRe.match(output);
                
                if (percentMatch.hasMatch()) {
                    int percent = percentMatch.captured(1).toInt();
                    int progress = 5 + (percent * 0.45);
                    
                    QRegularExpression sizeRe(R"(\s+(\d+\.?\d*)([KM]?)\s+(\d+\.?\d*)([KM]?)B/s\s+eta)");
                    QRegularExpressionMatch sizeMatch = sizeRe.match(output);
                    
                    QString statusMessage;
                    if (sizeMatch.hasMatch()) {
                        QString downloaded = sizeMatch.captured(1) + sizeMatch.captured(2);
                        QString speed = sizeMatch.captured(3) + sizeMatch.captured(4);
                        statusMessage = QString("Descargando: %1% (%2 a %3/s)").arg(percent).arg(downloaded).arg(speed);
                    } else {
                        statusMessage = QString("Descargando: %1%").arg(percent);
                    }
                    
                    emit progressUpdated(progress, statusMessage);
                    
                    static int lastLoggedPercent = 0;
                    if (percent >= lastLoggedPercent + 10) {
                        emit logMessage(QString("📊 %1% descargado").arg(percent));
                        lastLoggedPercent = percent - (percent % 10);
                    }
                }
            }
        });

        connect(&wgetProcess, &QProcess::readyReadStandardOutput, this, [this, &wgetProcess]() {
            QString output = QString::fromUtf8(wgetProcess.readAllStandardOutput());
            if (!output.trimmed().isEmpty()) {
                QRegularExpression infoRe(R"(Length:\s+(\d+)\s+\((\d+)([KM]?)\))");
                QRegularExpressionMatch infoMatch = infoRe.match(output);
                if (infoMatch.hasMatch()) {
                    QString totalSize = infoMatch.captured(1);
                    QString humanSize = infoMatch.captured(2) + infoMatch.captured(3);
                    emit logMessage(QString("📁 Tamaño total del archivo: %1 (%2 bytes)").arg(humanSize).arg(totalSize));
                }
            }
        });
        
        connect(&wgetProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                &loop, &QEventLoop::quit);
        
        connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        timer.start(7200000);
        
        loop.exec();
        
        QFile::remove(cookiesFile);
        QFile::remove(htmlFile);
        
        if (wgetProcess.exitCode() != 0 && !m_canceled) {
            emit logMessage(QString("❌ wget falló con código: %1").arg(wgetProcess.exitCode()));
            return false;
        }
        
        if (QFile::exists(outputPath)) {
            QFileInfo fileInfo(outputPath);
            qint64 size = fileInfo.size();
            
            if (size < 10000) {
                QFile checkFile(outputPath);
                if (checkFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                    QString header = checkFile.read(100);
                    checkFile.close();
                    
                    if (header.contains("<!DOCTYPE") || header.contains("<html")) {
                        emit logMessage("❌ ERROR: Se descargó HTML en lugar del archivo");
                        QFile::remove(outputPath);
                        return false;
                    }
                }
            }
            
            emit logMessage(QString("✅ Descarga completada: %1 bytes").arg(size));
            return true;
        }
        
        return false;
    }
    
    QString formatBytes(qint64 bytes) {
        const qint64 KB = 1024;
        const qint64 MB = KB * 1024;
        const qint64 GB = MB * 1024;
        
        if (bytes >= GB) {
            return QString("%1 GB").arg(QString::number(bytes / (double)GB, 'f', 2));
        } else if (bytes >= MB) {
            return QString("%1 MB").arg(QString::number(bytes / (double)MB, 'f', 2));
        } else if (bytes >= KB) {
            return QString("%1 KB").arg(QString::number(bytes / (double)KB, 'f', 2));
        } else {
            return QString("%1 bytes").arg(bytes);
        }
    }
    
    bool downloadWithCurlResumable(const QString &url, const QString &outputPath) {
        QProcess curlProcess;
        
        QStringList curlArgs;
        curlArgs << "-L";
        
        if (url.contains("localhost") || url.contains("127.0.0.1")) {
            curlArgs << "#";
            emit logMessage("🌐 Usando modo local - progreso simplificado");
        } else {
            curlArgs << "--progress-bar";
        }
        
        curlArgs << "-C";
        curlArgs << "-";
        curlArgs << "--output" << outputPath;
        curlArgs << "--location-trusted";
        curlArgs << "--retry" << "3";
        curlArgs << "--retry-delay" << "5";
        curlArgs << url;
        
        curlProcess.start("curl", curlArgs);
        
        if (!curlProcess.waitForStarted()) {
            emit logMessage("curl no está disponible");
            return false;
        }
        
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        
        QTimer progressTimer;
        progressTimer.setInterval(1000);
        qint64 lastSize = 0;
        qint64 totalSize = 0;
        QDateTime downloadStartTime = QDateTime::currentDateTime();
        
        if (url.contains("localhost") || url.contains("127.0.0.1")) {
            QProcess headProcess;
            headProcess.start("curl", QStringList() << "-I" << url);
            headProcess.waitForFinished();
            QString output = QString::fromUtf8(headProcess.readAllStandardOutput());
            
            QRegularExpression re("Content-Length: (\\d+)");
            QRegularExpressionMatch match = re.match(output);
            if (match.hasMatch()) {
                totalSize = match.captured(1).toLongLong();
                emit logMessage(QString("📏 Tamaño total del archivo local: %1").arg(formatBytes(totalSize)));
            }
        }
        
        connect(&progressTimer, &QTimer::timeout, this, [this, outputPath, &lastSize, totalSize, &downloadStartTime]() {
            QFileInfo fileInfo(outputPath);
            qint64 currentSize = fileInfo.size();
            
            if (currentSize > lastSize) {
                QDateTime now = QDateTime::currentDateTime();
                qint64 elapsedSeconds = downloadStartTime.secsTo(now);
                
                if (elapsedSeconds > 0) {
                    double speed = (currentSize - lastSize) / 1024.0;
                    QString speedStr = QString::number(speed, 'f', 1);
                    
                    int percent = 0;
                    if (totalSize > 0) {
                        percent = (currentSize * 100) / totalSize;
                    }
                    int progress = 3 + (percent * 0.47);
                    
                    QString statusMessage;
                    if (totalSize > 0) {
                        QString eta = calculateSimpleETA(currentSize, totalSize, downloadStartTime);
                        statusMessage = QString("Descargando: %1% (%2 KB/s) - %3")
                                        .arg(percent)
                                        .arg(speedStr)
                                        .arg(eta);
                    } else {
                        statusMessage = QString("Descargando: %1 a %2 KB/s")
                                        .arg(formatBytes(currentSize))
                                        .arg(speedStr);
                    }
                    
                    emit progressUpdated(progress, statusMessage);
                }
                
                lastSize = currentSize;
            }
        });
        
        connect(&curlProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                &loop, &QEventLoop::quit);
        
        connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        
        progressTimer.start();
        timer.start(7200000);
        
        loop.exec();
        
        progressTimer.stop();
        timer.stop();
        
        if (curlProcess.exitCode() != 0 && !m_canceled) {
            emit logMessage(QString("curl salió con código: %1").arg(curlProcess.exitCode()));
            
            if (QFile::exists(outputPath)) {
                qint64 currentSize = QFileInfo(outputPath).size();
                emit logMessage(QString("Progreso guardado: %1 bytes descargados").arg(currentSize));
            }
            
            return false;
        }
        
        return !m_canceled;
    }

    QString calculateSimpleETA(qint64 currentSize, qint64 totalSize, const QDateTime &startTime) {
        if (currentSize <= 0 || totalSize <= 0) return "";
        
        QDateTime now = QDateTime::currentDateTime();
        qint64 elapsedSeconds = startTime.secsTo(now);
        if (elapsedSeconds <= 0) return "";
        
        double speed = currentSize / (double)elapsedSeconds;
        qint64 remainingBytes = totalSize - currentSize;
        int remainingSeconds = qRound(remainingBytes / speed);
        
        if (remainingSeconds < 60) {
            return QString("%1s").arg(remainingSeconds);
        } else if (remainingSeconds < 3600) {
            return QString("%1m").arg(qRound(remainingSeconds / 60.0));
        } else {
            return QString("%1h").arg(qRound(remainingSeconds / 3600.0));
        }
    }
    
    bool extractArchiveIncremental(const QString &archivePath, const QString &outputDir) {
        emit logMessage("🧹 Preparando directorio destino: " + outputDir);
        
        QFileInfo dirInfo(outputDir);
        if (dirInfo.exists() && !dirInfo.isDir()) {
            emit logMessage("⚠️  '" + outputDir + "' es un archivo, eliminándolo...");
            if (!QFile::remove(outputDir)) {
                emit logMessage("❌ No se pudo eliminar el archivo: " + outputDir);
                return false;
            }
            emit logMessage("✅ Archivo eliminado, creando directorio...");
        }
        
        // MODIFICADO: Verificar si hay archivos existentes antes de limpiar
        bool shouldClean = false;
        if (QDir(outputDir).exists()) {
            QDir dir(outputDir);
            QStringList items = dir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
            
            if (!items.isEmpty()) {
                emit logMessage("⚠️  Directorio no vacío detectado");
                emit logMessage("📊 Contiene " + QString::number(items.size()) + " elementos");
                
                // Verificar si ya está instalado Atlas Interactivo
                bool hasAtlas = items.contains("Atlas_Interactivo") || 
                            items.contains("Atlas_Interactivo-1.0.0-linux-x64") ||
                            items.contains(".atlas_version.json");
                
                if (hasAtlas) {
                    emit logMessage("✅ Atlas Interactivo ya parece estar instalado aquí");
                    emit logMessage("🔄 Continuando sin limpiar...");
                } else {
                    emit logMessage("🗑️  Limpiando directorio existente...");
                    shouldClean = true;
                }
            }
        }
        
        if (shouldClean) {
            QDir dir(outputDir);
            QStringList items = dir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
            
            int removedCount = 0;
            foreach (const QString &item, items) {
                QString itemPath = outputDir + "/" + item;
                if (QFileInfo(itemPath).isDir()) {
                    if (QDir(itemPath).removeRecursively()) {
                        removedCount++;
                    }
                } else {
                    if (QFile::remove(itemPath)) {
                        removedCount++;
                    }
                }
            }
            emit logMessage(QString("✅ Eliminados %1 elementos previos").arg(removedCount));
        }
        
        if (!QDir().mkpath(outputDir)) {
            emit logMessage("❌ No se pudo crear directorio: " + outputDir);
            return false;
        }
        emit logMessage("✅ Directorio listo: " + outputDir);

        emit logMessage("🔄 Extrayendo en grupos optimizados...");
        
        QDir().mkpath(outputDir);
        
        emit logMessage("Obteniendo lista de archivos del .tar...");
        QStringList fileList = getTarFileList(archivePath);
        
        if (fileList.isEmpty()) {
            emit logMessage("❌ El archivo .tar está vacío o corrupto");
            return false;
        }
        
        int totalFiles = fileList.size();
        emit logMessage(QString("✅ Encontrados %1 archivos en el .tar").arg(totalFiles));
        
        // MODIFICADO: Manejar diferentes estructuras de archivo
        QString prefix = "";
        QString detectedOldDirName = "";
        
        // Detectar diferentes posibles prefijos
        if (!fileList.isEmpty()) {
            QString firstFile = fileList[0];
            
            // Verificar patrones comunes
            if (firstFile.startsWith("Atlas_Interactivo-1.0.0-linux-x64/")) {
                prefix = "Atlas_Interactivo-1.0.0-linux-x64/";
                detectedOldDirName = "Atlas_Interactivo-1.0.0-linux-x64";
                emit logMessage("📁 PREFIJO DETECTADO: '" + prefix + "'");
                emit logMessage("🔧 Se usará: --strip-components=1");
            }
            else if (firstFile.startsWith("Atlas_Interactivo/")) {
                prefix = "Atlas_Interactivo/";
                emit logMessage("📁 PREFIJO DETECTADO: '" + prefix + "'");
                emit logMessage("🔧 Se usará: --strip-components=1");
            }
            else if (firstFile.contains("/")) {
                // Si tiene directorios pero no el prefijo esperado
                int slashPos = firstFile.indexOf('/');
                if (slashPos > 0) {
                    prefix = firstFile.left(slashPos + 1);
                    detectedOldDirName = firstFile.left(slashPos);
                    emit logMessage("📁 PREFIJO DETECTADO (genérico): '" + prefix + "'");
                    emit logMessage("🔧 Se usará: --strip-components=1");
                }
            }
            else {
                emit logMessage("ℹ️  No se detectó estructura de directorios");
                emit logMessage("   Primer archivo: " + firstFile);
                emit logMessage("🔧 Sin --strip-components");
            }
            
            // Validar prefijo
            if (!prefix.isEmpty()) {
                bool validPrefix = true;
                int checkedFiles = 0;
                for (int i = 0; i < qMin(100, fileList.size()); i++) {
                    if (!fileList[i].startsWith(prefix) && fileList[i] != detectedOldDirName) {
                        checkedFiles++;
                        if (checkedFiles > 10) { // Solo fallar si varios archivos no coinciden
                            emit logMessage("⚠️  Archivo sin prefijo esperado: " + fileList[i]);
                            validPrefix = false;
                            break;
                        }
                    }
                }
                
                if (!validPrefix) {
                    emit logMessage("⚠️  Prefijo inconsistente, usando extracción normal");
                    prefix = "";
                    detectedOldDirName = "";
                }
            }
        }
        
        int optimalGroupSize = 50000;
        emit logMessage(QString("📊 Tamaño de grupo: %1 archivos por grupo").arg(optimalGroupSize));
        
        int totalGroups = (totalFiles + optimalGroupSize - 1) / optimalGroupSize;
        int currentGroup = 0;
        
        emit progressUpdated(60, "Extrayendo archivos...");
        
        QDateTime extractionStartTime = QDateTime::currentDateTime();
        
        for (int i = 0; i < totalFiles; i += optimalGroupSize) {
            currentGroup++;
            int startIdx = i;
            int endIdx = qMin(i + optimalGroupSize, totalFiles);
            
            QDateTime now = QDateTime::currentDateTime();
            qint64 elapsedSeconds = extractionStartTime.secsTo(now);
            
            QString etaMessage;
            if (elapsedSeconds > 0 && i > 0) {
                double speed = i / (double)elapsedSeconds;
                int remainingFiles = totalFiles - i;
                int remainingSeconds = qRound(remainingFiles / speed);
                
                if (remainingSeconds < 60) {
                    etaMessage = QString(" - ETA: %1s").arg(remainingSeconds);
                } else if (remainingSeconds < 3600) {
                    etaMessage = QString(" - ETA: %1m").arg(qRound(remainingSeconds / 60.0));
                } else {
                    etaMessage = QString(" - ETA: %1h").arg(qRound(remainingSeconds / 3600.0));
                }
            }
            
            emit logMessage(QString("📦 Grupo %1/%2: archivos %3-%4%5")
                        .arg(currentGroup).arg(totalGroups)
                        .arg(startIdx + 1).arg(endIdx)
                        .arg(etaMessage));
            
            QStringList group = fileList.mid(startIdx, optimalGroupSize);
            if (!extractFileGroupWithPrefix(archivePath, outputDir, group, prefix)) {
                emit logMessage("❌ Error extrayendo grupo");
                return false;
            }
            
            int progress = 60 + (40 * endIdx / totalFiles);
            emit progressUpdated(progress, 
                QString("Extrayendo: %1/%2 archivos").arg(endIdx).arg(totalFiles));
            
            if (currentGroup % 5 == 0) {
                QThread::msleep(50);
            }
        }
        
        emit logMessage("✅ Todos los grupos extraídos correctamente");
        
        QDir outputDirObj(outputDir);
        QStringList extractedItems = outputDirObj.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        
        emit logMessage("📁 Archivos extraídos en el directorio destino:");
        for (int i = 0; i < qMin(10, extractedItems.size()); i++) {
            emit logMessage("   " + extractedItems[i]);
        }
        
        emit logMessage(QString("📊 Total extraído: %1 archivos/directorios").arg(extractedItems.size()));
        
        QString oldDirPath = outputDir + "/" + detectedOldDirName;
        
        if (QDir(oldDirPath).exists()) {
            emit logMessage("🔄 Reorganizando: Moviendo archivos desde " + detectedOldDirName + "/");
            if (!reorganizeExtractedFiles(outputDir, detectedOldDirName)) {
                emit logMessage("⚠️  Error reorganizando, pero la extracción fue exitosa");
            }
        } else {
            emit logMessage("✅ Los archivos ya están en la ubicación correcta");
        }
        
        return true;
    }

    bool reorganizeExtractedFiles(const QString &outputDir, const QString &oldDirName) {
        QString oldDirPath = outputDir + "/" + oldDirName;
        QDir oldDir(oldDirPath);
        
        if (!oldDir.exists()) {
            emit logMessage("ℹ️  No se encontró directorio a reorganizar: " + oldDirName);
            return true;
        }
        
        emit logMessage("🔄 Reorganizando: Moviendo contenido de " + oldDirName + " a raíz...");
        
        QStringList items = oldDir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        
        if (items.isEmpty()) {
            emit logMessage("⚠️  Directorio vacío: " + oldDirName);
            oldDir.rmdir(oldDirPath);
            return true;
        }
        
        emit logMessage(QString("📦 Moviendo %1 elementos...").arg(items.size()));
        
        int movedCount = 0;
        int failedCount = 0;
        
        foreach (const QString &item, items) {
            QString sourcePath = oldDirPath + "/" + item;
            QString destPath = outputDir + "/" + item;
            
            emit logMessage("   Mover: " + item);
            
            if (QFile::exists(destPath)) {
                emit logMessage("   ⚠️  Ya existe: " + item + " - Sobrescribiendo");
                
                if (QFileInfo(destPath).isDir()) {
                    QDir(destPath).removeRecursively();
                } else {
                    QFile::remove(destPath);
                }
            }
            
            if (QFile::rename(sourcePath, destPath)) {
                movedCount++;
                emit logMessage("   ✅ Movido: " + item);
            } else {
                emit logMessage("   🔄 Rename falló, intentando copiar: " + item);
                
                QProcess cpProcess;
                if (QFileInfo(sourcePath).isDir()) {
                    cpProcess.start("cp", QStringList() << "-r" << sourcePath << destPath);
                } else {
                    cpProcess.start("cp", QStringList() << sourcePath << destPath);
                }
                
                cpProcess.waitForFinished(30000);
                
                if (cpProcess.exitCode() == 0 && QFile::exists(destPath)) {
                    movedCount++;
                    if (QFileInfo(sourcePath).isDir()) {
                        QDir(sourcePath).removeRecursively();
                    } else {
                        QFile::remove(sourcePath);
                    }
                    emit logMessage("   ✅ Copiado: " + item);
                } else {
                    failedCount++;
                    emit logMessage("   ❌ Falló: " + item);
                }
            }
        }
        
        emit logMessage(QString("📊 Resultado: %1 movidos, %2 fallos").arg(movedCount).arg(failedCount));
        
        if (oldDir.exists()) {
            QStringList remaining = oldDir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
            if (remaining.isEmpty()) {
                if (oldDir.rmdir(oldDirPath)) {
                    emit logMessage("🗑️  Directorio vacío eliminado: " + oldDirName);
                }
            } else {
                emit logMessage("⚠️  Directorio no vacío, no se puede eliminar: " + oldDirName);
                emit logMessage("   Archivos restantes: " + remaining.join(", "));
            }
        }
        
        return failedCount == 0;
    }

    bool extractFileGroupWithPrefix(const QString &archivePath, const QString &outputDir, 
                                 const QStringList &files, const QString &prefix) {
        if (files.isEmpty()) {
            return true;
        }
        
        QString tempListFile = QDir::tempPath() + "/tar_list_" + 
                            QUuid::createUuid().toString().mid(1, 8) + ".txt";
        
        QFile listFile(tempListFile);
        if (!listFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            emit logMessage("❌ No se pudo crear archivo de lista temporal");
            return false;
        }
        
        QTextStream out(&listFile);
        foreach (const QString &file, files) {
            out << file << "\n";
        }
        listFile.close();
        
        emit logMessage(QString("📄 Extrayendo %1 archivos...").arg(files.size()));
        
        QProcess tarProcess;
        QStringList tarArgs;
        tarArgs << "-xf" << archivePath;
        tarArgs << "-C" << outputDir;
        
        if (!prefix.isEmpty() && prefix.endsWith("/")) {
            emit logMessage("🔧 Aplicando: --strip-components=1 (prefijo: " + prefix + ")");
            tarArgs << "--strip-components=1";
        } else {
            emit logMessage("🔧 Sin --strip-components (no hay prefijo)");
        }
        
        tarArgs << "-T" << tempListFile;
        
        emit logMessage("💻 Comando: tar " + tarArgs.join(" "));
        
        tarProcess.start("tar", tarArgs);
        
        if (!tarProcess.waitForFinished(300000)) {
            emit logMessage("❌ Timeout extrayendo grupo");
            QFile::remove(tempListFile);
            return false;
        }
        
        QFile::remove(tempListFile);
        
        if (tarProcess.exitCode() != 0) {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            
            emit logMessage("❌ Error en tar:");
            QStringList errorLines = error.split('\n', Qt::SkipEmptyParts);
            for (int i = 0; i < qMin(5, errorLines.size()); i++) {
                emit logMessage("   " + errorLines[i]);
            }
            
            bool criticalError = false;
            foreach (const QString &line, errorLines) {
                if (line.contains("Not found in archive") || 
                    line.contains("Exiting with failure status") ||
                    line.contains("Cannot open")) {
                    criticalError = true;
                    break;
                }
            }
            
            if (criticalError) {
                emit logMessage("❌ ERROR CRÍTICO en extracción");
                return false;
            } else if (!error.trimmed().isEmpty()) {
                emit logMessage("⚠️  Advertencias en tar (continuando...)");
            }
        } else {
            emit logMessage("✅ Grupo extraído exitosamente");
        }
        
        return true;
    }
    
    QStringList getTarFileList(const QString &archivePath) {
        QProcess tarProcess;
        tarProcess.start("tar", QStringList() << "-tf" << archivePath);
        
        if (!tarProcess.waitForFinished(120000)) { // 2 minutos timeout
            emit logMessage("❌ Timeout obteniendo lista de archivos");
            emit logMessage("⚠️  Intentando método alternativo...");
            
            // Método alternativo: extraer directamente sin lista
            return QStringList(); // Lista vacía para usar extracción simple
        }
        
        if (tarProcess.exitCode() != 0) {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            emit logMessage(QString("❌ Error leyendo .tar: %1").arg(error.left(100)));
            emit logMessage("⚠️  Intentando extracción directa...");
            return QStringList(); // Lista vacía para usar extracción simple
        }
        
        QString output = QString::fromUtf8(tarProcess.readAllStandardOutput());
        QStringList fileList = output.split('\n', Qt::SkipEmptyParts);
        
        fileList = fileList.filter(QRegularExpression(".+"));
        
        emit logMessage(QString("📊 Se leerán %1 archivos del tar").arg(fileList.size()));
        
        // Si hay demasiados archivos, usar extracción simple
        if (fileList.size() > 100000) {
            emit logMessage("⚠️  Muchos archivos detectados, usando extracción optimizada");
            // Filtrar solo directorios principales para extracción optimizada
            QStringList filtered;
            QSet<QString> dirs;
            
            foreach (const QString &file, fileList) {
                if (file.contains('/')) {
                    QString dir = file.section('/', 0, 0);
                    if (!dirs.contains(dir)) {
                        dirs.insert(dir);
                        filtered.append(dir + "/");
                    }
                } else {
                    filtered.append(file);
                }
            }
            
            if (filtered.size() < fileList.size() / 10) {
                emit logMessage(QString("📊 Extracción optimizada: %1 elementos vs %2 originales")
                            .arg(filtered.size()).arg(fileList.size()));
                return filtered;
            }
        }
        
        return fileList;
    }
    
    bool extractFileGroup(const QString &archivePath, const QString &outputDir, const QStringList &files) {
        if (files.isEmpty()) {
            return true;
        }
        
        emit logMessage(QString("📂 Extrayendo %1 archivos...").arg(files.size()));
        
        foreach (const QString &filePath, files) {
            QString fullPath = outputDir + "/" + filePath;
            QFileInfo fileInfo(fullPath);
            
            QDir().mkpath(fileInfo.absolutePath());
        }
        
        QProcess tarProcess;
        QStringList tarArgs;
        tarArgs << "-xf" << archivePath;
        tarArgs << "-C" << outputDir;
        
        QStringList filteredFiles;
        
        foreach (const QString &file, files) {
            if (file.startsWith("Atlas_Interactivo-1.0.0-linux-x64/")) {
                filteredFiles << file;
            } else if (file.contains("/")) {
                QString dirPath = file.left(file.lastIndexOf('/'));
                if (!filteredFiles.contains(dirPath)) {
                    filteredFiles << dirPath;
                }
            } else {
                filteredFiles << file;
            }
        }
        
        if (filteredFiles.isEmpty()) {
            emit logMessage("ℹ️  Extrayendo todo el contenido del archivo...");
            tarArgs << "--strip-components=0";
        } else {
            emit logMessage(QString("📁 Extrayendo %1 elementos...").arg(filteredFiles.size()));
            foreach (const QString &file, filteredFiles) {
                tarArgs << file;
            }
        }
        
        emit logMessage("🔧 Comando tar: tar " + tarArgs.join(" "));
        
        tarProcess.start("tar", tarArgs);
        
        if (!tarProcess.waitForFinished(300000)) {
            emit logMessage("❌ Timeout extrayendo grupo");
            return false;
        }
        
        if (tarProcess.exitCode() != 0) {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            emit logMessage("❌ Error extrayendo grupo: " + error);
            
            emit logMessage("🔄 Intentando método alternativo de extracción...");
            
            QProcess tarProcess2;
            tarProcess2.start("tar", QStringList() 
                << "-xf" << archivePath
                << "-C" << outputDir
                << "--strip-components=0");
            
            if (!tarProcess2.waitForFinished(300000)) {
                emit logMessage("❌ Falló método alternativo también");
                return false;
            }
            
            if (tarProcess2.exitCode() != 0) {
                QString error2 = QString::fromUtf8(tarProcess2.readAllStandardError());
                emit logMessage("❌ Error método alternativo: " + error2);
                return false;
            }
            
            emit logMessage("✅ Extracción exitosa con método alternativo");
        }
        
        emit logMessage("✅ Grupo extraído correctamente");
        return true;
    }
    
    void createVersionFile() {
        QString versionFile = m_installDir + "/.atlas_version.json";
        QFile file(versionFile);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            out << "{\n";
            out << "  \"version\": \"1.0.0\",\n";
            out << "  \"installed\": true,\n";
            out << "  \"install_path\": \"" << m_installDir << "\",\n";
            out << "  \"install_date\": \"" << QDateTime::currentDateTime().toString(Qt::ISODate) << "\",\n";
            out << "  \"file_type\": \"tar\",\n";
            out << "  \"download_method\": \"" << m_downloadMethod << "\",\n"; // ========== NUEVO ==========
            out << "  \"download_size\": \"variable\",\n";
            out << "  \"download_resumable\": true,\n";
            out << "  \"download_attempts\": " << m_downloadAttempts << ",\n";
            out << "  \"extraction_method\": \"incremental_groups\"\n";
            out << "}\n";
            file.close();
            emit logMessage("✅ Archivo de versión creado");
        }
    }
    
signals:
    void progressUpdated(int value, const QString &message);
    void workFinished(bool success, const QString &message);
    void logMessage(const QString &message);
    
private:
    QString m_installDir;
    QString m_downloadMethod; // ========== NUEVO ==========
    QString m_ftpUrl;         // ========== NUEVO ==========
    QString m_driveId;
    QString m_tempArchive;
    bool m_canceled;
    int m_downloadAttempts;
};

// ========== IMPLEMENTACIÓN PRINCIPAL ==========

InstallerWindow::InstallerWindow(QWidget *parent) 
    : QMainWindow(parent), 
      networkManager(nullptr),
      m_skipDesktopShortcuts(false),
      dpiScale(1.0),
      m_hasSufficientSpace(true),
      diskSpaceTimer(nullptr),
      currentWorker(nullptr),
      currentThread(nullptr),
      m_isInstalling(false),
      downloadMethod("ftp"), // ========== NUEVO ==========
      ftpUrl("ftp://atlas.example.com/Atlas_Interactivo_Linux.tar"), // ========== NUEVO ==========
      driveId("1y8_Lt0xO5hp3Wbx1hQrZOc_ZP1Vj70-y") // ========== NUEVO ==========
{
    qDebug() << "DEBUG: Constructor InstallerWindow - INICIO";
    
    // Calcular escala DPI basada en la pantalla
    QScreen *screen = QGuiApplication::primaryScreen();
    dpiScale = screen->logicalDotsPerInch() / 96.0;
    if (dpiScale < 1.0) dpiScale = 1.0;
    if (dpiScale > 2.5) dpiScale = 2.5;
    
    setWindowTitle("Atlas Interactivo - Instalador");
    setupUI();
    
    qDebug() << "DEBUG: Después de setupUI()";
    
    // Configurar directorio predeterminado
    QString appPath = QCoreApplication::applicationDirPath();
    if (!appPath.isEmpty() && appPath != QDir::currentPath()) {
        installDir = appPath + "/Atlas_Interactivo";
    } else {
        installDir = QDir::homePath() + "/Atlas_Interactivo";
    }
    
    if (directoryEdit) {
        directoryEdit->setText(installDir);
    }
    
    // Inicializar timer para actualizar espacio en disco
    diskSpaceTimer = new QTimer(this);
    diskSpaceTimer->setInterval(2000);
    connect(diskSpaceTimer, &QTimer::timeout, this, &InstallerWindow::updateDiskSpace);
    diskSpaceTimer->start();
    
    // Verificar espacio en disco inicial
    updateDiskSpace();
    
    qDebug() << "DEBUG: Constructor InstallerWindow - FIN";
}

// ========== NUEVO MÉTODO PARA CONFIGURAR MÉTODO DE DESCARGA ==========
void InstallerWindow::setDownloadMethod(bool useFTP, bool useDrive) {
    if (useFTP) {
        downloadMethod = "ftp";
        if (downloadMethodLabel) {
            downloadMethodLabel->setText("🌐 Método de descarga: FTP");
            downloadMethodLabel->setStyleSheet("color: #3498db; font-weight: bold;");
        }
    } else if (useDrive) {
        downloadMethod = "drive";
        if (downloadMethodLabel) {
            downloadMethodLabel->setText("🌐 Método de descarga: Google Drive");
            downloadMethodLabel->setStyleSheet("color: #e74c3c; font-weight: bold;");
        }
    }
    
    qDebug() << "DEBUG: Método de descarga configurado a:" << downloadMethod;
}

QString InstallerWindow::formatBytes(qint64 bytes) {
    const qint64 KB = 1024;
    const qint64 MB = KB * 1024;
    const qint64 GB = MB * 1024;
    
    if (bytes >= GB) {
        return QString("%1 GB").arg(QString::number(bytes / (double)GB, 'f', 2));
    } else if (bytes >= MB) {
        return QString("%1 MB").arg(QString::number(bytes / (double)MB, 'f', 2));
    } else if (bytes >= KB) {
        return QString("%1 KB").arg(QString::number(bytes / (double)KB, 'f', 2));
    } else {
        return QString("%1 bytes").arg(bytes);
    }
}

qint64 InstallerWindow::getAvailableDiskSpace(const QString &path)
{
    struct statvfs stat;
    QString checkPath = path;
    
    while (!QDir(checkPath).exists() && checkPath != "/") {
        checkPath = QFileInfo(checkPath).dir().absolutePath();
    }
    
    if (checkPath.isEmpty()) {
        checkPath = "/";
    }
    
    if (statvfs(checkPath.toUtf8().constData(), &stat) == 0) {
        return (qint64)stat.f_bsize * stat.f_bavail;
    }
    
    return -1;
}

qint64 InstallerWindow::getAvailableDiskSpacePrecise(const QString &path)
{
    struct statvfs stat;
    QString checkPath = path;
    
    while (!QDir(checkPath).exists() && checkPath != "/") {
        checkPath = QFileInfo(checkPath).dir().absolutePath();
    }
    
    if (checkPath.isEmpty()) {
        checkPath = "/";
    }
    
    if (statvfs(checkPath.toUtf8().constData(), &stat) == 0) {
        return (qint64)stat.f_frsize * stat.f_bavail;
    }
    
    return -1;
}

bool InstallerWindow::hasSufficientDiskSpace(qint64 requiredGB)
{
    qint64 availableBytes = getAvailableDiskSpacePrecise(installDir);
    if (availableBytes < 0) {
        return true;
    }
    
    qint64 requiredBytes = requiredGB * 1024 * 1024 * 1024;
    return availableBytes >= requiredBytes;
}

QFont InstallerWindow::getScaledFont(int baseSize) {
    int scaledSize = qRound(baseSize * dpiScale);
    return QFont("Segoe UI", qMax(scaledSize, 8));
}

void InstallerWindow::setupUI()
{
    QRect screenGeometry = QGuiApplication::primaryScreen()->availableGeometry();
    
    int baseWidth = 1200;
    int baseHeight = 1200;

    int windowWidth = qMin(qRound(baseWidth * dpiScale), int(screenGeometry.width() * 0.9));
    int windowHeight = qMin(qRound(baseHeight * dpiScale), int(screenGeometry.height() * 0.9));
    
    setMinimumSize(qRound(700 * dpiScale), qRound(600 * dpiScale));
    resize(windowWidth, windowHeight);
    
    centralWidget = new QWidget(this);
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);
    mainLayout->setSpacing(qRound(10 * dpiScale));
    mainLayout->setContentsMargins(
        qRound(15 * dpiScale),
        qRound(15 * dpiScale),
        qRound(15 * dpiScale),
        qRound(15 * dpiScale)
    );
    
    // ENCABEZADO
    QHBoxLayout *headerLayout = new QHBoxLayout();
    
    QLabel *iconLabel = new QLabel("🌍", this);
    iconLabel->setStyleSheet(QString("font-size: %1px; padding-right: %2px;")
        .arg(qRound(40 * dpiScale))
        .arg(qRound(10 * dpiScale)));
    
    QVBoxLayout *titleLayout = new QVBoxLayout();
    titleLabel = new QLabel("ATLAS INTERACTIVO", this);
    titleLabel->setFont(getScaledFont(20));
    titleLabel->setStyleSheet("color: #2c3e50; font-weight: bold;");
    
    subtitleLabel = new QLabel("Instalador Oficial para Linux", this);
    subtitleLabel->setFont(getScaledFont(11));
    subtitleLabel->setStyleSheet("color: #7f8c8d;");
    
    titleLayout->addWidget(titleLabel);
    titleLayout->addWidget(subtitleLabel);
    
    headerLayout->addWidget(iconLabel);
    headerLayout->addLayout(titleLayout);
    headerLayout->addStretch();
    
    QLabel *versionLabel = new QLabel("v1.0.0", this);
    versionLabel->setFont(getScaledFont(9));
    versionLabel->setStyleSheet("color: #95a5a6;");
    headerLayout->addWidget(versionLabel);
    
    mainLayout->addLayout(headerLayout);
    mainLayout->addSpacing(qRound(10 * dpiScale));
    
    // ========== NUEVA ETIQUETA PARA MÉTODO DE DESCARGA ==========
    downloadMethodLabel = new QLabel("🌐 Método de descarga: FTP (por defecto)", this);
    downloadMethodLabel->setFont(getScaledFont(9));
    downloadMethodLabel->setStyleSheet("color: #3498db; font-weight: bold;");
    downloadMethodLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(downloadMethodLabel);
    mainLayout->addSpacing(qRound(5 * dpiScale));
    
    // CONFIGURACIÓN
    QGroupBox *configGroup = new QGroupBox("CONFIGURACIÓN DE INSTALACIÓN", this);
    configGroup->setFont(getScaledFont(10));
    
    QVBoxLayout *configLayout = new QVBoxLayout(configGroup);
    configLayout->setSpacing(qRound(8 * dpiScale));
    configLayout->setContentsMargins(
        qRound(12 * dpiScale),
        qRound(12 * dpiScale),
        qRound(12 * dpiScale),
        qRound(12 * dpiScale)
    );
    
    QHBoxLayout *dirLayout = new QHBoxLayout();
    QLabel *dirLabel = new QLabel("Ubicación:", this);
    dirLabel->setFont(getScaledFont(10));
    dirLabel->setStyleSheet("font-weight: bold;");
    dirLabel->setMinimumWidth(qRound(85 * dpiScale));
    
    directoryEdit = new QLineEdit(installDir, this);
    directoryEdit->setFont(getScaledFont(9));
    directoryEdit->setMinimumHeight(qRound(32 * dpiScale));
    connect(directoryEdit, &QLineEdit::textChanged, this, [this](const QString &text) {
        installDir = text;
        updateDiskSpace();
    });
    
    browseButton = new QPushButton("Examinar", this);
    browseButton->setFont(getScaledFont(9));
    browseButton->setMinimumWidth(qRound(120 * dpiScale));
    browseButton->setMinimumHeight(qRound(32 * dpiScale));
    connect(browseButton, &QPushButton::clicked, this, &InstallerWindow::browseDirectory);
    
    dirLayout->addWidget(dirLabel);
    dirLayout->addWidget(directoryEdit, 1);
    dirLayout->addWidget(browseButton);
    configLayout->addLayout(dirLayout);
    
    QHBoxLayout *spaceLayout = new QHBoxLayout();
    diskSpaceLabel = new QLabel("", this);
    diskSpaceLabel->setFont(getScaledFont(9));
    diskSpaceLabel->setStyleSheet("font-weight: bold;");
    
    spaceWarningLabel = new QLabel("", this);
    spaceWarningLabel->setFont(getScaledFont(9));
    spaceWarningLabel->setAlignment(Qt::AlignRight);
    
    spaceLayout->addWidget(diskSpaceLabel);
    spaceLayout->addStretch();
    spaceLayout->addWidget(spaceWarningLabel);
    configLayout->addLayout(spaceLayout);
    
    QHBoxLayout *shortcutLayout = new QHBoxLayout();
    desktopShortcutCheck = new QCheckBox("Acceso directo en escritorio", this);
    desktopShortcutCheck->setFont(getScaledFont(9));
    desktopShortcutCheck->setChecked(true);
    
    menuShortcutCheck = new QCheckBox("Menú de aplicaciones", this);
    menuShortcutCheck->setFont(getScaledFont(9));
    menuShortcutCheck->setChecked(true);
    
    shortcutLayout->addWidget(desktopShortcutCheck);
    shortcutLayout->addSpacing(qRound(20 * dpiScale));
    shortcutLayout->addWidget(menuShortcutCheck);
    shortcutLayout->addStretch();
    configLayout->addLayout(shortcutLayout);
    
    QFrame *infoFrame = new QFrame(this);
    infoFrame->setMinimumHeight(qRound(100 * dpiScale));
    infoFrame->setStyleSheet(R"(
        QFrame {
            background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 #e3f2fd, stop:1 #f3e5f5);
            border-left: 4px solid #3498db;
            border-radius: 6px;
            padding: 10px;
        }
    )");
    
    QVBoxLayout *infoLayout = new QVBoxLayout(infoFrame);
    QLabel *infoTitle = new QLabel("INFORMACIÓN IMPORTANTE", this);
    infoTitle->setFont(getScaledFont(9));
    infoTitle->setStyleSheet("font-weight: bold; color: #2c3e50;");
    
    // ========== INFORMACIÓN ACTUALIZADA CON MÉTODO DE DESCARGA ==========
    QString infoText;
    if (downloadMethod == "ftp") {
        infoText = 
            "• Descarga desde FTP (~20 GB)\n"
            "• Formato: archivo .tar sin compresión\n"
            "• Se requieren 25 GB de espacio disponible\n"
            "• El archivo temporal se elimina automáticamente\n"
            "• Espacio final después de instalación: ~20 GB";
    } else {
        infoText = 
            "• Descarga desde Google Drive (~20 GB)\n"
            "• Formato: archivo .tar sin compresión\n"
            "• Se requieren 25 GB de espacio disponible\n"
            "• El archivo temporal se elimina automáticamente\n"
            "• Espacio final después de instalación: ~20 GB";
    }
    
    QLabel *infoContent = new QLabel(infoText, this);
    infoContent->setFont(getScaledFont(8));
    infoContent->setStyleSheet("color: #34495e; line-height: 130%;");
    infoContent->setWordWrap(true);
    
    infoLayout->addWidget(infoTitle);
    infoLayout->addWidget(infoContent);
    configLayout->addWidget(infoFrame);
    
    mainLayout->addWidget(configGroup);
    mainLayout->addSpacing(qRound(10 * dpiScale));
    
    // PROGRESO
    QGroupBox *progressGroup = new QGroupBox("PROGRESO DE INSTALACIÓN", this);
    progressGroup->setFont(getScaledFont(10));
    
    QVBoxLayout *progressLayout = new QVBoxLayout(progressGroup);
    progressLayout->setSpacing(qRound(6 * dpiScale));
    progressLayout->setContentsMargins(
        qRound(12 * dpiScale),
        qRound(12 * dpiScale),
        qRound(12 * dpiScale),
        qRound(12 * dpiScale)
    );
    
    QHBoxLayout *progressHeader = new QHBoxLayout();
    QLabel *progressTitle = new QLabel("Progreso:", this);
    progressTitle->setFont(getScaledFont(10));
    progressTitle->setStyleSheet("font-weight: bold;");
    
    statusLabel = new QLabel("Listo para comenzar la instalación", this);
    statusLabel->setFont(getScaledFont(9));
    statusLabel->setStyleSheet("color: #34495e;");
    
    progressHeader->addWidget(progressTitle);
    progressHeader->addStretch();
    progressHeader->addWidget(statusLabel);
    progressLayout->addLayout(progressHeader);
    
    progressBar = new QProgressBar(this);
    progressBar->setTextVisible(true);
    progressBar->setFormat("%p%");
    progressBar->setMinimumHeight(qRound(26 * dpiScale));
    progressLayout->addWidget(progressBar);
    
    QFrame *logFrame = new QFrame(this);
    logFrame->setMinimumHeight(qRound(160 * dpiScale));
    logFrame->setStyleSheet(R"(
        QFrame {
            background-color: #1a1a2e;
            border-radius: 5px;
            padding: 4px;
        }
    )");
    
    QVBoxLayout *logLayout = new QVBoxLayout(logFrame);
    QHBoxLayout *logHeader = new QHBoxLayout();
    QLabel *logTitle = new QLabel("REGISTRO DE INSTALACIÓN", this);
    logTitle->setFont(getScaledFont(9));
    logTitle->setStyleSheet("color: #ffffff; font-weight: bold;");
    
    clearLogButton = new QPushButton("Limpiar", this);
    clearLogButton->setFont(getScaledFont(8));
    clearLogButton->setMinimumWidth(qRound(80 * dpiScale));
    clearLogButton->setMinimumHeight(qRound(24 * dpiScale));
    clearLogButton->setStyleSheet(R"(
        QPushButton {
            background-color: #6c757d;
            color: white;
            border: none;
            padding: 3px 10px;
            border-radius: 3px;
        }
        QPushButton:hover {
            background-color: #5a6268;
        }
    )");
    connect(clearLogButton, &QPushButton::clicked, this, &InstallerWindow::clearLog);
    
    logHeader->addWidget(logTitle);
    logHeader->addStretch();
    logHeader->addWidget(clearLogButton);
    logLayout->addLayout(logHeader);
    
    logText = new QTextEdit(this);
    logText->setFont(QFont("Monaco", qRound(8 * dpiScale)));
    logText->setMinimumHeight(qRound(120 * dpiScale));
    logText->setPlaceholderText("Aquí aparecerán los detalles de la instalación...");
    logText->setStyleSheet("background-color: #1a1a2e; color: #e0e0e0; border: none;");
    logLayout->addWidget(logText);
    
    progressLayout->addWidget(logFrame);
    mainLayout->addWidget(progressGroup);
    
    mainLayout->addSpacing(qRound(5 * dpiScale));
    
    // BOTONES
    QHBoxLayout *buttonLayout = new QHBoxLayout();
    
    aboutButton = new QPushButton("Acerca de", this);
    aboutButton->setFont(getScaledFont(9));
    aboutButton->setMinimumWidth(qRound(120 * dpiScale));
    aboutButton->setMinimumHeight(qRound(36 * dpiScale));
    aboutButton->setStyleSheet(R"(
        QPushButton {
            background-color: #6c757d;
            color: white;
            border: none;
            padding: 6px 14px;
            border-radius: 5px;
            font-weight: bold;
        }
        QPushButton:hover {
            background-color: #5a6268;
        }
    )");

    connect(aboutButton, &QPushButton::clicked, [this]() {
        QString methodText = (downloadMethod == "ftp") ? "FTP" : "Google Drive";
        QMessageBox::about(this, "Acerca de Atlas Interactivo",
            "<h3>Atlas Interactivo</h3>"
            "<p>Instalador para Linux v1.0.0</p>"
            "<p>© 2025 Atlas Interactivo Team</p>"
            "<p>Compilado con Qt " QT_VERSION_STR "</p>"
            "<p><b>Método de descarga:</b> " + methodText + "</p>"
            "<p><b>Características:</b></p>"
            "<p>• Descarga resumible con 3 reintentos</p>"
            "<p>• Extracción por grupos de 50k archivos</p>"
            "<p>• Espacio temporal máximo: 25 GB</p>");
    });
    
    exitButton = new QPushButton("Salir", this);
    exitButton->setFont(getScaledFont(9));
    exitButton->setMinimumWidth(qRound(100 * dpiScale));
    exitButton->setMinimumHeight(qRound(36 * dpiScale));
    exitButton->setStyleSheet(R"(
        QPushButton {
            background-color: #dc3545;
            color: white;
            border: none;
            padding: 6px 14px;
            border-radius: 5px;
            font-weight: bold;
        }
        QPushButton:hover {
            background-color: #c82333;
        }
    )");

    // CONEXIÓN MEJORADA PARA EL BOTÓN SALIR
    connect(exitButton, &QPushButton::clicked, this, [this]() {
        if (m_isInstalling) {
            // Preguntar si realmente quiere cancelar
            QMessageBox msgBox(this);
            msgBox.setWindowTitle("Instalación en progreso");
            msgBox.setIcon(QMessageBox::Warning);
            msgBox.setText("⚠️ Hay una instalación en progreso");
            msgBox.setInformativeText("¿Estás seguro que deseas salir?\n\n"
                                    "La instalación será cancelada y todos los archivos temporales serán eliminados.");
            
            QPushButton *continueButton = msgBox.addButton("Continuar instalación", QMessageBox::RejectRole);
            QPushButton *cancelButton = msgBox.addButton("Cancelar y salir", QMessageBox::AcceptRole);
            
            msgBox.setDefaultButton(continueButton);
            msgBox.exec();
            
            if (msgBox.clickedButton() == cancelButton) {
                // Mostrar mensaje de cancelación
                logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] ⚠️ Cancelando instalación por solicitud del usuario...");
                
                // Cancelar la instalación de manera segura
                cancelCurrentInstallation();
                
                // Cerrar la ventana después de un breve retraso
                QTimer::singleShot(500, this, [this]() {
                    if (logText) {
                        logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] ✅ Aplicación cerrada");
                    }
                    close();
                });
            }
        } else {
            // Si no hay instalación en curso, preguntar normalmente
            QMessageBox::StandardButton reply;
            reply = QMessageBox::question(this, "Confirmar salida",
                "¿Estás seguro que deseas salir del instalador?",
                QMessageBox::Yes | QMessageBox::No,
                QMessageBox::No);
            
            if (reply == QMessageBox::Yes) {
                close();
            }
        }
    });

    installButton = new QPushButton("INICIAR INSTALACIÓN", this);
    installButton->setFont(getScaledFont(10));
    installButton->setMinimumWidth(qRound(200 * dpiScale));
    installButton->setMinimumHeight(qRound(40 * dpiScale));
    installButton->setStyleSheet(R"(
        QPushButton {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #2ecc71, stop:1 #27ae60);
            color: white;
            border: none;
            padding: 8px 18px;
            border-radius: 5px;
            font-weight: bold;
        }
        QPushButton:hover {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #27ae60, stop:1 #219653);
        }
        QPushButton:disabled {
            background-color: #95a5a6;
            color: #7f8c8d;
        }
    )");
    connect(installButton, &QPushButton::clicked, this, &InstallerWindow::startInstallation);
    
    buttonLayout->addWidget(aboutButton);
    buttonLayout->addStretch();
    buttonLayout->addWidget(exitButton);
    buttonLayout->addSpacing(qRound(15 * dpiScale));
    buttonLayout->addWidget(installButton);
    
    mainLayout->addLayout(buttonLayout);
    mainLayout->addSpacing(qRound(5 * dpiScale));
    
    // FOOTER
    QFrame *footerFrame = new QFrame(this);
    footerFrame->setMinimumHeight(qRound(28 * dpiScale));
    footerFrame->setStyleSheet(R"(
        QFrame {
            background-color: #2c3e50;
            border-radius: 5px;
            padding: 6px;
        }
    )");
    
    QHBoxLayout *footerLayout = new QHBoxLayout(footerFrame);
    QString footerText;
    if (downloadMethod == "ftp") {
        footerText = "⚠️ Requiere conexión a Internet estable • Descarga FTP • 3 reintentos • Extracción por grupos • Espacio temporal: 25 GB";
    } else {
        footerText = "⚠️ Requiere conexión a Internet estable • Descarga Google Drive • 3 reintentos • Extracción por grupos • Espacio temporal: 25 GB";
    }
    
    QLabel *footerLabel = new QLabel(footerText, this);
    footerLabel->setFont(getScaledFont(7));
    footerLabel->setStyleSheet("color: #ecf0f1;");
    footerLabel->setAlignment(Qt::AlignCenter);
    footerLabel->setWordWrap(true);
    
    footerLayout->addWidget(footerLabel);
    mainLayout->addWidget(footerFrame);
    
    setCentralWidget(centralWidget);
    
    int x = (screenGeometry.width() - width()) / 2;
    int y = (screenGeometry.height() - height()) / 2;
    move(x, y);
}

void InstallerWindow::clearLog() {
    logText->clear();
}

bool InstallerWindow::checkDiskSpace()
{
    return m_hasSufficientSpace;
}

void InstallerWindow::browseDirectory()
{
    QString currentDir = directoryEdit->text();
    if (currentDir.isEmpty()) {
        currentDir = QDir::currentPath();
    }
    
    QString dir = QFileDialog::getExistingDirectory(this, 
        "Seleccionar directorio de instalación",
        currentDir,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks);
    
    if (!dir.isEmpty()) {
        directoryEdit->setText(dir);
        installDir = dir;
        updateDiskSpace();
    }
}

void InstallerWindow::updateProgress(int value, const QString &message)
{
    progressBar->setValue(value);
    statusLabel->setText(message);
}

void InstallerWindow::cancelCurrentInstallation()
{
    static bool isCancelling = false;  // Prevenir llamadas recursivas
    
    if (isCancelling) {
        qDebug() << "DEBUG: cancelCurrentInstallation ya en progreso, ignorando llamada duplicada";
        return;
    }
    
    isCancelling = true;
    
    qDebug() << "DEBUG: Entrando a cancelCurrentInstallation()";
    qDebug() << "DEBUG: m_isInstalling =" << m_isInstalling;
    
    // VERIFICACIÓN EXTRA DE SEGURIDAD
    // Solo podemos estar cancelando si el usuario realmente inició la instalación
    bool userInitiated = false;
    
    // Verificar si el usuario hizo clic en "INICIAR INSTALACIÓN"
    if (installButton && installButton->text() == "Instalando..." && !installButton->isEnabled()) {
        userInitiated = true;
        qDebug() << "DEBUG: Instalación iniciada por usuario detectada";
    }
    
    if (!userInitiated && !m_isInstalling) {
        qDebug() << "DEBUG: ⚠️ INSTALACIÓN NO INICIADA - Cancelación ignorada";
        isCancelling = false;
        return;
    }
    
    // Marcar que ya no estamos instalando
    m_isInstalling = false;
    
    // Mostrar mensaje en log
    if (logText) {
        logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] ⚠️ Cancelando instalación...");
    }
    
    // Cancelar el worker si existe
    if (currentWorker) {
        qDebug() << "DEBUG: Cancelando worker...";
        
        // Llamar al método de limpieza del worker
        QMetaObject::invokeMethod(currentWorker, "cleanupProcesses", 
            Qt::BlockingQueuedConnection);
        
        // Pequeña pausa
        QThread::msleep(100);
        QApplication::processEvents();
    }
    
    // Detener el thread de manera segura
    if (currentThread && currentThread->isRunning()) {
        qDebug() << "DEBUG: Deteniendo thread...";
        
        currentThread->requestInterruption();
        currentThread->quit();
        
        // Esperar que termine
        if (!currentThread->wait(1000)) {
            qDebug() << "DEBUG: Forzando terminación del thread...";
            currentThread->terminate();
            currentThread->wait(500);
        }
        
        qDebug() << "DEBUG: Thread detenido";
    }
    
    // Limpiar archivos temporales
    QString tempDir = QDir::tempPath();
    if (!tempDir.isEmpty() && QDir(tempDir).exists()) {
        QDir temp(tempDir);
        
        QStringList patterns;
        patterns << "atlas_*.tar" << "gdrive_*" 
                 << "tar_list_*.txt" << "*.part" 
                 << "cookies.txt" << "gdrive_response.html" 
                 << "gdrive_cookies_*.txt";
        
        foreach (const QString &pattern, patterns) {
            QStringList tempFiles = temp.entryList(QStringList() << pattern, QDir::Files);
            foreach (const QString &file, tempFiles) {
                QString filePath = tempDir + "/" + file;
                if (!filePath.isEmpty() && QFile::exists(filePath)) {
                    for (int attempt = 0; attempt < 3; attempt++) {
                        if (QFile::remove(filePath)) {
                            if (logText) {
                                logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] 🗑️ Archivo temporal eliminado: " + file);
                            }
                            break;
                        }
                        QThread::msleep(100);
                    }
                }
            }
        }
    }
    
    // Limpiar objetos de manera segura (EVITAR doble eliminación)
    qDebug() << "DEBUG: Limpiando objetos...";
    
    if (currentWorker) {
        // NO usar disconnect() - puede causar problemas
        // NO usar deleteLater() aquí - ya se maneja en las conexiones del thread
        
        // Solo establecer a nullptr
        currentWorker = nullptr;
    }
    
    if (currentThread) {
        // NO usar disconnect() o deleteLater() aquí
        
        // Solo establecer a nullptr
        currentThread = nullptr;
    }
    
    // Actualizar UI
    if (installButton) {
        installButton->setEnabled(true);
        installButton->setText("INICIAR INSTALACIÓN");
    }
    
    if (browseButton) {
        browseButton->setEnabled(true);
    }
    
    if (progressBar) {
        progressBar->setValue(0);
    }
    
    if (statusLabel) {
        statusLabel->setText("Instalación cancelada");
    }
    
    if (logText) {
        logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] ✅ Instalación cancelada correctamente");
    }
    
    // Forzar actualización
    QApplication::processEvents();
    
    qDebug() << "DEBUG: ✅ Cancelación completada";
    
    isCancelling = false;
}

bool InstallerWindow::extractArchive(const QString &archivePath, const QString &outputDir)
{
    QProcess tarProcess;
    tarProcess.setWorkingDirectory(outputDir);
    tarProcess.start("tar", QStringList() << "-xf" << archivePath);
    
    return tarProcess.waitForFinished() && tarProcess.exitCode() == 0;
}

void InstallerWindow::createDesktopEntry()
{
    logText->append("[INFO] Creando accesos directos...");
    
    if (!QDir(installDir).exists()) {
        logText->append("❌ Error: El directorio de instalación no existe: " + installDir);
        return;
    }
    
    QString executablePath = installDir + "/Atlas_Interactivo";
    QString iconPath = installDir + "/resources/logos/icon.png";
    
    logText->append("📁 Icono configurado en: " + iconPath);
    
    QString desktopDir = QDir::homePath() + "/.local/share/applications";
    if (!QDir().mkpath(desktopDir)) {
        logText->append("❌ Error: No se pudo crear el directorio: " + desktopDir);
        return;
    }
    
    QString desktopFile = desktopDir + "/atlas-interactivo.desktop";
    
    QString desktopContent = QString(
        "[Desktop Entry]\n"
        "Version=1.0\n"
        "Type=Application\n"
        "Name=Atlas Interactivo\n"
        "GenericName=Atlas Digital\n"
        "Comment=Atlas digital interactivo con mapas y datos geográficos\n"
        "Exec=%1 --no-sandbox\n"
        "Path=%2\n"
        "Icon=%3\n"
        "Terminal=false\n"
        "Categories=Education;Geography;Science;\n"
        "Keywords=atlas;map;geography;education;interactive;\n"
        "StartupNotify=true\n"
        "StartupWMClass=atlas-interactivo\n"
    ).arg(executablePath).arg(installDir).arg(iconPath);
    
    QFile file(desktopFile);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << desktopContent;
        file.close();
        
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                            QFile::ReadGroup | QFile::ExeGroup |
                            QFile::ReadOther | QFile::ExeOther);
        
        logText->append("✅ Archivo .desktop creado en: " + desktopFile);
        logText->append("   Icono configurado: " + iconPath);
    } else {
        logText->append("❌ Error: No se pudo escribir el archivo .desktop");
        return;
    }
    
    if (desktopShortcutCheck->isChecked()) {
        QString desktopShortcut = QDir::homePath() + "/Desktop/Atlas_Interactivo.desktop";
        
        if (QFile::exists(desktopShortcut)) {
            logText->append("⚠️  Ya existe un acceso directo en el escritorio, sobrescribiendo...");
            QFile::remove(desktopShortcut);
        }
        
        if (QFile::copy(desktopFile, desktopShortcut)) {
            QFile shortcutFile(desktopShortcut);
            shortcutFile.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                                        QFile::ReadGroup | QFile::ExeGroup |
                                        QFile::ReadOther | QFile::ExeOther);
            
            logText->append("✅ Acceso directo creado en escritorio: " + desktopShortcut);
        } else {
            logText->append("⚠️  No se pudo crear el acceso directo en el escritorio");
        }
    }
    
    QProcess updateProcess;
    updateProcess.start("update-desktop-database", QStringList() << desktopDir);
    
    if (updateProcess.waitForFinished(5000)) {
        if (updateProcess.exitCode() == 0) {
            logText->append("✅ Base de datos de aplicaciones actualizada");
        } else {
            logText->append("⚠️  No se pudo actualizar la base de datos de aplicaciones");
        }
    }
    
    logText->append("");
    logText->append("🎉 ACCESOS DIRECTOS CREADOS EXITOSAMENTE");
    logText->append("========================================");
    logText->append("• Menú de aplicaciones: Busca 'Atlas Interactivo' en tu menú");
    
    if (desktopShortcutCheck->isChecked()) {
        logText->append("• Escritorio: Icono 'Atlas Interactivo' en tu escritorio");
    }
    
    logText->append("");
    logText->append("📋 Ruta del ejecutable: " + executablePath);
    logText->append("📋 Ruta del icono: " + iconPath);
}

void InstallerWindow::setInstallDir(const QString &dir)
{
    installDir = dir;
    if (directoryEdit) {
        directoryEdit->setText(dir);
    }
    updateDiskSpace();
}

void InstallerWindow::setSkipDesktopShortcuts(bool skip)
{
    m_skipDesktopShortcuts = skip;
    if (desktopShortcutCheck) {
        desktopShortcutCheck->setChecked(!skip);
        desktopShortcutCheck->setEnabled(!skip);
    }
    if (menuShortcutCheck) {
        menuShortcutCheck->setChecked(!skip);
        menuShortcutCheck->setEnabled(!skip);
    }
}

void InstallerWindow::closeEvent(QCloseEvent *event)
{
    if (m_isInstalling) {
        QMessageBox msgBox(this);
        msgBox.setWindowTitle("Instalación en progreso");
        msgBox.setIcon(QMessageBox::Warning);
        msgBox.setText("⚠️ Hay una instalación en progreso");
        msgBox.setInformativeText("¿Estás seguro que deseas salir?\n\n"
                                 "La instalación será cancelada y todos los archivos temporales serán eliminados.");
        
        QPushButton *cancelButton = msgBox.addButton("Continuar instalación", QMessageBox::RejectRole);
        QPushButton *exitButton = msgBox.addButton("Cancelar y salir", QMessageBox::AcceptRole);
        
        msgBox.setDefaultButton(cancelButton);
        msgBox.exec();
        
        if (msgBox.clickedButton() == exitButton) {
            // Mostrar mensaje de cancelación
            QMetaObject::invokeMethod(logText, "append", Qt::QueuedConnection,
                Q_ARG(QString, "[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] ⚠️ Cancelando instalación por solicitud del usuario..."));
            
            // Esperar un momento para que se muestre el mensaje
            QApplication::processEvents();
            QThread::msleep(300);
            
            // Cancelar la instalación
            cancelCurrentInstallation();
            
            // Esperar un poco más para que todo se limpie
            QThread::msleep(500);
            QApplication::processEvents();
            
            event->accept();
        } else {
            event->ignore();
        }
    }
}

// ========== NUEVOS MÉTODOS AGREGADOS ==========

void InstallerWindow::updateDiskSpacePeriodic() {
    if (m_isInstalling) {
        updateDiskSpace();
        // Programar próxima actualización en 3 segundos
        QTimer::singleShot(3000, this, &InstallerWindow::updateDiskSpacePeriodic);
    }
}

void InstallerWindow::startInstallation()
{
    installDir = directoryEdit->text();
    
    if (!installDir.endsWith("/Atlas_Interactivo")) {
        QString newPath = QDir::cleanPath(installDir + "/Atlas_Interactivo");
        logText->append("[INFO] Ajustando ruta de instalación a: " + newPath);
        installDir = newPath;
        directoryEdit->setText(installDir);
        
        updateDiskSpace();
    }

    if (!checkDiskSpace()) {
        QMessageBox::critical(this, "Espacio insuficiente", 
            QString("No hay suficiente espacio en disco.\n\n"
                   "Se requieren 25 GB de espacio libre.\n"
                   "Espacio disponible: %1\n\n"
                   "NOTA: Se necesitan 25 GB porque:\n"
                   "• Archivo comprimido: ~20 GB\n"
                   "• Buffer de seguridad: 5 GB\n"
                   "• Archivo temporal se elimina después")
                   .arg(diskSpaceLabel->text()));
        return;
    }
    
    QMessageBox msgBox(this);
    msgBox.setWindowTitle("Confirmar instalación");
    msgBox.setTextFormat(Qt::RichText);
    
    QString methodText = (downloadMethod == "ftp") ? "FTP" : "Google Drive";
    
    msgBox.setText(
        "<div align='center'>"
        "<h3>Método de descarga: " + methodText + "</h3>"
        "<p><b>✅ Descarga resumible con 3 reintentos</b></p>"
        "<p><b>✅ Extracción por grupos de 50k archivos</b></p>"
        "<p><b>✅ Espacio temporal máximo: <font color='green'>25 GB</font></b></p>"
        "<br>"
        "<p>¿Desea continuar con la instalación?</p>"
        "</div>"
    );
        
    msgBox.setStyleSheet(
        "QMessageBox { "
        "   min-width: 600px; "
        "} "
        "QLabel { "
        "   min-width: 550px; "
        "}"
    );
    
    msgBox.setStandardButtons(QMessageBox::Ok | QMessageBox::No);
    msgBox.setDefaultButton(QMessageBox::No);
    
    QMessageBox::StandardButton reply = static_cast<QMessageBox::StandardButton>(msgBox.exec());
    
    if (reply != QMessageBox::Ok) {
        return;
    }

    QProcess tarCheck;
    tarCheck.start("which", QStringList() << "tar");
    tarCheck.waitForFinished();
    
    if (tarCheck.exitCode() != 0) {
        QMessageBox::warning(this, "Dependencia faltante", 
                           "El programa 'tar' no está instalado.\n\n"
                           "Instálalo con:\n"
                           "sudo apt install tar");
        return;
    }
    
    QDir().mkpath(installDir);
    
    installButton->setEnabled(false);
    browseButton->setEnabled(false);
    installButton->setText("Instalando...");
    
    // ========== INICIAR ACTUALIZACIÓN PERIÓDICA DEL ESPACIO ==========
    updateDiskSpacePeriodic();
    
    updateProgress(0, "Preparando instalación...");
    logText->clear();
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Iniciando instalación...");
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Método de descarga: " + methodText);
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Descarga resumible activada");
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Extracción por grupos de 50k archivos");
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Espacio temporal máximo: 25 GB");
    
    // ========== PASAR MÉTODO DE DESCARGA AL WORKER ==========
    currentThread = new QThread;
    currentWorker = new InstallWorker(installDir, downloadMethod, ftpUrl, driveId);
    
    currentWorker->moveToThread(currentThread);
    m_isInstalling = true;
    
    // CONEXIONES MEJORADAS
    connect(currentWorker, &InstallWorker::progressUpdated, this, 
        [this](int value, const QString &message) {
            QMetaObject::invokeMethod(this, "updateProgress", 
                Qt::QueuedConnection,
                Q_ARG(int, value),
                Q_ARG(QString, message));
        });
    
    connect(currentWorker, &InstallWorker::workFinished, this,
        [this](bool success, const QString &message) {
            QMetaObject::invokeMethod(this, "installationFinished",
                Qt::QueuedConnection,
                Q_ARG(bool, success),
                Q_ARG(QString, message));
        });
    
    connect(currentWorker, &InstallWorker::logMessage, this,
        [this](const QString &msg) {
            QMetaObject::invokeMethod(logText, "append",
                Qt::QueuedConnection,
                Q_ARG(QString, "[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] " + msg));
        });
    
    // CONEXIÓN PARA LIMPIEZA
    connect(currentThread, &QThread::finished, currentWorker, &QObject::deleteLater);
    connect(currentThread, &QThread::finished, currentThread, &QObject::deleteLater);
    
    // Conectar started del thread para iniciar el trabajo
    connect(currentThread, &QThread::started, currentWorker, &InstallWorker::doWork);
    
    // Iniciar thread
    currentThread->start();
}

void InstallerWindow::updateDiskSpace()
{
    const qint64 REQUIRED_SPACE_GB = 25;
    
    qint64 availableBytes = getAvailableDiskSpacePrecise(installDir);
    if (availableBytes < 0) {
        diskSpaceLabel->setText("Espacio en disco: No disponible");
        diskSpaceLabel->setStyleSheet("color: #95a5a6; font-weight: bold;");
        spaceWarningLabel->setText("");
        installButton->setEnabled(true);
        m_hasSufficientSpace = true;
        return;
    }
    
    double availableGB = availableBytes / (1024.0 * 1024.0 * 1024.0);
    qint64 requiredBytes = REQUIRED_SPACE_GB * 1024LL * 1024LL * 1024LL;
    
    QString diskSpaceText = QString("Espacio disponible: %1 GB").arg(QString::number(availableGB, 'f', 2));
    
    if (availableBytes >= requiredBytes) {
        diskSpaceLabel->setText(diskSpaceText);
        diskSpaceLabel->setStyleSheet("color: #27ae60; font-weight: bold;");
        spaceWarningLabel->setText("✅ Espacio suficiente");
        spaceWarningLabel->setStyleSheet("color: #27ae60; font-weight: bold;");
        installButton->setEnabled(true);
        m_hasSufficientSpace = true;
        
        // Solo mostrar el mensaje de espacio una vez al inicio
        static bool loggedOnce = false;
        if (!loggedOnce && !m_isInstalling) {
            logText->append(QString("[INFO] Espacio en disco: %1 GB disponibles").arg(QString::number(availableGB, 'f', 2)));
            loggedOnce = true;
        }
        
        // Si estamos instalando, mostrar actualización periódica en el log
        if (m_isInstalling) {
            static QTime lastUpdate;
            if (!lastUpdate.isValid() || lastUpdate.elapsed() > 30000) { // Cada 30 segundos
                logText->append(QString("[INFO] Espacio restante: %1 GB").arg(QString::number(availableGB, 'f', 2)));
                lastUpdate = QTime::currentTime();
            }
        }
    } else {
        diskSpaceLabel->setText(diskSpaceText);
        diskSpaceLabel->setStyleSheet("color: #e74c3c; font-weight: bold;");
        spaceWarningLabel->setText(QString("❌ Requiere %1 GB").arg(REQUIRED_SPACE_GB));
        spaceWarningLabel->setStyleSheet("color: #e74c3c; font-weight: bold;");
        installButton->setEnabled(false);
        m_hasSufficientSpace = false;
        
        // Si estamos instalando y se quedó sin espacio, mostrar alerta
        if (m_isInstalling) {
            logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] ❌¡ALERTA! Espacio en disco insuficiente");
            logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Disponible: " + QString::number(availableGB, 'f', 2) + " GB");
            logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Requerido: " + QString::number(REQUIRED_SPACE_GB) + " GB");
            
            // Opcional: Cancelar automáticamente la instalación
            if (availableGB < 5) { // Menos de 5 GB es crítico
                QMetaObject::invokeMethod(this, "cancelCurrentInstallation", Qt::QueuedConnection);
                QMessageBox::critical(this, "Espacio crítico",
                    "¡Espacio en disco crítico!\n\n"
                    "La instalación ha sido cancelada automáticamente.\n"
                    "Libera al menos 25 GB de espacio e intenta nuevamente.");
            }
        }
    }
}

void InstallerWindow::installationFinished(bool success, const QString &message)
{
    m_isInstalling = false;  // Detener la actualización periódica
    
    // Detener el timer de espacio en disco si existe
    if (diskSpaceTimer) {
        diskSpaceTimer->stop();
    }
    
    // Limpiar worker y thread
    if (currentWorker) {
        currentWorker->deleteLater();
        currentWorker = nullptr;
    }
    
    if (currentThread) {
        currentThread->quit();
        currentThread->wait(1000);
        currentThread->deleteLater();
        currentThread = nullptr;
    }
    
    // Actualizar UI
    installButton->setEnabled(true);
    browseButton->setEnabled(true);
    installButton->setText("INICIAR INSTALACIÓN");
    
    // Actualizar espacio en disco final
    updateDiskSpace();
    
    if (success) {
        updateProgress(100, "Instalación completada");
        
        logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] " + message);
        
        if (!m_skipDesktopShortcuts && 
            (desktopShortcutCheck->isChecked() || menuShortcutCheck->isChecked())) {
            createDesktopEntry();
        }
        
        QMessageBox::information(this, "Instalación completada", 
            "✅ " + message + "\n\n"
            "Ubicación: " + installDir + "\n\n"
            "¡Gracias por instalar Atlas Interactivo!");
        
    } else {
        QMessageBox::critical(this, "Error de instalación", 
            "❌ " + message + "\n\n"
            "Posibles soluciones:\n"
            "• Verifica tu conexión a Internet\n"
            "• Asegúrate de tener al menos 25 GB libres\n"
            "• Verifica que 'tar' esté instalado\n"
            "• Intenta nuevamente");
        
        updateProgress(0, "Instalación fallida");
    }
}

#include "installerwindow.moc"
EOF

# ========== COMPILAR ==========
echo "🔧 Compilando con soporte DPI y selección de método de descarga para Qt 5..."
qmake AtlasInstaller.pro

# Verificar si qmake tuvo éxito
if [ ! -f "Makefile" ]; then
    echo "❌ Error: qmake no generó Makefile"
    echo "   Verifica que Qt esté instalado correctamente"
    echo ""
    echo "💡 INSTALACIÓN DE DEPENDENCIAS PARA UBUNTU/DEBIAN:"
    echo "   sudo apt update"
    echo "   sudo apt install qt5-default qttools5-dev-tools g++ make"
    echo "   sudo apt install libqt5widgets5 libqt5gui5 libqt5core5a"
    exit 1
fi

echo "⚙️  Ejecutando make..."
make -j$(nproc)

# ========== VERIFICAR COMPILACIÓN ==========
if [ -f "AtlasInstaller" ]; then
    echo "✅ Compilación exitosa"
    
    echo "🔧 Optimizando binario..."
    strip AtlasInstaller 2>/dev/null || true
    
    mv AtlasInstaller ../../AtlasInstallerQt
    
    size_kb=$(du -k ../../AtlasInstallerQt 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    
    echo "📦 Instalador Qt creado: ../AtlasInstallerQt (${size_mb}MB)"
    
    echo ""
    echo "✨ CONSTRUCCIÓN COMPLETADA CON ÉXITO ✨"
    echo "======================================"
    echo ""
    echo "📁 ARCHIVOS CREADOS:"
    echo "  1. 📦 ../AtlasInstallerQt - Ejecutable principal (${size_mb}MB)"
    echo ""
    echo "🎯 CARACTERÍSTICAS:"
    echo "  ✅ Compatible con Qt 5 (Ubuntu/Debian)"
    echo "  ✅ Escalado DPI mediante variables de entorno"
    echo "  ✅ Manejo de cierre corregido"
    echo "  ✅ Cancelación de instalación robusta"
    echo "  ✅ Selección de método de descarga"
    echo ""
    echo "🚀 MÉTODO DE EJECUCIÓN:"
    echo "  ./AtlasInstallerQt                     # FTP por defecto"
    echo "  ./AtlasInstallerQt --use-drive         # Usar Google Drive"
    echo "  ./AtlasInstallerQt --use-ftp           # Forzar FTP"
    echo ""
    echo "🔧 OPCIONES DE DPI:"
    echo "  QT_AUTO_SCREEN_SCALE_FACTOR=1 QT_SCALE_FACTOR=1.5 ./AtlasInstallerQt"
    echo "  ./AtlasInstallerQt --scale-factor 1.5"
    
else
    echo "❌ Error: No se creó el ejecutable"
    echo "   Revisa los mensajes de error anteriores"
    
    echo ""
    echo "🛠️  SOLUCIÓN DE PROBLEMAS:"
    echo "   1. Verificar que Qt 5 está instalado:"
    echo "      qmake --version"
    echo "   2. Instalar Qt 5 en Ubuntu/Debian:"
    echo "      sudo apt install qt5-default qttools5-dev-tools"
    echo "   3. Instalar compilador C++:"
    echo "      sudo apt install g++ make"
    
    exit 1
fi

# ========== LIMPIAR ==========
cd ..
rm -r build_qt/ 2>/dev/null || true

echo ""
echo "✅ Script completado. ¡Instalador listo con selección de método de descarga!"
echo ""
echo "📝 RESUMEN DE LA ACTUALIZACIÓN:"
echo "   • Por defecto: Descarga desde FTP"
echo "   • Con --use-drive: Descarga desde Google Drive"
echo "   • Con --use-ftp: Descarga desde FTP (explícito)"
echo "   • Se mantiene toda la funcionalidad existente"
echo ""
echo "💡 NOTA: Cambia la URL FTP en installerwindow.cpp (línea con 'ftp://atlas.example.com/...')"
echo "         para usar tu servidor FTP real."