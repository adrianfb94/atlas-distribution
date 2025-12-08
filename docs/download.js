// download.js
class AtlasDownloader {
    constructor() {
        // Configuración de archivos en Drive (actualizar con tus IDs reales)
        this.fileConfig = {
            windows: {
                installer: {
                    name: 'AtlasInstaller.exe',
                    id: 'TU_ID_ATLASINSTALLER_EXE', // Reemplazar con ID real
                    size: 5 * 1024 * 1024, // 5MB aproximado
                    url: 'https://drive.google.com/uc?id=TU_ID_ATLASINSTALLER_EXE&export=download'
                },
                full: {
                    name: 'Atlas_Windows_v1.0.0.zip',
                    id: 'TU_ID_WINDOWS_ZIP', // Reemplazar con ID real
                    size: 20 * 1024 * 1024 * 1024 // 20GB
                }
            },
            linux: {
                installer: {
                    name: 'AtlasInstaller.AppImage',
                    id: 'TU_ID_ATLASINSTALLER_APPIMAGE', // Reemplazar con ID real
                    size: 5 * 1024 * 1024, // 5MB aproximado
                    url: 'https://drive.google.com/uc?id=TU_ID_ATLASINSTALLER_APPIMAGE&export=download'
                },
                full: {
                    name: 'Atlas_Linux_v1.0.0.tar.gz',
                    id: 'TU_ID_LINUX_TARGZ', // Reemplazar con ID real
                    size: 13 * 1024 * 1024 * 1024 // 13GB
                }
            }
        };
        
        this.downloads = new Map();
        this.init();
    }
    
    init() {
        console.log('Atlas Downloader inicializado');
        this.bindEvents();
    }
    
    bindEvents() {
        // Los botones de descarga ya están manejados en script.js
        // Aquí se conectarían las funciones reales de descarga
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
            
            // Crear enlace de descarga
            const downloadUrl = this.getDirectDownloadUrl(installer.id);
            
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
    
    showProgress(progressId, percent, message = '') {
        const progressContainer = document.getElementById(progressId);
        if (!progressContainer) return;
        
        progressContainer.classList.remove('hidden');
        
        const progressFill = progressContainer.querySelector('.progress-fill');
        const progressPercent = progressContainer.querySelector('.progress-percent');
        const progressHeader = progressContainer.querySelector('.progress-header span:first-child');
        
        if (progressFill) progressFill.style.width = `${percent}%`;
        if (progressPercent) progressPercent.textContent = `${Math.round(percent)}%`;
        if (progressHeader && message) progressHeader.textContent = message;
    }
    
    updateProgress(progressId, percent) {
        const progressContainer = document.getElementById(progressId);
        if (!progressContainer) return;
        
        const progressFill = progressContainer.querySelector('.progress-fill');
        const progressPercent = progressContainer.querySelector('.progress-percent');
        const speedElement = progressContainer.querySelector('.speed');
        const timeElement = progressContainer.querySelector('.time');
        
        if (progressFill) progressFill.style.width = `${percent}%`;
        if (progressPercent) progressPercent.textContent = `${Math.round(percent)}%`;
        
        // Simular velocidad y tiempo restante (en implementación real se calcularía)
        if (speedElement && timeElement && percent < 100) {
            const speed = (Math.random() * 2 + 1).toFixed(1);
            const remaining = ((100 - percent) / (percent > 0 ? percent : 1)) * 10;
            
            speedElement.textContent = `Velocidad: ${speed} MB/s`;
            timeElement.textContent = `Tiempo restante: ${Math.round(remaining)}s`;
        }
    }
    
    showInstallInstructions(platform) {
        const instructions = {
            windows: `
                <strong>Instrucciones para Windows:</strong>
                <ol>
                    <li>Ejecuta <code>AtlasInstaller.exe</code> (descargado)</li>
                    <li>Selecciona la carpeta de instalación (25GB libres)</li>
                    <li>El instalador descargará automáticamente los 20GB</li>
                    <li>¡Listo! Ejecuta Atlas_Interactivo.exe</li>
                </ol>
            `,
            linux: `
                <strong>Instrucciones para Linux:</strong>
                <ol>
                    <li>Abre terminal en la carpeta de descarga</li>
                    <li>Ejecuta: <code>chmod +x AtlasInstaller.AppImage</code></li>
                    <li>Ejecuta: <code>./AtlasInstaller.AppImage</code></li>
                    <li>Sigue las instrucciones en pantalla</li>
                </ol>
            `
        };
        
        // Crear notificación con instrucciones
        this.showNotification(instructions[platform], 'info', true);
    }
    
    showNotification(message, type = 'info', html = false) {
        // Similar a la función en script.js pero más específica
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        
        if (html) {
            notification.innerHTML = `
                <i class="fas fa-${type === 'success' ? 'check-circle' : 'info-circle'}"></i>
                <div>${message}</div>
                <button class="notification-close"><i class="fas fa-times"></i></button>
            `;
        } else {
            notification.innerHTML = `
                <i class="fas fa-${type === 'success' ? 'check-circle' : 'info-circle'}"></i>
                <span>${message}</span>
                <button class="notification-close"><i class="fas fa-times"></i></button>
            `;
        }
        
        document.body.appendChild(notification);
        
        // Auto-remove
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 10000);
        
        notification.querySelector('.notification-close').addEventListener('click', () => {
            notification.remove();
        });
    }
    
    // Verificar actualizaciones disponibles
    async checkForUpdates(platform, currentVersion) {
        try {
            // En implementación real, se obtendría de un archivo JSON en Drive
            const response = await fetch('https://drive.google.com/uc?id=TU_ID_PATCH_INDEX&export=download');
            const patchIndex = await response.json();
            
            const availablePatches = patchIndex.patches.filter(patch => 
                patch.platform === platform && 
                this.isNewerVersion(patch.version, currentVersion)
            );
            
            return availablePatches;
            
        } catch (error) {
            console.error('Error verificando actualizaciones:', error);
            return [];
        }
    }
    
    isNewerVersion(newVersion, currentVersion) {
        // Comparación simple de versiones
        const newParts = newVersion.split('.').map(Number);
        const currentParts = currentVersion.split('.').map(Number);
        
        for (let i = 0; i < Math.max(newParts.length, currentParts.length); i++) {
            const newPart = newParts[i] || 0;
            const currentPart = currentParts[i] || 0;
            
            if (newPart > currentPart) return true;
            if (newPart < currentPart) return false;
        }
        
        return false;
    }
}

// Inicializar cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    window.atlasDownloader = new AtlasDownloader();
    
    // Conectar botones de descarga reales
    document.querySelectorAll('.download-btn').forEach(button => {
        button.addEventListener('click', async function() {
            const platform = this.getAttribute('data-platform');
            const button = this;
            
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
                    }, 3000);
                } else {
                    button.innerHTML = `<i class="fas fa-redo"></i> Reintentar`;
                    button.disabled = false;
                }
                
            } catch (error) {
                console.error('Error:', error);
                button.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Error`;
                setTimeout(() => {
                    button.innerHTML = originalText;
                    button.disabled = false;
                }, 3000);
            }
        });
    });
});