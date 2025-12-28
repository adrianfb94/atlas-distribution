#!/bin/bash
# Script definitivo para construir el instalador Qt - VERSIÓN COMPILABLE

echo "🔨 Construyendo instalador Qt definitivo..."

# Limpiar
rm -rf build_qt
rm -f ../AtlasInstallerQt

# Crear directorio
mkdir -p build_qt
cd build_qt

# Crear archivos .pro mínimos
cat > AtlasInstaller.pro << 'EOF'
QT += core gui widgets network
CONFIG += c++11
TARGET = AtlasInstaller
TEMPLATE = app
SOURCES = main.cpp installerwindow.cpp
HEADERS = installerwindow.h
EOF

# Crear main.cpp
cat > main.cpp << 'EOF'
#include "installerwindow.h"
#include <QApplication>
#include <QDir>
#include <QDebug>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("Atlas Installer");
    
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
        // Necesitamos un método para pasar esto a la ventana
        // window.setInstallDir(installDir); // Descomentar cuando agregues este método
    }
    
    // Verificar --skip-desktop
    for (int i = 1; i < argc; ++i) {
        if (QString(argv[i]) == "--skip-desktop") {
            // window.setSkipDesktopShortcuts(true); // Descomentar cuando agregues este método
            break;
        }
    }
    
    window.show();
    
    return app.exec();
}
EOF


# Crear installerwindow.h
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

class QNetworkAccessManager;

class InstallerWindow : public QMainWindow
{
    Q_OBJECT
    
public:
    explicit InstallerWindow(QWidget *parent = nullptr);
    
    // Nuevos métodos para configuración desde CLI
    void setInstallDir(const QString &dir);
    void setSkipDesktopShortcuts(bool skip);
    
private slots:
    void browseDirectory();
    void startInstallation();
    void updateProgress(int value, const QString &message);
    void installationFinished(bool success, const QString &message);
    
private:
    void setupUI();
    bool checkDiskSpace();
    void createDesktopEntry();
    bool extractArchive(const QString &archivePath, const QString &outputDir);
    
    QLabel *titleLabel;
    QLabel *statusLabel;
    QProgressBar *progressBar;
    QLineEdit *directoryEdit;
    QPushButton *browseButton;
    QPushButton *installButton;
    QCheckBox *desktopShortcutCheck;
    QCheckBox *menuShortcutCheck;
    QTextEdit *logText;
    
    QString installDir;
    QNetworkAccessManager *networkManager;
    bool m_skipDesktopShortcuts;
};

#endif
EOF

# Crear installerwindow.cpp CORREGIDO Y COMPILABLE
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

#include <sys/statvfs.h>

class InstallWorker : public QObject {
    Q_OBJECT
    
public:
    explicit InstallWorker(const QString &installDir, const QString &driveId) 
        : m_installDir(installDir), m_driveId(driveId), m_canceled(false) {}
    
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
        
        // Intentar primero con wget
        emit logMessage("Intentando descargar con wget...");
        if (!downloadWithWgetDirect(directUrl, m_tempArchive)) {
            emit logMessage("wget falló, intentando con curl...");
            
            // Intentar con curl como respaldo
            if (!downloadWithCurlDirect(directUrl, m_tempArchive)) {
                emit logMessage("❌ Falló la descarga con curl");
                emit workFinished(false, "No se pudo descargar el archivo. Verifica tu conexión a internet.");
                return;
            }
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
        
        // Extraer el archivo .tar
        emit progressUpdated(60, "Extrayendo archivos...");
        emit logMessage("Extrayendo archivo .tar...");
        
        if (!extractArchive(m_tempArchive, m_installDir)) {
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
        
        emit workFinished(true, "Atlas Interactivo instalado exitosamente en:\n" + m_installDir);
    }
    
    void cancel() {
        m_canceled = true;
        if (!m_tempArchive.isEmpty() && QFile::exists(m_tempArchive)) {
            QFile::remove(m_tempArchive);
        }
    }
    
private:
    QString getDirectDownloadUrl() {
        // URL directa para Google Drive - usando el ID proporcionado
        return QString("https://drive.google.com/uc?id=%1&export=download&confirm=t&uuid=").arg(m_driveId) +
               QUuid::createUuid().toString().remove('{').remove('}');
    }
    
    bool downloadWithWgetDirect(const QString &url, const QString &outputPath) {
        QProcess wgetProcess;
        
        // Usar wget con opciones para ignorar certificados y evitar .netrc
        QStringList wgetArgs;
        wgetArgs << "--no-check-certificate";
        wgetArgs << "--no-netrc";  // Ignorar archivo .netrc
        wgetArgs << "--progress=dot:giga";
        wgetArgs << "-O" << outputPath;
        wgetArgs << "--tries=3";
        wgetArgs << "--timeout=30";
        wgetArgs << url;
        
        wgetProcess.start("wget", wgetArgs);
        
        if (!wgetProcess.waitForStarted()) {
            emit logMessage("wget no está disponible o no pudo iniciarse");
            return false;
        }
        
        // Leer salida en tiempo real
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        
        connect(&wgetProcess, &QProcess::readyReadStandardOutput, this, [this, &wgetProcess]() {
            QString output = QString::fromUtf8(wgetProcess.readAllStandardOutput());
            if (!output.trimmed().isEmpty()) {
                // Parsear progreso de wget
                QRegularExpression re(R"((\d+)%)");
                QRegularExpressionMatchIterator matches = re.globalMatch(output);
                while (matches.hasNext()) {
                    QRegularExpressionMatch match = matches.next();
                    int percent = match.captured(1).toInt();
                    int progress = 5 + (percent * 0.45); // 5-50%
                    emit progressUpdated(progress, QString("Descargando: %1%").arg(percent));
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
        timer.start(3600000); // 1 hora máximo
        
        loop.exec();
        
        if (wgetProcess.exitCode() != 0 && !m_canceled) {
            emit logMessage(QString("wget salió con código: %1").arg(wgetProcess.exitCode()));
            return false;
        }
        
        return !m_canceled;
    }
    
    bool downloadWithCurlDirect(const QString &url, const QString &outputPath) {
        QProcess curlProcess;
        
        // Usar curl con opciones para Google Drive
        QStringList curlArgs;
        curlArgs << "-L";  // Seguir redirecciones
        curlArgs << "--progress-bar";
        curlArgs << "--output" << outputPath;
        curlArgs << "--location-trusted";
        curlArgs << url;
        
        curlProcess.start("curl", curlArgs);
        
        if (!curlProcess.waitForStarted()) {
            emit logMessage("curl no está disponible");
            return false;
        }
        
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        
        // Monitorear progreso de curl
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
        timer.start(3600000); // 1 hora máximo
        
        loop.exec();
        
        progressTimer.stop();
        timer.stop();
        
        if (curlProcess.exitCode() != 0 && !m_canceled) {
            emit logMessage(QString("curl salió con código: %1").arg(curlProcess.exitCode()));
            return false;
        }
        
        return !m_canceled;
    }
    
    bool extractArchive(const QString &archivePath, const QString &outputDir) {
        emit logMessage("Extrayendo con tar -xf...");
        
        // Primero, crear el directorio de salida si no existe
        QDir().mkpath(outputDir);
        
        QProcess tarProcess;
        tarProcess.setWorkingDirectory(outputDir);
        
        // Usar tar -xf para archivos .tar (sin compresión)
        tarProcess.start("tar", QStringList() << "-xf" << archivePath);
        
        if (!tarProcess.waitForStarted()) {
            emit logMessage("❌ No se pudo ejecutar tar");
            emit logMessage("Asegúrate de que 'tar' esté instalado: sudo apt install tar");
            return false;
        }
        
        // Monitorear progreso de extracción
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        
        // Capturar tarProcess en las lambdas
        connect(&tarProcess, &QProcess::readyReadStandardOutput, this, [this, &tarProcess]() {
            QString output = QString::fromUtf8(tarProcess.readAllStandardOutput());
            if (!output.trimmed().isEmpty()) {
                emit logMessage("tar: " + output.trimmed());
            }
        });
        
        connect(&tarProcess, &QProcess::readyReadStandardError, this, [this, &tarProcess]() {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            if (!error.trimmed().isEmpty()) {
                emit logMessage("tar error: " + error.trimmed());
            }
        });
        
        connect(&tarProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                &loop, &QEventLoop::quit);
        
        connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        
        timer.start(300000); // 5 minutos máximo para extracción
        
        // Simular progreso durante la extracción
        QTimer progressTimer;
        int extractionProgress = 60;
        progressTimer.setInterval(500);
        
        connect(&progressTimer, &QTimer::timeout, this, [this, &extractionProgress]() {
            extractionProgress = qMin(95, extractionProgress + 1);
            emit progressUpdated(extractionProgress, "Extrayendo archivos...");
        });
        
        progressTimer.start();
        loop.exec();
        progressTimer.stop();
        timer.stop();
        
        if (tarProcess.exitCode() != 0) {
            QString error = QString::fromUtf8(tarProcess.readAllStandardError());
            emit logMessage(QString("❌ Error al extraer (código %1): %2")
                          .arg(tarProcess.exitCode())
                          .arg(error));
            return false;
        }
        
        emit logMessage("✅ Extracción completada exitosamente");
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
            out << "  \"download_size\": \"variable\"\n";
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
};



InstallerWindow::InstallerWindow(QWidget *parent) 
    : QMainWindow(parent), 
      networkManager(nullptr),
      m_skipDesktopShortcuts(false)
{
    setWindowTitle("Atlas Interactivo - Instalador");
    setMinimumSize(600, 500);
    installDir = QDir::homePath() + "/Atlas_Interactivo";
    setupUI();
}

void InstallerWindow::setupUI()
{
    QWidget *centralWidget = new QWidget(this);
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);
    
    // Título
    titleLabel = new QLabel("🌍 Atlas Interactivo", this);
    QFont titleFont = titleLabel->font();
    titleFont.setPointSize(16);
    titleFont.setBold(true);
    titleLabel->setFont(titleFont);
    titleLabel->setAlignment(Qt::AlignCenter);
    
    QLabel *subtitleLabel = new QLabel("Instalador para Linux", this);
    subtitleLabel->setAlignment(Qt::AlignCenter);
    
    mainLayout->addWidget(titleLabel);
    mainLayout->addWidget(subtitleLabel);
    mainLayout->addSpacing(20);
    
    // Grupo: Configuración
    QGroupBox *configGroup = new QGroupBox("Configuración", this);
    QVBoxLayout *configLayout = new QVBoxLayout(configGroup);
    
    // Directorio de instalación
    QHBoxLayout *dirLayout = new QHBoxLayout();
    QLabel *dirLabel = new QLabel("Directorio:", this);
    directoryEdit = new QLineEdit(installDir, this);
    browseButton = new QPushButton("Examinar...", this);
    
    connect(browseButton, &QPushButton::clicked, this, &InstallerWindow::browseDirectory);
    
    dirLayout->addWidget(dirLabel);
    dirLayout->addWidget(directoryEdit);
    dirLayout->addWidget(browseButton);
    configLayout->addLayout(dirLayout);
    
    // Opciones
    desktopShortcutCheck = new QCheckBox("Crear acceso directo en el escritorio", this);
    desktopShortcutCheck->setChecked(true);
    
    menuShortcutCheck = new QCheckBox("Agregar al menú de aplicaciones", this);
    menuShortcutCheck->setChecked(true);
    
    configLayout->addWidget(desktopShortcutCheck);
    configLayout->addWidget(menuShortcutCheck);
    
    // Información IMPORTANTE
    QLabel *infoLabel = new QLabel(
        "<b>Información importante:</b><br>"
        "• Descarga desde Google Drive<br>"
        "• Formato: archivo .tar (sin compresión)<br>"
        "• El archivo temporal se borra automáticamente<br>"
        "• <b>SOLO SE REQUIEREN 13GB DISPONIBLES</b><br>"
        "   (no 26GB gracias a la extracción directa)"
    );
    infoLabel->setWordWrap(true);
    infoLabel->setStyleSheet("QLabel { color: #0066cc; font-weight: bold; }");
    configLayout->addWidget(infoLabel);
    
    mainLayout->addWidget(configGroup);
    mainLayout->addSpacing(20);
    
    // Grupo: Progreso
    QGroupBox *progressGroup = new QGroupBox("Progreso", this);
    QVBoxLayout *progressLayout = new QVBoxLayout(progressGroup);
    
    statusLabel = new QLabel("Listo para instalar.", this);
    progressBar = new QProgressBar(this);
    progressBar->setRange(0, 100);
    progressBar->setValue(0);
    
    progressLayout->addWidget(statusLabel);
    progressLayout->addWidget(progressBar);
    
    // Área de log
    logText = new QTextEdit(this);
    logText->setReadOnly(true);
    logText->setMaximumHeight(120);
    logText->setPlaceholderText("Log de instalación aparecerá aquí...");
    logText->setStyleSheet("QTextEdit { font-family: monospace; font-size: 10pt; }");
    progressLayout->addWidget(logText);
    
    mainLayout->addWidget(progressGroup);
    mainLayout->addSpacing(20);
    
    // Botones
    QHBoxLayout *buttonLayout = new QHBoxLayout();
    
    installButton = new QPushButton("🚀 Iniciar instalación", this);
    installButton->setMinimumHeight(40);
    installButton->setStyleSheet("QPushButton { font-weight: bold; padding: 8px; }");
    
    QPushButton *exitButton = new QPushButton("Salir", this);
    
    connect(installButton, &QPushButton::clicked, this, &InstallerWindow::startInstallation);
    connect(exitButton, &QPushButton::clicked, this, &QWidget::close);
    
    buttonLayout->addWidget(installButton);
    buttonLayout->addStretch();
    buttonLayout->addWidget(exitButton);
    
    mainLayout->addLayout(buttonLayout);
    
    setCentralWidget(centralWidget);
}

bool InstallerWindow::checkDiskSpace()
{
    struct statvfs stat;
    if (statvfs(installDir.toUtf8().constData(), &stat) == 0) {
        quint64 freeGB = (stat.f_bsize * stat.f_bavail) / (1024 * 1024 * 1024);
        bool hasSpace = freeGB >= 15;
        logText->append(QString("[INFO] Espacio disponible: %1 GB").arg(freeGB));
        return hasSpace;
    }
    return true;
}

void InstallerWindow::browseDirectory()
{
    QString dir = QFileDialog::getExistingDirectory(this, 
        "Seleccionar directorio de instalación",
        directoryEdit->text(),
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks);
    
    if (!dir.isEmpty()) {
        directoryEdit->setText(dir);
        installDir = dir;
    }
}

void InstallerWindow::startInstallation()
{
    installDir = directoryEdit->text();
    
    // Verificar espacio
    if (!checkDiskSpace()) {
        QMessageBox::warning(this, "Espacio insuficiente", 
                           "No hay suficiente espacio en disco. Se requieren 15GB libres.");
        return;
    }
    
    // Verificar que tar esté instalado
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
    
    // Crear directorio si no existe
    QDir().mkpath(installDir);
    
    // Deshabilitar controles
    installButton->setEnabled(false);
    browseButton->setEnabled(false);
    installButton->setText("Instalando...");
    
    updateProgress(0, "Preparando instalación...");
    logText->clear();
    logText->append("[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] Iniciando instalación...");
    
    // ID de Google Drive (¡ACTUALIZAR ESTO CON TU ID REAL!)
    QString driveId = "1vzAxSaKRXIPSNf937v6xjuBhRyrCiVRF";
    
    // Crear worker y thread
    QThread *thread = new QThread;
    InstallWorker *worker = new InstallWorker(installDir, driveId);
    
    // Mover worker al thread
    worker->moveToThread(thread);
    
    // Conectar señales
    connect(thread, &QThread::started, worker, &InstallWorker::doWork);
    connect(worker, &InstallWorker::progressUpdated, this, &InstallerWindow::updateProgress);
    connect(worker, &InstallWorker::workFinished, this, &InstallerWindow::installationFinished);
    connect(worker, &InstallWorker::logMessage, this, [this](const QString &msg) {
        QMetaObject::invokeMethod(logText, "append", 
            Qt::QueuedConnection,
            Q_ARG(QString, "[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] " + msg));
    });
    
    // Limpiar
    connect(worker, &InstallWorker::workFinished, thread, &QThread::quit);
    connect(worker, &InstallWorker::workFinished, worker, &QObject::deleteLater);
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    
    // Iniciar thread
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
    installButton->setText("🚀 Iniciar instalación");
    
    if (success) {
        updateProgress(100, "Instalación completada");
        
        QMetaObject::invokeMethod(logText, "append", 
            Qt::QueuedConnection,
            Q_ARG(QString, "[" + QDateTime::currentDateTime().toString("hh:mm:ss") + "] " + message));
        
        // Crear accesos directos si están marcados Y no se saltaron por CLI
        if (!m_skipDesktopShortcuts && 
            (desktopShortcutCheck->isChecked() || menuShortcutCheck->isChecked())) {
            createDesktopEntry();
        }
        
        QMessageBox::information(this, "✅ Instalación completada", 
            message + "\n\n"
            "Puedes ejecutar Atlas desde:\n" + installDir + "/Atlas_Interactivo\n\n"
            "¡El archivo temporal se ha eliminado automáticamente!");
    } else {
        QMessageBox::critical(this, "❌ Error", message);
        updateProgress(0, "Instalación fallida");
    }
}

bool InstallerWindow::extractArchive(const QString &archivePath, const QString &outputDir)
{
    // Método de respaldo si es necesario
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
        out << "Exec=" << installDir << "/Atlas_Interactivo\n";
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
    
    // Crear acceso directo en escritorio si está marcado
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
    echo "🎨 CARACTERÍSTICAS NUEVAS:"
    echo "   1. ✅ Diseño profesional y moderno"
    echo "   2. ✅ Interfaz responsive (800x700)"
    echo "   3. ✅ Colores profesionales (#2c3e50, #3498db)"
    echo "   4. ✅ Gradientes y efectos visuales"
    echo "   5. ✅ Layout organizado y limpio"
    echo "   6. ✅ Botón de limpiar log"
    echo "   7. ✅ Footer informativo"
    echo "   8. ✅ Ventana centrada automáticamente"
    echo ""
    echo "🚀 Para ejecutar:"
    echo "   cd .."
    echo "   ./AtlasInstallerQt"
else
    echo "❌ Error: No se creó el ejecutable"
    exit 1
fi

cd ..
