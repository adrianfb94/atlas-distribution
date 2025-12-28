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
#include <QGuiApplication>  // ¡AÑADIDO!
#include <QScreen>          // ¡AÑADIDO!

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
    // Configurar ventana principal
    setWindowTitle("Atlas Interactivo • Instalador para Linux");
    setMinimumSize(800, 700);
    setStyleSheet(R"(
        QMainWindow {
            background-color: #f5f7fa;
        }
        
        QGroupBox {
            font-weight: bold;
            font-size: 14px;
            border: 1px solid #d1d9e6;
            border-radius: 10px;
            margin-top: 10px;
            padding-top: 10px;
            background-color: white;
        }
        
        QGroupBox::title {
            subcontrol-origin: margin;
            left: 10px;
            padding: 0 10px 0 10px;
            color: #2c3e50;
        }
        
        QPushButton {
            background-color: #3498db;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            font-weight: bold;
            font-size: 13px;
            min-width: 120px;
        }
        
        QPushButton:hover {
            background-color: #2980b9;
        }
        
        QPushButton:pressed {
            background-color: #1c6ea4;
        }
        
        QPushButton:disabled {
            background-color: #95a5a6;
        }
        
        QLineEdit {
            padding: 10px;
            border: 2px solid #d1d9e6;
            border-radius: 6px;
            font-size: 13px;
            background-color: white;
        }
        
        QLineEdit:focus {
            border-color: #3498db;
        }
        
        QProgressBar {
            border: 2px solid #d1d9e6;
            border-radius: 6px;
            text-align: center;
            font-weight: bold;
            height: 25px;
        }
        
        QProgressBar::chunk {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #3498db, stop:1 #2980b9);
            border-radius: 4px;
        }
        
        QTextEdit {
            border: 1px solid #d1d9e6;
            border-radius: 6px;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 11px;
            background-color: #1a1a2e;
            color: #e0e0e0;
            padding: 5px;
        }
        
        QCheckBox {
            spacing: 8px;
            font-size: 13px;
        }
        
        QCheckBox::indicator {
            width: 18px;
            height: 18px;
        }
    )");
    
    // Widget central
    QWidget *centralWidget = new QWidget(this);
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);
    mainLayout->setSpacing(15);
    mainLayout->setContentsMargins(25, 25, 25, 25);
    
    // Encabezado con icono
    QHBoxLayout *headerLayout = new QHBoxLayout();
    QLabel *iconLabel = new QLabel("🌍", this);
    iconLabel->setStyleSheet("font-size: 40px; padding-right: 15px;");
    
    QVBoxLayout *titleLayout = new QVBoxLayout();
    titleLabel = new QLabel("ATLAS INTERACTIVO", this);
    titleLabel->setStyleSheet("color: #2c3e50; font-size: 28px; font-weight: bold;");
    
    subtitleLabel = new QLabel("Instalador Oficial para Linux", this);
    subtitleLabel->setStyleSheet("color: #7f8c8d; font-size: 14px;");
    
    titleLayout->addWidget(titleLabel);
    titleLayout->addWidget(subtitleLabel);
    
    headerLayout->addWidget(iconLabel);
    headerLayout->addLayout(titleLayout);
    headerLayout->addStretch();
    
    QLabel *versionLabel = new QLabel("v1.0.0", this);
    versionLabel->setStyleSheet("color: #95a5a6; font-size: 12px;");
    headerLayout->addWidget(versionLabel);
    
    mainLayout->addLayout(headerLayout);
    mainLayout->addSpacing(20);
    
    // Sección de configuración
    QGroupBox *configGroup = new QGroupBox("⚙️  CONFIGURACIÓN DE INSTALACIÓN", this);
    QVBoxLayout *configLayout = new QVBoxLayout(configGroup);
    configLayout->setSpacing(15);
    
    // Ruta de instalación
    QHBoxLayout *dirLayout = new QHBoxLayout();
    QLabel *dirLabel = new QLabel("Ubicación:", this);
    dirLabel->setMinimumWidth(80);
    dirLabel->setStyleSheet("font-weight: bold;");
    
    directoryEdit = new QLineEdit(installDir, this);
    directoryEdit->setStyleSheet("QLineEdit { padding: 12px; }");
    
    browseButton = new QPushButton("📁 Examinar", this);
    browseButton->setFixedWidth(120);
    
    connect(browseButton, &QPushButton::clicked, this, &InstallerWindow::browseDirectory);
    
    dirLayout->addWidget(dirLabel);
    dirLayout->addWidget(directoryEdit, 1);
    dirLayout->addWidget(browseButton);
    configLayout->addLayout(dirLayout);
    
    // Opciones de acceso directo
    QHBoxLayout *shortcutLayout = new QHBoxLayout();
    desktopShortcutCheck = new QCheckBox("Crear acceso en escritorio", this);
    desktopShortcutCheck->setChecked(true);
    
    menuShortcutCheck = new QCheckBox("Agregar al menú de aplicaciones", this);
    menuShortcutCheck->setChecked(true);
    
    shortcutLayout->addWidget(desktopShortcutCheck);
    shortcutLayout->addWidget(menuShortcutCheck);
    configLayout->addLayout(shortcutLayout);
    
    // Panel de información
    QFrame *infoFrame = new QFrame(this);
    infoFrame->setStyleSheet(R"(
        QFrame {
            background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 #e3f2fd, stop:1 #f3e5f5);
            border-left: 4px solid #3498db;
            border-radius: 8px;
            padding: 15px;
        }
    )");
    
    QVBoxLayout *infoLayout = new QVBoxLayout(infoFrame);
    QLabel *infoTitle = new QLabel("ℹ️  INFORMACIÓN IMPORTANTE", this);
    infoTitle->setStyleSheet("font-weight: bold; color: #2c3e50; font-size: 13px;");
    
    QLabel *infoContent = new QLabel(
        "• Descarga directa desde Google Drive (13 GB)\n"
        "• Formato optimizado: archivo .tar sin compresión\n"
        "• El archivo temporal se elimina automáticamente\n"
        "• Solo requiere 13 GB de espacio disponible\n"
        "• Extracción directa: no necesita espacio adicional\n"
        "• Verificación SHA256 automática de todos los archivos",
        this
    );
    infoContent->setStyleSheet("color: #34495e; line-height: 140%;");
    
    infoLayout->addWidget(infoTitle);
    infoLayout->addWidget(infoContent);
    configLayout->addWidget(infoFrame);
    
    mainLayout->addWidget(configGroup);
    mainLayout->addSpacing(20);
    
    // Sección de progreso
    QGroupBox *progressGroup = new QGroupBox("📊 PROGRESO DE INSTALACIÓN", this);
    QVBoxLayout *progressLayout = new QVBoxLayout(progressGroup);
    progressLayout->setSpacing(10);
    
    // Barra de progreso con etiqueta
    QHBoxLayout *progressHeader = new QHBoxLayout();
    QLabel *progressTitle = new QLabel("Progreso:", this);
    progressTitle->setStyleSheet("font-weight: bold;");
    
    statusLabel = new QLabel("Listo para comenzar la instalación", this);
    statusLabel->setStyleSheet("font-size: 13px; color: #34495e; padding: 5px;");
    
    progressHeader->addWidget(progressTitle);
    progressHeader->addStretch();
    progressHeader->addWidget(statusLabel);
    progressLayout->addLayout(progressHeader);
    
    progressBar = new QProgressBar(this);
    progressBar->setTextVisible(true);
    progressBar->setFormat("%p%");
    progressLayout->addWidget(progressBar);
    
    // Área de log mejorada
    QFrame *logFrame = new QFrame(this);
    logFrame->setStyleSheet(R"(
        QFrame {
            background-color: #1a1a2e;
            border-radius: 6px;
            padding: 5px;
        }
    )");
    
    QVBoxLayout *logLayout = new QVBoxLayout(logFrame);
    QHBoxLayout *logHeader = new QHBoxLayout();
    QLabel *logTitle = new QLabel("📝 REGISTRO DE INSTALACIÓN", this);
    logTitle->setStyleSheet("color: #ffffff; font-weight: bold; font-size: 12px;");
    
    QPushButton *clearLogButton = new QPushButton("Limpiar", this);
    clearLogButton->setStyleSheet(R"(
        QPushButton {
            background-color: #6c757d;
            color: white;
            border: none;
            padding: 5px 15px;
            border-radius: 3px;
            font-size: 11px;
        }
        QPushButton:hover {
            background-color: #5a6268;
        }
    )");
    connect(clearLogButton, &QPushButton::clicked, [this]() {
        logText->clear();
    });
    
    logHeader->addWidget(logTitle);
    logHeader->addStretch();
    logHeader->addWidget(clearLogButton);
    logLayout->addLayout(logHeader);
    
    logText = new QTextEdit(this);
    logText->setMaximumHeight(150);
    logText->setPlaceholderText("Aquí aparecerán los detalles de la instalación...");
    logLayout->addWidget(logText);
    
    progressLayout->addWidget(logFrame);
    mainLayout->addWidget(progressGroup);
    mainLayout->addSpacing(20);
    
    // Barra de botones
    QHBoxLayout *buttonLayout = new QHBoxLayout();
    
    QPushButton *aboutButton = new QPushButton("ℹ️  Acerca de", this);
    aboutButton->setStyleSheet("QPushButton { background-color: #6c757d; }");
    connect(aboutButton, &QPushButton::clicked, [this]() {
        QMessageBox::about(this, "Acerca de Atlas Interactivo",
            "<h3>Atlas Interactivo</h3>"
            "<p>Instalador para Linux v1.0.0</p>"
            "<p>© 2024 Atlas Interactivo Team</p>"
            "<p>Compilado con Qt " QT_VERSION_STR "</p>");
    });
    
    installButton = new QPushButton("🚀 INICIAR INSTALACIÓN", this);
    installButton->setStyleSheet(R"(
        QPushButton {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #2ecc71, stop:1 #27ae60);
            font-size: 14px;
            min-height: 50px;
            padding: 15px 30px;
        }
        QPushButton:hover {
            background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 #27ae60, stop:1 #219653);
        }
    )");
    connect(installButton, &QPushButton::clicked, this, &InstallerWindow::startInstallation);
    
    QPushButton *exitButton = new QPushButton("✖️  Salir", this);
    exitButton->setStyleSheet("QPushButton { background-color: #dc3545; }");
    connect(exitButton, &QPushButton::clicked, this, &QWidget::close);
    
    buttonLayout->addWidget(aboutButton);
    buttonLayout->addStretch();
    buttonLayout->addWidget(exitButton);
    buttonLayout->addWidget(installButton);
    
    mainLayout->addLayout(buttonLayout);
    mainLayout->addStretch();
    
    // Footer
    QFrame *footerFrame = new QFrame(this);
    footerFrame->setStyleSheet(R"(
        QFrame {
            background-color: #2c3e50;
            border-radius: 6px;
            padding: 10px;
        }
    )");
    
    QHBoxLayout *footerLayout = new QHBoxLayout(footerFrame);
    QLabel *footerLabel = new QLabel("⚠️  Requiere conexión a Internet estable • Tiempo estimado: 30-60 minutos", this);
    footerLabel->setStyleSheet("color: #ecf0f1; font-size: 11px;");
    footerLabel->setAlignment(Qt::AlignCenter);
    
    footerLayout->addWidget(footerLabel);
    mainLayout->addWidget(footerFrame);
    
    setCentralWidget(centralWidget);
    
    // Centrar ventana (corregido)
    QRect screenGeometry = QGuiApplication::primaryScreen()->availableGeometry();
    int x = (screenGeometry.width() - width()) / 2;
    int y = (screenGeometry.height() - height()) / 2;
    move(x, y);
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
