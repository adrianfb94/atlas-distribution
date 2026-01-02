using System;
using System.Drawing;
using System.IO;
using System.Net;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.IO.Compression;
using System.ComponentModel;
using System.Linq;
using System.Text;

namespace AtlasInstaller
{
    public partial class MainForm : Form
    {
        // Colores inspirados en Qt de Linux
        private readonly Color COLOR_PRIMARY = Color.FromArgb(52, 152, 219);    // Azul Qt
        private readonly Color COLOR_SECONDARY = Color.FromArgb(44, 62, 80);    // Gris oscuro
        private readonly Color COLOR_SUCCESS = Color.FromArgb(46, 204, 113);    // Verde
        private readonly Color COLOR_ERROR = Color.FromArgb(231, 76, 60);       // Rojo
        private readonly Color COLOR_BACKGROUND = Color.FromArgb(245, 247, 250); // Fondo claro
        private readonly Color COLOR_INFO_BG = Color.FromArgb(227, 242, 253);   // Fondo info
        private readonly Color COLOR_LOG_BG = Color.FromArgb(26, 26, 46);       // Fondo log oscuro
        private readonly Color COLOR_LOG_TEXT = Color.FromArgb(224, 224, 224);  // Texto log claro
        private readonly Color COLOR_FOOTER_BG = Color.FromArgb(44, 62, 80);    // Footer
        private readonly Color COLOR_WARNING = Color.FromArgb(241, 196, 15);    // Amarillo
        
        // Componentes UI (igual que en Qt)
        private Label lblTitle;
        private Label lblSubtitle;
        private Label lblVersion;
        private Label lblDirectory;
        private TextBox txtDirectory;
        private Button btnBrowse;
        private CheckBox chkDesktop;
        private CheckBox chkMenu;
        private GroupBox grpConfig;
        private GroupBox grpProgress;
        private Label lblStatus;
        private ProgressBar progressBar;
        private RichTextBox txtLog;
        private Button btnClearLog;
        private Button btnAbout;
        private Button btnInstall;
        private Button btnExit;
        private Label lblFooter;
        private Panel pnlInfo;
        private Label lblDiskSpace;
        private Label lblSpaceWarning;
        
        private bool isInstalling = false;
        private string installPath = @"C:\AtlasInteractivo";
        private WebClient downloadClient;
        // private System.Windows.Forms.Timer diskSpaceTimer;
        
        public MainForm()
        {
            InitializeComponent();
            SetupUI();
            UpdateDiskSpace(); // Solo una vez al inicio
        }
        

        private void InitializeComponent()
        {
            // Configuración básica de la ventana
            this.Text = "Atlas Interactivo - Instalador para Windows";
            this.Size = new Size(750, 750);
            // this.Size = new Size(750, 650);
            this.BackColor = COLOR_BACKGROUND;
            this.FormBorderStyle = FormBorderStyle.Sizable;
            this.MinimumSize = new Size(750, 600); // Aumentado mínimo para más espacio
            this.StartPosition = FormStartPosition.CenterScreen;
            this.Font = new Font("Segoe UI", 10F);
            this.Padding = new Padding(15);
            
            // Layout principal - AJUSTADO
            TableLayoutPanel mainLayout = new TableLayoutPanel();
            mainLayout.Dock = DockStyle.Fill;
            mainLayout.ColumnCount = 1;
            mainLayout.RowCount = 5;
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 80));   // Header
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 260));  // Config (AUMENTADO de 220 a 260)
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 60));    // Progress
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 60));   // Botones
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 35));   // Footer
            mainLayout.Padding = new Padding(0, 0, 0, 5);


            // ========== ENCABEZADO CON ANCHORS CORRECTOS ==========
            Panel headerPanel = new Panel();
            headerPanel.Dock = DockStyle.Fill;
            headerPanel.BackColor = Color.Transparent;
            
            // Icono
            Label lblIcon = new Label();
            lblIcon.Text = "🌍";
            lblIcon.Font = new Font("Segoe UI", 28F);
            lblIcon.Location = new Point(15, 15);
            lblIcon.Size = new Size(45, 45);
            lblIcon.TextAlign = ContentAlignment.MiddleCenter;
            
            // Título
            lblTitle = new Label();
            lblTitle.Text = "ATLAS INTERACTIVO";
            lblTitle.Font = new Font("Segoe UI", 20F, FontStyle.Bold);
            lblTitle.ForeColor = COLOR_SECONDARY;
            lblTitle.Location = new Point(70, 15);
            lblTitle.Size = new Size(300, 30);
            lblTitle.TextAlign = ContentAlignment.MiddleLeft;
            
            // Subtítulo
            lblSubtitle = new Label();
            lblSubtitle.Text = "Instalador Oficial para Windows";
            lblSubtitle.Font = new Font("Segoe UI", 9F);
            lblSubtitle.ForeColor = Color.FromArgb(127, 140, 141);
            lblSubtitle.Location = new Point(70, 45);
            lblSubtitle.Size = new Size(250, 20);
            lblSubtitle.TextAlign = ContentAlignment.MiddleLeft;
            
            // Versión - MEJORADO
            lblVersion = new Label();
            lblVersion.Text = "v1.0.0";
            lblVersion.Font = new Font("Segoe UI", 8F);
            lblVersion.ForeColor = Color.FromArgb(149, 165, 166);
            lblVersion.AutoSize = true;
            lblVersion.Location = new Point(headerPanel.Width - 120, 10); // Posición inicial
            lblVersion.TextAlign = ContentAlignment.MiddleRight;
            
            // Evento para ajustar la posición de la versión cuando cambie el tamaño
            headerPanel.SizeChanged += (s, e) => {
                lblVersion.Left = headerPanel.Width - lblVersion.Width - 15;
            };
            
            headerPanel.Controls.AddRange(new Control[] { lblIcon, lblTitle, lblSubtitle, lblVersion });
            mainLayout.Controls.Add(headerPanel, 0, 0);


            // ========== GRUPO CONFIGURACIÓN CORREGIDO ==========
            grpConfig = new GroupBox();
            grpConfig.Dock = DockStyle.Fill;
            grpConfig.Text = " CONFIGURACIÓN DE INSTALACIÓN";
            grpConfig.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
            grpConfig.ForeColor = COLOR_SECONDARY;
            
            TableLayoutPanel configLayout = new TableLayoutPanel();
            configLayout.Dock = DockStyle.Fill;
            configLayout.Padding = new Padding(10);
            configLayout.ColumnCount = 1;
            configLayout.RowCount = 4;
            configLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 35));     // Ruta
            configLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));     // Espacio
            configLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 35));     // Accesos directos
            configLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));     // Información
            
            // Fila 1: Ruta de instalación - CORREGIDO
            Panel dirPanel = new Panel();
            dirPanel.Dock = DockStyle.Fill;
            
            lblDirectory = new Label();
            lblDirectory.Text = "Ubicación:";
            lblDirectory.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            lblDirectory.ForeColor = COLOR_SECONDARY;
            lblDirectory.Location = new Point(0, 8);
            lblDirectory.Size = new Size(70, 20);
            
            txtDirectory = new TextBox();
            txtDirectory.Text = installPath;
            txtDirectory.Font = new Font("Segoe UI", 9F);
            txtDirectory.Location = new Point(80, 6);
            txtDirectory.Size = new Size(400, 24); // REDUCIDO para dar espacio al botón
            txtDirectory.BackColor = Color.White;
            txtDirectory.TextChanged += (s, e) => { 
                installPath = txtDirectory.Text; 
                UpdateDiskSpace();
            };
            
            btnBrowse = new Button();
            btnBrowse.Text = "Examinar";
            btnBrowse.Font = new Font("Segoe UI", 8F, FontStyle.Bold);
            btnBrowse.BackColor = COLOR_PRIMARY;
            btnBrowse.ForeColor = Color.White;
            btnBrowse.FlatStyle = FlatStyle.Flat;
            btnBrowse.FlatAppearance.BorderSize = 0;
            btnBrowse.Size = new Size(100, 25);
            btnBrowse.Location = new Point(490, 6); // POSICIÓN FIJA, NO ANCHOR
            btnBrowse.Cursor = Cursors.Hand;
            btnBrowse.Click += BtnBrowse_Click;
            
            // Añadir evento para redimensionar el textbox cuando cambie el tamaño
            dirPanel.SizeChanged += (s, e) => {
                // Cuando el panel cambie de tamaño, ajustar el textbox y botón
                int availableWidth = dirPanel.Width - 190; // 80 (label) + 10 (margen) + 100 (botón)
                if (availableWidth > 100) {
                    txtDirectory.Width = availableWidth;
                    btnBrowse.Left = 80 + availableWidth + 10;
                }
            };
            
            dirPanel.Controls.AddRange(new Control[] { lblDirectory, txtDirectory, btnBrowse });
            configLayout.Controls.Add(dirPanel, 0, 0);
            



            // Fila 2: Información de espacio en disco - CON ANCHORS
            Panel spacePanel = new Panel();
            spacePanel.Dock = DockStyle.Fill;
            spacePanel.Height = 40;
            
            lblDiskSpace = new Label();
            lblDiskSpace.Text = "Calculando espacio disponible...";
            lblDiskSpace.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            lblDiskSpace.ForeColor = COLOR_SECONDARY;
            lblDiskSpace.Location = new Point(80, 10);
            lblDiskSpace.Size = new Size(300, 20);
            lblDiskSpace.Anchor = AnchorStyles.Left | AnchorStyles.Top; // <-- ANCHOR
            
            lblSpaceWarning = new Label();
            lblSpaceWarning.Text = "";
            lblSpaceWarning.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            lblSpaceWarning.Location = new Point(390, 10);
            lblSpaceWarning.Size = new Size(250, 20);
            lblSpaceWarning.TextAlign = ContentAlignment.MiddleRight;
            lblSpaceWarning.Anchor = AnchorStyles.Top | AnchorStyles.Right; // <-- ANCHOR
            
            spacePanel.Controls.AddRange(new Control[] { lblDiskSpace, lblSpaceWarning });
            configLayout.Controls.Add(spacePanel, 0, 1);
            
            // Fila 3: Opciones de acceso directo
            Panel shortcutPanel = new Panel();
            shortcutPanel.Dock = DockStyle.Fill;
            
            chkDesktop = new CheckBox();
            chkDesktop.Text = "Acceso directo en escritorio";
            chkDesktop.Font = new Font("Segoe UI", 9F);
            chkDesktop.Checked = true;
            chkDesktop.Location = new Point(0, 8);
            chkDesktop.Size = new Size(180, 20);
            
            chkMenu = new CheckBox();
            chkMenu.Text = "Menú de aplicaciones";
            chkMenu.Font = new Font("Segoe UI", 9F);
            chkMenu.Checked = true;
            chkMenu.Location = new Point(190, 8);
            chkMenu.Size = new Size(160, 20);
            
            shortcutPanel.Controls.AddRange(new Control[] { chkDesktop, chkMenu });
            configLayout.Controls.Add(shortcutPanel, 0, 2);
            
            // Fila 4: Panel de información - USANDO TEXTBOX (SOLUCIÓN DEFINITIVA)
            pnlInfo = new Panel();
            pnlInfo.Dock = DockStyle.Fill;
            pnlInfo.BackColor = COLOR_INFO_BG;
            pnlInfo.BorderStyle = BorderStyle.FixedSingle;
            pnlInfo.Padding = new Padding(10, 15, 10, 10); // Más padding arriba
            
            Label infoTitle = new Label();
            infoTitle.Text = "INFORMACIÓN IMPORTANTE";
            infoTitle.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            infoTitle.ForeColor = COLOR_SECONDARY;
            infoTitle.Location = new Point(0, 0);
            infoTitle.Size = new Size(200, 20);
            
            // USANDO TEXTBOX MULTILÍNEA (SOLUCIÓN DEFINITIVA)
            TextBox infoContent = new TextBox();
            infoContent.Text = "• Descarga desde Google Drive (~20 GB)\r\n" +
                            "• Se requieren 25 GB de espacio disponible\r\n" +
                            "• Archivo temporal se elimina automáticamente\r\n" +
                            "• Descarga resumible con 3 reintentos";
            infoContent.Font = new Font("Segoe UI", 9F); // Fuente un poco más grande
            infoContent.ForeColor = Color.FromArgb(52, 73, 94);
            infoContent.BackColor = COLOR_INFO_BG;
            infoContent.BorderStyle = BorderStyle.None;
            infoContent.Multiline = true;
            infoContent.ReadOnly = true;
            infoContent.Location = new Point(0, 25);
            infoContent.Size = new Size(pnlInfo.Width - 20, pnlInfo.Height - 35); // Tamaño dinámico
            infoContent.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom; // <-- ANCHOR para redimensionar
            infoContent.ScrollBars = ScrollBars.None;
            
            pnlInfo.Controls.AddRange(new Control[] { infoTitle, infoContent });
            configLayout.Controls.Add(pnlInfo, 0, 3);
            
            grpConfig.Controls.Add(configLayout);
            mainLayout.Controls.Add(grpConfig, 0, 1);
            
            // ========== GRUPO PROGRESO CORREGIDO ==========
            grpProgress = new GroupBox();
            grpProgress.Dock = DockStyle.Fill;
            grpProgress.Text = " PROGRESO DE INSTALACIÓN";
            grpProgress.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
            grpProgress.ForeColor = COLOR_SECONDARY;
            
            TableLayoutPanel progressLayout = new TableLayoutPanel();
            progressLayout.Dock = DockStyle.Fill;
            progressLayout.Padding = new Padding(10);
            progressLayout.ColumnCount = 1;
            progressLayout.RowCount = 3;
            progressLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30)); // Estado
            progressLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30)); // Barra
            progressLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); // Log
            
            // Fila 1: Estado
            Panel statusPanel = new Panel();
            statusPanel.Dock = DockStyle.Fill;
            
            Label lblStatusTitle = new Label();
            lblStatusTitle.Text = "Progreso:";
            lblStatusTitle.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            lblStatusTitle.Location = new Point(0, 5);
            lblStatusTitle.Size = new Size(60, 20);
            
            lblStatus = new Label();
            lblStatus.Text = "Listo para comenzar la instalación";
            lblStatus.Font = new Font("Segoe UI", 9F);
            lblStatus.ForeColor = Color.FromArgb(52, 73, 94);
            lblStatus.Location = new Point(65, 5);
            lblStatus.Size = new Size(500, 20);
            lblStatus.Anchor = AnchorStyles.Left | AnchorStyles.Top | AnchorStyles.Right; // <-- ANCHOR
            
            statusPanel.Controls.AddRange(new Control[] { lblStatusTitle, lblStatus });
            progressLayout.Controls.Add(statusPanel, 0, 0);
            
            // Fila 2: Barra de progreso
            progressBar = new ProgressBar();
            progressBar.Dock = DockStyle.Fill;
            progressBar.Value = 0;
            progressBar.Style = ProgressBarStyle.Continuous;
            progressBar.ForeColor = COLOR_PRIMARY;
            progressBar.Height = 20;
            progressLayout.Controls.Add(progressBar, 0, 1);
            


            // Fila 3: Área de log (estilo Qt oscuro)
            Panel logPanel = new Panel();
            logPanel.Dock = DockStyle.Fill;
            
            Panel logHeader = new Panel();
            logHeader.Dock = DockStyle.Top;
            logHeader.Height = 35;
            logHeader.BackColor = COLOR_LOG_BG;
            logHeader.Padding = new Padding(10, 5, 10, 5);
                        

            Label lblLogTitle = new Label();
            lblLogTitle.Text = "REGISTRO DE INSTALACIÓN";
            lblLogTitle.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            lblLogTitle.ForeColor = Color.White;
            lblLogTitle.Dock = DockStyle.Left;
            lblLogTitle.TextAlign = ContentAlignment.MiddleLeft;
            lblLogTitle.AutoSize = false;
            lblLogTitle.Size = new Size(300, 20);


            btnClearLog = new Button();
            btnClearLog.Text = "Limpiar";
            btnClearLog.Font = new Font("Segoe UI", 8F);
            btnClearLog.BackColor = Color.FromArgb(108, 117, 125);
            btnClearLog.ForeColor = Color.White;
            btnClearLog.FlatStyle = FlatStyle.Flat;
            btnClearLog.FlatAppearance.BorderSize = 0;
            btnClearLog.Size = new Size(80, 25);
            btnClearLog.Dock = DockStyle.Right;
            btnClearLog.Cursor = Cursors.Hand;
            btnClearLog.Click += BtnClearLog_Click;
            
            logHeader.Controls.AddRange(new Control[] { lblLogTitle, btnClearLog });
            
            txtLog = new RichTextBox();
            txtLog.Dock = DockStyle.Fill;
            txtLog.ReadOnly = true;
            txtLog.BackColor = COLOR_LOG_BG;
            txtLog.ForeColor = COLOR_LOG_TEXT;
            txtLog.Font = new Font("Consolas", 9F);
            txtLog.BorderStyle = BorderStyle.None;
            txtLog.Padding = new Padding(10);
            
            logPanel.Controls.AddRange(new Control[] { logHeader, txtLog });
            progressLayout.Controls.Add(logPanel, 0, 2);
            
            grpProgress.Controls.Add(progressLayout);
            mainLayout.Controls.Add(grpProgress, 0, 2);

            // ========== BOTONES CON ANCHORS ==========
            Panel buttonPanel = new Panel();
            buttonPanel.Dock = DockStyle.Fill;
            buttonPanel.BackColor = Color.Transparent;
            buttonPanel.Padding = new Padding(15, 10, 15, 0);
            
            // Botón "Acerca de"
            btnAbout = new Button();
            btnAbout.Text = "Acerca de";
            btnAbout.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            btnAbout.BackColor = Color.FromArgb(108, 117, 125);
            btnAbout.ForeColor = Color.White;
            btnAbout.FlatStyle = FlatStyle.Flat;
            btnAbout.FlatAppearance.BorderSize = 0;
            btnAbout.FlatAppearance.MouseOverBackColor = Color.FromArgb(90, 98, 104);
            btnAbout.Size = new Size(110, 35);
            btnAbout.Location = new Point(15, 0);
            btnAbout.Cursor = Cursors.Hand;
            btnAbout.Click += BtnAbout_Click;
            
            // Contenedor para botones derechos
            Panel rightButtonsPanel = new Panel();
            rightButtonsPanel.Size = new Size(350, 40);
            rightButtonsPanel.Location = new Point(buttonPanel.Width - 365, 0);
            rightButtonsPanel.Anchor = AnchorStyles.Top | AnchorStyles.Right; // <-- ANCHOR IMPORTANTE
            
            // Botón "Salir"
            btnExit = new Button();
            btnExit.Text = "Salir";
            btnExit.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            btnExit.BackColor = COLOR_ERROR;
            btnExit.ForeColor = Color.White;
            btnExit.FlatStyle = FlatStyle.Flat;
            btnExit.FlatAppearance.BorderSize = 0;
            btnExit.FlatAppearance.MouseOverBackColor = Color.FromArgb(200, 60, 50);
            btnExit.Size = new Size(100, 35);
            btnExit.Location = new Point(0, 0);
            btnExit.Cursor = Cursors.Hand;
            btnExit.Click += BtnExit_Click;
            
            // Botón "INICIAR INSTALACIÓN"
            btnInstall = new Button();
            btnInstall.Text = "INICIAR INSTALACIÓN";
            btnInstall.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
            btnInstall.BackColor = COLOR_SUCCESS;
            btnInstall.ForeColor = Color.White;
            btnInstall.FlatStyle = FlatStyle.Flat;
            btnInstall.FlatAppearance.BorderSize = 0;
            btnInstall.FlatAppearance.MouseOverBackColor = Color.FromArgb(40, 180, 90);
            btnInstall.Size = new Size(200, 40);
            btnInstall.Location = new Point(110, 0);
            btnInstall.Cursor = Cursors.Hand;
            btnInstall.Click += BtnInstall_Click;
            
            rightButtonsPanel.Controls.AddRange(new Control[] { btnExit, btnInstall });
            buttonPanel.Controls.AddRange(new Control[] { btnAbout, rightButtonsPanel });
            mainLayout.Controls.Add(buttonPanel, 0, 3);
            
            // ========== FOOTER ==========
            Panel footerPanel = new Panel();
            footerPanel.Dock = DockStyle.Fill;
            footerPanel.BackColor = COLOR_FOOTER_BG;
            footerPanel.Padding = new Padding(8, 5, 8, 5);
            footerPanel.Height = 35;
            
            lblFooter = new Label();
            lblFooter.Dock = DockStyle.Fill;
            lblFooter.Text = "⚠️ Requiere conexión a Internet • Descarga resumible • 3 reintentos • Espacio temporal: 25 GB";
            lblFooter.Font = new Font("Segoe UI", 8.5F, FontStyle.Bold);
            lblFooter.ForeColor = Color.FromArgb(236, 240, 241);
            lblFooter.TextAlign = ContentAlignment.MiddleCenter;
            lblFooter.Padding = new Padding(5, 0, 5, 0);
            lblFooter.AutoEllipsis = true;
            
            footerPanel.Controls.Add(lblFooter);
            mainLayout.Controls.Add(footerPanel, 0, 4);
            
            // Agregar layout principal al formulario
            this.Controls.Add(mainLayout);
            
            // Asignar eventos
            this.Load += MainForm_Load;
            this.FormClosing += MainForm_FormClosing;
            this.Resize += MainForm_Resize;
        }  
        


        private void MainForm_Resize(object sender, EventArgs e)
        {
            // Asegurar que el texto de espacio no se corte
            int availableWidth = this.Width - 200;
            
            if (availableWidth < 500)
            {
                lblDiskSpace.Size = new Size(200, 20);
                lblSpaceWarning.Size = new Size(180, 20);
            }
            else if (availableWidth < 700)
            {
                lblDiskSpace.Size = new Size(300, 20);
                lblSpaceWarning.Size = new Size(250, 20);
            }
            else
            {
                lblDiskSpace.Size = new Size(400, 20);
                lblSpaceWarning.Size = new Size(300, 20);
            }
            
            // Ajustar el tamaño del texto del footer
            if (this.Width < 700)
            {
                lblFooter.Font = new Font("Segoe UI", 7F, FontStyle.Bold);
                lblFooter.Text = "⚠️ Internet • Resumible • 25 GB";
            }
            else if (this.Width < 850)
            {
                lblFooter.Font = new Font("Segoe UI", 7.5F, FontStyle.Bold);
                lblFooter.Text = "⚠️ Conexión Internet • Descarga resumible • 25 GB";
            }
            else
            {
                lblFooter.Font = new Font("Segoe UI", 8.5F, FontStyle.Bold);
                lblFooter.Text = "⚠️ Requiere conexión a Internet • Descarga resumible • 3 reintentos • Espacio temporal: 25 GB";
            }
            
            // Forzar redibujado para ajustar controles
            this.PerformLayout();
        }



        private void SetupUI()
        {
            // Configuraciones adicionales de UI

            // Primero una línea en blanco para separar
            txtLog.AppendText("\n");
            txtLog.AppendText("\n");
            txtLog.AppendText("\n");
 
            // SOLO ESTE MENSAJE INICIAL (elimina los otros)
            txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] Instalador listo. Selecciona ubicación y haz clic en Instalar.\n");
            
            // Configurar tooltips para mejor experiencia de usuario
            SetupToolTips();
        }

        private void SetupToolTips()
        {
            var toolTip = new ToolTip();
            toolTip.SetToolTip(btnBrowse, "Seleccionar carpeta de instalación");
            toolTip.SetToolTip(btnClearLog, "Limpiar el registro de instalación");
            toolTip.SetToolTip(btnAbout, "Acerca del instalador");
            toolTip.SetToolTip(btnExit, "Salir del instalador");
            toolTip.SetToolTip(btnInstall, "Iniciar instalación de Atlas Interactivo");
            toolTip.SetToolTip(txtDirectory, "Ruta donde se instalará el programa");
            toolTip.SetToolTip(chkDesktop, "Crear acceso directo en el escritorio");
            toolTip.SetToolTip(chkMenu, "Añadir al menú de aplicaciones");
        }



        private void UpdateDiskSpace()
        {
            try
            {
                if (string.IsNullOrEmpty(installPath) || isInstalling)
                    return;
                    
                const long REQUIRED_SPACE_GB = 25;
                
                string drivePath = Path.GetPathRoot(installPath);
                if (string.IsNullOrEmpty(drivePath))
                    drivePath = "C:\\";
                
                DriveInfo drive = new DriveInfo(drivePath);
                
                if (drive.IsReady)
                {
                    double availableGB = drive.AvailableFreeSpace / (1024.0 * 1024.0 * 1024.0);
                    long requiredBytes = REQUIRED_SPACE_GB * 1024L * 1024L * 1024L;
                    
                    if (drive.AvailableFreeSpace >= requiredBytes)
                    {
                        // Suficiente espacio - LETRERO VERDE VISIBLE
                        lblDiskSpace.Text = $"Espacio disponible en {drive.Name}: {availableGB:F2} GB";
                        lblDiskSpace.ForeColor = COLOR_SUCCESS;
                        lblDiskSpace.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                        
                        lblSpaceWarning.Text = "✅ ESPACIO SUFICIENTE";
                        lblSpaceWarning.ForeColor = COLOR_SUCCESS;
                        lblSpaceWarning.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                        
                        // LOG EN COLOR VERDE usando AppendText con color
                        string logMessage = $"[{DateTime.Now:HH:mm:ss}] ✅ Espacio suficiente: {availableGB:F2} GB disponibles";
                        AppendColoredLogMessage(logMessage, COLOR_SUCCESS);
                        
                        btnInstall.Enabled = true;
                    }
                    else
                    {
                        // Espacio insuficiente - LETRERO ROJO VISIBLE
                        lblDiskSpace.Text = $"Espacio disponible en {drive.Name}: {availableGB:F2} GB";
                        lblDiskSpace.ForeColor = COLOR_ERROR;
                        lblDiskSpace.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                        
                        lblSpaceWarning.Text = $"❌ REQUIERE {REQUIRED_SPACE_GB} GB";
                        lblSpaceWarning.ForeColor = COLOR_ERROR;
                        lblSpaceWarning.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                        
                        // LOG EN COLOR ROJO
                        string logMessage = $"[{DateTime.Now:HH:mm:ss}] ❌ Espacio insuficiente: {availableGB:F2} GB disponibles, se requieren {REQUIRED_SPACE_GB} GB";
                        AppendColoredLogMessage(logMessage, COLOR_ERROR);
                        
                        btnInstall.Enabled = false;
                    }
                }
                else
                {
                    lblDiskSpace.Text = "No se puede acceder a la unidad";
                    lblDiskSpace.ForeColor = Color.Gray;
                    lblDiskSpace.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                    
                    lblSpaceWarning.Text = "⚠️ VERIFICACIÓN FALLIDA";
                    lblSpaceWarning.ForeColor = COLOR_WARNING;
                    lblSpaceWarning.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                    
                    AppendColoredLogMessage($"[{DateTime.Now:HH:mm:ss}] ⚠️ No se puede verificar el espacio en disco", COLOR_WARNING);
                }
            }
            catch (Exception ex)
            {
                lblDiskSpace.Text = "No se pudo verificar el espacio";
                lblDiskSpace.ForeColor = Color.Gray;
                lblDiskSpace.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                
                lblSpaceWarning.Text = "⚠️ ERROR DE VERIFICACIÓN";
                lblSpaceWarning.ForeColor = COLOR_WARNING;
                lblSpaceWarning.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
                
                btnInstall.Enabled = true; // Permitir instalación si no se puede verificar
                AppendColoredLogMessage($"[{DateTime.Now:HH:mm:ss}] ⚠️ Error verificando espacio: {ex.Message}", COLOR_WARNING);
            }
        }


        private void AppendColoredLogMessage(string message, Color color)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => AppendColoredLogMessage(message, color)));
                return;
            }
            
            // Guardar la posición del cursor
            int start = txtLog.TextLength;
            
            // Añadir el texto
            txtLog.AppendText(message + "\n");
            
            // Aplicar color a la parte recién añadida
            int end = txtLog.TextLength;
            
            txtLog.Select(start, end - start);
            txtLog.SelectionColor = color;
            txtLog.SelectionLength = 0; // Deseleccionar
            
            // Desplazar al final
            txtLog.ScrollToCaret();
        }
        
        // ========== EVENT HANDLERS ==========

        private void BtnBrowse_Click(object sender, EventArgs e)
        {
            if (isInstalling)
            {
                MessageBox.Show("No se puede cambiar la ubicación durante la instalación.", 
                    "Instalación en progreso", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            
            using (var dialog = new FolderBrowserDialog())
            {
                dialog.Description = "Selecciona carpeta para instalar Atlas Interactivo";
                dialog.ShowNewFolderButton = true;
                dialog.SelectedPath = txtDirectory.Text;
                
                // **MEJOR SOLUCIÓN: Centrar manualmente el diálogo**
                
                // Calcular posición para el diálogo (arriba de nuestra ventana)
                int dialogTop = Math.Max(50, this.Top - 350);
                int dialogLeft = this.Left + (this.Width / 2) - 200;
                
                // Usar reflexión para intentar posicionar el diálogo
                try
                {
                    // Intentar establecer la posición (esto funciona en Windows)
                    typeof(Form).GetField("defaultDialogLocation", 
                        System.Reflection.BindingFlags.NonPublic | 
                        System.Reflection.BindingFlags.Static)?
                        .SetValue(null, new Point(dialogLeft, dialogTop));
                }
                catch
                {
                    // Si falla, usar método simple
                }
                
                // Mostrar el diálogo
                DialogResult result = dialog.ShowDialog();
                
                if (result == DialogResult.OK)
                {
                    txtDirectory.Text = dialog.SelectedPath;
                    installPath = dialog.SelectedPath;
                    
                    UpdateDiskSpace();
                    LogMessage($"Ubicación cambiada a: {installPath}");
                }
            }
        }

        private void BtnClearLog_Click(object sender, EventArgs e)
        {
            if (isInstalling)
            {
                MessageBox.Show("No se puede limpiar el registro durante la instalación.", 
                    "Instalación en progreso", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            
            var result = MessageBox.Show("¿Estás seguro de que deseas limpiar el registro?", 
                "Confirmar limpieza", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            
            if (result == DialogResult.Yes)
            {
                // LIMPIA el RichTextBox
                txtLog.Clear();
                
                // Añade SOLO UNA VEZ el mensaje (sin usar LogMessage que duplica el timestamp)
                txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] Registro limpiado por el usuario\n");
                
                // Si quieres mantener un mensaje inicial después de limpiar
                txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] Instalador listo. Selecciona ubicación y haz clic en Instalar.\n");
            }
        }

        private void BtnAbout_Click(object sender, EventArgs e)
        {
            MessageBox.Show(
                "Atlas Interactivo\n\n" +
                "Instalador para Windows v1.0.0\n" +
                "© 2025 Atlas Interactivo Team\n\n" +
                "Características:\n" +
                "• Descarga resumible con 3 reintentos\n" +
                "• Extracción automática\n" +
                "• Espacio temporal máximo: 25 GB\n" +
                "• Verificación de espacio en tiempo real\n" +
                "• Registro detallado de instalación",
                "Acerca de Atlas Interactivo",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
        }
        
        private void BtnExit_Click(object sender, EventArgs e)
        {
            if (isInstalling)
            {
                var result = MessageBox.Show(
                    "La instalación está en progreso. ¿Estás seguro de que deseas salir?",
                    "Confirmar salida",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);
                
                if (result == DialogResult.Yes)
                {
                    if (downloadClient != null && downloadClient.IsBusy)
                    {
                        downloadClient.CancelAsync();
                    }
                    Application.Exit();
                }
            }
            else
            {
                Application.Exit();
            }
        }
        


        private async void BtnInstall_Click(object sender, EventArgs e)
        {
            if (isInstalling) return;
            
            // Validar ruta
            if (string.IsNullOrWhiteSpace(txtDirectory.Text))
            {
                MessageBox.Show("Por favor, selecciona una ubicación para la instalación.",
                    "Ubicación requerida", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            
            // Verificar espacio en disco
            if (!CheckDiskSpace(installPath, 25))
            {
                MessageBox.Show(
                    "Se requieren al menos 25 GB de espacio libre en la unidad.\n\n" +
                    $"Espacio disponible: {GetAvailableSpaceGB(installPath):F2} GB\n" +
                    "Espacio requerido: 25 GB",
                    "Espacio insuficiente",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }
            
            // Verificar si el directorio está vacío
            if (Directory.Exists(installPath) && !IsDirectoryEmpty(installPath))
            {
                var result = MessageBox.Show(
                    $"El directorio '{installPath}' no está vacío.\n\n" +
                    "¿Deseas continuar? Los archivos existentes podrían ser sobrescritos.",
                    "Directorio no vacío",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);
                
                if (result != DialogResult.Yes) return;
            }
            
            // Confirmar instalación
            var confirmResult = MessageBox.Show(
                "MÉTODO OPTIMIZADO ACTIVADO\n\n" +
                "✓ Descarga resumible con 3 reintentos\n" +
                "✓ Extracción automática\n" +
                "✓ Espacio temporal máximo: 25 GB\n\n" +
                "¿Desea continuar con la instalación?",
                "Confirmar instalación",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);
            
            if (confirmResult != DialogResult.Yes) return;
            
            isInstalling = true;
            
            btnInstall.Enabled = false;
            btnBrowse.Enabled = false;
            btnExit.Enabled = false;
            btnAbout.Enabled = false;
            btnInstall.Text = "Instalando...";
            
            txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] Iniciando instalación...\n");
            txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] Descarga resumible activada\n");
            txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] Espacio temporal máximo: 25 GB\n");
            
            // Ejecutar instalación en segundo plano
            await Task.Run(() => InstallAtlas());
            
            btnInstall.Enabled = true;
            btnBrowse.Enabled = true;
            btnExit.Enabled = true;
            btnAbout.Enabled = true;
            btnInstall.Text = "INICIAR INSTALACIÓN";
            
            // Actualizar espacio después de instalación (UNA SOLA VEZ)
            UpdateDiskSpace();
        }


        private void MainForm_Load(object sender, EventArgs e)
        {
            // Asegurar que todo esté visible
            this.Refresh();
            
            // **REDUCIR EL TAMAÑO DE LA VENTANA AL CARGAR**
            this.Height = Math.Min(750, Screen.PrimaryScreen.Bounds.Height - 100);
            
            // Asegurar que la ventana esté activa y visible
            this.TopMost = true;
            this.TopMost = false; // Esto trae la ventana al frente
            this.Activate();
            this.Focus();
        }


        private void MainForm_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (isInstalling)
            {
                var result = MessageBox.Show(
                    "La instalación está en progreso. ¿Estás seguro de que deseas salir?",
                    "Confirmar salida",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);
                
                if (result != DialogResult.Yes)
                {
                    e.Cancel = true;
                }
                else if (downloadClient != null && downloadClient.IsBusy)
                {
                    downloadClient.CancelAsync();
                }
            }
            
            // NO HAY TIMER QUE LIMPIAR
        }

        // ========== LÓGICA DE INSTALACIÓN ==========
        
        private void InstallAtlas()
        {
            string tempFile = null;
            
            try
            {
                // ID de Google Drive (mismo que en Qt)
                // string driveId = "1vzAxSaKRXIPSNf937v6xjuBhRyrCiVRF";
                string driveId = "1X-ZkC1hHNTEivXDoCOZQKgVODeWdN5LW";

                
                // Actualizar UI
                UpdateStatus("Verificando espacio en disco...", 5);
                LogMessage("Verificando requisitos del sistema...");
                
                // Crear directorio si no existe
                Directory.CreateDirectory(installPath);
                
                // Descarga real
                UpdateStatus("Descargando desde Google Drive...", 10);
                LogMessage($"Iniciando descarga desde Google Drive...");
                
                // Crear archivo temporal
                tempFile = Path.Combine(Path.GetTempPath(), $"atlas_{Guid.NewGuid()}.zip");
                
                // URL de descarga de Google Drive
                string downloadUrl = $"https://drive.google.com/uc?id={driveId}&export=download&confirm=t";
                
                LogMessage($"URL de descarga: {downloadUrl}");
                LogMessage($"Archivo temporal: {tempFile}");
                
                // Descargar con WebClient
                downloadClient = new WebClient();
                
                // Configurar eventos
                downloadClient.DownloadProgressChanged += (s, e) =>
                {
                    int progress = 10 + (int)(e.BytesReceived * 0.4 / e.TotalBytesToReceive);
                    UpdateProgress(progress);
                    UpdateStatus($"Descargando: {e.BytesReceived / (1024 * 1024):N0} MB de {e.TotalBytesToReceive / (1024 * 1024):N0} MB", progress);
                    
                    if (e.ProgressPercentage % 10 == 0 && e.ProgressPercentage > 0)
                    {
                        LogMessage($"Progreso: {e.ProgressPercentage}% - Descargado: {e.BytesReceived / (1024 * 1024):N0} MB");
                    }
                };
                
                downloadClient.DownloadFileCompleted += (s, e) =>
                {
                    if (e.Cancelled)
                    {
                        LogMessage("❌ Descarga cancelada por el usuario");
                        UpdateStatus("Descarga cancelada", 0);
                    }
                    else if (e.Error != null)
                    {
                        LogMessage($"❌ Error en la descarga: {e.Error.Message}");
                        UpdateStatus("Error en la descarga", 0);
                    }
                    else
                    {
                        LogMessage("✅ Descarga completada");
                        UpdateStatus("Descarga completada", 50);
                    }
                };
                
                // Iniciar descarga asíncrona
                var downloadTask = downloadClient.DownloadFileTaskAsync(new Uri(downloadUrl), tempFile);
                
                // Esperar a que termine la descarga
                downloadTask.Wait();
                
                if (!isInstalling)
                {
                    LogMessage("Instalación cancelada por el usuario");
                    if (tempFile != null && File.Exists(tempFile)) File.Delete(tempFile);
                    return;
                }
                
                // Verificar archivo descargado
                if (!File.Exists(tempFile) || new FileInfo(tempFile).Length == 0)
                {
                    throw new Exception("El archivo descargado está vacío o no existe");
                }
                
                long fileSize = new FileInfo(tempFile).Length;
                LogMessage($"✅ Descarga completada: {fileSize / (1024 * 1024):N0} MB");
                UpdateStatus("Descarga completada", 50);
                
                // Extraer archivo
                UpdateStatus("Extrayendo archivos...", 55);
                LogMessage("Extrayendo archivo ZIP...");
                
                // Extraer ZIP
                using (ZipArchive archive = ZipFile.OpenRead(tempFile))
                {
                    int totalEntries = archive.Entries.Count;
                    int currentEntry = 0;
                    
                    LogMessage($"Total de archivos a extraer: {totalEntries}");
                    
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        if (!isInstalling) break;
                        
                        string fullPath = Path.Combine(installPath, entry.FullName);
                        
                        // Crear directorio si es necesario
                        if (entry.Name == "")
                        {
                            Directory.CreateDirectory(Path.GetDirectoryName(fullPath));
                            continue;
                        }
                        
                        // Extraer archivo
                        try
                        {
                            entry.ExtractToFile(fullPath, true);
                        }
                        catch (Exception ex)
                        {
                            LogMessage($"⚠️ Error extrayendo {entry.FullName}: {ex.Message}");
                        }
                        
                        currentEntry++;
                        int progress = 55 + (int)(currentEntry * 40.0 / totalEntries);
                        UpdateProgress(progress);
                        
                        if (currentEntry % 100 == 0 || currentEntry == totalEntries)
                        {
                            LogMessage($"Extrayendo: {currentEntry}/{totalEntries} archivos");
                            UpdateStatus($"Extrayendo: {currentEntry}/{totalEntries} archivos", progress);
                        }
                    }
                }
                
                if (!isInstalling)
                {
                    LogMessage("Instalación cancelada por el usuario");
                    if (tempFile != null && File.Exists(tempFile)) File.Delete(tempFile);
                    return;
                }
                
                // Eliminar archivo temporal
                if (tempFile != null && File.Exists(tempFile))
                {
                    File.Delete(tempFile);
                    LogMessage("Archivo temporal eliminado");
                }
                
                // Crear archivo de versión
                CreateVersionFile();
                
                // Completar
                UpdateStatus("Instalación completada", 100);
                LogMessage("¡Instalación completada exitosamente!");
                LogMessage($"Ubicación: {installPath}");
                
                // Mostrar mensaje de éxito
                this.Invoke(new Action(() =>
                {
                    MessageBox.Show(
                        "✅ INSTALACIÓN COMPLETADA\n\n" +
                        "Atlas Interactivo se ha instalado exitosamente\n\n" +
                        $"Ubicación:\n{installPath}\n\n" +
                        "¡Gracias por instalar Atlas Interactivo!",
                        "Instalación Completada",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                }));
                
                isInstalling = false;
            }
            catch (WebException ex) when (ex.Status == WebExceptionStatus.NameResolutionFailure)
            {
                LogMessage("❌ ERROR: No se puede resolver 'drive.google.com'");
                LogMessage("   Verifica tu conexión a Internet");
                UpdateStatus("Error de conexión", 0);
                
                this.Invoke(new Action(() =>
                {
                    MessageBox.Show(
                        "❌ ERROR DE CONEXIÓN\n\n" +
                        "No se puede conectar a Google Drive\n\n" +
                        "Posibles soluciones:\n" +
                        "• Verifica tu conexión a Internet\n" +
                        "• Verifica el firewall/antivirus\n" +
                        "• Intenta nuevamente más tarde",
                        "Error de conexión",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                }));
            }
            catch (WebException ex) when ((ex.Response as HttpWebResponse)?.StatusCode == HttpStatusCode.NotFound)
            {
                LogMessage("❌ ERROR: Archivo no encontrado en Google Drive (404)");
                UpdateStatus("Archivo no encontrado", 0);
                
                this.Invoke(new Action(() =>
                {
                    MessageBox.Show(
                        "❌ ARCHIVO NO ENCONTRADO\n\n" +
                        "No se encontró el archivo en Google Drive\n\n" +
                        "Posibles causas:\n" +
                        "• El archivo fue movido o eliminado\n" +
                        "• El ID del archivo es incorrecto\n" +
                        "• Contacta al soporte técnico",
                        "Error de descarga",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                }));
            }
            catch (OperationCanceledException)
            {
                LogMessage("Instalación cancelada por el usuario");
                UpdateStatus("Instalación cancelada", 0);
            }
            catch (Exception ex)
            {
                LogMessage($"❌ ERROR: {ex.Message}");
                LogMessage($"Detalles: {ex.GetType().Name}");
                UpdateStatus("Instalación fallida", 0);
                
                this.Invoke(new Action(() =>
                {
                    MessageBox.Show(
                        "❌ ERROR EN LA INSTALACIÓN\n\n" +
                        $"{ex.Message}\n\n" +
                        "Posibles soluciones:\n" +
                        "• Verifica tu conexión a Internet\n" +
                        "• Asegúrate de tener al menos 25 GB libres\n" +
                        "• Verifica permisos de escritura\n" +
                        "• Intenta nuevamente",
                        "Error de instalación",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                }));
            }
            finally
            {
                // Limpiar
                if (tempFile != null && File.Exists(tempFile))
                {
                    try { File.Delete(tempFile); } catch { }
                }
                
                downloadClient?.Dispose();
                downloadClient = null;
                
                this.Invoke(new Action(() =>
                {
                    isInstalling = false;
                    btnInstall.Enabled = true;
                    btnBrowse.Enabled = true;
                    btnExit.Enabled = true;
                    btnAbout.Enabled = true;
                    btnInstall.Text = "INICIAR INSTALACIÓN";
                }));
            }
        }
        
        // ========== MÉTODOS AUXILIARES ==========
        
        private void UpdateStatus(string message, int progress)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => UpdateStatus(message, progress)));
                return;
            }
            
            lblStatus.Text = message;
            progressBar.Value = Math.Min(100, Math.Max(0, progress));
        }
        
        private void UpdateProgress(int value)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => UpdateProgress(value)));
                return;
            }
            
            progressBar.Value = Math.Min(100, Math.Max(0, value));
        }
                


        private void LogMessage(string message, Color? color = null)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => LogMessage(message, color)));
                return;
            }
            
            // SOLO usar AppendColoredLogMessage si hay color
            if (color.HasValue)
            {
                AppendColoredLogMessage($"[{DateTime.Now:HH:mm:ss}] {message}", color.Value);
            }
            else
            {
                // Añadir directamente con timestamp
                txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}\n");
                txtLog.ScrollToCaret();
            }
        }


        // ========== MÉTODOS DE VERIFICACIÓN ==========
        
        private bool CheckDiskSpace(string path, long requiredGB = 25)
        {
            try
            {
                DriveInfo drive = new DriveInfo(Path.GetPathRoot(path));
                long availableSpaceGB = drive.AvailableFreeSpace / (1024 * 1024 * 1024);
                return availableSpaceGB >= requiredGB;
            }
            catch
            {
                return false; // Si hay error, no permitir instalación
            }
        }
        
        private double GetAvailableSpaceGB(string path)
        {
            try
            {
                DriveInfo drive = new DriveInfo(Path.GetPathRoot(path));
                return drive.AvailableFreeSpace / (1024.0 * 1024.0 * 1024.0);
            }
            catch
            {
                return 0;
            }
        }
        
        private bool IsDirectoryEmpty(string path)
        {
            if (!Directory.Exists(path))
                return true;
                
            return !Directory.EnumerateFileSystemEntries(path).Any();
        }
        
        private void CreateVersionFile()
        {
            try
            {
                string versionFile = Path.Combine(installPath, ".atlas_version.json");
                
                string json = $@"{{
  ""version"": ""1.0.0"",
  ""installed"": true,
  ""install_path"": ""{installPath.Replace("\\", "\\\\")}"",
  ""install_date"": ""{DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss")}"",
  ""file_type"": ""zip"",
  ""download_size"": ""20 GB"",
  ""platform"": ""windows""
}}";
                
                File.WriteAllText(versionFile, json);
                LogMessage("✅ Archivo de versión creado");
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ No se pudo crear archivo de versión: {ex.Message}");
            }
        }
    }
    
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}