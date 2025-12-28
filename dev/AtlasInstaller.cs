using System;
using System.IO;
using System.Net;
using System.Windows.Forms;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.IO.Compression;

namespace AtlasInstaller
{
    public partial class MainForm : Form
    {
        // Para detectar si estamos en Windows o Linux/Mono
        private bool IsWindows = Environment.OSVersion.Platform == PlatformID.Win32NT;
        
        public MainForm()
        {
            InitializeComponent();
            SetupModernUI();
        }

        private void SetupModernUI()
        {
            // Configuración moderna de la interfaz
            this.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            this.BackColor = Color.FromArgb(240, 240, 240);
            
            // Hacer la ventana redimensionable solo en Windows
            // En Linux con Mono, Sizable puede causar problemas
            this.FormBorderStyle = IsWindows ? FormBorderStyle.Sizable : FormBorderStyle.FixedDialog;
            this.MaximizeBox = IsWindows;
            this.MinimizeBox = true;
            
            // Configurar tamaño inicial - VERSIÓN SIMPLIFICADA
            if (IsWindows)
            {
                // Solo en Windows usar Screen.PrimaryScreen
                try
                {
                    Rectangle screen = Screen.PrimaryScreen.WorkingArea;
                    this.Width = (int)(screen.Width * 0.5);
                    this.Height = (int)(screen.Height * 0.6);
                }
                catch
                {
                    // Fallback a tamaño fijo
                    this.Width = 600;
                    this.Height = 400;
                }
            }
            else
            {
                // En Linux, tamaño fijo pero más grande
                this.Width = 600;
                this.Height = 400;
            }
            
            // Centrar ventana
            this.StartPosition = FormStartPosition.CenterScreen;
            
            // Configurar colores y estilos
            lblTitle.Font = new Font("Segoe UI", 14F, FontStyle.Bold, GraphicsUnit.Point);
            lblTitle.ForeColor = Color.FromArgb(44, 62, 80);
            
            lblStatus.Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);
            lblStatus.ForeColor = Color.FromArgb(127, 140, 141);
            
            lblProgress.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            lblProgress.ForeColor = Color.FromArgb(52, 152, 219);
            
            progressBar.BackColor = Color.FromArgb(236, 240, 241);
            progressBar.ForeColor = Color.FromArgb(52, 152, 219);
            
            btnCancel.BackColor = Color.FromArgb(231, 76, 60);
            btnCancel.ForeColor = Color.White;
            btnCancel.FlatStyle = FlatStyle.Flat;
            btnCancel.FlatAppearance.BorderSize = 0;
            
            // Solo configurar resize en Windows
            if (IsWindows)
            {
                this.Resize += MainForm_Resize;
            }
        }

        private async void MainForm_Load(object sender, EventArgs e)
        {
            lblStatus.Text = "Preparando instalación...";
            
            // Verificar espacio en disco (versión simplificada)
            if (!CheckDiskSpace())
            {
                MessageBox.Show("Espacio en disco insuficiente. Necesitas al menos 20GB libres.", 
                    "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Application.Exit();
                return;
            }
            
            await InstallAtlasAsync();
        }

        private bool CheckDiskSpace()
        {
            try
            {
                if (IsWindows)
                {
                    // Versión Windows
                    string systemDrive = Path.GetPathRoot(Environment.GetFolderPath(Environment.SpecialFolder.System));
                    DriveInfo drive = new DriveInfo(systemDrive);
                    long freeSpaceGB = drive.AvailableFreeSpace / (1024 * 1024 * 1024);
                    return freeSpaceGB >= 20;
                }
                else
                {
                    // Versión Linux/Mono - simplificada
                    // En Linux, verificar espacio en el home del usuario
                    string homePath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                    try
                    {
                        DriveInfo drive = new DriveInfo(Path.GetPathRoot(homePath) ?? "/");
                        long freeSpaceGB = drive.AvailableFreeSpace / (1024 * 1024 * 1024);
                        return freeSpaceGB >= 20;
                    }
                    catch
                    {
                        return true; // Si no podemos verificar, asumimos que hay espacio
                    }
                }
            }
            catch
            {
                return true; // Si no podemos verificar, asumimos que hay espacio
            }
        }

        private async Task InstallAtlasAsync()
        {
            try
            {
                // 1. Seleccionar carpeta
                using (var dialog = new FolderBrowserDialog())
                {
                    dialog.Description = "Selecciona carpeta para instalar Atlas Interactivo";
                    dialog.ShowNewFolderButton = true;
                    
                    // Root folder que funcione en ambos sistemas
                    dialog.RootFolder = Environment.SpecialFolder.MyComputer;
                    
                    if (dialog.ShowDialog() != DialogResult.OK)
                    {
                        MessageBox.Show("Instalación cancelada", "Atlas Interactivo", 
                            MessageBoxButtons.OK, MessageBoxIcon.Information);
                        Application.Exit();
                        return;
                    }
                    
                    string installPath = dialog.SelectedPath;
                    lblStatus.Text = $"Instalando en: {installPath}";
                    
                    // Verificar que la carpeta esté vacía (opcional, simplificado)
                    try
                    {
                        if (Directory.Exists(installPath) && 
                            Directory.GetFiles(installPath).Length > 0 &&
                            Directory.GetDirectories(installPath).Length > 0)
                        {
                            DialogResult result = MessageBox.Show(
                                "La carpeta seleccionada no está vacía. ¿Deseas continuar?",
                                "Advertencia",
                                MessageBoxButtons.YesNo,
                                MessageBoxIcon.Warning);
                            
                            if (result != DialogResult.Yes)
                            {
                                Application.Exit();
                                return;
                            }
                        }
                    }
                    catch
                    {
                        // Continuar incluso si no podemos verificar
                    }
                    
                    // 2. Descargar archivos
                    lblStatus.Text = "Descargando Atlas Interactivo...";
                    bool downloadSuccess = await DownloadFilesAsync(installPath);
                    
                    if (!downloadSuccess)
                    {
                        MessageBox.Show("Error durante la descarga. Verifica tu conexión a internet.", 
                            "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        Application.Exit();
                        return;
                    }
                    
                    // 3. Extraer
                    lblStatus.Text = "Extrayendo archivos...";
                    bool extractSuccess = ExtractFiles(installPath);
                    
                    if (!extractSuccess)
                    {
                        MessageBox.Show("Error extrayendo archivos.", 
                            "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        Application.Exit();
                        return;
                    }
                    
                    // 4. Crear acceso directo (solo si es posible)
                    try
                    {
                        lblStatus.Text = "Finalizando instalación...";
                        CreateShortcut(installPath);
                    }
                    catch
                    {
                        // No es crítico si falla el acceso directo
                    }
                    
                    // 5. Mostrar mensaje de éxito
                    lblStatus.Text = "¡Instalación completada!";
                    progressBar.Value = 100;
                    
                    DialogResult launchResult = MessageBox.Show(
                        "¡Atlas Interactivo se ha instalado exitosamente!\n\n" +
                        $"Carpeta de instalación: {installPath}\n\n" +
                        "¿Deseas abrir la carpeta de instalación?",
                        "Instalación Completada", 
                        MessageBoxButtons.YesNo, 
                        MessageBoxIcon.Information);
                    
                    if (launchResult == DialogResult.Yes)
                    {
                        OpenInstallFolder(installPath);
                    }
                    
                    Application.Exit();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}", "Error", 
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
                Application.Exit();
            }
        }

        private async Task<bool> DownloadFilesAsync(string installPath)
        {
            try
            {
                // URL del archivo en Google Drive
                string fileId = "TU_FILE_ID_DE_DRIVE"; // Cambiar por tu ID real
                string downloadUrl = $"https://drive.google.com/uc?export=download&id={fileId}";
                
                using (var client = new WebClient())
                {
                    client.DownloadProgressChanged += (s, e) =>
                    {
                        // Asegurarse de que estamos en el hilo de la UI
                        if (this.InvokeRequired)
                        {
                            this.Invoke(new Action(() =>
                            {
                                progressBar.Value = e.ProgressPercentage;
                                lblProgress.Text = $"{e.ProgressPercentage}% - {e.BytesReceived / 1024 / 1024}MB";
                                lblStatus.Text = $"Descargando... {e.ProgressPercentage}%";
                                
                                // Actualizar título de ventana con progreso
                                this.Text = $"Instalador Atlas Interactivo - {e.ProgressPercentage}%";
                            }));
                        }
                        else
                        {
                            progressBar.Value = e.ProgressPercentage;
                            lblProgress.Text = $"{e.ProgressPercentage}% - {e.BytesReceived / 1024 / 1024}MB";
                            lblStatus.Text = $"Descargando... {e.ProgressPercentage}%";
                            this.Text = $"Instalador Atlas Interactivo - {e.ProgressPercentage}%";
                        }
                    };
                    
                    string tempFile = Path.Combine(Path.GetTempPath(), "atlas_temp.zip");
                    await client.DownloadFileTaskAsync(new Uri(downloadUrl), tempFile);
                    
                    // Mover a carpeta de instalación
                    string destFile = Path.Combine(installPath, "atlas_files.zip");
                    if (File.Exists(tempFile))
                    {
                        File.Move(tempFile, destFile);
                        return true;
                    }
                    
                    return false;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error descargando: {ex.Message}", "Error", 
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
        }

        private bool ExtractFiles(string installPath)
        {
            try
            {
                string zipFile = Path.Combine(installPath, "atlas_files.zip");
                string extractPath = installPath;
                
                if (!File.Exists(zipFile))
                {
                    MessageBox.Show("No se encontró el archivo descargado.", "Error", 
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return false;
                }
                
                // Método universal: usar System.IO.Compression que funciona en ambos
                try
                {
                    // Crear directorio si no existe
                    if (!Directory.Exists(extractPath))
                        Directory.CreateDirectory(extractPath);
                    
                    // Extraer con System.IO.Compression
                    ZipFile.ExtractToDirectory(zipFile, extractPath);
                    
                    // Eliminar zip después de extraer
                    File.Delete(zipFile);
                    return true;
                }
                catch (Exception zipEx)
                {
                    // Fallback: intentar con herramienta externa
                    return ExtractWithExternalTool(zipFile, extractPath);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error extrayendo: {ex.Message}", "Error", 
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
        }

        private bool ExtractWithExternalTool(string zipFile, string extractPath)
        {
            try
            {
                if (IsWindows)
                {
                    // En Windows, intentar con PowerShell
                    string command = $@"Expand-Archive -Path '{zipFile}' -DestinationPath '{extractPath}' -Force";
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = "powershell",
                        Arguments = $"-Command \"{command}\"",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };
                    
                    using (Process process = Process.Start(psi))
                    {
                        process.WaitForExit(30000); // 30 segundos timeout
                        if (process.ExitCode == 0 && File.Exists(zipFile))
                        {
                            File.Delete(zipFile);
                            return true;
                        }
                    }
                }
                else
                {
                    // En Linux, intentar con unzip
                    string unzipCommand = IsWindows ? "powershell Expand-Archive" : "unzip";
                    
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = IsWindows ? "powershell" : "unzip",
                        Arguments = IsWindows ? 
                            $"-Command \"Expand-Archive -Path '{zipFile}' -DestinationPath '{extractPath}' -Force\"" :
                            $"-o '{zipFile}' -d '{extractPath}'",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };
                    
                    using (Process process = Process.Start(psi))
                    {
                        process.WaitForExit(30000);
                        if (process.ExitCode == 0 && File.Exists(zipFile))
                        {
                            File.Delete(zipFile);
                            return true;
                        }
                    }
                }
                
                // Si llegamos aquí, falló
                MessageBox.Show("No se pudo extraer el archivo. Por favor, extrae manualmente el archivo .zip", 
                    "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
            catch
            {
                return false;
            }
        }

        private void CreateShortcut(string installPath)
        {
            try
            {
                string exePath = Path.Combine(installPath, "Atlas_Interactivo.exe");
                
                if (File.Exists(exePath))
                {
                    if (IsWindows)
                    {
                        // En Windows, crear archivo .url
                        string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
                        string urlShortcut = Path.Combine(desktopPath, "Atlas Interactivo.url");
                        string urlContent = $"[InternetShortcut]\nURL=file:///{exePath.Replace("\\", "/")}\nIconIndex=0\nIconFile={exePath}";
                        
                        File.WriteAllText(urlShortcut, urlContent);
                    }
                    else
                    {
                        // En Linux, crear un script .desktop simple
                        string desktopPath = Path.Combine(
                            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                            "Desktop",
                            "Atlas_Interactivo.desktop");
                        
                        string desktopContent = $@"[Desktop Entry]
Version=1.0
Type=Application
Name=Atlas Interactivo
Comment=Atlas Interactivo
Exec={exePath}
Icon=
Terminal=false
Categories=Education;Geography;
";
                        
                        File.WriteAllText(desktopPath, desktopContent);
                        
                        // Hacer ejecutable
                        Process.Start("chmod", $"+x \"{desktopPath}\"");
                    }
                }
            }
            catch (Exception ex)
            {
                // No es crítico si falla el acceso directo
                Debug.WriteLine($"Error creando acceso directo: {ex.Message}");
            }
        }

        private void OpenInstallFolder(string installPath)
        {
            try
            {
                if (IsWindows)
                {
                    Process.Start("explorer.exe", installPath);
                }
                else
                {
                    // En Linux, intentar con xdg-open
                    Process.Start("xdg-open", installPath);
                }
            }
            catch
            {
                // Si falla, mostrar mensaje
                MessageBox.Show($"La carpeta de instalación es:\n{installPath}", 
                    "Carpeta de Instalación", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private void MainForm_Resize(object sender, EventArgs e)
        {
            // Solo en Windows hacer resize dinámico
            if (!IsWindows) return;
            
            try
            {
                int margin = 20;
                int controlWidth = this.ClientSize.Width - (margin * 2);
                
                // Título
                lblTitle.Location = new Point(margin, margin);
                lblTitle.Size = new Size(controlWidth, 30);
                
                // Estado
                lblStatus.Location = new Point(margin, lblTitle.Bottom + 10);
                lblStatus.Size = new Size(controlWidth, 30);
                
                // Barra de progreso
                progressBar.Location = new Point(margin, lblStatus.Bottom + 10);
                progressBar.Size = new Size(controlWidth, 25);
                
                // Detalles de progreso
                lblProgress.Location = new Point(margin, progressBar.Bottom + 10);
                lblProgress.Size = new Size(controlWidth, 20);
                
                // Botón cancelar
                btnCancel.Location = new Point(
                    this.ClientSize.Width - btnCancel.Width - margin,
                    this.ClientSize.Height - btnCancel.Height - margin);
            }
            catch
            {
                // Ignorar errores de resize
            }
        }

        private void btnCancel_Click(object sender, EventArgs e)
        {
            DialogResult result = MessageBox.Show(
                "¿Estás seguro de que deseas cancelar la instalación?",
                "Confirmar Cancelación",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);
            
            if (result == DialogResult.Yes)
            {
                Application.Exit();
            }
        }

        #region Windows Form Designer generated code
        private System.ComponentModel.IContainer components = null;
        private Label lblTitle;
        private Label lblStatus;
        private ProgressBar progressBar;
        private Label lblProgress;
        private Button btnCancel;

        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
                components.Dispose();
            base.Dispose(disposing);
        }

        private void InitializeComponent()
        {
            this.lblTitle = new Label();
            this.lblStatus = new Label();
            this.progressBar = new ProgressBar();
            this.lblProgress = new Label();
            this.btnCancel = new Button();
            this.SuspendLayout();
            
            // lblTitle
            this.lblTitle.AutoSize = false;
            this.lblTitle.Font = new Font("Segoe UI", 14F, FontStyle.Bold, GraphicsUnit.Point);
            this.lblTitle.ForeColor = Color.FromArgb(44, 62, 80);
            this.lblTitle.Location = new Point(20, 20);
            this.lblTitle.Size = new Size(560, 40); // Más grande
            this.lblTitle.Text = "🌍 Atlas Interactivo - Instalador";
            this.lblTitle.TextAlign = ContentAlignment.MiddleCenter;
            
            // lblStatus
            this.lblStatus.AutoSize = false;
            this.lblStatus.Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);
            this.lblStatus.ForeColor = Color.FromArgb(127, 140, 141);
            this.lblStatus.Location = new Point(20, 80);
            this.lblStatus.Size = new Size(560, 30);
            this.lblStatus.Text = "Preparando instalación...";
            this.lblStatus.TextAlign = ContentAlignment.MiddleLeft;
            
            // progressBar
            this.progressBar.Location = new Point(20, 120);
            this.progressBar.Size = new Size(560, 30); // Más grande
            this.progressBar.Style = ProgressBarStyle.Continuous;
            this.progressBar.Minimum = 0;
            this.progressBar.Maximum = 100;
            
            // lblProgress
            this.lblProgress.AutoSize = false;
            this.lblProgress.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            this.lblProgress.ForeColor = Color.FromArgb(52, 152, 219);
            this.lblProgress.Location = new Point(20, 160);
            this.lblProgress.Size = new Size(560, 25);
            this.lblProgress.Text = "0% - 0MB";
            this.lblProgress.TextAlign = ContentAlignment.MiddleCenter;
            
            // btnCancel
            this.btnCancel.Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);
            this.btnCancel.Location = new Point(470, 200); // Posición fija
            this.btnCancel.Size = new Size(110, 35);
            this.btnCancel.Text = "Cancelar";
            this.btnCancel.UseVisualStyleBackColor = true;
            this.btnCancel.Click += new EventHandler(btnCancel_Click);
            
            // MainForm - TAMAÑO INICIAL MÁS GRANDE
            this.ClientSize = new Size(600, 250);
            this.Controls.Add(this.lblTitle);
            this.Controls.Add(this.lblStatus);
            this.Controls.Add(this.progressBar);
            this.Controls.Add(this.lblProgress);
            this.Controls.Add(this.btnCancel);
            
            // Usar FixedDialog en ambos para evitar problemas
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = true;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.Text = "Instalador Atlas Interactivo";
            this.Load += new EventHandler(MainForm_Load);
            this.ResumeLayout(false);
        }
        #endregion
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            // Configurar alta compatibilidad DPI solo en Windows
            if (Environment.OSVersion.Platform == PlatformID.Win32NT)
            {
                try
                {
                    SetProcessDPIAware();
                }
                catch
                {
                    // Ignorar si falla
                }
            }
            
            Application.Run(new MainForm());
        }
        
        // Solo incluir en Windows
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();
    }
}