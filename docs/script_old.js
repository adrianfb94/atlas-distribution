// script.js
document.addEventListener('DOMContentLoaded', function() {
    // Theme Toggle
    const themeToggle = document.getElementById('theme-icon');
    const currentTheme = localStorage.getItem('theme') || 'light';
    
    if (currentTheme === 'dark') {
        document.documentElement.setAttribute('data-theme', 'dark');
        themeToggle.classList.remove('fa-moon');
        themeToggle.classList.add('fa-sun');
    }
    
    themeToggle.addEventListener('click', function() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        
        if (newTheme === 'dark') {
            this.classList.remove('fa-moon');
            this.classList.add('fa-sun');
        } else {
            this.classList.remove('fa-sun');
            this.classList.add('fa-moon');
        }
    });
    
    // Smooth scrolling for navigation links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href');
            if (targetId === '#') return;
            
            const targetElement = document.querySelector(targetId);
            if (targetElement) {
                const headerHeight = document.querySelector('.header').offsetHeight;
                const targetPosition = targetElement.offsetTop - headerHeight - 20;
                
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
                
                // Update active nav link
                document.querySelectorAll('.nav-links a').forEach(link => {
                    link.classList.remove('active');
                });
                this.classList.add('active');
            }
        });
    });
    
    // Guide Tabs
    const guideTabs = document.querySelectorAll('.guide-tab');
    const guideSteps = document.querySelectorAll('.guide-steps');
    
    guideTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            const tabType = this.getAttribute('data-tab');
            
            // Update active tab
            guideTabs.forEach(t => t.classList.remove('active'));
            this.classList.add('active');
            
            // Show corresponding steps
            guideSteps.forEach(steps => {
                steps.classList.remove('active');
                if (steps.classList.contains(`${tabType}-steps`)) {
                    steps.classList.add('active');
                }
            });
        });
    });
    
    // FAQ Accordion
    const faqQuestions = document.querySelectorAll('.faq-question');
    
    faqQuestions.forEach(question => {
        question.addEventListener('click', function() {
            const faqItem = this.parentElement;
            const isActive = faqItem.classList.contains('active');
            
            // Close all FAQ items
            document.querySelectorAll('.faq-item').forEach(item => {
                item.classList.remove('active');
            });
            
            // Open clicked item if it wasn't active
            if (!isActive) {
                faqItem.classList.add('active');
            }
        });
    });
    
    // Download button handlers (will be connected to download.js)
    const downloadButtons = document.querySelectorAll('.download-btn');
    
    downloadButtons.forEach(button => {
        button.addEventListener('click', function() {
            const platform = this.getAttribute('data-platform');
            console.log(`Iniciando descarga para ${platform}`);
            
            // Show progress container
            const progressContainer = document.getElementById(`${platform}-progress`);
            progressContainer.classList.remove('hidden');
            
            // Disable button during download
            this.disabled = true;
            this.innerHTML = `<i class="fas fa-spinner fa-spin"></i> Descargando...`;
            
            // In a real implementation, this would call download.js functions
            // For now, simulate a download
            simulateDownload(platform, progressContainer, this);
        });
    });
    
    // Simulate download (for demo purposes)
    function simulateDownload(platform, progressContainer, button) {
        const progressFill = progressContainer.querySelector('.progress-fill');
        const progressPercent = progressContainer.querySelector('.progress-percent');
        const speedElement = progressContainer.querySelector('.speed');
        const timeElement = progressContainer.querySelector('.time');
        
        let progress = 0;
        const totalSize = platform === 'windows' ? 5 * 1024 * 1024 : 5 * 1024 * 1024; // 5MB
        
        const interval = setInterval(() => {
            progress += Math.random() * 5 * 1024 * 1024 / 100; // Random progress
            const percent = Math.min(100, (progress / totalSize) * 100);
            
            progressFill.style.width = `${percent}%`;
            progressPercent.textContent = `${Math.round(percent)}%`;
            speedElement.textContent = `Velocidad: ${(Math.random() * 2 + 1).toFixed(1)} MB/s`;
            
            // Calculate estimated time
            const remaining = (100 - percent) / 2; // Simple estimation
            timeElement.textContent = `Tiempo restante: ${Math.round(remaining)}s`;
            
            if (percent >= 100) {
                clearInterval(interval);
                progressContainer.classList.add('hidden');
                button.disabled = false;
                button.innerHTML = `<i class="fas fa-download"></i> Descargar AtlasInstaller.${platform === 'windows' ? 'exe' : 'AppImage'} (5 MB)`;
                
                // Show success message
                showNotification(`Instalador de ${platform} descargado. Ejecútalo para continuar.`, 'success');
            }
        }, 200);
    }
    
    // Notification system
    function showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.innerHTML = `
            <i class="fas fa-${type === 'success' ? 'check-circle' : 'info-circle'}"></i>
            <span>${message}</span>
            <button class="notification-close"><i class="fas fa-times"></i></button>
        `;
        
        document.body.appendChild(notification);
        
        // Add styles
        if (!document.querySelector('#notification-styles')) {
            const style = document.createElement('style');
            style.id = 'notification-styles';
            style.textContent = `
                .notification {
                    position: fixed;
                    top: 20px;
                    right: 20px;
                    padding: 1rem 1.5rem;
                    background-color: var(--card-bg);
                    border-left: 4px solid var(--primary-color);
                    border-radius: var(--radius);
                    box-shadow: var(--shadow-lg);
                    display: flex;
                    align-items: center;
                    gap: 10px;
                    z-index: 9999;
                    animation: slideIn 0.3s ease;
                    max-width: 400px;
                }
                .notification-success {
                    border-left-color: #10b981;
                }
                .notification-error {
                    border-left-color: #ef4444;
                }
                .notification-close {
                    background: none;
                    border: none;
                    color: var(--text-light);
                    cursor: pointer;
                    margin-left: auto;
                }
                @keyframes slideIn {
                    from { transform: translateX(100%); opacity: 0; }
                    to { transform: translateX(0); opacity: 1; }
                }
            `;
            document.head.appendChild(style);
        }
        
        // Auto-remove after 5 seconds
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 5000);
        
        // Close button
        notification.querySelector('.notification-close').addEventListener('click', () => {
            notification.remove();
        });
    }
    
    // Load patch information
    loadPatchInfo();
    
    async function loadPatchInfo() {
        try {
            // In a real implementation, this would fetch from your patch_index.json
            // For now, use mock data
            const mockPatches = [
                {
                    name: "patch_20251120_windows.zip",
                    date: "2025-11-20",
                    platform: "windows",
                    size_mb: 45.2,
                    changes: { new: 12, modified: 8, deleted: 2 }
                },
                {
                    name: "patch_20251115_windows.zip",
                    date: "2025-11-15",
                    platform: "windows",
                    size_mb: 23.7,
                    changes: { new: 5, modified: 3, deleted: 0 }
                },
                {
                    name: "patch_20251118_linux.tar.gz",
                    date: "2025-11-18",
                    platform: "linux",
                    size_mb: 38.9,
                    changes: { new: 8, modified: 6, deleted: 1 }
                }
            ];
            
            const patchList = document.getElementById('patchList');
            if (!patchList) return;
            
            patchList.innerHTML = '';
            
            mockPatches.forEach(patch => {
                const patchItem = document.createElement('div');
                patchItem.className = 'patch-item';
                patchItem.innerHTML = `
                    <div class="patch-details">
                        <div class="patch-name">${patch.name}</div>
                        <div class="patch-meta">
                            <span>${patch.date}</span>
                            <span>•</span>
                            <span class="patch-platform">${patch.platform}</span>
                            <span>•</span>
                            <span>+${patch.changes.new} ✏️${patch.changes.modified} -${patch.changes.deleted}</span>
                        </div>
                    </div>
                    <div class="patch-size">${patch.size_mb.toFixed(1)} MB</div>
                `;
                
                patchList.appendChild(patchItem);
            });
            
        } catch (error) {
            console.error('Error loading patch info:', error);
            document.getElementById('patchList').innerHTML = 
                '<div class="loading-patches">No se pudieron cargar los parches. Verifica tu conexión.</div>';
        }
    }
    
    // Active nav link on scroll
    window.addEventListener('scroll', function() {
        const sections = document.querySelectorAll('section[id]');
        const scrollPosition = window.scrollY + 100;
        
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.offsetHeight;
            const sectionId = section.getAttribute('id');
            
            if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
                document.querySelectorAll('.nav-links a').forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${sectionId}`) {
                        link.classList.add('active');
                    }
                });
            }
        });
    });
});