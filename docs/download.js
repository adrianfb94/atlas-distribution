// download.js (versión modificada para GitHub)
class AtlasDownloader {
    constructor() {
        // URLs de GitHub para instaladores (actualizar con tu repositorio)
        this.githubConfig = {
            repo: 'tuusuario/turepositorio', // Reemplazar con usuario/repo real
            branch: 'main'
        };

        this.fileConfig = {
            windows: {
                installer: {
                    name: 'AtlasInstaller.exe',
                    url: 'https://raw.githubusercontent.com/tuusuario/turepositorio/main/instaladores/AtlasInstaller.exe', // URL directa
                    size: 0.02 * 1024 * 1024, // 0.02 MB ≈ 20KB
                    githubPath: 'instaladores/AtlasInstaller.exe',
                    downloadType: 'github'
                },
                full: {
                    name: 'Atlas_Windows_v1.0.0.zip',
                    id: 'TU_ID_WINDOWS_ZIP', // ID de Drive para el ZIP completo
                    size: 20 * 1024 * 1024 * 1024, // 20GB
                    downloadType: 'drive'
                }
            },
            // linux: {
            //     installer: {
            //         name: 'AtlasInstaller.AppImage',
            //         url: 'https://raw.githubusercontent.com/tuusuario/turepositorio/main/instaladores/AtlasInstaller.AppImage',
            //         size: 38.3 * 1024 * 1024, // 38.3 MB
            //         githubPath: 'instaladores/AtlasInstaller.AppImage',
            //         downloadType: 'github'
            //     },

            linux: {
                installer: {
                    // name: 'AtlasInstaller.AppImage',  // O 'AtlasInstaller' para solo binario
                    name: "AtlasInstallerQt",
                    url: 'https://raw.githubusercontent.com/tuusuario/turepositorio/main/instaladores/AtlasInstaller.AppImage',
                    size: 3 * 1024 * 1024, // ~3MB
                    githubPath: 'instaladores/AtlasInstaller.AppImage',
                    downloadType: 'github',
                    isAppImage: true
                },


                full: {
                    name: 'Atlas_Linux_v1.0.0.tar.gz',
                    id: '1vzAxSaKRXIPSNf937v6xjuBhRyrCiVRF', // ID de Drive
                    size: 13 * 1024 * 1024 * 1024, // 13GB
                    downloadType: 'drive'
                }
            }
        };
        
        this.downloads = new Map();
        this.init();
    }
    
    init() {
        console.log('Atlas Downloader inicializado (GitHub + Drive)');
        this.bindEvents();
    }
    
    bindEvents() {
        // Los eventos ya están manejados al final del archivo
    }
    
    async downloadInstaller(platform) {
        const config = this.fileConfig[platform];
        if (!config) {
            throw new Error(`Plataforma no soportada: ${platform}`);
        }
        
        const installer = config.installer;
        const progressId = `${platform}-progress`;
        
        try {
            // Mostrar progreso
            this.showProgress(progressId, 0, 'Preparando descarga...');
            
            let downloadUrl;
            
            if (installer.downloadType === 'github') {
                // Descargar desde GitHub
                downloadUrl = installer.url;
                console.log(`Descargando desde GitHub: ${downloadUrl}`);
            } else {
                // Descargar desde Drive (backup)
                downloadUrl = this.getDirectDownloadUrl(installer.id);
                console.log(`Descargando desde Drive: ${downloadUrl}`);
            }
            
            // Iniciar descarga
            await this.downloadFile(downloadUrl, installer.name, (progress) => {
                this.updateProgress(progressId, progress);
            });
            
            // Descarga completada
            this.showProgress(progressId, 100, 'Descarga completada');
            
            // Mostrar instrucciones
            this.showInstallInstructions(platform);
            
            return true;
            
        } catch (error) {
            console.error('Error descargando instalador:', error);
            
            // Intentar con URL alternativa si falla GitHub
            if (installer.downloadType === 'github') {
                this.showProgress(progressId, 0, 'Reintentando desde Drive...');
                try {
                    // Intentar desde Drive como fallback
                    const driveUrl = this.getDirectDownloadUrl(
                        platform === 'windows' ? 'TU_ID_ATLASINSTALLER_EXE' : 'TU_ID_ATLASINSTALLER_APPIMAGE'
                    );
                    await this.downloadFile(driveUrl, installer.name, (progress) => {
                        this.updateProgress(progressId, progress);
                    });
                    
                    this.showProgress(progressId, 100, 'Descarga completada (Drive)');
                    this.showInstallInstructions(platform);
                    return true;
                } catch (driveError) {
                    console.error('Error con Drive también:', driveError);
                }
            }
            
            this.showProgress(progressId, 0, `Error: ${error.message}`);
            return false;
        }
    }
    
    getDirectDownloadUrl(fileId) {
        // URL directa para descarga desde Google Drive
        return `https://drive.google.com/uc?id=${fileId}&export=download&confirm=t`;
    }
    
    async downloadFile(url, filename, onProgress) {
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            xhr.open('GET', url, true);
            xhr.responseType = 'blob';
            
            xhr.onprogress = (event) => {
                if (event.lengthComputable) {
                    const percentComplete = (event.loaded / event.total) * 100;
                    onProgress(percentComplete);
                }
            };
            
            xhr.onload = () => {
                if (xhr.status === 200) {
                    // Crear enlace de descarga
                    const blob = xhr.response;
                    
                    // Verificar tamaño del archivo
                    if (blob.size < 100) {
                        // Archivo muy pequeño, podría ser una página de error
                        const reader = new FileReader();
                        reader.onload = function(e) {
                            const content = e.target.result;
                            if (content.includes('<html') || content.includes('DOCTYPE')) {
                                reject(new Error('URL retornó una página HTML en lugar del archivo'));
                            } else {
                                triggerDownload();
                            }
                        };
                        reader.readAsText(blob.slice(0, 1024)); // Leer primeros 1KB
                    } else {
                        triggerDownload();
                    }
                    
                    function triggerDownload() {
                        const downloadUrl = window.URL.createObjectURL(blob);
                        const a = document.createElement('a');
                        a.href = downloadUrl;
                        a.download = filename;
                        document.body.appendChild(a);
                        a.click();
                        
                        // Limpiar
                        setTimeout(() => {
                            window.URL.revokeObjectURL(downloadUrl);
                            document.body.removeChild(a);
                        }, 100);
                        
                        resolve();
                    }
                } else {
                    reject(new Error(`HTTP ${xhr.status}: ${xhr.statusText}`));
                }
            };
            
            xhr.onerror = () => {
                reject(new Error('Error de red'));
            };
            
            xhr.send();
        });
    }
    
    // ... (el resto de los métodos permanecen igual) ...
    showProgress(progressId, percent, message = '') { /* mismo código */ }
    updateProgress(progressId, percent) { /* mismo código */ }
    showInstallInstructions(platform) { /* mismo código */ }
    showNotification(message, type = 'info', html = false) { /* mismo código */ }
    async checkForUpdates(platform, currentVersion) { /* mismo código */ }
    isNewerVersion(newVersion, currentVersion) { /* mismo código */ }
}

// Inicializar cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    window.atlasDownloader = new AtlasDownloader();
    
    // Conectar botones de descarga reales
    document.querySelectorAll('.download-btn').forEach(button => {
        button.addEventListener('click', async function() {
            const platform = this.getAttribute('data-platform');
            const button = this;
            const progressContainer = document.getElementById(`${platform}-progress`);
            
            // Mostrar contenedor de progreso
            progressContainer.classList.remove('hidden');
            
            // Deshabilitar botón durante descarga
            button.disabled = true;
            const originalText = button.innerHTML;
            button.innerHTML = `<i class="fas fa-spinner fa-spin"></i> Preparando...`;
            
            try {
                const success = await window.atlasDownloader.downloadInstaller(platform);
                
                if (success) {
                    button.innerHTML = `<i class="fas fa-check"></i> Descargado`;
                    setTimeout(() => {
                        button.innerHTML = originalText;
                        button.disabled = false;
                        progressContainer.classList.add('hidden');
                    }, 3000);
                } else {
                    button.innerHTML = `<i class="fas fa-redo"></i> Reintentar`;
                    button.disabled = false;
                    progressContainer.classList.add('hidden');
                }
                
            } catch (error) {
                console.error('Error:', error);
                button.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Error`;
                progressContainer.classList.add('hidden');
                setTimeout(() => {
                    button.innerHTML = originalText;
                    button.disabled = false;
                }, 3000);
            }
        });
    });
});