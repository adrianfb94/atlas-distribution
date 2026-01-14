(function loadFontAwesome() {
    const existingLink = document.querySelector('link[href*="font-awesome"], link[href*="all.min.css"]');

    if (!existingLink) {
        console.log('Cargando Font Awesome dinámicamente...');
        const fontAwesomeCDN = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css';

        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = fontAwesomeCDN;
        link.integrity = 'sha512-iecdLmaskl7CVkqkXNQ/ZH/XLlvWZOJyj7Yy7tcenmpD1ypASozpmT/E0iPtmFIB46ZmdtAc9eNBvH0H/ZpiBw==';
        link.crossOrigin = 'anonymous';
        
        document.head.appendChild(link);
    }
})();

class AtlasDownloader {
    constructor() {
        this.fileConfig = {
            windows: {
                installer: {
                    name: 'AtlasInstaller.exe',
                    latestUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/latest/download/AtlasInstaller.exe'
                }
            },
            linux: {
                installer: {
                    name: 'AtlasInstallerQt',
                    latestUrl: 'https://github.com/adrianfb94/atlas-distribution/releases/latest/download/AtlasInstallerQt'
                }
            }
        };
    }

    async downloadInstaller(platform) {
        const config = this.fileConfig[platform];
        if (!config) return false;

        const installer = config.installer;
        
        try {
            // Descarga directa con enlace invisible
            this.directDownload(installer.latestUrl, installer.name);
            
            // Mostrar instrucciones
            setTimeout(() => this.showInstallInstructions(platform), 500);
            
            return true;
        } catch (error) {
            console.error('Error:', error);
            return false;
        }
    }

    directDownload(url, filename) {
        // Crear enlace invisible y hacer clic
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.style.display = 'none';
        
        // Forzar descarga en la misma pestaña/ventana
        a.target = '_self';
        
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    showInstallInstructions(platform) {
        const isWindows = platform === 'windows';
        const platformName = isWindows ? 'Windows' : 'Linux';
        const icon = isWindows ? 'windows' : 'linux';
        const fileName = isWindows ? 'AtlasInstaller.exe' : 'AtlasInstallerQt';
        
        const htmlContent = `
            <div class="instruction-box" style="background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 15px 0; border-left: 4px solid #3498db;">
                <h4 style="display: flex; align-items: center; gap: 10px; margin: 0 0 15px 0; color: #2c3e50;">
                    <i class="fab fa-${icon}"></i> Instrucciones para ${platformName}
                </h4>
                <p style="margin-bottom: 15px;">El instalador <strong>${fileName}</strong> se está descargando.</p>
                
                ${isWindows ? `
                <div style="background: #e8f4f8; padding: 15px; border-radius: 6px; margin: 15px 0;">
                    <h5 style="margin: 0 0 10px 0; color: #2980b9; display: flex; align-items: center; gap: 8px;">
                        <i class="fas fa-shield-alt"></i> Si Windows Defender muestra advertencia:
                    </h5>
                    <ol style="margin: 10px 0; padding-left: 20px;">
                        <li style="margin-bottom: 5px;">Haz clic en <strong>"Más información"</strong></li>
                        <li>Luego en <strong>"Ejecutar de todos modos"</strong></li>
                    </ol>
                </div>
                
                <ol style="margin: 15px 0; padding-left: 20px;">
                    <li style="margin-bottom: 8px;"><strong>Ejecuta</strong> el archivo descargado</li>
                    <li style="margin-bottom: 8px;">Sigue las instrucciones del instalador</li>
                    <li style="margin-bottom: 8px;">Requiere <strong>25GB de espacio libre</strong></li>
                    <li>El instalador descargará automáticamente los 20GB de mapas</li>
                </ol>
                ` : `
                <ol style="margin: 15px 0; padding-left: 20px;">
                    <li style="margin-bottom: 8px;">Abre una terminal en la carpeta de descargas</li>
                    <li style="margin-bottom: 8px;">Hazlo ejecutable: <code style="background: #e8e8e8; padding: 2px 8px; border-radius: 4px; font-family: monospace;">chmod +x AtlasInstallerQt</code></li>
                    <li style="margin-bottom: 8px;">Ejecuta el instalador: <code style="background: #e8e8e8; padding: 2px 8px; border-radius: 4px; font-family: monospace;">./AtlasInstallerQt</code></li>
                    <li style="margin-bottom: 8px;">Requiere <strong>25GB de espacio libre</strong></li>
                    <li>El instalador Qt descargará automáticamente los mapas</li>
                </ol>
                `}
                
                <p style="color: #666; margin-top: 15px; font-size: 14px; display: flex; align-items: center; gap: 8px;">
                    <i class="fas fa-info-circle"></i> Si la descarga no inicia, recarga la página e intenta de nuevo.
                </p>
            </div>
        `;

        this.showNotification(`Descarga iniciada - ${platformName}`, 'success', htmlContent);
    }

    showNotification(title, type = 'info', html = '') {
        // Crear o obtener contenedor de notificaciones
        let container = document.getElementById('atlas-notifications');
        if (!container) {
            container = document.createElement('div');
            container.id = 'atlas-notifications';
            container.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 9999;
                max-width: 500px;
            `;
            document.body.appendChild(container);
        }

        // Crear notificación
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: relative;
            background: white;
            color: #333;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 10px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.15);
            animation: slideIn 0.3s ease-out;
            border-left: 5px solid ${type === 'success' ? '#2ecc71' : '#3498db'};
        `;

        notification.innerHTML = html || `
            <div style="display: flex; align-items: center; gap: 12px;">
                <i class="fas fa-${type === 'success' ? 'check-circle' : 'info-circle'}" 
                   style="color: ${type === 'success' ? '#2ecc71' : '#3498db'}; font-size: 20px;"></i>
                <span style="font-weight: 500;">${title}</span>
            </div>
        `;

        // Botón para cerrar
        const closeBtn = document.createElement('button');
        closeBtn.innerHTML = '×';
        closeBtn.style.cssText = `
            position: absolute;
            top: 10px;
            right: 15px;
            background: none;
            border: none;
            color: #999;
            font-size: 24px;
            cursor: pointer;
            width: 30px;
            height: 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 50%;
            transition: background-color 0.2s;
        `;
        closeBtn.onmouseover = () => closeBtn.style.backgroundColor = '#f5f5f5';
        closeBtn.onmouseout = () => closeBtn.style.backgroundColor = 'transparent';
        closeBtn.onclick = () => {
            notification.style.opacity = '0';
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => notification.remove(), 300);
        };

        notification.appendChild(closeBtn);
        container.appendChild(notification);

        // Auto-eliminar después de 10 segundos
        setTimeout(() => {
            if (notification.parentNode) {
                notification.style.opacity = '0';
                notification.style.transform = 'translateX(100%)';
                notification.style.transition = 'opacity 0.3s, transform 0.3s';
                setTimeout(() => notification.remove(), 300);
            }
        }, 10000);
    }
}

// Inicialización SUPER SIMPLE
document.addEventListener('DOMContentLoaded', () => {
    window.atlasDownloader = new AtlasDownloader();
    
    // Agregar estilos de animación
    if (!document.querySelector('#atlas-styles')) {
        const style = document.createElement('style');
        style.id = 'atlas-styles';
        style.textContent = `
            @keyframes slideIn {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
        `;
        document.head.appendChild(style);
    }
    
    // Manejar clics en botones de descarga
    document.querySelectorAll('.download-btn').forEach(button => {
        button.addEventListener('click', async function(e) {
            e.preventDefault();
            
            const platform = this.getAttribute('data-platform');
            const originalHTML = this.innerHTML;
            
            // Cambiar estado del botón
            this.disabled = true;
            this.innerHTML = `<i class="fas fa-download"></i> Descargando...`;
            
            // Descargar
            const success = await window.atlasDownloader.downloadInstaller(platform);
            
            // Restaurar botón después de 2 segundos
            setTimeout(() => {
                this.innerHTML = success ? 
                    `<i class="fas fa-check"></i> ¡Listo!` : 
                    `<i class="fas fa-redo"></i> Reintentar`;
                
                setTimeout(() => {
                    this.innerHTML = originalHTML;
                    this.disabled = false;
                }, 2000);
            }, 1000);
        });
    });
});