// En installerwindow.cpp, modificar funciones específicas de Linux
#ifdef Q_OS_WIN
    #include <windows.h>
    #include <shellapi.h>
    
    bool InstallerWindow::checkDiskSpace() {
        ULARGE_INTEGER freeBytes;
        if (GetDiskFreeSpaceExW(installDir.toStdWString().c_str(), &freeBytes, NULL, NULL)) {
            quint64 freeGB = freeBytes.QuadPart / (1024 * 1024 * 1024);
            bool hasSpace = freeGB >= 15;
            logText->append(QString("[INFO] Espacio disponible: %1 GB").arg(freeGB));
            return hasSpace;
        }
        return true;
    }
    
    void InstallerWindow::createDesktopEntry() {
        // Crear acceso directo en Windows
        QString shortcutPath = QDir::homePath() + "/Desktop/Atlas Interactivo.lnk";
        QString targetPath = installDir + "/Atlas_Interactivo.exe";
        
        // Usar PowerShell para crear acceso directo
        QProcess::execute("powershell", QStringList() 
            << "-Command" 
            << QString("$ws = New-Object -ComObject WScript.Shell; "
                       "$sc = $ws.CreateShortcut('%1'); "
                       "$sc.TargetPath = '%2'; "
                       "$sc.Save()").arg(shortcutPath).arg(targetPath));
        
        logText->append("✅ Acceso directo creado en escritorio Windows");
    }
#endif