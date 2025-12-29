// // // download.js (versión modificada para GitHub)
// // class AtlasDownloader {
// //     constructor() {
// //         // URLs de GitHub para instaladores (actualizar con tu repositorio)
// //         this.githubConfig = {
// //             repo: 'adrianfb94/atlas-distribution', // Reemplazar con usuario/repo real
// //             branch: 'main'
// //         };

// //         this.fileConfig = {
// //             windows: {
// //                 installer: {
// //                     name: 'AtlasInstaller.exe',
// //                     url: 'https://github.com/adrianfb94/atlas-distribution/blob/main/AtlasInstaller.exe', // URL directa
// //                     size: 0.02 * 1024 * 1024, // 0.02 MB ≈ 20KB
// //                     githubPath: 'instaladores/AtlasInstaller.exe',
// //                     downloadType: 'github'
// //                 },
// //                 full: {
// //                     name: 'Atlas_Windows_v1.0.0.zip',
// //                     id: 'TU_ID_WINDOWS_ZIP', // ID de Drive para el ZIP completo
// //                     size: 20 * 1024 * 1024 * 1024, // 20GB
// //                     downloadType: 'drive'
// //                 }
// //             },
// //             // linux: {
// //             //     installer: {
// //             //         name: 'AtlasInstaller.AppImage',
// //             //         url: 'https://raw.githubusercontent.com/tuusuario/turepositorio/main/instaladores/AtlasInstaller.AppImage',
// //             //         size: 38.3 * 1024 * 1024, // 38.3 MB
// //             //         githubPath: 'instaladores/AtlasInstaller.AppImage',
// //             //         downloadType: 'github'
// //             //     },

// //             linux: {
// //                 installer: {
// //                     // name: 'AtlasInstaller.AppImage',  // O 'AtlasInstaller' para solo binario
// //                     name: "AtlasInstallerQt",
// //                     url: 'https://raw.githubusercontent.com/tuusuario/turepositorio/main/instaladores/AtlasInstaller.AppImage',
// //                     size: 3 * 1024 * 1024, // ~3MB
// //                     githubPath: 'instaladores/AtlasInstaller.AppImage',
// //                     downloadType: 'github',
// //                     isAppImage: true
// //                 },


// //                 full: {
// //                     name: 'Atlas_Linux_v1.0.0.tar.gz',
// //                     id: '1vzAxSaKRXIPSNf937v6xjuBhRyrCiVRF', // ID de Drive
// //                     size: 13 * 1024 * 1024 * 1024, // 13GB
// //                     downloadType: 'drive'
// //                 }
// //             }
// //         };
        
// //         this.downloads = new Map();
// //         this.init();
// //     }
    
// //     init() {
// //         console.log('Atlas Downloader inicializado (GitHub + Drive)');
// //         this.bindEvents();
// //     }
    
// //     bindEvents() {
// //         // Los eventos ya están manejados al final del archivo
// //     }
    
// //     async downloadInstaller(platform) {
// //         const config = this.fileConfig[platform];
// //         if (!config) {
// //             throw new Error(`Plataforma no soportada: ${platform}`);
// //         }
        
// //         const installer = config.installer;
// //         const progressId = `${platform}-progress`;
        
// //         try {
// //             // Mostrar progreso
// //             this.showProgress(progressId, 0, 'Preparando descarga...');
            
// //             let downloadUrl;
            
// //             if (installer.downloadType === 'github') {
// //                 // Descargar desde GitHub
// //                 downloadUrl = installer.url;
// //                 console.log(`Descargando desde GitHub: ${downloadUrl}`);
// //             } else {
// //                 // Descargar desde Drive (backup)
// //                 downloadUrl = this.getDirectDownloadUrl(installer.id);
// //                 console.log(`Descargando desde Drive: ${downloadUrl}`);
// //             }
            
// //             // Iniciar descarga
// //             await this.downloadFile(downloadUrl, installer.name, (progress) => {
// //                 this.updateProgress(progressId, progress);
// //             });
            
// //             // Descarga completada
// //             this.showProgress(progressId, 100, 'Descarga completada');
            
// //             // Mostrar instrucciones
// //             this.showInstallInstructions(platform);
            
// //             return true;
            
// //         } catch (error) {
// //             console.error('Error descargando instalador:', error);
            
// //             // Intentar con URL alternativa si falla GitHub
// //             if (installer.downloadType === 'github') {
// //                 this.showProgress(progressId, 0, 'Reintentando desde Drive...');
// //                 try {
// //                     // Intentar desde Drive como fallback
// //                     const driveUrl = this.getDirectDownloadUrl(
// //                         platform === 'windows' ? 'TU_ID_ATLASINSTALLER_EXE' : 'TU_ID_ATLASINSTALLER_APPIMAGE'
// //                     );
// //                     await this.downloadFile(driveUrl, installer.name, (progress) => {
// //                         this.updateProgress(progressId, progress);
// //                     });
                    
// //                     this.showProgress(progressId, 100, 'Descarga completada (Drive)');
// //                     this.showInstallInstructions(platform);
// //                     return true;
// //                 } catch (driveError) {
// //                     console.error('Error con Drive también:', driveError);
// //                 }
// //             }
            
// //             this.showProgress(progressId, 0, `Error: ${error.message}`);
// //             return false;
// //         }
// //     }
    
// //     getDirectDownloadUrl(fileId) {
// //         // URL directa para descarga desde Google Drive
// //         return `https://drive.google.com/uc?id=${fileId}&export=download&confirm=t`;
// //     }
    
// //     async downloadFile(url, filename, onProgress) {
// //         return new Promise((resolve, reject) => {
// //             const xhr = new XMLHttpRequest();
// //             xhr.open('GET', url, true);
// //             xhr.responseType = 'blob';
            
// //             xhr.onprogress = (event) => {
// //                 if (event.lengthComputable) {
// //                     const percentComplete = (event.loaded / event.total) * 100;
// //                     onProgress(percentComplete);
// //                 }
// //             };
            
// //             xhr.onload = () => {
// //                 if (xhr.status === 200) {
// //                     // Crear enlace de descarga
// //                     const blob = xhr.response;
                    
// //                     // Verificar tamaño del archivo
// //                     if (blob.size < 100) {
// //                         // Archivo muy pequeño, podría ser una página de error
// //                         const reader = new FileReader();
// //                         reader.onload = function(e) {
// //                             const content = e.target.result;
// //                             if (content.includes('<html') || content.includes('DOCTYPE')) {
// //                                 reject(new Error('URL retornó una página HTML en lugar del archivo'));
// //                             } else {
// //                                 triggerDownload();
// //                             }
// //                         };
// //                         reader.readAsText(blob.slice(0, 1024)); // Leer primeros 1KB
// //                     } else {
// //                         triggerDownload();
// //                     }
                    
// //                     function triggerDownload() {
// //                         const downloadUrl = window.URL.createObjectURL(blob);
// //                         const a = document.createElement('a');
// //                         a.href = downloadUrl;
// //                         a.download = filename;
// //                         document.body.appendChild(a);
// //                         a.click();
                        
// //                         // Limpiar
// //                         setTimeout(() => {
// //                             window.URL.revokeObjectURL(downloadUrl);
// //                             document.body.removeChild(a);
// //                         }, 100);
                        
// //                         resolve();
// //                     }
// //                 } else {
// //                     reject(new Error(`HTTP ${xhr.status}: ${xhr.statusText}`));
// //                 }
// //             };
            
// //             xhr.onerror = () => {
// //                 reject(new Error('Error de red'));
// //             };
            
// //             xhr.send();
// //         });
// //     }
    
// //     // ... (el resto de los métodos permanecen igual) ...
// //     showProgress(progressId, percent, message = '') { /* mismo código */ }
// //     updateProgress(progressId, percent) { /* mismo código */ }
// //     showInstallInstructions(platform) { /* mismo código */ }
// //     showNotification(message, type = 'info', html = false) { /* mismo código */ }
// //     async checkForUpdates(platform, currentVersion) { /* mismo código */ }
// //     isNewerVersion(newVersion, currentVersion) { /* mismo código */ }
// // }

// // // Inicializar cuando el DOM esté listo
// // document.addEventListener('DOMContentLoaded', () => {
// //     window.atlasDownloader = new AtlasDownloader();
    
// //     // Conectar botones de descarga reales
// //     document.querySelectorAll('.download-btn').forEach(button => {
// //         button.addEventListener('click', async function() {
// //             const platform = this.getAttribute('data-platform');
// //             const button = this;
// //             const progressContainer = document.getElementById(`${platform}-progress`);
            
// //             // Mostrar contenedor de progreso
// //             progressContainer.classList.remove('hidden');
            
// //             // Deshabilitar botón durante descarga
// //             button.disabled = true;
// //             const originalText = button.innerHTML;
// //             button.innerHTML = `<i class="fas fa-spinner fa-spin"></i> Preparando...`;
            
// //             try {
// //                 const success = await window.atlasDownloader.downloadInstaller(platform);
                
// //                 if (success) {
// //                     button.innerHTML = `<i class="fas fa-check"></i> Descargado`;
// //                     setTimeout(() => {
// //                         button.innerHTML = originalText;
// //                         button.disabled = false;
// //                         progressContainer.classList.add('hidden');
// //                     }, 3000);
// //                 } else {
// //                     button.innerHTML = `<i class="fas fa-redo"></i> Reintentar`;
// //                     button.disabled = false;
// //                     progressContainer.classList.add('hidden');
// //                 }
                
// //             } catch (error) {
// //                 console.error('Error:', error);
// //                 button.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Error`;
// //                 progressContainer.classList.add('hidden');
// //                 setTimeout(() => {
// //                     button.innerHTML = originalText;
// //                     button.disabled = false;
// //                 }, 3000);
// //             }
// //         });
// //     });
// // });




// // download.js - Versión corregida para GitHub Pages
// class AtlasDownloader {
//     constructor() {
//         this.fileConfig = {
//             windows: {
//                 installer: {
//                     name: 'AtlasInstaller.exe',
//                     // URL CORRECTA para GitHub Releases
//                     releaseUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/download/v1.0.0/AtlasInstaller.exe',
//                     // O para "latest" (siempre apunta al último release)
//                     latestUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/latest/download/AtlasInstaller.exe',
//                     size: 0.02 * 1024 * 1024,
//                     downloadType: 'github'
//                 }
//             },
//             linux: {
//                 installer: {
//                     name: 'AtlasInstallerQt',
//                     releaseUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/download/v1.0.0/AtlasInstallerQt',
//                     latestUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/latest/download/AtlasInstallerQt',
//                     size: 0.08 * 1024 * 1024,
//                     downloadType: 'github'
//                 }
//             }
//         };        
//         this.downloads = new Map();
//         this.init();
//     }
    
//     init() {
//         console.log('Atlas Downloader inicializado (GitHub Releases)');
//         this.bindEvents();
//     }
    
//     bindEvents() {
//         // Eventos se manejan al final
//     }
    
//     async downloadInstaller(platform) {
//         const config = this.fileConfig[platform];
//         if (!config) {
//             throw new Error(`Plataforma no soportada: ${platform}`);
//         }
        
//         const installer = config.installer;
//         const progressId = `${platform}-progress`;
        
//         try {
//             // Mostrar progreso
//             this.showProgress(progressId, 0, 'Preparando descarga...');
            
//             // Estrategia: Intentar GitHub Releases primero, luego GitHub Raw
//             let downloadSuccess = false;
//             let errorMessages = [];
            
//             // Intento 1: GitHub Releases (más confiable)
//             try {
//                 await this.downloadViaAnchor(installer.releaseUrl, installer.name, progressId);
//                 downloadSuccess = true;
//             } catch (releaseError) {
//                 errorMessages.push(`Releases: ${releaseError.message}`);
//                 console.warn('Falló GitHub Releases:', releaseError);
                
//                 // Intento 2: GitHub Raw
//                 try {
//                     this.showProgress(progressId, 0, 'Intentando descarga alternativa...');
//                     await this.downloadViaAnchor(installer.rawUrl, installer.name, progressId);
//                     downloadSuccess = true;
//                 } catch (rawError) {
//                     errorMessages.push(`Raw: ${rawError.message}`);
//                     console.warn('Falló GitHub Raw:', rawError);
//                 }
//             }
            
//             if (downloadSuccess) {
//                 this.showProgress(progressId, 100, 'Descarga completada');
//                 // this.showInstallInstructions(platform);
//                 return true;
//             } else {
//                 throw new Error(`Todas las fuentes fallaron: ${errorMessages.join(', ')}`);
//             }
            
//         } catch (error) {
//             console.error('Error descargando instalador:', error);
//             this.showProgress(progressId, 0, 'Error: No se pudo descargar');
            
//             // Mostrar instrucciones manuales como fallback
//             this.showManualDownloadInstructions(platform);
//             return false;
//         }
//     }
    
//     // Método usando <a> tag (sin CORS issues)
//     async downloadViaAnchor(url, filename, progressId) {
//         return new Promise((resolve, reject) => {
//             // Crear enlace invisible
//             const a = document.createElement('a');
//             a.href = url;
//             a.download = filename;
//             a.style.display = 'none';
            
//             // Configurar eventos
//             a.onclick = () => {
//                 this.showProgress(progressId, 25, 'Iniciando descarga...');
//             };
            
//             // Para monitorear la descarga (limitado por CORS)
//             const timeout = setTimeout(() => {
//                 // Asumir éxito después de un tiempo
//                 this.showProgress(progressId, 100, 'Descarga en progreso...');
//                 resolve();
//             }, 2000);
            
//             // Fallback si hay error
//             window.addEventListener('error', (e) => {
//                 if (e.target === a) {
//                     clearTimeout(timeout);
//                     reject(new Error('Error al descargar'));
//                 }
//             }, { once: true, capture: true });
            
//             document.body.appendChild(a);
//             a.click();
            
//             // Limpiar
//             setTimeout(() => {
//                 document.body.removeChild(a);
//                 clearTimeout(timeout);
//             }, 3000);
//         });
//     }
    
//     showProgress(progressId, percent, message = '') {
//         const progressBar = document.querySelector(`#${progressId} .progress-bar`);
//         const progressText = document.querySelector(`#${progressId} .progress-text`);
        
//         if (progressBar) {
//             progressBar.style.width = `${percent}%`;
//         }
//         if (progressText && message) {
//             progressText.textContent = message;
//         }
//     }
    
//     updateProgress(progressId, percent) {
//         this.showProgress(progressId, percent, `Descargando... ${Math.round(percent)}%`);
//     }
    
//     showInstallInstructions(platform) {
//         let message = '';
//         let htmlContent = '';
        
//         if (platform === 'windows') {
//             message = 'Instalador de Windows descargado';
//             htmlContent = `
//                 <div class="instruction-box">
//                     <h4><i class="fas fa-windows"></i> Instrucciones para Windows</h4>
//                     <ol>
//                         <li>Ejecuta <strong>AtlasInstaller.exe</strong></li>
//                         <li>Si Windows Defender muestra advertencia, haz clic en "Más información" → "Ejecutar de todos modos"</li>
//                         <li>Sigue las instrucciones del instalador</li>
//                         <li>Requiere Windows 10/11 de 64-bit</li>
//                     </ol>
//                 </div>
//             `;
//         } else if (platform === 'linux') {
//             message = 'Instalador de Linux descargado';
//             htmlContent = `
//                 <div class="instruction-box">
//                     <h4><i class="fab fa-linux"></i> Instrucciones para Linux</h4>
//                     <ol>
//                         <li>Abre una terminal en la carpeta de descargas</li>
//                         <li>Hazlo ejecutable: <code>chmod +x AtlasInstallerQt</code></li>
//                         <li>Ejecuta: <code>./AtlasInstallerQt</code></li>
//                         <li>Sigue las instrucciones en pantalla</li>
//                         <li>Requiere 15GB de espacio libre</li>
//                     </ol>
//                 </div>
//             `;
//         }
        
//         this.showNotification(message, 'success', htmlContent);
//     }
    
//     showManualDownloadInstructions(platform) {
//         let htmlContent = '';
//         const config = this.fileConfig[platform];
        
//         if (platform === 'windows') {
//             htmlContent = `
//                 <div class="manual-download-box">
//                     <h4><i class="fas fa-download"></i> Descarga Manual para Windows</h4>
//                     <p>La descarga automática falló. Por favor descarga manualmente:</p>
//                     <div class="manual-links">
//                         <a href="${config.installer.releaseUrl}" class="btn-secondary" target="_blank">
//                             <i class="fas fa-external-link-alt"></i> Descargar desde GitHub Releases
//                         </a>
//                         <a href="${config.installer.rawUrl}" class="btn-secondary" target="_blank" style="margin-left: 10px;">
//                             <i class="fas fa-external-link-alt"></i> Descargar desde GitHub Raw
//                         </a>
//                     </div>
//                     <p><small>Nota: Haz clic derecho → "Guardar enlace como..." si el navegador no descarga automáticamente.</small></p>
//                 </div>
//             `;
//         } else {
//             htmlContent = `
//                 <div class="manual-download-box">
//                     <h4><i class="fab fa-linux"></i> Descarga Manual para Linux</h4>
//                     <p>La descarga automática falló. Por favor descarga manualmente:</p>
//                     <div class="manual-links">
//                         <a href="${config.installer.releaseUrl}" class="btn-secondary" target="_blank">
//                             <i class="fas fa-external-link-alt"></i> Descargar desde GitHub Releases
//                         </a>
//                         <a href="${config.installer.rawUrl}" class="btn-secondary" target="_blank" style="margin-left: 10px;">
//                             <i class="fas fa-external-link-alt"></i> Descargar desde GitHub Raw
//                         </a>
//                     </div>
//                     <p><small>Después de descargar: <code>chmod +x AtlasInstallerQt && ./AtlasInstallerQt</code></small></p>
//                 </div>
//             `;
//         }
        
//         this.showNotification('Descarga manual requerida', 'warning', htmlContent);
//     }
    
//     showNotification(message, type = 'info', html = false) {
//         // Crear notificación
//         const notification = document.createElement('div');
//         notification.className = `notification notification-${type}`;
        
//         if (html) {
//             notification.innerHTML = html;
//         } else {
//             notification.textContent = message;
//         }
        
//         // Añadir al contenedor de notificaciones
//         const container = document.getElementById('notifications') || (() => {
//             const div = document.createElement('div');
//             div.id = 'notifications';
//             div.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 1000;';
//             document.body.appendChild(div);
//             return div;
//         })();
        
//         container.appendChild(notification);
        
//         // Auto-eliminar después de 10 segundos
//         setTimeout(() => {
//             if (notification.parentNode) {
//                 notification.style.opacity = '0';
//                 notification.style.transition = 'opacity 0.5s';
//                 setTimeout(() => {
//                     if (notification.parentNode) {
//                         notification.parentNode.removeChild(notification);
//                     }
//                 }, 500);
//             }
//         }, 10000);
        
//         // Botón para cerrar
//         const closeBtn = document.createElement('button');
//         closeBtn.innerHTML = '×';
//         closeBtn.style.cssText = 'background: none; border: none; color: inherit; font-size: 20px; cursor: pointer; position: absolute; top: 5px; right: 10px;';
//         closeBtn.onclick = () => {
//             if (notification.parentNode) {
//                 notification.parentNode.removeChild(notification);
//             }
//         };
        
//         notification.style.cssText = `
//             position: relative;
//             background: ${type === 'success' ? '#d4edda' : type === 'warning' ? '#fff3cd' : '#d1ecf1'};
//             color: ${type === 'success' ? '#155724' : type === 'warning' ? '#856404' : '#0c5460'};
//             border: 1px solid ${type === 'success' ? '#c3e6cb' : type === 'warning' ? '#ffeaa7' : '#bee5eb'};
//             border-radius: 5px;
//             padding: 15px 35px 15px 15px;
//             margin-bottom: 10px;
//             min-width: 300px;
//             max-width: 500px;
//             box-shadow: 0 2px 10px rgba(0,0,0,0.1);
//         `;
        
//         notification.appendChild(closeBtn);
//     }
// }

// // Inicializar cuando el DOM esté listo
// document.addEventListener('DOMContentLoaded', () => {
//     window.atlasDownloader = new AtlasDownloader();
    
//     // Conectar botones de descarga
//     document.querySelectorAll('.download-btn').forEach(button => {
//         button.addEventListener('click', async function() {
//             const platform = this.getAttribute('data-platform');
//             const button = this;
//             const progressContainer = document.getElementById(`${platform}-progress`);
            
//             // Mostrar contenedor de progreso si existe
//             if (progressContainer) {
//                 progressContainer.classList.remove('hidden');
//             }
            
//             // Deshabilitar botón durante descarga
//             button.disabled = true;
//             const originalText = button.innerHTML;
//             button.innerHTML = `<i class="fas fa-spinner fa-spin"></i> Preparando...`;
            
//             try {
//                 const success = await window.atlasDownloader.downloadInstaller(platform);
                
//                 if (success) {
//                     button.innerHTML = `<i class="fas fa-check"></i> Descargado`;
//                     setTimeout(() => {
//                         button.innerHTML = originalText;
//                         button.disabled = false;
//                         if (progressContainer) {
//                             progressContainer.classList.add('hidden');
//                         }
//                     }, 3000);
//                 } else {
//                     button.innerHTML = `<i class="fas fa-redo"></i> Reintentar`;
//                     button.disabled = false;
//                     if (progressContainer) {
//                         progressContainer.classList.add('hidden');
//                     }
//                 }
                
//             } catch (error) {
//                 console.error('Error:', error);
//                 button.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Error`;
//                 if (progressContainer) {
//                     progressContainer.classList.add('hidden');
//                 }
//                 setTimeout(() => {
//                     button.innerHTML = originalText;
//                     button.disabled = false;
//                 }, 3000);
//             }
//         });
//     });
// });

// download.js - Versión corregida con progreso funcional




class AtlasDownloader {
    constructor() {
        this.fileConfig = {
            windows: {
                installer: {
                    name: 'AtlasInstaller.exe',
                    releaseUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/download/v1.0.0/AtlasInstaller.exe',
                    latestUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/latest/download/AtlasInstaller.exe',
                    size: 0.02 * 1024 * 1024,
                    downloadType: 'github'
                }
            },
            linux: {
                installer: {
                    name: 'AtlasInstallerQt',
                    releaseUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/download/v1.0.0/AtlasInstallerQt',
                    latestUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/latest/download/AtlasInstallerQt',
                    size: 0.08 * 1024 * 1024,
                    downloadType: 'github'
                }
            }
        };
        
        this.downloads = new Map();
        this.init();
    }
    
    init() {
        console.log('Atlas Downloader inicializado (GitHub Releases)');
    }
    
    async downloadInstaller(platform) {
        const config = this.fileConfig[platform];
        if (!config) {
            throw new Error(`Plataforma no soportada: ${platform}`);
        }
        
        const installer = config.installer;
        const progressId = `${platform}-progress`;
        
        try {
            // Mostrar progreso inicial
            this.showProgress(progressId, 0, 'Preparando descarga...');
            
            // Simular progreso antes de iniciar la descarga
            await this.simulateProgress(progressId, 25, 'Conectando...', 500);
            
            // Usar GitHub Releases
            await this.downloadViaAnchor(installer.latestUrl, installer.name, progressId);
            
            // Mostrar éxito
            this.showProgress(progressId, 100, 'Descarga completada');
            
            // Mostrar instrucciones después de 1 segundo
            setTimeout(() => {
                this.showInstallInstructions(platform);
            }, 1000);
            
            return true;
            
        } catch (error) {
            console.error('Error descargando instalador:', error);
            this.showProgress(progressId, 0, `Error: ${error.message}`);
            
            // Mostrar instrucciones manuales
            this.showManualDownloadInstructions(platform);
            return false;
        }
    }
    
    // Método mejorado con progreso simulado
    async downloadViaAnchor(url, filename, progressId) {
        return new Promise((resolve, reject) => {
            // Simular progreso de conexión
            this.simulateProgress(progressId, 50, 'Descargando...', 1000)
                .then(() => {
                    // Crear enlace de descarga
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = filename;
                    a.style.display = 'none';
                    
                    // Configurar eventos
                    a.onclick = () => {
                        this.showProgress(progressId, 75, 'Iniciando descarga...');
                    };
                    
                    // Añadir al documento y hacer clic
                    document.body.appendChild(a);
                    a.click();
                    
                    // Simular progreso final
                    setTimeout(() => {
                        this.showProgress(progressId, 100, 'Descarga completada');
                        document.body.removeChild(a);
                        resolve();
                    }, 1500);
                    
                })
                .catch(reject);
        });
    }
    
    // Método para simular progreso (para GitHub no podemos medir progreso real)
    async simulateProgress(progressId, targetPercent, message, duration = 1000) {
        return new Promise((resolve) => {
            const startTime = Date.now();
            const updateProgress = () => {
                const elapsed = Date.now() - startTime;
                const progress = Math.min(targetPercent, (elapsed / duration) * targetPercent);
                
                this.showProgress(progressId, progress, message);
                
                if (progress < targetPercent) {
                    requestAnimationFrame(updateProgress);
                } else {
                    resolve();
                }
            };
            
            updateProgress();
        });
    }
    
    showProgress(progressId, percent, message = '') {
        const progressContainer = document.getElementById(progressId);
        if (!progressContainer) return;
        
        // Actualizar elementos de progreso
        const progressStatus = progressContainer.querySelector('.progress-status');
        const progressPercent = progressContainer.querySelector('.progress-percent');
        const progressFill = progressContainer.querySelector('.progress-fill');
        
        if (progressStatus) progressStatus.textContent = message;
        if (progressPercent) progressPercent.textContent = `${Math.round(percent)}%`;
        if (progressFill) progressFill.style.width = `${percent}%`;
        
        // Actualizar detalles de velocidad (simulados)
        const speedElement = progressContainer.querySelector('.speed');
        const timeElement = progressContainer.querySelector('.time');
        
        if (speedElement && percent > 0 && percent < 100) {
            // Simular velocidad basada en el progreso
            const speed = (2 + Math.random()).toFixed(1);
            speedElement.textContent = `Velocidad: ${speed} MB/s`;
        }
        
        if (timeElement && percent > 0 && percent < 100) {
            // Calcular tiempo restante simulado
            const remaining = Math.max(1, Math.round((100 - percent) / 2));
            timeElement.textContent = `Tiempo restante: ${remaining}s`;
        }
    }
    
    // showInstallInstructions(platform) {
    //     let message = '';
    //     let htmlContent = '';
        
    //     if (platform === 'windows') {
    //         message = '¡Instalador de Windows descargado!';
    //         htmlContent = `
    //             <div class="instruction-box">
    //                 <h4><i class="fas fa-windows"></i> Instrucciones para Windows</h4>
    //                 <p>El instalador <strong>AtlasInstaller.exe</strong> se ha descargado correctamente.</p>
    //                 <ol>
    //                     <li><strong>Ejecuta</strong> el archivo descargado</li>
    //                     <li>Si Windows Defender muestra advertencia:
    //                         <ul>
    //                             <li>Haz clic en "Más información"</li>
    //                             <li>Luego en "Ejecutar de todos modos"</li>
    //                         </ul>
    //                     </li>
    //                     <li>Sigue las instrucciones del instalador</li>
    //                     <li>Requiere <strong>Windows 10/11 de 64-bit</strong></li>
    //                 </ol>
    //                 <p><small>El instalador descargará los 13GB de mapas automáticamente.</small></p>
    //             </div>
    //         `;
    //     } else if (platform === 'linux') {
    //         message = '¡Instalador de Linux descargado!';
    //         htmlContent = `
    //             <div class="instruction-box">
    //                 <h4><i class="fab fa-linux"></i> Instrucciones para Linux</h4>
    //                 <p>El instalador <strong>AtlasInstallerQt</strong> se ha descargado correctamente.</p>
    //                 <ol>
    //                     <li>Abre una terminal en la carpeta de descargas</li>
    //                     <li>Hazlo ejecutable: <code>chmod +x AtlasInstallerQt</code></li>
    //                     <li>Ejecuta el instalador: <code>./AtlasInstallerQt</code></li>
    //                     <li>Sigue las instrucciones en pantalla</li>
    //                     <li>Requiere <strong>15GB de espacio libre</strong></li>
    //                 </ol>
    //                 <p><small>El instalador Qt descargará y extraerá los 13GB automáticamente.</small></p>
    //             </div>
    //         `;
    //     }
        
    //     this.showNotification(message, 'success', htmlContent);
    // }
    
    showInstallInstructions(platform) {
        let message = '';
        let htmlContent = '';
        
        if (platform === 'windows') {
            message = '¡Instalador de Windows descargado!';
            htmlContent = `
                <div class="instruction-box">
                    <h4 style="display: flex; align-items: center; gap: 8px; margin: 0 0 15px 0; font-size: 18px;">
                        <span style="font-size: 24px;">🪟</span> Instrucciones para Windows
                    </h4>
                    <p>El instalador <strong>AtlasInstaller.exe</strong> se ha descargado correctamente.</p>
                    <ol style="margin: 15px 0; padding-left: 20px;">
                        <li style="margin-bottom: 8px;"><strong>Ejecuta</strong> el archivo descargado</li>
                        <li style="margin-bottom: 8px;">Si Windows Defender muestra advertencia:
                            <ul style="margin: 5px 0 5px 20px;">
                                <li>Haz clic en "Más información"</li>
                                <li>Luego en "Ejecutar de todos modos"</li>
                            </ul>
                        </li>
                        <li style="margin-bottom: 8px;">Sigue las instrucciones del instalador</li>
                        <li style="margin-bottom: 8px;">Requiere <strong>Windows 10/11 de 64-bit</strong></li>
                    </ol>
                    <p style="font-size: 12px; color: #666; margin-top: 15px;">
                        📦 El instalador descargará los 13GB de mapas automáticamente.
                    </p>
                </div>
            `;
        } else if (platform === 'linux') {
            message = '¡Instalador de Linux descargado!';
            htmlContent = `
                <div class="instruction-box">
                    <h4 style="display: flex; align-items: center; gap: 8px; margin: 0 0 15px 0; font-size: 18px;">
                        <span style="font-size: 24px;">🐧</span> Instrucciones para Linux
                    </h4>
                    <p>El instalador <strong>AtlasInstallerQt</strong> se ha descargado correctamente.</p>
                    <ol style="margin: 15px 0; padding-left: 20px;">
                        <li style="margin-bottom: 8px;">Abre una terminal en la carpeta de descargas</li>
                        <li style="margin-bottom: 8px;">Hazlo ejecutable: <code style="background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-family: monospace;">chmod +x AtlasInstallerQt</code></li>
                        <li style="margin-bottom: 8px;">Ejecuta el instalador: <code style="background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-family: monospace;">./AtlasInstallerQt</code></li>
                        <li style="margin-bottom: 8px;">Sigue las instrucciones en pantalla</li>
                        <li style="margin-bottom: 8px;">Requiere <strong>15GB de espacio libre</strong></li>
                    </ol>
                    <p style="font-size: 12px; color: #666; margin-top: 15px;">
                        📦 El instalador Qt descargará y extraerá los 13GB automáticamente.
                    </p>
                </div>
            `;
        }
        
        this.showNotification(message, 'success', htmlContent);
    }

    // showManualDownloadInstructions(platform) {
    //     const config = this.fileConfig[platform];
    //     let platformName = platform === 'windows' ? 'Windows' : 'Linux';
    //     let fileName = platform === 'windows' ? 'AtlasInstaller.exe' : 'AtlasInstallerQt';
        
    //     let htmlContent = `
    //         <div class="manual-download-box">
    //             <h4><i class="fas fa-download"></i> Descarga Manual para ${platformName}</h4>
    //             <p>La descarga automática no pudo iniciarse. Por favor descarga manualmente:</p>
    //             <div class="manual-links">
    //                 <a href="${config.installer.latestUrl}" class="btn-secondary" target="_blank" download="${fileName}">
    //                     <i class="fas fa-external-link-alt"></i> Descargar ${fileName} desde GitHub
    //                 </a>
    //             </div>
    //             <div class="manual-steps">
    //                 <h5>Pasos manuales:</h5>
    //                 <ol>
    //                     <li>Haz clic en el enlace arriba para descargar</li>
    //                     <li>Guarda el archivo en tu carpeta de descargas</li>
    //     `;
        
    //     if (platform === 'linux') {
    //         htmlContent += `
    //                     <li>Abre terminal y ejecuta:
    //                         <code>chmod +x ~/Descargas/AtlasInstallerQt</code>
    //                     </li>
    //                     <li>Luego ejecuta:
    //                         <code>./AtlasInstallerQt</code>
    //                     </li>
    //         `;
    //     } else {
    //         htmlContent += `
    //                     <li>Ejecuta el archivo AtlasInstaller.exe</li>
    //                     <li>Sigue las instrucciones del instalador</li>
    //         `;
    //     }
        
    //     htmlContent += `
    //                 </ol>
    //             </div>
    //         </div>
    //     `;
        
    //     this.showNotification('Descarga manual requerida', 'warning', htmlContent);
    // }

    
    showManualDownloadInstructions(platform) {
        const config = this.fileConfig[platform];
        let platformName = platform === 'windows' ? 'Windows' : 'Linux';
        let fileName = platform === 'windows' ? 'AtlasInstaller.exe' : 'AtlasInstallerQt';
        let platformIcon = platform === 'windows' ? '🪟' : '🐧';
        
        let htmlContent = `
            <div class="manual-download-box">
                <h4 style="display: flex; align-items: center; gap: 8px; margin: 0 0 15px 0; font-size: 18px;">
                    <span style="font-size: 24px;">${platformIcon}</span> Descarga Manual para ${platformName}
                </h4>
                <p style="margin-bottom: 15px;">La descarga automática no pudo iniciarse. Por favor descarga manualmente:</p>
                <div class="manual-links" style="margin: 20px 0;">
                    <a href="${config.installer.latestUrl}" target="_blank" download="${fileName}" 
                    style="display: inline-flex; align-items: center; gap: 8px; padding: 12px 24px; background-color: #3498db; color: white; text-decoration: none; border-radius: 6px; font-weight: bold; transition: background-color 0.3s;">
                        🔗 Descargar ${fileName} desde GitHub
                    </a>
                </div>
                <div class="manual-steps" style="margin-top: 20px; padding-top: 20px; border-top: 1px solid #e0e0e0;">
                    <h5 style="margin: 0 0 10px 0; font-size: 16px;">📝 Pasos manuales:</h5>
                    <ol style="margin: 10px 0; padding-left: 20px;">
                        <li style="margin-bottom: 8px;">Haz clic en el enlace arriba para descargar</li>
                        <li style="margin-bottom: 8px;">Guarda el archivo en tu carpeta de descargas</li>
        `;
        
        if (platform === 'linux') {
            htmlContent += `
                        <li style="margin-bottom: 8px;">Abre terminal y ejecuta:
                            <code style="background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-family: monospace; display: block; margin: 5px 0;">chmod +x ~/Descargas/AtlasInstallerQt</code>
                        </li>
                        <li style="margin-bottom: 8px;">Luego ejecuta:
                            <code style="background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-family: monospace; display: block; margin: 5px 0;">./AtlasInstallerQt</code>
                        </li>
            `;
        } else {
            htmlContent += `
                        <li style="margin-bottom: 8px;">Ejecuta el archivo AtlasInstaller.exe</li>
                        <li style="margin-bottom: 8px;">Sigue las instrucciones del instalador</li>
            `;
        }
        
        htmlContent += `
                    </ol>
                </div>
            </div>
        `;
        
        this.showNotification('⚠️ Descarga manual requerida', 'warning', htmlContent);
    }

    // showNotification(message, type = 'info', html = false) {
    //     // Crear notificación (mismo código que antes)
    //     const notification = document.createElement('div');
    //     notification.className = `notification notification-${type}`;
        
    //     if (html) {
    //         notification.innerHTML = html;
    //     } else {
    //         notification.textContent = message;
    //     }
        
    //     // Añadir al contenedor
    //     const container = document.getElementById('notifications') || (() => {
    //         const div = document.createElement('div');
    //         div.id = 'notifications';
    //         div.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 1000;';
    //         document.body.appendChild(div);
    //         return div;
    //     })();
        
    //     container.appendChild(notification);
        
    //     // Estilo para la notificación
    //     notification.style.cssText = `
    //         position: relative;
    //         background: ${type === 'success' ? '#d4edda' : type === 'warning' ? '#fff3cd' : '#d1ecf1'};
    //         color: ${type === 'success' ? '#155724' : type === 'warning' ? '#856404' : '#0c5460'};
    //         border: 1px solid ${type === 'success' ? '#c3e6cb' : type === 'warning' ? '#ffeaa7' : '#bee5eb'};
    //         border-radius: 5px;
    //         padding: 15px 35px 15px 15px;
    //         margin-bottom: 10px;
    //         min-width: 300px;
    //         max-width: 500px;
    //         box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    //     `;
        
    //     // Botón para cerrar
    //     const closeBtn = document.createElement('button');
    //     closeBtn.innerHTML = '×';
    //     closeBtn.style.cssText = 'background: none; border: none; color: inherit; font-size: 20px; cursor: pointer; position: absolute; top: 5px; right: 10px;';
    //     closeBtn.onclick = () => notification.remove();
        
    //     notification.appendChild(closeBtn);
        
    //     // Auto-eliminar después de 10 segundos
    //     setTimeout(() => {
    //         notification.style.opacity = '0';
    //         notification.style.transition = 'opacity 0.5s';
    //         setTimeout(() => notification.remove(), 500);
    //     }, 10000);
    // }

    showNotification(message, type = 'info', html = false) {
        const notification = document.createElement('div');
        
        // Iconos Unicode según tipo
        let typeIcon = 'ℹ️'; // info por defecto
        if (type === 'success') typeIcon = '✅';
        if (type === 'warning') typeIcon = '⚠️';
        if (type === 'error') typeIcon = '❌';
        
        if (html) {
            notification.innerHTML = html;
        } else {
            notification.innerHTML = `
                <div style="display: flex; align-items: flex-start; gap: 12px; padding-right: 30px;">
                    <span style="font-size: 20px; flex-shrink: 0;">${typeIcon}</span>
                    <span style="flex: 1;">${message}</span>
                </div>
            `;
        }
        
        // Añadir al contenedor
        const container = document.getElementById('notifications') || (() => {
            const div = document.createElement('div');
            div.id = 'notifications';
            div.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 1000;';
            document.body.appendChild(div);
            return div;
        })();
        
        container.appendChild(notification);
        
        // Estilo para la notificación
        notification.style.cssText = `
            position: relative;
            background: ${type === 'success' ? '#d4edda' : type === 'warning' ? '#fff3cd' : '#d1ecf1'};
            color: ${type === 'success' ? '#155724' : type === 'warning' ? '#856404' : '#0c5460'};
            border: 1px solid ${type === 'success' ? '#c3e6cb' : type === 'warning' ? '#ffeaa7' : '#bee5eb'};
            border-radius: 5px;
            padding: 15px 35px 15px 15px;
            margin-bottom: 10px;
            min-width: 300px;
            max-width: 500px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        `;
        
        // Botón para cerrar
        const closeBtn = document.createElement('button');
        closeBtn.innerHTML = '×';
        closeBtn.style.cssText = 'background: none; border: none; color: inherit; font-size: 20px; cursor: pointer; position: absolute; top: 5px; right: 10px;';
        closeBtn.onclick = () => notification.remove();
        
        notification.appendChild(closeBtn);
        
        // Auto-eliminar después de 10 segundos
        setTimeout(() => {
            notification.style.opacity = '0';
            notification.style.transition = 'opacity 0.5s';
            setTimeout(() => notification.remove(), 500);
        }, 10000);
    }


}

// Inicialización corregida
document.addEventListener('DOMContentLoaded', () => {
    window.atlasDownloader = new AtlasDownloader();
    
    // Conectar botones de descarga
    document.querySelectorAll('.download-btn').forEach(button => {
        button.addEventListener('click', async function() {
            const platform = this.getAttribute('data-platform');
            const button = this;
            const progressContainer = document.getElementById(`${platform}-progress`);
            
            // Mostrar contenedor de progreso
            if (progressContainer) {
                progressContainer.classList.remove('hidden');
            }
            
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
                        if (progressContainer) {
                            progressContainer.classList.add('hidden');
                        }
                    }, 3000);
                } else {
                    button.innerHTML = `<i class="fas fa-redo"></i> Reintentar`;
                    button.disabled = false;
                    if (progressContainer) {
                        progressContainer.classList.add('hidden');
                    }
                }
                
            } catch (error) {
                console.error('Error:', error);
                button.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Error`;
                if (progressContainer) {
                    progressContainer.classList.add('hidden');
                }
                setTimeout(() => {
                    button.innerHTML = originalText;
                    button.disabled = false;
                }, 3000);
            }
        });
    });
});
