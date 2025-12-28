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
