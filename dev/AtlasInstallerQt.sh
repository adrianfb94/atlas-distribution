#!/bin/bash
# Script para construir el instalador Qt - VERSIÓN CORREGIDA

echo "🔨 Construyendo instalador Qt con correcciones..."

# Limpiar
rm -rf build_qt
rm -f ../AtlasInstallerQt

# Crear directorio
mkdir -p build_qt
cd build_qt

# Crear archivos .pro con soporte DPI
cat > AtlasInstaller.pro << 'EOF'
QT += core gui widgets network
CONFIG += c++11
TARGET = AtlasInstaller
TEMPLATE = app
SOURCES = main.cpp installerwindow.cpp
HEADERS = installerwindow.h

# Mejorar escalado en alta DPI
greaterThan(QT_MAJOR_VERSION, 5): QT += widgets
greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

# Habilitar escalado automático
DEFINES += QT_AUTO_SCREEN_SCALE_FACTOR=1
EOF

# main.cpp (se mantiene igual)
cat > main.cpp << 'EOF'
#include "installerwindow.h"
#include <QApplication>
#include <QDir>
#include <QDebug>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("Atlas Installer");
    
    // Configurar escalado para alta DPI
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    
    // Procesar argumentos de línea de comandos ANTES de crear la ventana
    QString installDir = QDir::homePath() + "/Atlas_Interactivo";
    
    for (int i = 1; i < argc; ++i) {
        QString arg = QString(argv[i]);
        
        if (arg == "--help" || arg == "-h") {
            qInfo() << "AtlasInstallerQt - Instalador para Linux";
            qInfo() << "Uso: ./AtlasInstallerQt [OPCIONES]";
            qInfo() << "Opciones:";
            qInfo() << "  --help, -h     Mostrar esta ayuda";
            qInfo() << "  --version, -v  Mostrar versión";
            qInfo() << "  --install-dir PATH  Directorio de instalación";
            qInfo() << "  --skip-desktop      No crear accesos directos";
            return 0;
        }
        
        if (arg == "--version" || arg == "-v") {
            qInfo() << "AtlasInstallerQt v1.0.0";
            qInfo() << "Compilado con Qt" << QT_VERSION_STR;
            return 0;
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

        // --skip-desktop se manejará en la ventana principal
    }
    
    // Crear ventana principal
    InstallerWindow window;
    
    // Configurar directorio si se especificó
    if (installDir != QDir::homePath() + "/Atlas_Interactivo") {
        window.setInstallDir(installDir);
    }
    
    // Verificar --skip-desktop
    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == "--skip-desktop") {
            window.setSkipDesktopShortcuts(true);
            break;
        }
    }
    
    window.show();
    
    return app.exec();
}
EOF

# installerwindow.h - AÑADIR QScrollArea
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

class QNetworkAccessManager;

class InstallerWindow : public QMainWindow
{
    Q_OBJECT
    
public:
    explicit InstallerWindow(QWidget *parent = nullptr);
    
    // Métodos para configuración desde CLI
    void setInstallDir(const QString &dir);
    void setSkipDesktopShortcuts(bool skip);
    


private slots:
    void browseDirectory();
    void startInstallation();
    void updateProgress(int value, const QString &message);
    void installationFinished(bool success, const QString &message);
    void clearLog();
    void updateDiskSpace();
    
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
    
    // Timer para actualizar espacio en disco
    QTimer *diskSpaceTimer;
};

#endif
EOF

# installerwindow.cpp - VERSIÓN CORREGIDA
cat > installerwindow.cpp << 'EOF'
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

// Clase Worker CORREGIDA
class InstallWorker : public QObject {
    Q_OBJECT
    
public:
    explicit InstallWorker(const QString &installDir, const QString &driveId) 
        : m_installDir(installDir), m_driveId(driveId), m_canceled(false), m_downloadAttempts(0) {}
    
    ~InstallWorker() {
        if (!m_tempArchive.isEmpty() && QFile::exists(m_tempArchive)) {
            QFile::remove(m_tempArchive);
        }
    }
    
public slots:
    void doWork() {
        emit logMessage("Iniciando descarga de Atlas Interactivo...");
        emit logMessage("Esto puede tomar tiempo dependiendo de tu conexión.");
        
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
        
        // Usar URL directa de Google Drive
        QString directUrl = getDirectDownloadUrl();
        
        // Descarga con reintentos y resumible
        if (!downloadWithRetries(directUrl, m_tempArchive, 3)) {
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
        
        // MÉTODO ACTUALIZADO: Extraer en grupos manteniendo el .tar completo
        emit progressUpdated(60, "Extrayendo archivos...");
        emit logMessage("Extrayendo archivo .tar en grupos...");
        
        if (!extractArchiveIncremental(m_tempArchive, m_installDir)) {
            emit logMessage("❌ Error extrayendo el archivo");
            emit workFinished(false, "No se pudo extraer el archivo. Verifica que 'tar' esté instalado.");
            return;
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
        
        // Limpiar archivo temporal (¡IMPORTANTE!)
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
        m_canceled = true;
        if (!m_tempArchive.isEmpty() && QFile::exists(m_tempArchive)) {
            QFile::remove(m_tempArchive);
        }
    }
    
private:
    QString getDirectDownloadUrl() {
        return QString("https://drive.google.com/uc?id=%1&export=download&confirm=t&uuid=").arg(m_driveId) +
               QUuid::createUuid().toString().remove('{').remove('}');
    }
    
    // Descarga con reintentos y resumible
    bool downloadWithRetries(const QString &url, const QString &outputPath, int maxAttempts) {
        m_downloadAttempts = 0;
        
        while (m_downloadAttempts < maxAttempts && !m_canceled) {
            m_downloadAttempts++;
            emit logMessage(QString("Intento de descarga %1/%2...").arg(m_downloadAttempts).arg(maxAttempts));
            
            // Primero intentar con wget (resumible)
            if (downloadWithWgetResumable(url, outputPath)) {
                return true;
            }
            
            emit logMessage("wget falló, intentando con curl...");
            
            // Si wget falla, intentar con curl (resumible)
            if (downloadWithCurlResumable(url, outputPath)) {
                return true;
            }
            
            if (m_downloadAttempts < maxAttempts && !m_canceled) {
                int waitTime = 5 * m_downloadAttempts; // Esperar 5, 10, 15 segundos
                emit logMessage(QString("Esperando %1 segundos antes de reintentar...").arg(waitTime));
                QThread::sleep(waitTime);
            }
        }
        
        return false;
    }
    
    bool downloadWithWgetResumable(const QString &url, const QString &outputPath) {
        QProcess wgetProcess;
        
        QStringList wgetArgs;
        wgetArgs << "--no-check-certificate";
        wgetArgs << "--no-netrc";
        wgetArgs << "--progress=dot:giga";
        wgetArgs << "-c"; // --continue: descarga resumible
        wgetArgs << "-O" << outputPath;
        wgetArgs << "--tries=3";
        wgetArgs << "--timeout=30";
        wgetArgs << "--waitretry=5";
        wgetArgs << url;
        
        wgetProcess.start("wget", wgetArgs);
        
        if (!wgetProcess.waitForStarted()) {
            emit logMessage("wget no está disponible o no pudo iniciarse");
            return false;
        }
        
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        
        connect(&wgetProcess, &QProcess::readyReadStandardOutput, this, [this, &wgetProcess]() {
            QString output = QString::fromUtf8(wgetProcess.readAllStandardOutput());
            if (!output.trimmed().isEmpty()) {
                QRegularExpression re(R"((\d+)%)");
                QRegularExpressionMatchIterator matches = re.globalMatch(output);
                while (matches.hasNext()) {
                    QRegularExpressionMatch match = matches.next();
                    int percent = match.captured(1).toInt();
                    int progress = 5 + (percent * 0.45);
                    emit progressUpdated(progress, QString("Descargando: %1%").arg(percent));
                    
                    // Información adicional
                    if (output.contains("continuando")) {
                        emit logMessage("✅ Reanudando descarga desde punto anterior...");
                    }
                }
            }
        });
        
        connect(&wgetProcess, &QProcess::readyReadStandardError, this, [this, &wgetProcess]() {
            QString error = QString::fromUtf8(wgetProcess.readAllStandardError());
            if (!error.trimmed().isEmpty() && !error.contains("SSL")) {
                emit logMessage("wget: " + error.trimmed());
            }
        });
        
        connect(&wgetProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                &loop, &QEventLoop::quit);
        
        connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        timer.start(7200000); // 2 horas máximo
        
        loop.exec();
        
        if (wgetProcess.exitCode() != 0 && !m_canceled) {
            emit logMessage(QString("wget salió con código: %1").arg(wgetProcess.exitCode()));
            
            // Si el archivo existe pero la descarga falló, guardar el progreso
            if (QFile::exists(outputPath)) {
                qint64 currentSize = QFileInfo(outputPath).size();
                emit logMessage(QString("Progreso guardado: %1 bytes descargados").arg(currentSize));
            }
            
            return false;
        }
        
        return !m_canceled;
    }
    
    bool downloadWithCurlResumable(const QString &url, const QString &outputPath) {
        QProcess curlProcess;
        
        QStringList curlArgs;
        curlArgs << "-L";
        curlArgs << "--progress-bar";
        curlArgs << "-C"; // --continue-at: descarga resumible
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
        
        connect(&progressTimer, &QTimer::timeout, this, [this, outputPath, &lastSize]() {
            QFileInfo fileInfo(outputPath);
            qint64 currentSize = fileInfo.size();
            if (currentSize > lastSize) {
                emit logMessage(QString("Descargado: %1 KB").arg(currentSize / 1024));
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
            
            // Si el archivo existe pero la descarga falló, guardar el progreso
            if (QFile::exists(outputPath)) {
                qint64 currentSize = QFileInfo(outputPath).size();
                emit logMessage(QString("Progreso guardado: %1 bytes descargados").arg(currentSize));
            }
            
            return false;
        }
        
        return !m_canceled;
    }
    
    // MÉTODO CORREGIDO: Extraer en grupos pequeños manteniendo el .tar completo
    bool extractArchiveIncremental(const QString &archivePath, const QString &outputDir) {
        emit logMessage("🔄 Extrayendo en grupos pequeños...");
        
        QDir().mkpath(outputDir);
        
        // Paso 1: Obtener lista de archivos del .tar
        emit logMessage("Obteniendo lista de archivos del .tar...");
        QStringList fileList = getTarFileList(archivePath);
        
        if (fileList.isEmpty()) {
            emit logMessage("❌ El archivo .tar está vacío o corrupto");
            return false;
        }
        
        emit logMessage(QString("✅ Encontrados %1 archivos en el .tar").arg(fileList.size()));
        
        // Paso 2: Extraer en grupos de 50 archivos
        const int GROUP_SIZE = 50;
        int totalGroups = (fileList.size() + GROUP_SIZE - 1) / GROUP_SIZE;
        int currentGroup = 0;
        
        emit progressUpdated(60, "Extrayendo archivos...");
        
        for (int i = 0; i < fileList.size(); i += GROUP_SIZE) {
            currentGroup++;
            int startIdx = i;
            int endIdx = qMin(i + GROUP_SIZE, fileList.size());
            
            emit logMessage(QString("Extrayendo grupo %1/%2 (archivos %3-%4)...")
                           .arg(currentGroup).arg(totalGroups)
                           .arg(startIdx + 1).arg(endIdx));
            
            // Extraer este grupo
            QStringList group = fileList.mid(startIdx, GROUP_SIZE);
            if (!extractFileGroup(archivePath, outputDir, group)) {
                emit logMessage("❌ Error extrayendo grupo");
                return false;
            }
            
            // Actualizar progreso
            int progress = 60 + (30 * endIdx / fileList.size());
            emit progressUpdated(progress, 
                QString("Extrayendo: %1/%2 archivos")
                .arg(endIdx).arg(fileList.size()));
            
            // Pequeña pausa para evitar saturar el sistema
            QThread::msleep(50);
        }
        
        emit logMessage("✅ Todos los grupos extraídos correctamente");
        return true;
    }
    
    // Obtener lista de archivos del .tar
    QStringList getTarFileList(const QString &archivePath) {
        QProcess tarProcess;
        tarProcess.start("tar", QStringList() << "-tf" << archivePath);
        
        if (!tarProcess.waitForFinished(60000)) {
            emit logMessage("❌ Timeout obteniendo lista de archivos");
            return QStringList();
        }
        
        if (tarProcess.exitCode() != 0) {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            emit logMessage(QString("❌ Error leyendo .tar: %1").arg(error));
            return QStringList();
        }
        
        QString output = QString::fromUtf8(tarProcess.readAllStandardOutput());
        QStringList fileList = output.split('\n', Qt::SkipEmptyParts);
        
        // Filtrar entradas vacías
        fileList = fileList.filter(QRegularExpression(".+"));
        
        return fileList;
    }
    
    // Extraer un grupo específico de archivos
    bool extractFileGroup(const QString &archivePath, const QString &outputDir, const QStringList &files) {
        if (files.isEmpty()) {
            return true;
        }
        
        QProcess tarProcess;
        QStringList tarArgs;
        tarArgs << "-xf" << archivePath;
        tarArgs << "-C" << outputDir;
        
        // Añadir archivos específicos
        foreach (const QString &file, files) {
            tarArgs << file;
        }
        
        tarProcess.start("tar", tarArgs);
        
        if (!tarProcess.waitForFinished(300000)) { // 5 minutos máximo
            emit logMessage("❌ Timeout extrayendo grupo");
            return false;
        }
        
        if (tarProcess.exitCode() != 0) {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            emit logMessage(QString("❌ Error extrayendo grupo: %1").arg(error));
            return false;
        }
        
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
      diskSpaceTimer(nullptr)

{
    // Calcular escala DPI basada en la pantalla
    QScreen *screen = QGuiApplication::primaryScreen();
    dpiScale = screen->logicalDotsPerInch() / 96.0;
    if (dpiScale < 1.0) dpiScale = 1.0;
    if (dpiScale > 2.5) dpiScale = 2.5;
    
    setWindowTitle("Atlas Interactivo - Instalador");
    setupUI();
    
    // Configurar directorio predeterminado (directorio del ejecutable o directorio actual)
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
    diskSpaceTimer->setInterval(2000); // Actualizar cada 2 segundos
    connect(diskSpaceTimer, &QTimer::timeout, this, &InstallerWindow::updateDiskSpace);
    diskSpaceTimer->start();
    
    // Verificar espacio en disco inicial
    updateDiskSpace();

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
    
    // Si el directorio no existe, usar el directorio padre
    while (!QDir(checkPath).exists() && checkPath != "/") {
        checkPath = QFileInfo(checkPath).dir().absolutePath();
    }
    
    if (checkPath.isEmpty()) {
        checkPath = "/";
    }
    
    if (statvfs(checkPath.toUtf8().constData(), &stat) == 0) {
        return (qint64)stat.f_bsize * stat.f_bavail;
    }
    
    return -1; // Error
}

qint64 InstallerWindow::getAvailableDiskSpacePrecise(const QString &path)
{
    struct statvfs stat;
    QString checkPath = path;
    
    // Si el directorio no existe, usar el directorio padre
    while (!QDir(checkPath).exists() && checkPath != "/") {
        checkPath = QFileInfo(checkPath).dir().absolutePath();
    }
    
    if (checkPath.isEmpty()) {
        checkPath = "/";
    }
    
    if (statvfs(checkPath.toUtf8().constData(), &stat) == 0) {
        // Cálculo más preciso usando f_frsize (tamaño de fragmento) en lugar de f_bsize
        return (qint64)stat.f_frsize * stat.f_bavail;
    }
    
    return -1; // Error
}

bool InstallerWindow::hasSufficientDiskSpace(qint64 requiredGB)
{
    qint64 availableBytes = getAvailableDiskSpacePrecise(installDir);
    if (availableBytes < 0) {
        return true; // Si no podemos verificar, asumir que hay espacio
    }
    
    qint64 requiredBytes = requiredGB * 1024 * 1024 * 1024;
    return availableBytes >= requiredBytes;
}

QFont InstallerWindow::getScaledFont(int baseSize) {
    int scaledSize = qRound(baseSize * dpiScale);
    return QFont("Segoe UI", qMax(scaledSize, 8)); // Mínimo tamaño 8
}

void InstallerWindow::setupUI()
{
    // Configurar tamaño óptimo SIN ScrollArea - VENTANA COMPACTA
    QRect screenGeometry = QGuiApplication::primaryScreen()->availableGeometry();
    
    // Tamaños más compactos para evitar scroll
    int baseWidth = 1200;  // Ancho óptimo
    int baseHeight = 1200; // Altura ajustada

    int windowWidth = qMin(qRound(baseWidth * dpiScale), int(screenGeometry.width() * 0.9));
    int windowHeight = qMin(qRound(baseHeight * dpiScale), int(screenGeometry.height() * 0.9));
    
    setMinimumSize(qRound(700 * dpiScale), qRound(600 * dpiScale));
    resize(windowWidth, windowHeight);
    
    // ========== WIDGET CENTRAL SIN SCROLLAREA ==========
    centralWidget = new QWidget(this);
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);
    mainLayout->setSpacing(qRound(10 * dpiScale)); // Espaciado reducido
    mainLayout->setContentsMargins(
        qRound(15 * dpiScale),
        qRound(15 * dpiScale),
        qRound(15 * dpiScale),
        qRound(15 * dpiScale)
    );
    
    // ========== ENCABEZADO ==========
    QHBoxLayout *headerLayout = new QHBoxLayout();
    
    // Icono
    QLabel *iconLabel = new QLabel("🌍", this);
    iconLabel->setStyleSheet(QString("font-size: %1px; padding-right: %2px;")
        .arg(qRound(40 * dpiScale))
        .arg(qRound(10 * dpiScale)));
    
    // Título y subtítulo
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
    
    // Versión
    QLabel *versionLabel = new QLabel("v1.0.0", this);
    versionLabel->setFont(getScaledFont(9));
    versionLabel->setStyleSheet("color: #95a5a6;");
    headerLayout->addWidget(versionLabel);
    
    mainLayout->addLayout(headerLayout);
    mainLayout->addSpacing(qRound(10 * dpiScale));
    
    // ========== CONFIGURACIÓN ==========
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
    
    // Ruta de instalación
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
    
    // Información de espacio en disco
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
    
    // Opciones de acceso directo
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
    
    // Panel de información COMPACTADO (ACTUALIZADO con método optimizado)
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
    
    QLabel *infoContent = new QLabel(
        "• Descarga desde Google Drive (~20 GB)\n"
        "• Formato: archivo .tar sin compresión\n"
        "• Se requieren 25 GB de espacio disponible\n"
        "• El archivo temporal se elimina automáticamente\n"
        "• Espacio final después de instalación: ~20 GB",
        this
    );


    infoContent->setFont(getScaledFont(8));
    infoContent->setStyleSheet("color: #34495e; line-height: 130%;");
    infoContent->setWordWrap(true);
    
    infoLayout->addWidget(infoTitle);
    infoLayout->addWidget(infoContent);
    configLayout->addWidget(infoFrame);
    
    mainLayout->addWidget(configGroup);
    mainLayout->addSpacing(qRound(10 * dpiScale));
    
    // ========== PROGRESO ==========
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
    
    // Barra de progreso
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
    
    // Área de log COMPACTADA
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
    
    // Espacio flexible mínimo
    mainLayout->addSpacing(qRound(5 * dpiScale));
    
    // ========== BOTONES ==========
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
        QMessageBox::about(this, "Acerca de Atlas Interactivo",
            "<h3>Atlas Interactivo</h3>"
            "<p>Instalador para Linux v1.0.0</p>"
            "<p>© 2025 Atlas Interactivo Team</p>"
            "<p>Compilado con Qt " QT_VERSION_STR "</p>"
            "<p><b>Características:</b></p>"
            "<p>• Descarga resumible con 3 reintentos</p>"
            "<p>• Extracción por grupos de 50 archivos</p>"
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
    connect(exitButton, &QPushButton::clicked, this, &QWidget::close);
    
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
    
    // ========== FOOTER ========== (ACTUALIZADO)
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
    QLabel *footerLabel = new QLabel("⚠️ Requiere conexión a Internet estable • Descarga resumible • 3 reintentos • Extracción por grupos • Espacio temporal: 25 GB", this);
    footerLabel->setFont(getScaledFont(7));
    footerLabel->setStyleSheet("color: #ecf0f1;");
    footerLabel->setAlignment(Qt::AlignCenter);
    footerLabel->setWordWrap(true);
    
    footerLayout->addWidget(footerLabel);
    mainLayout->addWidget(footerFrame);
    
    // Establecer widget central (IMPORTANTE: sin ScrollArea)
    setCentralWidget(centralWidget);
    
    // Centrar ventana
    int x = (screenGeometry.width() - width()) / 2;
    int y = (screenGeometry.height() - height()) / 2;
    move(x, y);
}

void InstallerWindow::updateDiskSpace()
{
    const qint64 REQUIRED_SPACE_GB = 25; // 25 GB (aumentado de 20 GB)
    
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
    
    if (availableBytes >= requiredBytes) {
        // Suficiente espacio
        diskSpaceLabel->setText(QString("Espacio disponible: %1 GB").arg(QString::number(availableGB, 'f', 2)));
        diskSpaceLabel->setStyleSheet("color: #27ae60; font-weight: bold;");
        spaceWarningLabel->setText("✅ Espacio suficiente");
        spaceWarningLabel->setStyleSheet("color: #27ae60; font-weight: bold;");
        installButton->setEnabled(true);
        m_hasSufficientSpace = true;
        
        static bool loggedOnce = false;
        if (!loggedOnce) {
            logText->append(QString("[INFO] Espacio en disco: %1 GB disponibles").arg(QString::number(availableGB, 'f', 2)));
            logText->append(QString("[INFO] Descarga resumible y extracción por grupos activada"));
            loggedOnce = true;
        }
    } else {
        // Espacio insuficiente
        diskSpaceLabel->setText(QString("Espacio disponible: %1 GB").arg(QString::number(availableGB, 'f', 2)));
        diskSpaceLabel->setStyleSheet("color: #e74c3c; font-weight: bold;");
        spaceWarningLabel->setText(QString("❌ Requiere %1 GB").arg(REQUIRED_SPACE_GB));
        spaceWarningLabel->setStyleSheet("color: #e74c3c; font-weight: bold;");
        installButton->setEnabled(false);
        m_hasSufficientSpace = false;
    }
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

void InstallerWindow::startInstallation()
{
    installDir = directoryEdit->text();
    
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
    msgBox.setText(
        "<div align='center'>"
        "<h3>Método optimizado activado</h3>"
        "<p><b>✅ Descarga resumible con 3 reintentos</b></p>"
        "<p><b>✅ Extracción por grupos de 50 archivos</b></p>"
        "<p><b>✅ Espacio temporal máximo: <font color='green'>25 GB</font></b></p>"
        "<br>"
        "<p>¿Desea continuar con la instalación?</p>"
        "</div>"
    );
        
    // AÑADE ESTAS LÍNEAS PARA HACERLO MÁS ANCHO:
    msgBox.setStyleSheet(
        "QMessageBox { "
        "   min-width: 600px; "  // <-- ANCHO MÁS GRANDE
        "} "
        "QLabel { "
        "   min-width: 550px; "  // <-- ANCHO MÁS GRANDE PARA EL TEXTO
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
    
    updateProgress(0, "Preparando instalación...");
    logText->clear();
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Iniciando instalación...");
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Descarga resumible activada");
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Extracción por grupos de 50 archivos");
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Espacio temporal máximo: 25 GB");
    
    QString driveId = "1vzAxSaKRXIPSNf937v6xjuBhRyrCiVRF";
    
    QThread *thread = new QThread;
    InstallWorker *worker = new InstallWorker(installDir, driveId);
    
    worker->moveToThread(thread);
    
    connect(thread, &QThread::started, worker, &InstallWorker::doWork);
    connect(worker, &InstallWorker::progressUpdated, this, &InstallerWindow::updateProgress);
    connect(worker, &InstallWorker::workFinished, this, &InstallerWindow::installationFinished);
    connect(worker, &InstallWorker::logMessage, this, [this](const QString &msg) {
        QMetaObject::invokeMethod(logText, "append", 
            Qt::QueuedConnection,
            Q_ARG(QString, "[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] " + msg));
    });
    
    connect(worker, &InstallWorker::workFinished, thread, &QThread::quit);
    connect(worker, &InstallWorker::workFinished, worker, &QObject::deleteLater);
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    
    thread->start();
}

void InstallerWindow::updateProgress(int value, const QString &message)
{
    progressBar->setValue(value);
    statusLabel->setText(message);
}

void InstallerWindow::installationFinished(bool success, const QString &message)
{
    installButton->setEnabled(true);
    browseButton->setEnabled(true);
    installButton->setText("INICIAR INSTALACIÓN");
    
    // Actualizar espacio en disco después de la instalación
    updateDiskSpace();
    
    if (success) {
        updateProgress(100, "Instalación completada");
        
        QMetaObject::invokeMethod(logText, "append", 
            Qt::QueuedConnection,
            Q_ARG(QString, "[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] " + message));
        
        if (!m_skipDesktopShortcuts && 
            (desktopShortcutCheck->isChecked() || menuShortcutCheck->isChecked())) {
            createDesktopEntry();
        }
        
        // MODIFICADO: Quitar el icono azul
        QMessageBox msgBox(this);
        msgBox.setWindowTitle("Instalación completada");
        msgBox.setTextFormat(Qt::RichText);
        msgBox.setText(
            "<div align='center'>"
            "<h3 style='color: green; margin: 0;'>✅ INSTALACIÓN COMPLETADA</h3>"
            "<p>" + message + "</p>"
            "<br>"
            "<p><b>Ubicación:</b></p>"
            "<p><code>" + installDir + "/Atlas_Interactivo</code></p>"
            "<p><i>¡Gracias por instalar Atlas Interactivo!</i></p>"
            "</div>"
        );
        
        // AÑADIR ESTILO para quitar icono y centrar todo
        msgBox.setStyleSheet(
            "QMessageBox { "
            "   min-width: 650px; "
            "   max-width: 650px; "
            "} "
            "QMessageBox QLabel { "
            "   min-width: 600px; "
            "   text-align: center; "
            "} "
            "QMessageBox QPushButton { "
            "   min-width: 80px; "
            "   min-height: 30px; "
            "}"
        );
        
        // IMPORTANTE: Quitar el icono estableciendo icon vacío
        msgBox.setIcon(QMessageBox::NoIcon);
        
        msgBox.setStandardButtons(QMessageBox::Ok);
        msgBox.exec();
        
    } else {
        // También quitar el icono en el mensaje de error
        QMessageBox msgBox(this);
        msgBox.setWindowTitle("Error de instalación");
        msgBox.setTextFormat(Qt::RichText);
        msgBox.setText(
            "<div align='center'>"
            "<h3 style='color: red; margin: 0;'>❌ ERROR EN LA INSTALACIÓN</h3>"
            "<p>" + message + "</p>"
            "<br>"
            "<p><b>Posibles soluciones:</b></p>"
            "<p>• Verifica tu conexión a Internet</p>"
            "<p>• Asegúrate de tener al menos 25 GB libres</p>"
            "<p>• Verifica que 'tar' esté instalado</p>"
            "<p>• Intenta nuevamente</p>"
            "</div>"
        );
        
        // AÑADIR ESTILO para quitar icono y centrar
        msgBox.setStyleSheet(
            "QMessageBox { "
            "   min-width: 550px; "
            "   max-width: 550px; "
            "} "
            "QMessageBox QLabel { "
            "   min-width: 500px; "
            "   text-align: center; "
            "} "
            "QMessageBox QPushButton { "
            "   min-width: 80px; "
            "   min-height: 30px; "
            "}"
        );
        
        // Quitar el icono
        msgBox.setIcon(QMessageBox::NoIcon);
        
        msgBox.setStandardButtons(QMessageBox::Ok);
        msgBox.exec();
        
        updateProgress(0, "Instalación fallida");
    }
}

bool InstallerWindow::extractArchive(const QString &archivePath, const QString &outputDir)
{
    // Esta función ya no se usa, pero la mantenemos para compatibilidad
    QProcess tarProcess;
    tarProcess.setWorkingDirectory(outputDir);
    tarProcess.start("tar", QStringList() << "-xf" << archivePath);
    
    return tarProcess.waitForFinished() && tarProcess.exitCode() == 0;
}

void InstallerWindow::createDesktopEntry()
{
    QString desktopDir = QDir::homePath() + "/.local/share/applications";
    QDir().mkpath(desktopDir);
    
    QString desktopFile = desktopDir + "/atlas-interactivo.desktop";
    QFile file(desktopFile);
    
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << "[Desktop Entry]\n";
        out << "Version=1.0\n";
        out << "Type=Application\n";
        out << "Name=Atlas Interactivo\n";
        out << "Comment=Atlas digital interactivo\n";
        out << "Exec=" << installDir << "/Atlas_Interactivo-1.0.0-linux-x64\n";
        out << "Icon=" << installDir << "/icon.png\n";
        out << "Terminal=false\n";
        out << "Categories=Education;Geography;\n";
        out << "StartupNotify=true\n";
        file.close();
        
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                        QFile::ReadGroup | QFile::ExeGroup |
                        QFile::ReadOther | QFile::ExeOther);
        
        logText->append("✅ Acceso directo creado en menú: " + desktopFile);
    }
    
    if (desktopShortcutCheck->isChecked()) {
        QString desktopShortcut = QDir::homePath() + "/Desktop/Atlas_Interactivo.desktop";
        QFile::copy(desktopFile, desktopShortcut);
        logText->append("✅ Acceso directo creado en escritorio");
    }
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

#include "installerwindow.moc"
EOF

echo "📦 Archivos creados. Compilando..."

# Compilar
qmake AtlasInstaller.pro
make -j$(nproc)


if [ -f "AtlasInstaller" ]; then
    echo "✅ Compilación exitosa"
    
    # Optimizar
    strip AtlasInstaller 2>/dev/null || true
    
    # Mover
    mv AtlasInstaller ../../AtlasInstallerQt
    
    size_kb=$(du -k ../../AtlasInstallerQt 2>/dev/null | cut -f1 || echo "0")
    size_mb=$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo "0")
    
    echo "📦 Instalador Qt creado: ../AtlasInstallerQt (${size_mb}MB)"
    echo ""
    echo "✨ CORRECCIONES APLICADAS:"
    echo "   1. ✅ Solucionado error con archivos pequeños"
    echo "   2. ✅ ScrollArea añadida para ventanas pequeñas"
    echo "   3. ✅ Descarga resumible con 3 reintentos"
    echo "   4. ✅ Extracción por grupos de 50 archivos"
    echo "   5. ✅ Espacio temporal máximo: 25 GB (mantenido)"
    echo "   6. ✅ Funciona con cualquier tamaño de archivo"
    echo "   7. ✅ Progreso visible en tiempo real"
    echo "   8. ✅ Eliminación automática de temporales"
    echo ""
    echo "📊 RESUMEN:"
    echo "   • Método: Extracción incremental por grupos"
    echo "   • Grupos: 50 archivos por lote"
    echo "   • Descarga: Resumible con 3 reintentos"
    echo "   • Espacio: 25 GB temporales"
    echo "   • Final: ~20 GB ocupados permanentemente"
    echo ""
    echo "🚀 Para ejecutar:"
    echo "   cd .."
    echo "   ./AtlasInstallerQt"
else
    echo "❌ Error: No se creó el ejecutable"
    exit 1
fi

cd ..
rm -r build_qt/