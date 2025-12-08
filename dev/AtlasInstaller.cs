// Atlas_Distribution/dev/AtlasInstaller.cs
using System;
using System.IO;
using System.Net;
using System.Diagnostics;
using System.IO.Compression;
using System.Windows.Forms;
using System.Drawing;
using System.Threading.Tasks;
using Newtonsoft.Json;
using System.Collections.Generic;

namespace AtlasInstaller
{
    public partial class MainForm : Form
    {
        // Configuración
        private const string DRIVE_FILE_ID = "1YOUR_FILE_ID_HERE"; // ID del ZIP en Drive
        private const string PATCHES_FOLDER_ID = "1YOUR_PATCHES_FOLDER_ID";
        private const string VERSION_FILE = ".atlas_version.json";
        
        // UI Elements
        private ProgressBar progressBar;
        private Label lblStatus;
        private Label lblSpeed;
        private Label lblTimeRemaining;
        private Button btnInstall;
        private Button btnCheckUpdates;
        private Button btnBrowse;
        private TextBox txtInstallPath;
        private CheckBox chkCreateDesktopShortcut;
        private CheckBox chkCreateStartMenu;
        private Panel panelMain;
        private Panel panelComplete;
        private WebClient webClient;
        private DateTime startTime;
        
        // Paths
        private string tempZipPath;
        private string installPath;
        private bool isInstalled = false;
        
        public MainForm()
        {
            InitializeComponent();
            SetupUI();
            
            // Configurar paths
            tempZipPath = Path.Combine(Path.GetTempPath(), $"atlas_temp_{Guid.NewGuid()}.zip");
            installPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Atlas_Interactivo");
            txtInstallPath.Text = installPath;
            
            // Verificar si ya está instalado
            CheckIfInstalled();
        }
        
        private void SetupUI()
        {
            // Configurar ventana
            this.Text = "Atlas Interactivo - Instalador";
            this.Size = new Size(600, 500);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(240, 240, 240);
            
            // Panel principal
            panelMain = new Panel();
            panelMain.Dock = DockStyle.Fill;
            panelMain.Padding = new Padding(20);
            
            // Título
            var lblTitle = new Label();
            lblTitle.Text = "🌍 Atlas Interactivo";
            lblTitle.Font = new Font("Segoe UI", 24, FontStyle.Bold);
            lblTitle.ForeColor = Color.FromArgb(44, 62, 80);
            lblTitle.AutoSize = true;
            lblTitle.Location = new Point(20, 20);
            
            var lblSubtitle = new Label();
            lblSubtitle.Text = "Software meteorológico profesional";
            lblSubtitle.Font = new Font("Segoe UI", 10);
            lblSubtitle.ForeColor = Color.Gray;
            lblSubtitle.AutoSize = true;
            lblSubtitle.Location = new Point(22, 60);
            
            // Ruta de instalación
            var lblPath = new Label();
            lblPath.Text = "Ruta de instalación:";
            lblPath.Font = new Font("Segoe UI", 9);
            lblPath.AutoSize = true;
            lblPath.Location = new Point(20, 100);
            
            txtInstallPath = new TextBox();
            txtInstallPath.Size = new Size(350, 25);
            txtInstallPath.Location = new Point(20, 125);
            txtInstallPath.Font = new Font("Segoe UI", 9);
            
            btnBrowse = new Button();
            btnBrowse.Text = "Examinar...";
            btnBrowse.Size = new Size(80, 25);
            btnBrowse.Location = new Point(380, 125);
            btnBrowse.Font = new Font("Segoe UI", 9);
            btnBrowse.Click += BtnBrowse_Click;
            
            // Opciones
            chkCreateDesktopShortcut = new CheckBox();
            chkCreateDesktopShortcut.Text = "Crear acceso directo en el escritorio";
            chkCreateDesktopShortcut.Checked = true;
            chkCreateDesktopShortcut.AutoSize = true;
            chkCreateDesktopShortcut.Location = new Point(20, 160);
            chkCreateDesktopShortcut.Font = new Font("Segoe UI", 9);
            
            chkCreateStartMenu = new CheckBox();
            chkCreateStartMenu.Text = "Agregar al menú Inicio";
            chkCreateStartMenu.Checked = true;
            chkCreateStartMenu.AutoSize = true;
            chkCreateStartMenu.Location = new Point(20, 185);
            chkCreateStartMenu.Font = new Font("Segoe UI", 9);
            
            // Barra de progreso
            progressBar = new ProgressBar();
            progressBar.Size = new Size(440, 30);
            progressBar.Location = new Point(20, 230);
            progressBar.Style = ProgressBarStyle.Continuous;
            
            // Labels de estado
            lblStatus = new Label();
            lblStatus.Text = "Listo para instalar";
            lblStatus.AutoSize = true;
            lblStatus.Location = new Point(20, 270);
            lblStatus.Font = new Font("Segoe UI", 9);
            
            lblSpeed = new Label();
            lblSpeed.Text = "";
            lblSpeed.AutoSize = true;
            lblSpeed.Location = new Point(20, 295);
            lblSpeed.Font = new Font("Segoe UI", 8);
            lblSpeed.ForeColor = Color.Gray;
            
            lblTimeRemaining = new Label();
            lblTimeRemaining.Text = "";
            lblTimeRemaining.AutoSize = true;
            lblTimeRemaining.Location = new Point(200, 295);
            lblTimeRemaining.Font = new Font("Segoe UI", 8);
            lblTimeRemaining.ForeColor = Color.Gray;
            
            // Botones
            btnInstall = new Button();
            btnInstall.Text = "Instalar Atlas";
            btnInstall.Size = new Size(150, 40);
            btnInstall.Location = new Point(20, 330);
            btnInstall.Font = new Font("Segoe UI", 10, FontStyle.Bold);
            btnInstall.BackColor = Color.FromArgb(52, 152, 219);
            btnInstall.ForeColor = Color.White;
            btnInstall.FlatStyle = FlatStyle.Flat;
            btnInstall.Click += BtnInstall_Click;
            
            btnCheckUpdates = new Button();
            btnCheckUpdates.Text = "Buscar Actualizaciones";
            btnCheckUpdates.Size = new Size(150, 40);
            btnCheckUpdates.Location = new Point(180, 330);
            btnCheckUpdates.Font = new Font("Segoe UI", 9);
            btnCheckUpdates.Enabled = false;
            btnCheckUpdates.Click += BtnCheckUpdates_Click;
            
            // Panel de completado
            panelComplete = new Panel();
            panelComplete.Dock = DockStyle.Fill;
            panelComplete.Visible = false;
            
            var lblComplete = new Label();
            lblComplete.Text = "✅ ¡Instalación Completada!";
            lblComplete.Font = new Font("Segoe UI", 24, FontStyle.Bold);
            lblComplete.ForeColor = Color.FromArgb(39, 174, 96);
            lblComplete.AutoSize = true;
            lblComplete.Location = new Point(150, 100);
            
            var lblCompletePath = new Label();
            lblCompletePath.Text = $"Atlas se ha instalado en:\n{installPath}";
            lblCompletePath.Font = new Font("Segoe UI", 10);
            lblCompletePath.AutoSize = false;
            lblCompletePath.Size = new Size(400, 60);
            lblCompletePath.Location = new Point(100, 180);
            lblCompletePath.TextAlign = ContentAlignment.MiddleCenter;
            
            var btnLaunch = new Button();
            btnLaunch.Text = "🎯 Ejecutar Atlas";
            btnLaunch.Size = new Size(200, 50);
            btnLaunch.Location = new Point(200, 250);
            btnLaunch.Font = new Font("Segoe UI", 11, FontStyle.Bold);
            btnLaunch.BackColor = Color.FromArgb(46, 204, 113);
            btnLaunch.ForeColor = Color.White;
            btnLaunch.FlatStyle = FlatStyle.Flat;
            btnLaunch.Click += (s, e) => LaunchAtlas();
            
            var btnOpenFolder = new Button();
            btnOpenFolder.Text = "📁 Abrir Carpeta";
            btnOpenFolder.Size = new Size(200, 40);
            btnOpenFolder.Location = new Point(200, 310);
            btnOpenFolder.Font = new Font("Segoe UI", 9);
            btnOpenFolder.Click += (s, e) => Process.Start("explorer.exe", installPath);
            
            panelComplete.Controls.AddRange(new Control[] { lblComplete, lblCompletePath, btnLaunch, btnOpenFolder });
            
            // Agregar controles al panel principal
            panelMain.Controls.AddRange(new Control[] {
                lblTitle, lblSubtitle, lblPath, txtInstallPath, btnBrowse,
                chkCreateDesktopShortcut, chkCreateStartMenu,
                progressBar, lblStatus, lblSpeed, lblTimeRemaining,
                btnInstall, btnCheckUpdates
            });
            
            this.Controls.Add(panelMain);
            this.Controls.Add(panelComplete);
        }
        
        private void BtnBrowse_Click(object sender, EventArgs e)
        {
            using (var dialog = new FolderBrowserDialog())
            {
                dialog.Description = "Selecciona la carpeta para instalar Atlas";
                dialog.SelectedPath = txtInstallPath.Text;
                
                if (dialog.ShowDialog() == DialogResult.OK)
                {
                    installPath = dialog.SelectedPath;
                    txtInstallPath.Text = installPath;
                }
            }
        }
        
        private void CheckIfInstalled()
        {
            string versionFile = Path.Combine(installPath, VERSION_FILE);
            if (File.Exists(versionFile))
            {
                isInstalled = true;
                btnInstall.Text = "Reparar Instalación";
                btnCheckUpdates.Enabled = true;
                lblStatus.Text = "Atlas ya está instalado. Puedes reparar o actualizar.";
            }
        }
        
        private async void BtnInstall_Click(object sender, EventArgs e)
        {
            btnInstall.Enabled = false;
            btnBrowse.Enabled = false;
            progressBar.Value = 0;
            startTime = DateTime.Now;
            
            try
            {
                // 1. Verificar espacio
                if (!CheckDiskSpace())
                {
                    MessageBox.Show("Espacio en disco insuficiente. Se requieren al menos 25GB libres.",
                                  "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }
                
                // 2. Crear directorio
                Directory.CreateDirectory(installPath);
                
                // 3. Descargar
                await DownloadFileAsync();
                
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error durante la instalación: {ex.Message}", 
                              "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                btnInstall.Enabled = true;
                btnBrowse.Enabled = true;
            }
        }
        
        private bool CheckDiskSpace()
        {
            DriveInfo drive = new DriveInfo(Path.GetPathRoot(installPath));
            long freeSpace = drive.AvailableFreeSpace;
            long requiredSpace = 25L * 1024 * 1024 * 1024; // 25GB
            
            return freeSpace >= requiredSpace;
        }
        
        private async Task DownloadFileAsync()
        {
            lblStatus.Text = "Conectando con Google Drive...";
            
            webClient = new WebClient();
            webClient.DownloadProgressChanged += WebClient_DownloadProgressChanged;
            webClient.DownloadFileCompleted += WebClient_DownloadFileCompleted;
            
            string url = $"https://drive.google.com/uc?id={DRIVE_FILE_ID}&export=download&confirm=t";
            
            await webClient.DownloadFileTaskAsync(new Uri(url), tempZipPath);
        }
        
        private void WebClient_DownloadProgressChanged(object sender, DownloadProgressChangedEventArgs e)
        {
            // Actualizar progreso
            progressBar.Value = e.ProgressPercentage;
            
            // Calcular velocidad y tiempo restante
            double elapsedSeconds = (DateTime.Now - startTime).TotalSeconds;
            double speed = e.BytesReceived / elapsedSeconds;
            double remainingBytes = e.TotalBytesToReceive - e.BytesReceived;
            double remainingSeconds = remainingBytes / speed;
            
            // Actualizar labels
            this.Invoke((MethodInvoker)delegate
            {
                lblStatus.Text = $"Descargando... {e.BytesReceived / (1024 * 1024):N0} MB / {e.TotalBytesToReceive / (1024 * 1024):N0} MB";
                lblSpeed.Text = $"Velocidad: {speed / 1024 / 1024:N1} MB/s";
                lblTimeRemaining.Text = $"Tiempo restante: {TimeSpan.FromSeconds(remainingSeconds):mm\\:ss}";
            });
        }
        
        private void WebClient_DownloadFileCompleted(object sender, System.ComponentModel.AsyncCompletedEventArgs e)
        {
            if (e.Error != null)
            {
                MessageBox.Show($"Error descargando: {e.Error.Message}", "Error", 
                              MessageBoxButtons.OK, MessageBoxIcon.Error);
                btnInstall.Enabled = true;
                btnBrowse.Enabled = true;
                return;
            }
            
            lblStatus.Text = "Descarga completada. Extrayendo archivos...";
            
            // Extraer en hilo separado
            Task.Run(() => ExtractAndInstall());
        }
        
        private void ExtractAndInstall()
        {
            try
            {
                int totalFiles = 0;
                int extractedFiles = 0;
                
                // Obtener número total de archivos en el ZIP
                using (ZipArchive archive = ZipFile.OpenRead(tempZipPath))
                {
                    totalFiles = archive.Entries.Count;
                }
                
                // Extraer con progreso
                using (ZipArchive archive = ZipFile.OpenRead(tempZipPath))
                {
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        string destinationPath = Path.Combine(installPath, entry.FullName);
                        
                        // Crear directorio si es necesario
                        string directory = Path.GetDirectoryName(destinationPath);
                        if (!Directory.Exists(directory))
                            Directory.CreateDirectory(directory);
                        
                        // Extraer archivo
                        entry.ExtractToFile(destinationPath, true);
                        
                        extractedFiles++;
                        int progress = (extractedFiles * 100) / totalFiles;
                        
                        // Actualizar UI
                        this.Invoke((MethodInvoker)delegate
                        {
                            progressBar.Value = progress;
                            lblStatus.Text = $"Extrayendo... {extractedFiles}/{totalFiles} archivos";
                        });
                    }
                }
                
                // Crear archivo de versión
                CreateVersionFile();
                
                // Crear accesos directos
                if (chkCreateDesktopShortcut.Checked)
                    CreateDesktopShortcut();
                    
                if (chkCreateStartMenu.Checked)
                    CreateStartMenuShortcut();
                
                // Limpiar archivo temporal
                File.Delete(tempZipPath);
                
                // Mostrar completado
                this.Invoke((MethodInvoker)delegate
                {
                    panelMain.Visible = false;
                    panelComplete.Visible = true;
                    btnCheckUpdates.Enabled = true;
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error extrayendo: {ex.Message}", "Error", 
                              MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        
        private void CreateVersionFile()
        {
            var versionInfo = new
            {
                version = "1.0.0",
                installed_date = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                install_path = installPath,
                total_files = CountFiles(installPath)
            };
            
            string json = JsonConvert.SerializeObject(versionInfo, Formatting.Indented);
            File.WriteAllText(Path.Combine(installPath, VERSION_FILE), json);
        }
        
        private int CountFiles(string directory)
        {
            return Directory.GetFiles(directory, "*", SearchOption.AllDirectories).Length;
        }
        
        private void CreateDesktopShortcut()
        {
            string shortcutPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                "Atlas Interactivo.lnk");
                
            CreateShortcut(shortcutPath);
        }
        
        private void CreateStartMenuShortcut()
        {
            string startMenuPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
                "Programs", "Atlas Interactivo.lnk");
                
            CreateShortcut(startMenuPath);
        }
        
        private void CreateShortcut(string shortcutPath)
        {
            try
            {
                string targetPath = Path.Combine(installPath, "Atlas_Interactivo.exe");
                
                if (!File.Exists(targetPath))
                    return;
                    
                // Usar Windows Script Host para crear acceso directo
                string script = $@"
                    Set oWS = WScript.CreateObject(""WScript.Shell"")
                    Set oLink = oWS.CreateShortcut(""{shortcutPath.Replace(@"\", @"\\")}"")
                    oLink.TargetPath = ""{targetPath.Replace(@"\", @"\\")}""
                    oLink.WorkingDirectory = ""{installPath.Replace(@"\", @"\\")}""
                    oLink.Save
                ";
                
                string tempScript = Path.GetTempFileName() + ".vbs";
                File.WriteAllText(tempScript, script);
                
                Process.Start("wscript.exe", tempScript).WaitForExit();
                File.Delete(tempScript);
            }
            catch { /* Silenciar errores de acceso directo */ }
        }
        
        private void LaunchAtlas()
        {
            string exePath = Path.Combine(installPath, "Atlas_Interactivo.exe");
            if (File.Exists(exePath))
            {
                Process.Start(exePath);
                Application.Exit();
            }
        }
        
        private async void BtnCheckUpdates_Click(object sender, EventArgs e)
        {
            var updateForm = new UpdateForm(installPath, PATCHES_FOLDER_ID);
            updateForm.ShowDialog();
        }
    }
    
    // Formulario de actualizaciones
    public class UpdateForm : Form
    {
        private string installPath;
        private string patchesFolderId;
        private ListView listViewPatches;
        private Button btnApply;
        private Button btnCancel;
        private List<PatchInfo> availablePatches;
        
        public UpdateForm(string path, string folderId)
        {
            installPath = path;
            patchesFolderId = folderId;
            InitializeComponent();
            LoadAvailablePatches();
        }
        
        private void InitializeComponent()
        {
            this.Text = "Actualizaciones de Atlas";
            this.Size = new Size(500, 400);
            this.StartPosition = FormStartPosition.CenterParent;
            
            // ListView para parches
            listViewPatches = new ListView();
            listViewPatches.Size = new Size(460, 250);
            listViewPatches.Location = new Point(20, 20);
            listViewPatches.View = View.Details;
            listViewPatches.CheckBoxes = true;
            listViewPatches.FullRowSelect = true;
            
            // Columnas
            listViewPatches.Columns.Add("", 30);
            listViewPatches.Columns.Add("Nombre", 200);
            listViewPatches.Columns.Add("Tamaño", 100);
            listViewPatches.Columns.Add("Fecha", 100);
            
            // Botones
            btnApply = new Button();
            btnApply.Text = "Aplicar Seleccionados";
            btnApply.Size = new Size(150, 35);
            btnApply.Location = new Point(100, 290);
            btnApply.Click += BtnApply_Click;
            
            btnCancel = new Button();
            btnCancel.Text = "Cancelar";
            btnCancel.Size = new Size(150, 35);
            btnCancel.Location = new Point(260, 290);
            btnCancel.Click += (s, e) => this.Close();
            
            this.Controls.AddRange(new Control[] { listViewPatches, btnApply, btnCancel });
        }
        
        private async void LoadAvailablePatches()
        {
            availablePatches = await PatchManager.GetAvailablePatches(installPath, patchesFolderId);
            
            foreach (var patch in availablePatches)
            {
                var item = new ListViewItem(new[] {
                    "",
                    patch.Name,
                    patch.Size,
                    patch.Date
                });
                item.Tag = patch;
                listViewPatches.Items.Add(item);
            }
        }
        
        private async void BtnApply_Click(object sender, EventArgs e)
        {
            var selectedPatches = new List<PatchInfo>();
            
            foreach (ListViewItem item in listViewPatches.Items)
            {
                if (item.Checked)
                {
                    selectedPatches.Add((PatchInfo)item.Tag);
                }
            }
            
            if (selectedPatches.Count == 0)
            {
                MessageBox.Show("Selecciona al menos un parche para aplicar.", 
                              "Información", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            
            // Aplicar parches
            var progressForm = new ProgressForm("Aplicando actualizaciones...");
            progressForm.Show();
            
            try
            {
                foreach (var patch in selectedPatches)
                {
                    await PatchManager.ApplyPatch(installPath, patch);
                }
                
                progressForm.Close();
                MessageBox.Show("Actualizaciones aplicadas correctamente.", 
                              "Éxito", MessageBoxButtons.OK, MessageBoxIcon.Information);
                this.Close();
            }
            catch (Exception ex)
            {
                progressForm.Close();
                MessageBox.Show($"Error aplicando parches: {ex.Message}", 
                              "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
    
    // Gestor de parches
    public static class PatchManager
    {
        public static async Task<List<PatchInfo>> GetAvailablePatches(string installPath, string folderId)
        {
            var patches = new List<PatchInfo>();
            
            // Leer versión actual
            string versionFile = Path.Combine(installPath, ".atlas_version.json");
            if (!File.Exists(versionFile))
                return patches;
                
            string currentVersion = JsonConvert.DeserializeObject<dynamic>(
                File.ReadAllText(versionFile)).version.ToString();
            
            // En una implementación real, aquí consultarías Drive API
            // Por ahora simulamos algunos parches
            patches.Add(new PatchInfo
            {
                Id = "patch_001",
                Name = "Actualización de mapas 2024",
                Size = "150 MB",
                Date = "2024-01-15",
                FileId = "PATCH_FILE_ID_1",
                Version = "1.0.1"
            });
            
            patches.Add(new PatchInfo
            {
                Id = "patch_002", 
                Name = "Nuevos datos climáticos",
                Size = "80 MB",
                Date = "2024-01-20",
                FileId = "PATCH_FILE_ID_2",
                Version = "1.0.2"
            });
            
            return patches;
        }
        
        public static async Task ApplyPatch(string installPath, PatchInfo patch)
        {
            // Descargar parche
            string tempFile = Path.GetTempFileName() + ".zip";
            string url = $"https://drive.google.com/uc?id={patch.FileId}&export=download";
            
            using (WebClient client = new WebClient())
            {
                await client.DownloadFileTaskAsync(new Uri(url), tempFile);
            }
            
            // Aplicar parche
            ZipFile.ExtractToDirectory(tempFile, installPath, true);
            
            // Actualizar versión
            UpdateVersion(installPath, patch.Version);
            
            // Limpiar
            File.Delete(tempFile);
        }
        
        private static void UpdateVersion(string installPath, string newVersion)
        {
            string versionFile = Path.Combine(installPath, ".atlas_version.json");
            var data = JsonConvert.DeserializeObject<dynamic>(File.ReadAllText(versionFile));
            data.version = newVersion;
            data.last_update = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            
            File.WriteAllText(versionFile, JsonConvert.SerializeObject(data, Formatting.Indented));
        }
    }
    
    public class PatchInfo
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Size { get; set; }
        public string Date { get; set; }
        public string FileId { get; set; }
        public string Version { get; set; }
    }
    
    // Formulario de progreso
    public class ProgressForm : Form
    {
        private Label lblMessage;
        private ProgressBar progressBar;
        
        public ProgressForm(string message)
        {
            this.Text = "Progreso";
            this.Size = new Size(300, 150);
            this.StartPosition = FormStartPosition.CenterParent;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.ControlBox = false;
            
            lblMessage = new Label();
            lblMessage.Text = message;
            lblMessage.AutoSize = true;
            lblMessage.Location = new Point(20, 20);
            
            progressBar = new ProgressBar();
            progressBar.Style = ProgressBarStyle.Marquee;
            progressBar.Size = new Size(260, 30);
            progressBar.Location = new Point(20, 60);
            
            this.Controls.AddRange(new Control[] { lblMessage, progressBar });
        }
    }
    
    // Punto de entrada
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