(function loadFontAwesome() {
    // Verificar si Font Awesome ya está cargado
    const existingLink = document.querySelector('link[href*="font-awesome"], link[href*="all.min.css"]');

    if (!existingLink) {
        console.log('Cargando Font Awesome dinámicamente...');

        // CORRECCIÓN: Usar CDN de Font Awesome con versión específica
        const fontAwesomeCDN = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css';

        // Crear script que espere a que Font Awesome cargue
        const loadScript = `
            (function() {
                const link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = '${fontAwesomeCDN}';
                link.integrity = 'sha512-iecdLmaskl7CVkqkXNQ/ZH/XLlvWZOJyj7Yy7tcenmpD1ypASozpmT/E0iPtmFIB46ZmdtAc9eNBvH0H/ZpiBw==';
                link.crossOrigin = 'anonymous';
                link.onload = function() {
                    console.log('✅ Font Awesome cargado dinámicamente');
                    // Disparar evento para que AtlasDownloader sepa que puede usar iconos
                    document.dispatchEvent(new Event('fontawesome-loaded'));
                };
                link.onerror = function() {
                    console.log('❌ Error cargando Font Awesome');
                };
                document.head.appendChild(link);
            })();
        `;

        // Ejecutar script inmediatamente
        const script = document.createElement('script');
        script.textContent = loadScript;
        document.head.appendChild(script);
    } else {
        // Si ya está cargado, disparar evento inmediatamente
        document.dispatchEvent(new Event('fontawesome-loaded'));
    }
})();

class AtlasDownloader {
    constructor() {
        this.fontAwesomeLoaded = false;

        // CORRECCIÓN: Esperar al evento fontawesome-loaded
        this.waitForFontAwesome().then(() => {
            this.fontAwesomeLoaded = true;
            console.log('Font Awesome cargado:', this.fontAwesomeLoaded);

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
        }).catch(() => {
            // Si falla Font Awesome, inicializar sin íconos
            console.warn('Font Awesome no disponible, usando Unicode');
            this.initWithoutFontAwesome();
        });
    }


    init() {
        console.log('Atlas Downloader inicializado (GitHub Releases)');
    }

    waitForFontAwesome() {
        return new Promise((resolve, reject) => {
            // Verificar si ya está cargado
            if (this.checkFontAwesomeLoaded()) {
                resolve();
                return;
            }

            // Esperar evento con timeout
            const timeout = setTimeout(() => {
                reject(new Error('Timeout esperando Font Awesome'));
            }, 3000); // 3 segundos de timeout

            document.addEventListener('fontawesome-loaded', () => {
                clearTimeout(timeout);
                resolve();
            }, { once: true });
        });
    }

    checkFontAwesomeLoaded() {
        const styleSheets = Array.from(document.styleSheets);
        return styleSheets.some(sheet => {
            try {
                return sheet.href && (
                    sheet.href.includes('font-awesome') ||
                    sheet.href.includes('all.min.css')
                );
            } catch (e) {
                return false;
            }
        });
    }

    initWithoutFontAwesome() {
        this.fontAwesomeLoaded = false;
        this.fileConfig = {
            // misma configuración...
        };
        this.downloads = new Map();
        this.init();
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

    showInstallInstructions(platform) {
        const useUnicode = !this.fontAwesomeLoaded;

        let message = '';
        let htmlContent = '';

        if (platform === 'windows') {
            const windowsIcon = useUnicode ? '🪟' : '<i class="fab fa-windows"></i>';
            message = '¡Instalador de Windows descargado!';
            htmlContent = `
            <div class="instruction-box">
                <h4 style="display: flex; align-items: center; gap: 8px; margin: 0 0 15px 0; font-size: 18px;">
                    <span style="font-size: 24px;">${windowsIcon}</span> Instrucciones para Windows
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
            // CORRECCIÓN: Usar condicional para Linux también
            const linuxIcon = useUnicode ? '🐧' : '<i class="fab fa-linux"></i>';
            message = '¡Instalador de Linux descargado!';
            htmlContent = `
            <div class="instruction-box">
                <h4 style="display: flex; align-items: center; gap: 8px; margin: 0 0 15px 0; font-size: 18px;">
                    <span style="font-size: 24px;">${linuxIcon}</span> Instrucciones para Linux
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
    // Inicializar el downloader
    window.atlasDownloader = new AtlasDownloader();
    
    // Función para actualizar el estado de los botones
    const updateButtonStates = () => {
        const isReady = window.atlasDownloader && window.atlasDownloader.fontAwesomeLoaded !== undefined;
        
        document.querySelectorAll('.download-btn').forEach(button => {
            if (!isReady) {
                // Si aún no está listo, mostrar estado de carga
                button.disabled = true;
                const originalHTML = button.getAttribute('data-original-html') || button.innerHTML;
                button.setAttribute('data-original-html', originalHTML);
                button.innerHTML = '<span class="loading-text">⌛ Cargando recursos...</span>';
            } else {
                // Si está listo, restaurar botones
                const originalHTML = button.getAttribute('data-original-html');
                if (originalHTML) {
                    button.innerHTML = originalHTML;
                    button.disabled = false;
                    button.removeAttribute('data-original-html');
                }
                
                // Verificar si ya tiene evento listener
                if (!button.hasAttribute('data-listener-attached')) {
                    attachDownloadListener(button);
                    button.setAttribute('data-listener-attached', 'true');
                }
            }
        });
    };
    
    // Función para adjuntar el listener de descarga
    const attachDownloadListener = (button) => {
        button.addEventListener('click', async function () {
            const platform = this.getAttribute('data-platform');
            const button = this;
            const progressContainer = document.getElementById(`${platform}-progress`);
            
            // Verificar si Font Awesome está disponible para íconos
            const useUnicode = !window.atlasDownloader.fontAwesomeLoaded;
            
            // Mostrar contenedor de progreso
            if (progressContainer) {
                progressContainer.classList.remove('hidden');
            }
            
            // Deshabilitar botón durante descarga
            button.disabled = true;
            const originalText = button.innerHTML;
            
            // Usar íconos Unicode si Font Awesome no está disponible
            if (useUnicode) {
                button.innerHTML = `⌛ Preparando...`;
            } else {
                button.innerHTML = `<i class="fas fa-spinner fa-spin"></i> Preparando...`;
            }
            
            try {
                const success = await window.atlasDownloader.downloadInstaller(platform);
                
                if (success) {
                    if (useUnicode) {
                        button.innerHTML = `✅ Descargado`;
                    } else {
                        button.innerHTML = `<i class="fas fa-check"></i> Descargado`;
                    }
                    
                    setTimeout(() => {
                        button.innerHTML = originalText;
                        button.disabled = false;
                        if (progressContainer) {
                            progressContainer.classList.add('hidden');
                        }
                    }, 3000);
                } else {
                    if (useUnicode) {
                        button.innerHTML = `🔄 Reintentar`;
                    } else {
                        button.innerHTML = `<i class="fas fa-redo"></i> Reintentar`;
                    }
                    
                    button.disabled = false;
                    if (progressContainer) {
                        progressContainer.classList.add('hidden');
                    }
                }
                
            } catch (error) {
                console.error('Error:', error);
                
                if (useUnicode) {
                    button.innerHTML = `⚠️ Error`;
                } else {
                    button.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Error`;
                }
                
                if (progressContainer) {
                    progressContainer.classList.add('hidden');
                }
                
                setTimeout(() => {
                    button.innerHTML = originalText;
                    button.disabled = false;
                }, 3000);
            }
        });
    };
    
    // Verificar el estado inicial
    updateButtonStates();
    
    // Verificar periódicamente si ya está listo (en caso de que la carga tome tiempo)
    let checkCount = 0;
    const maxChecks = 30; // 3 segundos máximo (100ms * 30)
    
    const checkReadyInterval = setInterval(() => {
        checkCount++;
        
        if (window.atlasDownloader && window.atlasDownloader.fontAwesomeLoaded !== undefined) {
            clearInterval(checkReadyInterval);
            updateButtonStates();
            console.log('AtlasDownloader completamente inicializado');
        } else if (checkCount >= maxChecks) {
            clearInterval(checkReadyInterval);
            // Forzar inicialización sin Font Awesome después de timeout
            if (window.atlasDownloader && window.atlasDownloader.initWithoutFontAwesome) {
                window.atlasDownloader.initWithoutFontAwesome();
            }
            updateButtonStates();
            console.warn('Timeout: Inicializando sin Font Awesome');
        }
    }, 100);
    
    // También escuchar el evento fontawesome-loaded
    document.addEventListener('fontawesome-loaded', () => {
        clearInterval(checkReadyInterval);
        if (window.atlasDownloader) {
            window.atlasDownloader.fontAwesomeLoaded = true;
        }
        updateButtonStates();
        console.log('Font Awesome cargado vía evento');
    });
    
    // Añadir estilos para el texto de carga
    if (!document.querySelector('#button-loading-styles')) {
        const style = document.createElement('style');
        style.id = 'button-loading-styles';
        style.textContent = `
            .loading-text {
                display: inline-flex;
                align-items: center;
                gap: 8px;
            }
            .download-btn:disabled {
                opacity: 0.7;
                cursor: not-allowed;
            }
        `;
        document.head.appendChild(style);
    }
});