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
    QLabel *subtitleLabel;
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
