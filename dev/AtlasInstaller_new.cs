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
using System.Collections.Generic;
using System.Threading;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Diagnostics; // NECESARIO para Process


// zip install page: https://www.7-zip.org/download.html 

namespace AtlasInstaller
{


    // ========== CLASE PRINCIPAL PARA DESCARGA Y EXTRACCIÓN ==========
    public class BufferedTarDownloader : IDisposable
    {
        private const int BUFFER_SIZE = 81920;
        private const long MAXIMUM_BUFFER_SIZE = 5L * 1024L * 1024L * 1024L; // 5 GB máximo
        
        private readonly string _url;
        private readonly string _extractPath;
        private readonly IProgress<int> _progress;
        private readonly CancellationToken _cancellationToken;
        
        private FileStream _tempFileStream;
        private long _totalBytesRead = 0;
        private long _totalBytesToRead = 0;
        private bool _isDisposed = false;
        private long _lastReportTime = 0;
        private string _tempTarPath;
        
        private DateTime _startTime;

        public event EventHandler<string> LogMessage;
        public event EventHandler<string> StatusUpdate;


        public BufferedTarDownloader(string url, string extractPath, IProgress<int> progress, CancellationToken cancellationToken)
        {
            _url = url;
            _extractPath = extractPath;
            _progress = progress;
            _cancellationToken = cancellationToken;
        }

        private void OnLogMessage(string message)
        {
            LogMessage?.Invoke(this, message);
        }

        private void OnStatusUpdate(string status)
        {
            StatusUpdate?.Invoke(this, status);
        }


        public async Task<bool> DownloadAndExtractIncremental()
        {
            _tempTarPath = Path.Combine(Path.GetTempPath(), $"atlas_{Guid.NewGuid():N}.tar");
            
            try
            {
                OnLogMessage("🚀 INICIANDO DESCARGA Y EXTRACCIÓN");
                OnLogMessage($"📁 Archivo temporal: {_tempTarPath}");
                OnLogMessage($"📁 Extraer a: {_extractPath}");
                
                // VERIFICAR SI YA EXISTE LA INSTALACIÓN
                if (IsInstallationComplete(_extractPath))
                {
                    OnLogMessage("✅ Instalación ya completa detectada");
                    OnLogMessage($"📊 Directorio contiene: {CountExtractedFiles(_extractPath)} archivos");
                    return true;
                }
                
                // Crear directorio de extracción
                Directory.CreateDirectory(_extractPath);
                
                // 1. Primero descargar COMPLETAMENTE el archivo
                OnLogMessage("📥 Descargando archivo TAR...");
                bool downloadSuccess = await DownloadToFile(_tempTarPath);
                
                if (!downloadSuccess)
                {
                    OnLogMessage("❌ Falló la descarga del archivo TAR");
                    return false;
                }
                
                // 2. CERRAR completamente el stream de archivo antes de proceder
                OnLogMessage("✅ Descarga completada, cerrando archivo...");
                if (_tempFileStream != null)
                {
                    _tempFileStream.Close();
                    _tempFileStream.Dispose();
                    _tempFileStream = null;
                }
                
                // 3. Pequeña pausa para asegurar que el sistema operativo libere el archivo
                await Task.Delay(1000);
                
                // 4. Verificar que el archivo existe y es accesible
                if (!File.Exists(_tempTarPath))
                {
                    OnLogMessage("❌ Archivo TAR no encontrado después de la descarga");
                    return false;
                }
                
                FileInfo downloadedFile = new FileInfo(_tempTarPath);
                double sizeGB = downloadedFile.Length / (1024.0 * 1024.0 * 1024.0);
                OnLogMessage($"📊 Tamaño del archivo TAR: {sizeGB:F2} GB");
                OnLogMessage($"📊 Archivo accesible: {(downloadedFile.IsReadOnly ? "Sí" : "Sí, no es de solo lectura")}");
                
                // 5. INTENTAR EXTRAER CON 7-ZIP
                OnLogMessage("🔧 Iniciando extracción con 7-zip...");
                bool extractSuccess = await ExtractAllWith7Zip(_tempTarPath, _extractPath);
                
                return extractSuccess;
            }
            catch (Exception ex)
            {
                OnLogMessage($"❌ ERROR: {ex.Message}");
                OnLogMessage($"📋 Stack trace: {ex.StackTrace}");
                return false;
            }
            finally
            {
                Cleanup();
            }
        }

        private async Task<bool> DownloadToFile(string filePath)
        {
            try
            {
                using (var client = CreateHttpClient())
                {
                    // Obtener tamaño total primero
                    await GetTotalFileSize();
                    
                    using (var response = await client.GetAsync(_url, HttpCompletionOption.ResponseHeadersRead, _cancellationToken))
                    using (var stream = await response.Content.ReadAsStreamAsync())
                    {
                        // Crear archivo nuevo cada vez
                        using (var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write, FileShare.None, BUFFER_SIZE, FileOptions.Asynchronous))
                        {
                            byte[] buffer = new byte[BUFFER_SIZE];
                            int bytesRead;
                            _totalBytesRead = 0;
                            _startTime = DateTime.Now;
                            
                            while ((bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, _cancellationToken)) > 0)
                            {
                                _cancellationToken.ThrowIfCancellationRequested();
                                
                                await fileStream.WriteAsync(buffer, 0, bytesRead, _cancellationToken);
                                await fileStream.FlushAsync(); // Forzar escritura inmediata
                                
                                _totalBytesRead += bytesRead;
                                UpdateProgressWithETA();
                            }
                            
                            // Cerrar y liberar el archivo inmediatamente
                            await fileStream.FlushAsync();
                        }
                    }
                    
                    OnLogMessage($"✅ Descarga completada: {_totalBytesRead / (1024.0 * 1024.0 * 1024.0):F2} GB");
                    return true;
                }
            }
            catch (OperationCanceledException)
            {
                OnLogMessage("Descarga cancelada");
                throw;
            }
            catch (Exception ex)
            {
                OnLogMessage($"❌ Error HTTP: {ex.Message}");
                return false;
            }
        }

        private async Task<bool> ExtractWithQtMethod(string tarPath, string extractPath)
        {
            try
            {
                OnLogMessage("🔄 Método Qt: Extracción por grupos con 7-zip");
                
                // 1. Verificar archivo
                if (!File.Exists(tarPath))
                {
                    OnLogMessage($"❌ ERROR: Archivo TAR no existe: {tarPath}");
                    return false;
                }
                
                FileInfo tarInfo = new FileInfo(tarPath);
                OnLogMessage($"✅ Archivo TAR: {tarPath}");
                OnLogMessage($"📊 Tamaño: {tarInfo.Length / (1024.0 * 1024.0 * 1024.0):F2} GB");
                
                // 2. Verificar 7-zip
                string sevenZipPath = Get7ZipPath();
                if (!File.Exists(sevenZipPath))
                {
                    OnLogMessage($"❌ ERROR: 7-zip no encontrado en: {sevenZipPath}");
                    OnLogMessage("💡 Por favor, instale 7-zip desde: https://www.7-zip.org/");
                    return false;
                }
                
                OnLogMessage($"✅ 7-zip encontrado: {sevenZipPath}");
                
                // INTENTAR EXTRACCIÓN COMPLETA DIRECTAMENTE (MÁS SIMPLE)
                OnLogMessage("🔧 Extrayendo archivo completo con 7-zip...");
                return await ExtractAllWith7Zip(tarPath, extractPath);
            }
            catch (Exception ex)
            {
                OnLogMessage($"❌ Error en extracción Qt: {ex.Message}");
                OnLogMessage($"📋 Stack trace: {ex.StackTrace}");
                return false;
            }
        }

        // Clase para almacenar información de archivos TAR
        private class TarFileInfo
        {
            public string Name { get; set; }
            public bool IsDirectory { get; set; }
            public long Size { get; set; }
            public DateTime ModifiedDate { get; set; }
        }

        // Método para obtener lista de archivos usando 7-zip (comando: 7z l test.tar)
        private async Task<List<TarFileInfo>> GetTarFileListWith7Zip(string tarPath)
        {
            return await Task.Run(() =>
            {
                var fileList = new List<TarFileInfo>();
                
                try
                {
                    string sevenZipPath = Get7ZipPath();
                    
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = $"\"{sevenZipPath}\"",
                        Arguments = $"l \"{tarPath}\"",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true,
                        StandardOutputEncoding = Encoding.UTF8
                    };
                    
                    using (Process process = new Process())
                    {
                        process.StartInfo = psi;
                        process.Start();
                        
                        // Leer la salida línea por línea
                        string output = process.StandardOutput.ReadToEnd();
                        process.WaitForExit(30000); // 30 segundos timeout
                        
                        // Parsear la salida (formato similar al que mostraste)
                        bool inFileList = false;
                        string[] lines = output.Split(new[] { '\n' }, StringSplitOptions.None);
                        
                        foreach (string line in lines)
                        {
                            string trimmedLine = line.Trim();
                            
                            // Buscar el inicio de la lista de archivos
                            if (trimmedLine.Contains("------------------- ----- ------------ ------------"))
                            {
                                inFileList = true;
                                continue;
                            }
                            
                            // Buscar el fin de la lista de archivos
                            if (inFileList && trimmedLine.Contains("------------------- ----- ------------ ------------"))
                            {
                                break;
                            }
                            
                            // Procesar líneas de archivos
                            if (inFileList && !string.IsNullOrWhiteSpace(trimmedLine))
                            {
                                try
                                {
                                    // Parsear la línea según el formato de 7-zip
                                    // Ejemplo: "2026-01-03 20:10:53 D....            0            0  Atlas_Interactivo-1.0.0-win32-x64"
                                    
                                    // Verificar si es un directorio (contiene "D....")
                                    bool isDirectory = trimmedLine.Contains("D....");
                                    
                                    // **SOLUCIÓN CORRECTA PARA .NET FRAMEWORK 4.x**
                                    // En .NET Framework 4.x, Split(char[], StringSplitOptions) no existe
                                    // Usamos Split(params char[]) y luego filtramos manualmente
                                    string[] rawParts = trimmedLine.Split(new char[] { ' ' });
                                    List<string> parts = new List<string>();
                                    
                                    foreach (string part in rawParts)
                                    {
                                        if (!string.IsNullOrWhiteSpace(part))
                                        {
                                            parts.Add(part);
                                        }
                                    }
                                    
                                    if (parts.Count >= 6)
                                    {
                                        string fileName = parts[parts.Count - 1];
                                        
                                        // Saltar archivos especiales de TAR
                                        if (fileName.Contains("PaxHeaders") || fileName.StartsWith("."))
                                        {
                                            continue;
                                        }
                                        
                                        // Extraer tamaño si es archivo
                                        long size = 0;
                                        if (!isDirectory && parts.Count >= 4)
                                        {
                                            long.TryParse(parts[3], out size);
                                        }
                                        
                                        // Extraer fecha
                                        DateTime date = DateTime.Now;
                                        if (parts.Count >= 2)
                                        {
                                            string dateStr = parts[0] + " " + parts[1];
                                            DateTime.TryParse(dateStr, out date);
                                        }
                                        
                                        fileList.Add(new TarFileInfo
                                        {
                                            Name = fileName,
                                            IsDirectory = isDirectory,
                                            Size = size,
                                            ModifiedDate = date
                                        });
                                    }
                                }
                                catch (Exception ex)
                                {
                                    OnLogMessage($"⚠️ Error parseando línea: {trimmedLine}");
                                    OnLogMessage($"   Error: {ex.Message}");
                                }
                            }
                        }
                    }
                    
                    if (fileList.Count == 0)
                    {
                        OnLogMessage("⚠️ No se pudieron obtener archivos, usando método alternativo...");
                        // Método alternativo: intentar con tar.exe si está disponible
                        fileList = GetTarFileListWithTarExe(tarPath);
                    }
                    
                    OnLogMessage($"📊 Archivos encontrados: {fileList.Count}");
                    return fileList;
                }
                catch (Exception ex)
                {
                    OnLogMessage($"⚠️ Error con 7-zip: {ex.Message}");
                    // Método alternativo
                    return GetTarFileListWithTarExe(tarPath);
                }
            });
        }

        // Método alternativo usando tar.exe (si está disponible)
        private List<TarFileInfo> GetTarFileListWithTarExe(string tarPath)
        {
            var fileList = new List<TarFileInfo>();
            
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "tar",
                    Arguments = $"tf \"{tarPath}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    StandardOutputEncoding = Encoding.UTF8
                };
                
                using (Process process = new Process())
                {
                    process.StartInfo = psi;
                    process.Start();
                    
                    string output = process.StandardOutput.ReadToEnd();
                    process.WaitForExit(30000);
                    
                    // **SOLUCIÓN CORRECTA PARA .NET FRAMEWORK 4.x**
                    string[] allLines = output.Split(new[] { '\n', '\r' }, StringSplitOptions.None);
                    List<string> linesList = new List<string>();

                    foreach (string line in allLines)
                    {
                        string trimmedLine = line.Trim();
                        if (!string.IsNullOrWhiteSpace(trimmedLine))
                        {
                            linesList.Add(trimmedLine);
                        }
                    }

                    string[] lines = linesList.ToArray();


                    foreach (string line in lines)
                    {
                        string trimmedLine = line.Trim();
                        if (!string.IsNullOrEmpty(trimmedLine) && 
                            !trimmedLine.Contains("PaxHeaders"))
                        {
                            bool isDirectory = trimmedLine.EndsWith("/");
                            string fileName = isDirectory ? trimmedLine.TrimEnd('/') : trimmedLine;
                            
                            fileList.Add(new TarFileInfo
                            {
                                Name = fileName,
                                IsDirectory = isDirectory,
                                Size = 0,
                                ModifiedDate = DateTime.Now
                            });
                        }
                    }
                }
                
                OnLogMessage($"✅ Lista obtenida con tar.exe: {fileList.Count} elementos");
            }
            catch (Exception ex)
            {
                OnLogMessage($"❌ tar.exe también falló: {ex.Message}");
            }
            
            return fileList;
        }

        // Método para extraer solo directorios primero
        private async Task<bool> ExtractDirectories(string tarPath, string extractPath, List<string> directories, int stripComponents)
        {
            return await Task.Run(() =>
            {
                try
                {
                    if (directories.Count == 0)
                        return true;
                    
                    OnLogMessage($"📂 Creando {directories.Count} directorios...");
                    
                    // Crear archivo de lista temporal
                    string listFile = Path.GetTempFileName();
                    File.WriteAllLines(listFile, directories);
                    
                    try
                    {
                        string sevenZipPath = Get7ZipPath();
                        
                        // Extraer solo los directorios primero
                        string args = $"x \"{tarPath}\" -o\"{extractPath}\" -aoa";
                        
                        ProcessStartInfo psi = new ProcessStartInfo
                        {
                            FileName = $"\"{sevenZipPath}\"",
                            Arguments = args,
                            UseShellExecute = false,
                            CreateNoWindow = true
                        };
                        
                        using (Process process = new Process())
                        {
                            process.StartInfo = psi;
                            process.Start();
                            
                            // Solo extraer estructura, no esperar a que termine completamente
                            process.WaitForExit(30000); // 30 segundos máximo
                            
                            if (process.ExitCode != 0)
                            {
                                OnLogMessage($"⚠️ 7-zip directorios falló con código: {process.ExitCode}");
                                // Continuar de todos modos, la extracción de archivos creará los directorios
                            }
                        }
                        
                        // También crear directorios manualmente por si acaso
                        foreach (string dir in directories)
                        {
                            string targetDir = dir;
                            
                            // Aplicar strip-components si es necesario
                            if (stripComponents > 0)
                            {
                                string[] parts = dir.Split('/');
                                if (parts.Length > stripComponents)
                                {
                                    targetDir = string.Join("/", parts.Skip(stripComponents));
                                }
                                else
                                {
                                    continue; // Saltar si el directorio está en el prefijo a remover
                                }
                            }
                            
                            if (!string.IsNullOrEmpty(targetDir))
                            {
                                string fullPath = Path.Combine(extractPath, targetDir);
                                try
                                {
                                    Directory.CreateDirectory(fullPath);
                                }
                                catch { }
                            }
                        }
                        
                        OnLogMessage($"✅ {directories.Count} directorios preparados");
                        return true;
                    }
                    finally
                    {
                        try { File.Delete(listFile); } catch { }
                    }
                }
                catch (Exception ex)
                {
                    OnLogMessage($"⚠️ Error creando directorios: {ex.Message}");
                    return false; // No es crítico, continuar
                }
            });
        }

        // Método para extraer grupo específico de archivos
        private async Task<bool> ExtractFileGroupWith7Zip(string tarPath, string extractPath, List<string> files, int stripComponents)
        {
            return await Task.Run(() =>
            {
                try
                {
                    if (files.Count == 0)
                        return true;
                    
                    OnLogMessage($"📄 Extrayendo {files.Count} archivos...");
                    
                    // Para 7-zip, necesitamos extraer archivos específicos
                    // 7-zip no soporta -T como tar, así que usamos un enfoque diferente
                    
                    string sevenZipPath = Get7ZipPath();
                    
                    // Crear archivo de lista temporal
                    string listFile = Path.GetTempFileName();
                    File.WriteAllLines(listFile, files);
                    
                    try
                    {
                        // Para archivos específicos con 7-zip, necesitamos usar patrones
                        // Esto es más complejo porque 7-zip no extrae por lista como tar
                        
                        // Enfoque: Extraer todo el TAR pero solo mantener los archivos que necesitamos
                        // Usar directorio temporal primero
                        string tempExtractDir = Path.Combine(Path.GetTempPath(), $"atlas_extract_{Guid.NewGuid():N}");
                        Directory.CreateDirectory(tempExtractDir);
                        
                        try
                        {
                            // Extraer TODO a directorio temporal
                            string args = $"x \"{tarPath}\" -o\"{tempExtractDir}\" -aoa";
                            
                            ProcessStartInfo psi = new ProcessStartInfo
                            {
                                FileName = $"\"{sevenZipPath}\"",
                                Arguments = args,
                                UseShellExecute = false,
                                RedirectStandardOutput = true,
                                CreateNoWindow = true
                            };
                            
                            using (Process process = new Process())
                            {
                                process.StartInfo = psi;
                                process.Start();
                                
                                // Leer salida para monitorear
                                StringBuilder output = new StringBuilder();
                                process.OutputDataReceived += (s, e) => {
                                    if (!string.IsNullOrEmpty(e.Data))
                                    {
                                        output.AppendLine(e.Data);
                                    }
                                };
                                
                                process.BeginOutputReadLine();
                                bool completed = process.WaitForExit(180000); // 3 minutos
                                
                                if (!completed)
                                {
                                    OnLogMessage("❌ Timeout extrayendo grupo");
                                    process.Kill();
                                    return false;
                                }
                                
                                if (process.ExitCode != 0)
                                {
                                    OnLogMessage($"⚠️ 7-zip falló con código: {process.ExitCode}");
                                    return false;
                                }
                            }
                            
                            // Ahora mover solo los archivos que necesitamos al destino final
                            int movedCount = 0;
                            foreach (string file in files)
                            {
                                try
                                {
                                    string sourcePath = Path.Combine(tempExtractDir, file);
                                    string targetPath = Path.Combine(extractPath, ApplyStripComponents(file, stripComponents));
                                    
                                    if (File.Exists(sourcePath))
                                    {
                                        // Crear directorio destino si no existe
                                        Directory.CreateDirectory(Path.GetDirectoryName(targetPath));
                                        
                                        // Mover archivo
                                        // File.Move(sourcePath, targetPath, true);
                                        if (File.Exists(targetPath))
                                        {
                                            File.Delete(targetPath);
                                        }
                                        File.Move(sourcePath, targetPath);                                        
                                        movedCount++;
                                    }
                                }
                                catch (Exception ex)
                                {
                                    OnLogMessage($"⚠️ Error moviendo archivo {file}: {ex.Message}");
                                }
                            }
                            
                            OnLogMessage($"✅ Moved {movedCount}/{files.Count} archivos del grupo");
                            return movedCount > 0;
                        }
                        finally
                        {
                            // Limpiar directorio temporal
                            try
                            {
                                Directory.Delete(tempExtractDir, true);
                            }
                            catch { }
                        }
                    }
                    finally
                    {
                        try { File.Delete(listFile); } catch { }
                    }
                }
                catch (Exception ex)
                {
                    OnLogMessage($"❌ Error extrayendo grupo: {ex.Message}");
                    return false;
                }
            });
        }

        // Método auxiliar para aplicar strip-components
        private string ApplyStripComponents(string path, int stripComponents)
        {
            if (stripComponents <= 0) return path;
            string[] parts = path.Split('/');
            if (parts.Length > stripComponents)
            {
                return string.Join("/", parts.Skip(stripComponents));
            }
            
            return path; // Si no hay suficientes partes, devolver original
        }


        private async Task<bool> ExtractAllWith7Zip(string tarPath, string extractPath)
        {
            return await Task.Run(() =>
            {
                try
                {
                    OnLogMessage("🔄 Extrayendo archivo completo con 7-zip...");
                    
                    string sevenZipPath = Get7ZipPath();
                    
                    // 1. VERIFICAR QUE EL ARCHIVO NO ESTÁ BLOQUEADO
                    OnLogMessage("🔍 Verificando acceso al archivo TAR...");
                    try
                    {
                        using (var testStream = new FileStream(tarPath, FileMode.Open, FileAccess.Read, FileShare.Read))
                        {
                            // Si podemos abrirlo en modo lectura compartida, está disponible
                            OnLogMessage("✅ Archivo TAR está disponible para lectura");
                        }
                    }
                    catch (IOException ioEx)
                    {
                        OnLogMessage($"❌ Archivo TAR está bloqueado: {ioEx.Message}");
                        OnLogMessage("🔄 Esperando 2 segundos y reintentando...");
                        Thread.Sleep(2000);
                        
                        // Reintentar
                        try
                        {
                            using (var testStream = new FileStream(tarPath, FileMode.Open, FileAccess.Read, FileShare.Read))
                            {
                                OnLogMessage("✅ Archivo TAR ahora está disponible");
                            }
                        }
                        catch
                        {
                            OnLogMessage("❌ Archivo aún bloqueado después de espera");
                            return false;
                        }
                    }
                    
                    // 2. Crear directorio destino si no existe
                    if (!Directory.Exists(extractPath))
                    {
                        Directory.CreateDirectory(extractPath);
                        OnLogMessage($"📁 Directorio creado: {extractPath}");
                    }
                    
                    // 3. Preparar comando 7-zip
                    string arguments = $"x \"{tarPath}\" -o\"{extractPath}\" -aoa -y -bso0 -bsp1";
                    OnLogMessage($"🔧 Comando 7-zip: \"{sevenZipPath}\" {arguments}");
                    
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = $"\"{sevenZipPath}\"",
                        Arguments = arguments,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true,
                        WorkingDirectory = Path.GetDirectoryName(tarPath)
                    };
                    
                    using (Process process = new Process())
                    {
                        process.StartInfo = psi;
                        process.Start();
                        
                        // Leer salida en tiempo real
                        StringBuilder output = new StringBuilder();
                        StringBuilder error = new StringBuilder();
                        
                        process.OutputDataReceived += (s, e) => {
                            if (!string.IsNullOrEmpty(e.Data))
                            {
                                output.AppendLine(e.Data);
                                OnLogMessage($"[7z] {e.Data}");
                            }
                        };
                        
                        process.ErrorDataReceived += (s, e) => {
                            if (!string.IsNullOrEmpty(e.Data))
                            {
                                error.AppendLine(e.Data);
                                OnLogMessage($"❌ [7z-error] {e.Data}");
                            }
                        };
                        
                        process.BeginOutputReadLine();
                        process.BeginErrorReadLine();
                        
                        // Esperar con timeout más largo
                        bool completed = process.WaitForExit(600000); // 10 minutos timeout
                        
                        if (!completed)
                        {
                            OnLogMessage("❌ Timeout en extracción completa");
                            try { process.Kill(); } catch { }
                            return false;
                        }
                        
                        OnLogMessage($"✅ 7-zip terminó con código: {process.ExitCode}");
                        
                        if (process.ExitCode == 0)
                        {
                            OnLogMessage("✅ Extracción completa exitosa");
                            
                            // Verificar archivos extraídos
                            if (Directory.Exists(extractPath))
                            {
                                string[] extractedFiles = Directory.GetFiles(extractPath, "*", SearchOption.AllDirectories);
                                string[] extractedDirs = Directory.GetDirectories(extractPath, "*", SearchOption.AllDirectories);
                                
                                OnLogMessage($"📊 Extracción completada: {extractedFiles.Length} archivos, {extractedDirs.Length} directorios");
                                
                                // Verificar archivo ejecutable principal
                                string[] exeFiles = Directory.GetFiles(extractPath, "*.exe", SearchOption.AllDirectories);
                                if (exeFiles.Length > 0)
                                {
                                    OnLogMessage($"🎯 Ejecutable principal: {Path.GetFileName(exeFiles[0])}");
                                }
                            }
                            
                            return true;
                        }
                        else
                        {
                            OnLogMessage($"❌ 7-zip falló con código: {process.ExitCode}");
                            
                            // Intentar método alternativo si falla
                            if (process.ExitCode == 2) // Error fatal
                            {
                                OnLogMessage("⚠️ Intentando método alternativo de extracción...");
                                return ExtractWithAlternativeMethod(tarPath, extractPath);
                            }
                            
                            return false;
                        }
                    }
                }
                catch (Exception ex)
                {
                    OnLogMessage($"❌ Error en extracción: {ex.Message}");
                    OnLogMessage($"📋 Stack trace: {ex.StackTrace}");
                    return false;
                }
            });
        }


        private bool ExtractWithAlternativeMethod(string tarPath, string extractPath)
        {
            try
            {
                OnLogMessage("🔄 Usando método alternativo: extracción por partes...");
                
                // Crear directorio temporal para extracción
                string tempExtractDir = Path.Combine(Path.GetTempPath(), $"atlas_temp_{Guid.NewGuid():N}");
                Directory.CreateDirectory(tempExtractDir);
                
                try
                {
                    string sevenZipPath = Get7ZipPath();
                    
                    // Paso 1: Listar contenido
                    OnLogMessage("📋 Listando contenido del TAR...");
                    ProcessStartInfo listPsi = new ProcessStartInfo
                    {
                        FileName = $"\"{sevenZipPath}\"",
                        Arguments = $"l \"{tarPath}\"",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        CreateNoWindow = true
                    };
                    
                    List<string> fileList = new List<string>();
                    using (Process listProcess = new Process())
                    {
                        listProcess.StartInfo = listPsi;
                        listProcess.Start();
                        string listOutput = listProcess.StandardOutput.ReadToEnd();
                        listProcess.WaitForExit();
                        
                        // Parsear lista (simplificado)
                        string[] lines = listOutput.Split('\n');
                        foreach (string line in lines)
                        {
                            if (line.Contains("Atlas_Interactivo") && !line.Contains("D...."))
                            {
                                int nameStart = line.LastIndexOf("  ") + 2;
                                if (nameStart > 2)
                                {
                                    string fileName = line.Substring(nameStart).Trim();
                                    if (!string.IsNullOrEmpty(fileName))
                                    {
                                        fileList.Add(fileName);
                                    }
                                }
                            }
                        }
                    }
                    
                    OnLogMessage($"📊 Encontrados {fileList.Count} archivos para extraer");
                    
                    // Paso 2: Extraer archivos importantes primero
                    if (fileList.Count > 0)
                    {
                        // Extraer los primeros 10 archivos para prueba
                        foreach (string file in fileList.Take(10))
                        {
                            OnLogMessage($"📄 Extrayendo: {file}");
                            ProcessStartInfo extractPsi = new ProcessStartInfo
                            {
                                FileName = $"\"{sevenZipPath}\"",
                                Arguments = $"e \"{tarPath}\" \"{file}\" -o\"{extractPath}\" -aoa -y",
                                UseShellExecute = false,
                                CreateNoWindow = true
                            };
                            
                            using (Process extractProcess = new Process())
                            {
                                extractProcess.StartInfo = extractPsi;
                                extractProcess.Start();
                                extractProcess.WaitForExit(30000);
                            }
                        }
                        
                        // Verificar si se extrajo algo
                        string[] extracted = Directory.GetFiles(extractPath, "*", SearchOption.AllDirectories);
                        if (extracted.Length > 0)
                        {
                            OnLogMessage($"✅ Método alternativo extrajo {extracted.Length} archivos");
                            return true;
                        }
                    }
                    
                    return false;
                }
                finally
                {
                    // Limpiar directorio temporal
                    try { Directory.Delete(tempExtractDir, true); } catch { }
                }
            }
            catch (Exception ex)
            {
                OnLogMessage($"❌ Método alternativo también falló: {ex.Message}");
                return false;
            }
        }

        // Método auxiliar para split compatible con .NET Framework 4.x
        private string[] SplitString(string input, string[] separators)
        {
            List<string> result = new List<string>();
            string[] temp = input.Split(separators, StringSplitOptions.None);
            
            foreach (string part in temp)
            {
                if (!string.IsNullOrWhiteSpace(part))
                {
                    result.Add(part);
                }
            }
            
            return result.ToArray();
        }        



        // Método para detectar prefijo común (como Qt)
        private string DetectPrefix(List<string> fileList)
        {
            if (fileList.Count == 0) return "";
            
            // Tomar el primer archivo como referencia
            string firstFile = fileList[0];
            
            // Buscar el primer directorio en la ruta
            if (firstFile.Contains('/'))
            {
                int firstSlash = firstFile.IndexOf('/');
                string potentialPrefix = firstFile.Substring(0, firstSlash + 1);
                
                // Verificar que al menos el 90% de los archivos tengan este prefijo
                int matchingCount = 0;
                int checkCount = Math.Min(100, fileList.Count); // Verificar máximo 100 archivos
                
                for (int i = 0; i < checkCount; i++)
                {
                    if (fileList[i].StartsWith(potentialPrefix))
                    {
                        matchingCount++;
                    }
                }
                
                if (matchingCount >= checkCount * 0.9) // 90% coincidencia
                {
                    return potentialPrefix;
                }
            }
            
            return "";
        }

        // Método para reorganizar archivos extraídos (mover fuera del directorio con prefijo)
        private async Task ReorganizeExtractedFiles(string extractPath, string prefix)
        {
            await Task.Run(() =>
            {
                try
                {
                    string prefixDir = prefix.TrimEnd('/');
                    string sourceDir = Path.Combine(extractPath, prefixDir);
                    
                    if (!Directory.Exists(sourceDir))
                    {
                        OnLogMessage($"⚠️ No se encontró directorio con prefijo: {prefixDir}");
                        return;
                    }
                    
                    OnLogMessage($"🔄 Reorganizando: Moviendo archivos desde {prefixDir}/...");
                    
                    // Mover todos los archivos un nivel arriba
                    string[] items = Directory.GetFileSystemEntries(sourceDir, "*", SearchOption.AllDirectories);
                    
                    int movedCount = 0;
                    int errorCount = 0;
                    
                    foreach (string item in items)
                    {
                        _cancellationToken.ThrowIfCancellationRequested();
                        
                        string relativePath = item.Substring(sourceDir.Length + 1);
                        string destPath = Path.Combine(extractPath, relativePath);
                        
                        // Crear directorio destino si no existe
                        Directory.CreateDirectory(Path.GetDirectoryName(destPath));
                        
                        try
                        {
                            if (File.Exists(item))
                            {
                                // Si el archivo destino ya existe, eliminarlo primero
                                if (File.Exists(destPath))
                                {
                                    File.Delete(destPath);
                                }
                                
                                File.Move(item, destPath);
                                movedCount++;
                                
                                // Mostrar progreso cada 100 archivos
                                if (movedCount % 100 == 0)
                                {
                                    OnLogMessage($"   {movedCount} archivos movidos...");
                                }
                            }
                            else if (Directory.Exists(item) && Directory.GetFileSystemEntries(item).Length == 0)
                            {
                                // Directorio vacío - eliminarlo
                                Directory.Delete(item);
                            }
                        }
                        catch (Exception ex)
                        {
                            errorCount++;
                            if (errorCount <= 5) // Mostrar solo los primeros 5 errores
                            {
                                OnLogMessage($"⚠️ Error moviendo {Path.GetFileName(item)}: {ex.Message}");
                            }
                        }
                    }
                    
                    // Intentar eliminar directorio fuente si está vacío
                    try
                    {
                        if (Directory.Exists(sourceDir) && !Directory.GetFileSystemEntries(sourceDir).Any())
                        {
                            Directory.Delete(sourceDir);
                            OnLogMessage($"🗑️ Directorio vacío eliminado: {prefixDir}");
                        }
                        else if (Directory.Exists(sourceDir))
                        {
                            OnLogMessage($"⚠️ Directorio {prefixDir} no está vacío, no se puede eliminar");
                        }
                    }
                    catch { }
                    
                    OnLogMessage($"✅ Reorganización completada: {movedCount} archivos movidos, {errorCount} errores");
                }
                catch (Exception ex)
                {
                    OnLogMessage($"⚠️ Error reorganizando archivos: {ex.Message}");
                }
            });
        }



        private string Get7ZipPath()
        {
            try
            {
                // Rutas absolutas primero
                string[] possiblePaths = {
                    @"C:\Program Files\7-Zip\7z.exe",
                    @"C:\Program Files (x86)\7-Zip\7z.exe"
                };
                
                foreach (string path in possiblePaths)
                {
                    if (File.Exists(path))
                    {
                        OnLogMessage($"✅ 7-zip encontrado en: {path}");
                        return path;
                    }
                }
                
                // Si no está en rutas absolutas, devolver la ruta por defecto
                OnLogMessage("⚠️ Usando ruta por defecto de 7-zip");
                return @"C:\Program Files\7-Zip\7z.exe";
            }
            catch
            {
                return @"C:\Program Files\7-Zip\7z.exe";
            }
        }


        private async Task GetTotalFileSize()
        {
            try
            {
                using (var client = CreateHttpClient())
                using (var request = new HttpRequestMessage(HttpMethod.Head, _url))
                {
                    var response = await client.SendAsync(request, _cancellationToken);
                    if (response.Content.Headers.ContentLength.HasValue)
                    {
                        _totalBytesToRead = response.Content.Headers.ContentLength.Value;
                        OnLogMessage($"📊 Tamaño total estimado: {_totalBytesToRead / (1024.0 * 1024.0 * 1024.0):F2} GB");
                    }
                    else
                    {
                        _totalBytesToRead = 20L * 1024L * 1024L * 1024L; // Asumir 20 GB
                        OnLogMessage($"📊 Tamaño estimado (fallback): {_totalBytesToRead / (1024.0 * 1024.0 * 1024.0):F2} GB");
                    }
                }
            }
            catch
            {
                _totalBytesToRead = 20L * 1024L * 1024L * 1024L;
                OnLogMessage($"📊 Usando tamaño estimado: {_totalBytesToRead / (1024.0 * 1024.0 * 1024.0):F2} GB");
            }
        }

        private HttpClient CreateHttpClient()
        {
            var handler = new HttpClientHandler
            {
                UseCookies = true,
                CookieContainer = new CookieContainer(),
                AllowAutoRedirect = true,
                AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
                UseProxy = false
            };
            
            var client = new HttpClient(handler);
            client.Timeout = TimeSpan.FromHours(3);
            client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
            client.DefaultRequestHeaders.Add("Accept", "*/*");
            client.DefaultRequestHeaders.Add("Accept-Language", "en-US,en;q=0.9");
            client.DefaultRequestHeaders.Add("Accept-Encoding", "gzip, deflate, br");
            client.DefaultRequestHeaders.Add("DNT", "1");
            client.DefaultRequestHeaders.Add("Connection", "keep-alive");
            client.DefaultRequestHeaders.Add("Upgrade-Insecure-Requests", "1");
            
            return client;
        }

        private bool IsInstallationComplete(string path)
        {
            try
            {
                if (!Directory.Exists(path))
                    return false;
                
                // Verificar si hay archivos clave de Atlas
                string[] keyFiles = {
                    "version.txt",
                    ".atlas_version.json",
                    "Atlas.exe",
                    "Atlas_Interactivo.exe",
                    "AtlasInteractivo.exe",
                    "app.exe",
                    "main.exe"
                };
                
                foreach (string file in keyFiles)
                {
                    if (File.Exists(Path.Combine(path, file)))
                    {
                        return true;
                    }
                }
                
                // Verificar por cantidad de archivos (mínimo 5 archivos)
                int fileCount = Directory.GetFiles(path, "*", SearchOption.AllDirectories).Length;
                return fileCount > 5;
            }
            catch
            {
                return false;
            }
        }

        private async Task<bool> DownloadCompleteFile()
        {
            try
            {
                using (var client = CreateHttpClient())
                {
                    // Iniciar descarga
                    using (var response = await client.GetAsync(_url, HttpCompletionOption.ResponseHeadersRead, _cancellationToken))
                    using (var stream = await response.Content.ReadAsStreamAsync())
                    {
                        byte[] buffer = new byte[BUFFER_SIZE];
                        
                        int bytesRead;
                        while ((bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, _cancellationToken)) > 0)
                        {
                            _cancellationToken.ThrowIfCancellationRequested();
                            
                            // Escribir al archivo temporal
                            await _tempFileStream.WriteAsync(buffer, 0, bytesRead, _cancellationToken);
                            
                            _totalBytesRead += bytesRead;
                            
                            // Actualizar progreso con ETA
                            UpdateProgressWithETA();
                        }
                        
                        OnLogMessage($"✅ Descarga completada: {_totalBytesRead / (1024.0 * 1024.0 * 1024.0):F2} GB");
                        return true;
                    }
                }
            }
            catch (OperationCanceledException)
            {
                OnLogMessage("Descarga cancelada");
                throw;
            }
            catch (Exception ex)
            {
                OnLogMessage($"❌ Error HTTP: {ex.Message}");
                return false;
            }
        }

        private void UpdateProgressWithETA()
        {
            try
            {
                if (_progress != null && _totalBytesToRead > 0)
                {
                    int percentage = (int)((_totalBytesRead * 100) / _totalBytesToRead);
                    _progress.Report(Math.Min(100, Math.Max(0, percentage)));
                    
                    // Calcular tiempo transcurrido
                    TimeSpan elapsed = DateTime.Now - _startTime;
                    
                    // Calcular velocidad en MB/s
                    double downloadedMB = _totalBytesRead / (1024.0 * 1024.0);
                    double speedMBps = 0;
                    if (elapsed.TotalSeconds > 0)
                    {
                        speedMBps = downloadedMB / elapsed.TotalSeconds;
                    }
                    
                    // Calcular ETA
                    string etaText = "";
                    if (speedMBps > 0.1 && _totalBytesRead < _totalBytesToRead)
                    {
                        double remainingMB = (_totalBytesToRead - _totalBytesRead) / (1024.0 * 1024.0);
                        int etaSeconds = (int)(remainingMB / speedMBps);
                        etaText = FormatETA(etaSeconds);
                    }
                    
                    // Actualizar estado cada 1 segundo
                    long currentTime = DateTime.Now.Ticks / TimeSpan.TicksPerMillisecond;
                    if (currentTime - _lastReportTime > 1000)
                    {
                        double downloadedGB = _totalBytesRead / (1024.0 * 1024.0 * 1024.0);
                        double totalGB = _totalBytesToRead / (1024.0 * 1024.0 * 1024.0);
                        
                        string status = $"Descarga: {downloadedGB:F2}/{totalGB:F2} GB ({percentage}%) - {speedMBps:F1} MB/s - ETA: {etaText}";
                        OnStatusUpdate(status);
                        
                        // Log cada 10%
                        if (percentage % 10 == 0 && currentTime - _lastReportTime > 5000)
                        {
                            OnLogMessage($"📥 {percentage}% - {downloadedGB:F2}/{totalGB:F2} GB - Vel: {speedMBps:F1} MB/s - ETA: {etaText}");
                        }
                        
                        _lastReportTime = currentTime;
                    }
                }
            }
            catch
            {
                // Ignorar errores en actualización de UI
            }
        }

        private string FormatETA(int totalSeconds)
        {
            if (totalSeconds <= 0) return "0s";
            
            if (totalSeconds < 60)
                return $"{totalSeconds}s";
            
            if (totalSeconds < 3600)
            {
                int minutesValue = totalSeconds / 60;
                int seconds = totalSeconds % 60;
                return $"{minutesValue}m {seconds}s";
            }
            
            int hours = totalSeconds / 3600;
            int remainingSeconds = totalSeconds % 3600;
            int minutesRemaining = remainingSeconds / 60;
            return $"{hours}h {minutesRemaining}m";
        }

        private int CountExtractedFiles(string path)
        {
            try
            {
                if (!Directory.Exists(path))
                    return 0;
                
                return Directory.GetFiles(path, "*", SearchOption.AllDirectories).Length;
            }
            catch
            {
                return 0;
            }
        }

        // private void Cleanup()
        // {
        //     try
        //     {
        //         _tempFileStream?.Dispose();
                
        //         if (File.Exists(_tempTarPath))
        //         {
        //             File.Delete(_tempTarPath);
        //             OnLogMessage("🗑️ Archivo temporal eliminado");
        //         }
        //     }
        //     catch { }
        // }

        private void Cleanup()
        {
            try
            {
                // 1. Cerrar y liberar el stream
                if (_tempFileStream != null)
                {
                    try
                    {
                        _tempFileStream.Close();
                        _tempFileStream.Dispose();
                    }
                    catch { }
                    _tempFileStream = null;
                }
                
                // 2. Esperar un poco para que el sistema operativo libere el archivo
                Thread.Sleep(500);
                
                // 3. Intentar eliminar el archivo temporal
                if (!string.IsNullOrEmpty(_tempTarPath) && File.Exists(_tempTarPath))
                {
                    try
                    {
                        // Primero intentar eliminar normalmente
                        File.Delete(_tempTarPath);
                        OnLogMessage("🗑️ Archivo temporal eliminado");
                    }
                    catch (IOException)
                    {
                        OnLogMessage("⚠️ Archivo temporal aún bloqueado, intentando forzar...");
                        
                        // Esperar un poco más
                        Thread.Sleep(1000);
                        
                        try
                        {
                            File.Delete(_tempTarPath);
                            OnLogMessage("🗑️ Archivo temporal eliminado después de espera");
                        }
                        catch
                        {
                            OnLogMessage("⚠️ No se pudo eliminar archivo temporal, se limpiará al reiniciar");
                        }
                    }
                }
            }
            catch { }
        }

        public void Dispose()
        {
            if (!_isDisposed)
            {
                _isDisposed = true;
                Cleanup();
                GC.SuppressFinalize(this);
            }
        }
    }

    // ========== EXTENSIÓN PARA TRUNCAR STRINGS ==========
    public static class StringExtensions
    {
        public static string Truncate(this string value, int maxLength)
        {
            if (string.IsNullOrEmpty(value)) return value;
            return value.Length <= maxLength ? value : value.Substring(0, maxLength) + "...";
        }
    }

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
        


        // ========== AÑADIR VARIABLES DE CONFIGURACIÓN ==========
        private const bool USE_FTP_DEFAULT = true; // Cambiar a false para usar Google Drive por defecto
        private bool useFTP = USE_FTP_DEFAULT;
        //private bool useGoogleDrive = !USE_FTP_DEFAULT;
        private string ftpUrl = "ftp://atlas.example.com/Atlas_Interactivo_Windows.tar"; // Cambiar por tu FTP real
        private string googleDriveId = "1GrsCj1gQgvGBRf94ovARro_QuGuVCrTk"; // ID del archivo TAR en Google Drive

        // ========== MÉTODO PARA PROCESAR ARGUMENTOS DE LÍNEA DE COMANDOS ==========
        private void ProcessCommandLineArgs()
        {
            string[] args = Environment.GetCommandLineArgs();
            
            for (int i = 1; i < args.Length; i++)
            {
                string arg = args[i].ToLower();
                
                switch (arg)
                {
                    case "--use-ftp":
                    case "/ftp":
                    case "-ftp":
                        useFTP = true;
                        //useGoogleDrive = false;
                        LogMessage("🌐 Método de descarga configurado: FTP", COLOR_PRIMARY);
                        break;
                        
                    case "--use-drive":
                    case "/drive":
                    case "-drive":
                        useFTP = false;
                        //useGoogleDrive = true;
                        LogMessage("🌐 Método de descarga configurado: Google Drive", COLOR_PRIMARY);
                        break;
                        
                    case "--ftp-url":
                    case "/ftpurl":
                        if (i + 1 < args.Length)
                        {
                            ftpUrl = args[++i];
                            LogMessage($"🔗 URL FTP configurada: {ftpUrl}", COLOR_PRIMARY);
                        }
                        break;
                        
                    case "--drive-id":
                    case "/driveid":
                        if (i + 1 < args.Length)
                        {
                            googleDriveId = args[++i];
                            LogMessage($"🔗 ID Google Drive configurado: {googleDriveId}", COLOR_PRIMARY);
                        }
                        break;
                        
                    case "--help":
                    case "/?":
                    case "-h":
                        ShowHelp();
                        Environment.Exit(0);
                        break;
                }
            }
        }

        // ========== MOSTRAR AYUDA ==========
        private void ShowHelp()
        {
            string helpText = @"
        Atlas Interactivo Installer for Windows v1.0.0

        Uso: AtlasInstaller.exe [OPCIONES]

        Opciones de descarga:
        --use-ftp, /ftp, -ftp      Usar FTP para descarga (POR DEFECTO)
        --use-drive, /drive, -drive Usar Google Drive para descarga
        
        --ftp-url URL              Especificar URL FTP personalizada
        --drive-id ID              Especificar ID de Google Drive personalizado

        Opciones generales:
        --help, /?, -h            Mostrar esta ayuda
        --install-dir PATH        Directorio de instalación

        Ejemplos:
        AtlasInstaller.exe                      # Usar FTP por defecto
        AtlasInstaller.exe --use-drive          # Usar Google Drive
        AtlasInstaller.exe --use-ftp            # Forzar FTP
        AtlasInstaller.exe --use-drive --drive-id TU_ID_AQUI
        
        Configuración FTP por defecto: " + ftpUrl + @"

        NOTA: Requiere 7-zip instalado para extracción.
        ";
            
            MessageBox.Show(helpText, "Ayuda - Atlas Interactivo Installer", 
                MessageBoxButtons.OK, MessageBoxIcon.Information);
        }


        // Método para obtener ruta de wget
        private string GetWgetPath()
        {
            try
            {
                // Buscar wget en rutas comunes de Windows
                string[] possiblePaths = {
                    @"C:\Program Files\Git\usr\bin\wget.exe",
                    @"C:\Program Files (x86)\Git\usr\bin\wget.exe",
                    @"C:\msys64\usr\bin\wget.exe",
                    @"C:\cygwin64\bin\wget.exe",
                    @"C:\cygwin\bin\wget.exe",
                    @"C:\Windows\System32\wget.exe", // Si está en PATH
                    @"wget.exe" // Buscar en PATH
                };
                
                foreach (string path in possiblePaths)
                {
                    if (File.Exists(path))
                    {
                        LogMessage($"✅ wget encontrado en: {path}", COLOR_SUCCESS);
                        return path;
                    }
                }
                
                // Intentar encontrar wget usando where (comando de Windows)
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = "where",
                        Arguments = "wget",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        CreateNoWindow = true
                    };
                    
                    using (Process process = new Process())
                    {
                        process.StartInfo = psi;
                        process.Start();
                        string output = process.StandardOutput.ReadToEnd();
                        process.WaitForExit();
                        
                        if (!string.IsNullOrWhiteSpace(output))
                        {
                            string[] paths = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                            foreach (string path in paths)
                            {
                                if (path.EndsWith("wget.exe", StringComparison.OrdinalIgnoreCase) && File.Exists(path))
                                {
                                    LogMessage($"✅ wget encontrado en PATH: {path}", COLOR_SUCCESS);
                                    return path;
                                }
                            }
                        }
                    }
                }
                catch { }
                
                LogMessage("⚠️ wget no encontrado. Instala Git Bash para usar FTP.", COLOR_WARNING);
                return null;
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error buscando wget: {ex.Message}", COLOR_WARNING);
                return null;
            }
        }


        private Task<bool> DownloadWithWgetResumable(string url, string outputPath, CancellationToken cancellationToken)
        {
            return Task.Run(() =>  // ← Envolver en Task.Run para ejecutar en otro hilo
            {
                try
                {
                    LogMessage("📥 Iniciando descarga con wget (resumible)...", COLOR_PRIMARY);
                    
                    // Verificar si wget está disponible
                    string wgetPath = GetWgetPath();
                    if (string.IsNullOrEmpty(wgetPath))
                    {
                        LogMessage("❌ wget no encontrado. Instálalo o usa el método HTTP integrado.", COLOR_ERROR);
                        return false;
                    }
                    
                    // Construir comando wget con opciones similares a Linux
                    string arguments = $"--no-check-certificate --progress=bar:force:noscroll -c -O \"{outputPath}\" --tries=3 --timeout=60 --waitretry=10 \"{url}\"";
                    
                    LogMessage($"🔧 Comando wget: {wgetPath} {arguments}");
                    
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = wgetPath,
                        Arguments = arguments,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true,
                        WorkingDirectory = Path.GetTempPath()
                    };
                    
                    using (Process process = new Process())
                    {
                        process.StartInfo = psi;
                        process.Start();
                        
                        // Leer salida para mostrar progreso
                        StringBuilder output = new StringBuilder();
                        StringBuilder error = new StringBuilder();
                        
                        process.OutputDataReceived += (s, e) => {
                            if (!string.IsNullOrEmpty(e.Data))
                            {
                                output.AppendLine(e.Data);
                                
                                // Parsear progreso de wget (formato: 45%[======>...])
                                var match = Regex.Match(e.Data, @"(\d+)%\[");
                                if (match.Success)
                                {
                                    int percent = int.Parse(match.Groups[1].Value);
                                    UpdateProgress(10 + (int)(percent * 0.4));
                                    UpdateStatus($"Descargando: {percent}%", progressBar.Value);
                                    
                                    if (percent % 10 == 0)
                                    {
                                        LogMessage($"📥 {percent}% descargado...");
                                    }
                                }
                            }
                        };
                        
                        process.ErrorDataReceived += (s, e) => {
                            if (!string.IsNullOrEmpty(e.Data))
                            {
                                error.AppendLine(e.Data);
                                
                                // Log de errores pero continuar
                                if (!e.Data.Contains("Continuing"))
                                {
                                    LogMessage($"[wget] {e.Data}");
                                }
                            }
                        };
                        
                        process.BeginOutputReadLine();
                        process.BeginErrorReadLine();
                        
                        // Esperar con timeout (2 horas)
                        bool completed = process.WaitForExit(7200000);
                        
                        if (!completed)
                        {
                            LogMessage("❌ Timeout en descarga wget", COLOR_ERROR);
                            try { process.Kill(); } catch { }
                            return false;
                        }
                        
                        if (process.ExitCode != 0)
                        {
                            LogMessage($"❌ wget falló con código: {process.ExitCode}", COLOR_WARNING);
                            
                            // Si es un error de conexión pero el archivo existe parcialmente, podemos continuar
                            if (File.Exists(outputPath) && new FileInfo(outputPath).Length > 0)
                            {
                                LogMessage("⚠️ Archivo parcial descargado. Se puede reanudar en el siguiente intento.", COLOR_WARNING);
                            }
                            
                            return false;
                        }
                        
                        // Verificar que el archivo existe y no está vacío
                        if (File.Exists(outputPath))
                        {
                            FileInfo fileInfo = new FileInfo(outputPath);
                            if (fileInfo.Length > 0)
                            {
                                LogMessage($"✅ Descarga completada: {fileInfo.Length / (1024.0 * 1024.0 * 1024.0):F2} GB", COLOR_SUCCESS);
                                return true;
                            }
                            else
                            {
                                LogMessage("❌ Archivo descargado está vacío", COLOR_ERROR);
                                File.Delete(outputPath);
                                return false;
                            }
                        }
                        
                        return false;
                    }
                }
                catch (Exception ex)
                {
                    LogMessage($"❌ Error con wget: {ex.Message}", COLOR_ERROR);
                    return false;
                }
            });
        }

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
        
        // Variables de estado mejoradas
        private bool isInstalling = false;
        private string installPath = @"C:\AtlasInteractivo";
        private CancellationTokenSource cancellationTokenSource;
        private bool isCancelling = false;
        
        // Constantes para la instalación
        private const long REQUIRED_SPACE_GB = 25;
        private const int MAX_DOWNLOAD_RETRIES = 3;
        private const int FILE_GROUP_SIZE = 1000; // Extraer en grupos de 1000 archivos
        private const bool USE_LOCAL_SERVER = true; // Cambiar a true para pruebas locales
        
        // Añadir estas variables a la clase MainForm
        private System.Windows.Forms.Timer progressTimer;
        // private DateTime downloadStartTime;

        // ID de Google Drive para TAR
        private const string GOOGLE_DRIVE_ID = "1GrsCj1gQgvGBRf94ovARro_QuGuVCrTk"; // Cambiar por ID del TAR

        public MainForm()
        {
            InitializeComponent();
            SetupUI();
            UpdateDiskSpace();

            // Timer simplificado
            progressTimer = new System.Windows.Forms.Timer();
            progressTimer.Interval = 1000;
            progressTimer.Tick += (s, e) => {
                if (isInstalling) UpdateDiskSpace();
            };

            progressTimer.Start();
        }




        // ========== MÉTODOS SIMPLIFICADOS PARA GOOGLE DRIVE ==========

        private async Task<string> GetDirectGoogleDriveUrl(string driveId)
        {
            try
            {
                LogMessage("🌐 Obteniendo enlace directo de Google Drive...", COLOR_PRIMARY);
                
                // Método 1: Intentar con la URL directa con confirm=t
                string directUrl = $"https://drive.google.com/uc?id={driveId}&export=download&confirm=t";
                
                // Método 2: URL alternativa usando drive.usercontent.google.com
                string alternativeUrl = $"https://drive.usercontent.google.com/download?id={driveId}&export=download&confirm=t";
                
                // Probar ambas URLs
                return await TestUrl(directUrl) ? directUrl : alternativeUrl;
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error obteniendo URL: {ex.Message}", COLOR_WARNING);
                // Fallback
                return $"https://drive.google.com/uc?id={driveId}&export=download&confirm=t";
            }
        }

        private async Task<bool> TestUrl(string url)
        {
            try
            {
                using (var client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(10);
                    var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                    return response.IsSuccessStatusCode;
                }
            }
            catch
            {
                return false;
            }
        }

        private async Task<bool> DownloadGoogleDriveWithTarMethod(string driveId, string extractPath, CancellationToken cancellationToken)
        {
            try
            {
                // Obtener URL directa
                string downloadUrl = await GetDirectGoogleDriveUrl(driveId);
                LogMessage($"🔗 URL de descarga TAR: {downloadUrl}", COLOR_PRIMARY);
                
                // INICIAR PROGRESO DESDE 10%
                UpdateStatus("Obteniendo información del servidor...", 10);
                
                // **USAR LA NUEVA CLASE BufferedTarDownloader**
                using (var downloader = new BufferedTarDownloader(
                    downloadUrl, 
                    extractPath, 
                    new Progress<int>(p => {
                        // Ajustar progreso: 10-60% para descarga, 60-100% para extracción
                        int progress = 10 + (int)(p * 0.9); // 10% a 100%
                        UpdateProgress(Math.Min(100, Math.Max(10, progress)));
                    }), 
                    cancellationToken))
                {
                    downloader.LogMessage += (sender, msg) => LogMessage(msg);
                    downloader.StatusUpdate += (sender, status) => UpdateStatus(status, progressBar.Value);
                    
                    LogMessage("🚀 Iniciando descarga con BufferedTarDownloader...", COLOR_PRIMARY);
                    UpdateStatus("Iniciando descarga y extracción TAR...", 15);
                    
                    return await downloader.DownloadAndExtractIncremental();
                }
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error descargando TAR: {ex.Message}", COLOR_ERROR);
                return false;
            }
        }


        private string Get7ZipPath()
        {
            try
            {
                // Rutas absolutas primero
                string[] possiblePaths = {
                    @"C:\Program Files\7-Zip\7z.exe",
                    @"C:\Program Files (x86)\7-Zip\7z.exe"
                };
                
                foreach (string path in possiblePaths)
                {
                    if (File.Exists(path))
                    {
                        LogMessage($"✅ 7-zip encontrado en: {path}");
                        return path;
                    }
                }
                
                // Si no está en rutas absolutas, devolver la ruta por defecto
                LogMessage("⚠️ Usando ruta por defecto de 7-zip");
                return @"C:\Program Files\7-Zip\7z.exe";
            }
            catch
            {
                return @"C:\Program Files\7-Zip\7z.exe";
            }
        }



        // NUEVO MÉTODO: Verificar si ya está instalado
        private bool IsAlreadyInstalled(string path)
        {
            try
            {
                if (!Directory.Exists(path))
                    return false;
                
                // Verificar archivos clave
                string[] requiredFiles = {
                    ".atlas_version.json",
                    "version.txt",
                    "Atlas.exe",
                    "README.md",
                    "LICENSE"
                };
                
                int foundCount = 0;
                foreach (string file in requiredFiles)
                {
                    if (File.Exists(Path.Combine(path, file)))
                    {
                        foundCount++;
                    }
                }
                
                // Si encontramos al menos 2 archivos clave, consideramos instalado
                return foundCount >= 2;
            }
            catch
            {
                return false;
            }
        }





        private async Task<bool> Install7ZipSimple()
        {
            try
            {
                LogMessage("📦 Instalando 7-zip...", COLOR_PRIMARY);
                
                // 1. Verificar si ya está instalado
                if (Is7ZipInstalled())
                {
                    LogMessage("✅ 7-zip ya está instalado", COLOR_SUCCESS);
                    return true;
                }
                
                // 2. Buscar instalador en Descargas
                string downloadsPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + @"\Downloads";
                string installerPath = FindLatest7ZipInstaller(downloadsPath);
                
                bool userInstalledManually = false;
                
                if (string.IsNullOrEmpty(installerPath))
                {
                    // Abrir página de descarga
                    Process.Start("https://www.7-zip.org/download.html");
                    
                    LogMessage("⚠️ 7-zip no encontrado. Por favor:", COLOR_WARNING);
                    LogMessage("1. Descargue 7-zip desde el navegador", COLOR_WARNING);
                    LogMessage("2. Guárdelo en 'Descargas'", COLOR_WARNING);
                    LogMessage("3. Ejecútelo y complete la instalación", COLOR_WARNING);
                    LogMessage("4. Haga clic en Aceptar en esta ventana", COLOR_WARNING);
                    
                    // MOSTRAR MessageBox y ESPERAR A QUE EL USUARIO LO CIERRE
                    var dialogResult = MessageBox.Show(
                        "7-zip no encontrado.\n\n" +
                        "Por favor:\n" +
                        "1. Descargue 7-zip desde el navegador que se abrirá\n" +
                        "2. Guárdelo en 'Descargas'\n" +
                        "3. Ejecútelo y complete la instalación\n" +
                        "4. Haga clic en Aceptar para continuar\n\n" +
                        "¿Ya instaló 7-zip?",
                        "7-zip requerido",
                        MessageBoxButtons.OKCancel,
                        MessageBoxIcon.Information);
                    
                    if (dialogResult == DialogResult.Cancel)
                    {
                        LogMessage("❌ Usuario canceló la instalación de 7-zip", COLOR_ERROR);
                        return false;
                    }
                    
                    userInstalledManually = true;
                    
                    // Buscar nuevamente después de que el usuario cierre el MessageBox
                    installerPath = FindLatest7ZipInstaller(downloadsPath);
                    
                    if (string.IsNullOrEmpty(installerPath))
                    {
                        // Esperar un poco más y buscar de nuevo
                        for (int i = 0; i < 3; i++)
                        {
                            LogMessage($"Esperando para buscar 7-zip... ({i + 1}/3)", COLOR_WARNING);
                            await Task.Delay(5000); // Esperar 5 segundos
                            installerPath = FindLatest7ZipInstaller(downloadsPath);
                            if (!string.IsNullOrEmpty(installerPath))
                                break;
                        }
                        
                        if (string.IsNullOrEmpty(installerPath))
                        {
                            // Dar otra oportunidad al usuario
                            var result = MessageBox.Show(
                                "No se encontró el instalador de 7-zip en Descargas.\n\n" +
                                "¿Ya descargó e instaló 7-zip?",
                                "Verificar 7-zip",
                                MessageBoxButtons.YesNo,
                                MessageBoxIcon.Question);
                            
                            if (result == DialogResult.No)
                            {
                                throw new Exception("No se encontró el instalador de 7-zip en Descargas");
                            }
                        }
                    }
                }
                
                // Si encontramos el instalador, ejecutarlo
                if (!string.IsNullOrEmpty(installerPath))
                {
                    LogMessage($"🔧 Ejecutando {Path.GetFileName(installerPath)}...", COLOR_PRIMARY);
                    
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = installerPath,
                        UseShellExecute = true,
                        Verb = "runas" // Ejecutar como administrador si es necesario
                    });
                    
                    MessageBox.Show(
                        "Complete la instalación de 7-zip y luego haga clic en Aceptar en esta ventana.",
                        "Complete la instalación",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                }
                else if (userInstalledManually)
                {
                    // El usuario dijo que ya instaló manualmente
                    LogMessage("⚠️ Asumiendo que el usuario instaló 7-zip manualmente...", COLOR_WARNING);
                }
                
                // 4. Esperar y verificar
                await Task.Delay(8000); // Esperar 8 segundos para que termine la instalación
                
                // Verificar múltiples veces
                bool isInstalled = false;
                for (int attempt = 0; attempt < 5; attempt++)
                {
                    if (Is7ZipInstalled())
                    {
                        isInstalled = true;
                        break;
                    }
                    await Task.Delay(2000); // Esperar 2 segundos entre intentos
                }
                
                if (!isInstalled)
                {
                    // Última verificación
                    await Task.Delay(3000);
                    isInstalled = Is7ZipInstalled();
                }
                
                if (isInstalled)
                {
                    LogMessage("✅ 7-zip instalado correctamente", COLOR_SUCCESS);
                    return true;
                }
                else
                {
                    throw new Exception("No se pudo verificar la instalación de 7-zip. Por favor, instálelo manualmente.");
                }
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error instalando 7-zip: {ex.Message}", COLOR_ERROR);
                return false;
            }
        }


        private bool Is7ZipInstalled()
        {
            try
            {
                // Verificar rutas comunes de 7-zip
                string[] possiblePaths = {
                    @"C:\Program Files\7-Zip\7z.exe",
                    @"C:\Program Files (x86)\7-Zip\7z.exe",
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "7-Zip", "7z.exe"),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "7-Zip", "7z.exe")
                };
                
                foreach (string path in possiblePaths)
                {
                    if (File.Exists(path))
                    {
                        LogMessage($"✅ 7-zip encontrado en: {path}", COLOR_SUCCESS);
                        return true;
                    }
                }
                
                // También verificar en PATH
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = "where",
                        Arguments = "7z",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        CreateNoWindow = true
                    };
                    
                    using (Process process = new Process())
                    {
                        process.StartInfo = psi;
                        process.Start();
                        string output = process.StandardOutput.ReadToEnd();
                        process.WaitForExit();
                        
                        if (!string.IsNullOrWhiteSpace(output) && output.Contains("7z.exe"))
                        {
                            LogMessage($"✅ 7-zip encontrado en PATH: {output.Trim()}", COLOR_SUCCESS);
                            return true;
                        }
                    }
                }
                catch { }
                
                LogMessage("⚠️ 7-zip no encontrado en ninguna ruta conocida", COLOR_WARNING);
                return false;
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error verificando 7-zip: {ex.Message}", COLOR_WARNING);
                return false;
            }
        }

        private string FindLatest7ZipInstaller(string downloadsPath)
        {
            try
            {
                if (!Directory.Exists(downloadsPath)) return null;
                
                // Buscar archivos que parezcan instaladores de 7-zip
                string[] files = Directory.GetFiles(downloadsPath, "7z*.exe")
                    .Concat(Directory.GetFiles(downloadsPath, "7-zip*.exe"))
                    .ToArray();
                
                // Filtrar por tamaño (1-10 MB) y tomar el más reciente
                var validFiles = files
                    .Where(f => 
                    {
                        try
                        {
                            var info = new FileInfo(f);
                            return info.Length > 1000000 && info.Length < 20000000;
                        }
                        catch { return false; }
                    })
                    .OrderByDescending(f => new FileInfo(f).LastWriteTime)
                    .ToList();
                
                return validFiles.FirstOrDefault();
            }
            catch
            {
                return null;
            }
        }


        private async Task<bool> DownloadWithTarMethod(string url, string extractPath, CancellationToken cancellationToken)
        {
            try
            {
                LogMessage("🚀 Iniciando descarga TAR...", COLOR_PRIMARY);
                
                using (var downloader = new BufferedTarDownloader(url, extractPath, 
                    new Progress<int>(p => UpdateProgress(10 + (int)(p * 0.5))), cancellationToken))
                {
                    downloader.LogMessage += (sender, msg) => LogMessage(msg);
                    downloader.StatusUpdate += (sender, status) => UpdateStatus(status, progressBar.Value);
                    
                    return await downloader.DownloadAndExtractIncremental();
                }
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error en descarga TAR: {ex.Message}", COLOR_ERROR);
                return false;
            }
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
            ""install_date"": ""{DateTime.Now:yyyy-MM-ddTHH:mm:ss}"",
            ""file_type"": ""tar"",
            ""download_size"": ""variable"",
            ""download_resumable"": true,
            ""download_attempts"": 1,
            ""extraction_method"": ""tar_exe_incremental"",
            ""extraction_groups"": 50000,
            ""extraction_tool"": ""tar.exe"",
            ""platform"": ""windows"",
            ""installer_version"": ""3.0.0"",
            ""requires_tar"": true
        }}";
                
                File.WriteAllText(versionFile, json, Encoding.UTF8);
                LogMessage("✅ Archivo de versión creado", COLOR_SUCCESS);
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ No se pudo crear archivo de versión: {ex.Message}", COLOR_WARNING);
            }
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
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 270));  // Config (AUMENTADO de 220 a 260)
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 80));    // Progress
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
                            "• Descarga resumible con 3 reintentos\r\n" +
                            "• Requiere 7-zip (se instala automáticamente)";
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
            
            // Fila 2: Barra de progreso MEJORADA
            progressBar = new ProgressBar();
            progressBar.Dock = DockStyle.Fill;
            progressBar.Value = 0;
            progressBar.Style = ProgressBarStyle.Continuous;
            progressBar.ForeColor = COLOR_PRIMARY;
            progressBar.Height = 25;
            progressBar.Step = 1;

            // Configurar para mostrar porcentaje (solo en Windows Forms nativo)
            // Nota: En algunos sistemas, puede necesitarse custom drawing
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
            btnExit.Text = "CANCELAR";
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
            lblFooter.Text = "⚠️ Requiere conexión a Internet • Descarga resumible • 3 reintentos • Requiere 7-zip • Espacio temporal: 25 GB";
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
            toolTip.SetToolTip(btnExit, "Cancelar instalación y salir");
            toolTip.SetToolTip(btnInstall, "Iniciar instalación de Atlas Interactivo");
            toolTip.SetToolTip(txtDirectory, "Ruta donde se instalará el programa");
            toolTip.SetToolTip(chkDesktop, "Crear acceso directo en el escritorio");
            toolTip.SetToolTip(chkMenu, "Añadir al menú de aplicaciones");
        }

        private void UpdateDiskSpace()
        {
            try
            {
                if (string.IsNullOrEmpty(installPath))
                    return;
                    
                string drivePath = Path.GetPathRoot(installPath);
                if (string.IsNullOrEmpty(drivePath))
                    drivePath = "C:\\";
                
                DriveInfo drive = new DriveInfo(drivePath);
                
                if (drive.IsReady)
                {
                    double availableGB = drive.AvailableFreeSpace / (1024.0 * 1024.0 * 1024.0);
                    long requiredBytes = REQUIRED_SPACE_GB * 1024L * 1024L * 1024L;
                    
                    // Usar Invoke para actualizar UI desde hilos secundarios
                    if (this.InvokeRequired)
                    {
                        this.Invoke(new Action(() => {
                            lblDiskSpace.Text = $"💾 Espacio en {drive.Name}: {availableGB:F2} GB";
                            
                            if (drive.AvailableFreeSpace >= requiredBytes)
                            {
                                lblDiskSpace.ForeColor = COLOR_SUCCESS;
                                lblSpaceWarning.Text = "✅ SUFICIENTE";
                                lblSpaceWarning.ForeColor = COLOR_SUCCESS;
                            }
                            else
                            {
                                lblDiskSpace.ForeColor = COLOR_ERROR;
                                lblSpaceWarning.Text = $"❌ REQUIERE {REQUIRED_SPACE_GB} GB";
                                lblSpaceWarning.ForeColor = COLOR_ERROR;
                            }
                        }));
                    }
                    else
                    {
                        lblDiskSpace.Text = $"💾 Espacio en {drive.Name}: {availableGB:F2} GB";
                        
                        if (drive.AvailableFreeSpace >= requiredBytes)
                        {
                            lblDiskSpace.ForeColor = COLOR_SUCCESS;
                            lblSpaceWarning.Text = "✅ SUFICIENTE";
                            lblSpaceWarning.ForeColor = COLOR_SUCCESS;
                            
                            // Log solo durante instalación
                            if (isInstalling)
                            {
                                // Log cada cambio significativo (cada 0.5 GB)
                                if (availableGB % 0.5 < 0.1)
                                {
                                    LogMessage($"💾 Espacio disponible: {availableGB:F2} GB", COLOR_SUCCESS);
                                }
                            }
                        }
                        else
                        {
                            lblDiskSpace.ForeColor = COLOR_ERROR;
                            lblSpaceWarning.Text = $"❌ REQUIERE {REQUIRED_SPACE_GB} GB";
                            lblSpaceWarning.ForeColor = COLOR_ERROR;
                            
                            // SIEMPRE mostrar advertencia si hay poco espacio durante instalación
                            if (isInstalling)
                            {
                                LogMessage($"⚠️ Espacio bajo: {availableGB:F2} GB", COLOR_WARNING);
                            }
                        }
                    }
                    
                    // Forzar actualización de UI
                    Application.DoEvents();
                }
            }
            catch (Exception ex)
            {
                // Mostrar error solo si estamos instalando
                if (isInstalling)
                {
                    LogMessage($"⚠️ Error verificando espacio: {ex.Message}", COLOR_WARNING);
                }
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








        // ========== MODIFICAR MainForm_Load PARA PROCESAR ARGUMENTOS ==========
        private void MainForm_Load(object sender, EventArgs e)
        {
            // Asegurar que todo esté visible
            this.Refresh();
            
            // **REDUCIR EL TAMAÑO DE LA VENTANA AL CARGAR**
            this.Height = Math.Min(750, Screen.PrimaryScreen.Bounds.Height - 100);
            
            // Procesar argumentos de línea de comandos
            ProcessCommandLineArgs();
            
            // Actualizar UI con método de descarga seleccionado
            UpdateDownloadMethodDisplay();
            
            // Asegurar que la ventana esté activa y visible
            this.TopMost = true;
            this.TopMost = false; // Esto trae la ventana al frente
            this.Activate();
            this.Focus();
        }

        // ========== ACTUALIZAR DISPLAY DEL MÉTODO DE DESCARGA ==========
        private void UpdateDownloadMethodDisplay()
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(UpdateDownloadMethodDisplay));
                return;
            }
            
            string methodText = useFTP ? "FTP" : "Google Drive";
            Color methodColor = useFTP ? COLOR_PRIMARY : Color.FromArgb(66, 133, 244); // Azul Google
            
            // Crear o actualizar etiqueta
            Label lblDownloadMethod = this.Controls.Find("lblDownloadMethod", true).FirstOrDefault() as Label;
            
            if (lblDownloadMethod == null)
            {
                lblDownloadMethod = new Label();
                lblDownloadMethod.Name = "lblDownloadMethod";
                lblDownloadMethod.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
                lblDownloadMethod.TextAlign = ContentAlignment.MiddleCenter;
                lblDownloadMethod.Dock = DockStyle.Top;
                lblDownloadMethod.Height = 25;
                
                // Insertar después del título
                Control headerPanel = this.Controls[0]; // Asumiendo que el primer control es el layout principal
                if (headerPanel is TableLayoutPanel)
                {
                    // Encontrar la posición correcta
                }
                else
                {
                    this.Controls.Add(lblDownloadMethod);
                    lblDownloadMethod.BringToFront();
                }
            }
            
            lblDownloadMethod.Text = $"🌐 Método de descarga: {methodText}";
            lblDownloadMethod.ForeColor = methodColor;
            
            // Actualizar mensaje de información
            UpdateInfoText();
        }

        // ========== ACTUALIZAR TEXTO INFORMATIVO ==========
        private void UpdateInfoText()
        {
            if (pnlInfo != null && pnlInfo.Controls.Count > 1)
            {
                TextBox infoContent = pnlInfo.Controls[1] as TextBox;
                if (infoContent != null)
                {
                    if (useFTP)
                    {
                        infoContent.Text = "• Descarga desde FTP (~20 GB)\r\n" +
                                        "• Se requieren 25 GB de espacio disponible\r\n" +
                                        "• Archivo temporal se elimina automáticamente\r\n" +
                                        "• Descarga resumible con 3 reintentos\r\n" +
                                        "• Requiere 7-zip (se instala automáticamente)\r\n" +
                                        $"• URL FTP: {ftpUrl}";
                    }
                    else
                    {
                        infoContent.Text = "• Descarga desde Google Drive (~20 GB)\r\n" +
                                        "• Se requieren 25 GB de espacio disponible\r\n" +
                                        "• Archivo temporal se elimina automáticamente\r\n" +
                                        "• Descarga resumible con 3 reintentos\r\n" +
                                        "• Requiere 7-zip (se instala automáticamente)\r\n" +
                                        $"• ID Google Drive: {googleDriveId}";
                    }
                }
            }
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

        
        private void LogMessage(string message, Color? color = null)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => LogMessage(message, color)));
                return;
            }
            
            if (color.HasValue)
            {
                AppendColoredLogMessage($"[{DateTime.Now:HH:mm:ss}] {message}", color.Value);
            }
            else
            {
                txtLog.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}\n");
                txtLog.ScrollToCaret();
            }
        }
        
        private void UpdateStatus(string message, int progress)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => UpdateStatus(message, progress)));
                return;
            }
            
            lblStatus.Text = message;
            
            // Solo actualizar si el progreso es diferente
            if (progressBar.Value != progress)
            {
                progressBar.Value = Math.Min(100, Math.Max(0, progress));
            }
            
            // Forzar actualización de la UI
            Application.DoEvents();
        }

        private void UpdateProgress(int value)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => UpdateProgress(value)));
                return;
            }
            
            progressBar.Value = Math.Min(100, Math.Max(0, value));
            
            // Actualizar el texto de la barra de progreso
            if (value >= 0 && value <= 100)
            {
                progressBar.Style = ProgressBarStyle.Continuous;
            }
        }

        
        private bool CheckDiskSpace()
        {
            try
            {
                string drivePath = Path.GetPathRoot(installPath);
                if (string.IsNullOrEmpty(drivePath))
                    drivePath = "C:\\";
                
                DriveInfo drive = new DriveInfo(drivePath);
                
                if (!drive.IsReady)
                {
                    LogMessage("⚠️ No se puede acceder a la unidad", COLOR_WARNING);
                    return true; // Permitir instalación si no se puede verificar
                }
                
                long requiredBytes = REQUIRED_SPACE_GB * 1024L * 1024L * 1024L;
                bool hasSpace = drive.AvailableFreeSpace >= requiredBytes;
                
                if (hasSpace)
                {
                    LogMessage($"✅ Espacio suficiente: {drive.AvailableFreeSpace / (1024.0 * 1024.0 * 1024.0):F2} GB", COLOR_SUCCESS);
                }
                else
                {
                    LogMessage($"❌ Espacio insuficiente: {drive.AvailableFreeSpace / (1024.0 * 1024.0 * 1024.0):F2} GB (requerido: {REQUIRED_SPACE_GB} GB)", COLOR_ERROR);
                }
                
                return hasSpace;
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error verificando espacio: {ex.Message}", COLOR_WARNING);
                return true; // Permitir instalación si hay error
            }
        }
        
        // ========== MODIFICAR EL MÉTODO BtnInstall_Click (confirmación) ==========
        private async void BtnInstall_Click(object sender, EventArgs e)
        {
            if (isInstalling || isCancelling) return;
            
            // Validar ruta
            if (string.IsNullOrWhiteSpace(txtDirectory.Text))
            {
                MessageBox.Show("Por favor, selecciona una ubicación para la instalación.",
                    "Ubicación requerida", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            
            installPath = txtDirectory.Text;
            
            // VERIFICAR SI YA ESTÁ INSTALADO
            if (IsAlreadyInstalled(installPath))
            {
                var result = MessageBox.Show(
                    $"Atlas Interactivo ya parece estar instalado en:\n\n{installPath}\n\n" +
                    "¿Deseas reinstalar? (Se sobrescribirán los archivos existentes)",
                    "Instalación detectada",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question);
                
                if (result != DialogResult.Yes) return;
            }
            
            // **Mensaje de confirmación ACTUALIZADO con método de descarga**
            string methodText = useFTP ? "FTP" : "Google Drive";
            
            var confirmResult = MessageBox.Show(
                $"MÉTODO: {methodText.ToUpper()}\n\n" +
                "✓ Descarga resumible con 3 reintentos\n" +
                "✓ Extracción por grupos de 50k archivos (método Qt)\n" +
                "✓ Usa 7-zip para máxima compatibilidad\n" +
                "✓ Formato TAR optimizado\n" +
                "✓ 7-zip se instalará automáticamente si no está presente\n" +
                "✓ Espacio temporal máximo: 25 GB\n\n" +
                $"Ubicación: {installPath}\n\n" +
                "¿Desea continuar con la instalación?",
                "Confirmar instalación",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);
            
            if (confirmResult != DialogResult.Yes) return;

            
            // Iniciar instalación
            isInstalling = true;
            
            btnInstall.Enabled = false;
            btnBrowse.Enabled = false;
            btnAbout.Enabled = false;
            btnClearLog.Enabled = false;
            btnInstall.Text = "Instalando...";
            
            // Limpiar log y mostrar información
            txtLog.Clear();
            txtLog.AppendText($"\n");
            txtLog.AppendText($"\n");
            txtLog.AppendText($"\n");
            txtLog.AppendText($"\n");
            txtLog.AppendText($"=== ATLAS INTERACTIVO INSTALADOR ===\n");
            txtLog.AppendText($"Fecha: {DateTime.Now:yyyy-MM-dd HH:mm:ss}\n");
            txtLog.AppendText($"Ubicación: {installPath}\n");
            txtLog.AppendText("Método: Descarga " + (USE_LOCAL_SERVER ? "LOCAL" : "Google Drive") + "\n");
            txtLog.AppendText($"Reintentos: {MAX_DOWNLOAD_RETRIES}\n");
            txtLog.AppendText($"Herramienta de extracción: 7-zip\n");
            txtLog.AppendText($"Grupos de extracción: 50,000 archivos (método Qt)\n\n");
            
            LogMessage("Iniciando instalación con método optimizado...", COLOR_PRIMARY);
            
            // Crear token de cancelación
            cancellationTokenSource = new CancellationTokenSource();
            
            try
            {
                // **EJECUTAR INSTALACIÓN CON 7-ZIP**
                await InstallWith7ZipMethod();
            }
            catch (OperationCanceledException)
            {
                LogMessage("Instalación cancelada por el usuario", COLOR_WARNING);
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error crítico: {ex.Message}", COLOR_ERROR);
                LogMessage($"Tipo: {ex.GetType().Name}", COLOR_ERROR);
                LogMessage($"Stack trace: {ex.StackTrace}", COLOR_ERROR);
                
                MessageBox.Show(
                    $"Error crítico durante la instalación:\n\n{ex.Message}\n\n" +
                    "Por favor, intenta nuevamente o contacta al soporte.",
                    "Error crítico",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
            finally
            {
                // Restaurar UI
                isInstalling = false;
                isCancelling = false;
                
                this.Invoke(new Action(() =>
                {
                    btnInstall.Enabled = true;
                    btnBrowse.Enabled = true;
                    btnExit.Enabled = true;
                    btnAbout.Enabled = true;
                    btnClearLog.Enabled = true;
                    btnInstall.Text = "INICIAR INSTALACIÓN";
                    UpdateDiskSpace(); // Actualizar espacio después de instalación
                }));
                
                cancellationTokenSource?.Dispose();
                cancellationTokenSource = null;
            }
        }
        

        // ========== MODIFICAR EL MÉTODO DE INSTALACIÓN PRINCIPAL ==========
        private async Task InstallWith7ZipMethod()
        {
            try
            {
                // Mostrar método de descarga seleccionado
                string methodText = useFTP ? "FTP" : "Google Drive";
                LogMessage($"🚀 Iniciando instalación con método: {methodText}", COLOR_PRIMARY);

                if (!progressTimer.Enabled)
                {
                    progressTimer.Start();
                }

                // VERIFICAR SI YA ESTÁ INSTALADO
                if (IsAlreadyInstalled(installPath))
                {
                    LogMessage("✅ Instalación detectada - No se requiere descarga", COLOR_SUCCESS);
                    UpdateStatus("Instalación ya completada", 100);
                    
                    this.Invoke(new Action(() =>
                    {
                        MessageBox.Show(
                            "✅ INSTALACIÓN YA COMPLETA\n\n" +
                            "Atlas Interactivo ya está instalado en:\n" +
                            $"{installPath}\n\n" +
                            "No se requiere descarga adicional.",
                            "Instalación Detectada",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Information);
                    }));
                    return;
                }

                UpdateStatus("Verificando 7-zip...", 5);
                LogMessage("🔍 Verificando 7-zip...");
                
                // Verificar e instalar 7-zip si es necesario
                bool sevenZipReady = await Install7ZipIfNeeded();
                
                if (!sevenZipReady)
                {
                    throw new Exception("No se pudo instalar o verificar 7-zip. Es requerido para la instalación.");
                }
                
                // Crear directorio de instalación
                Directory.CreateDirectory(installPath);
                
                // === DESCARGA CON MÉTODO SELECCIONADO ===
                bool downloadSuccess = false;
                int downloadAttempt = 0;
                
                while (downloadAttempt < MAX_DOWNLOAD_RETRIES && !cancellationTokenSource.Token.IsCancellationRequested)
                {
                    downloadAttempt++;
                    LogMessage($"🔄 Intento {downloadAttempt}/{MAX_DOWNLOAD_RETRIES}...", COLOR_PRIMARY);
                    UpdateStatus($"Intento {downloadAttempt} de descarga...", 10);
                    
                    try
                    {
                        if (useFTP)
                        {
                            // USAR FTP con wget
                            downloadSuccess = await DownloadWithFtpMethod(ftpUrl, installPath, cancellationTokenSource.Token);
                        }
                        else
                        {
                            // USAR Google Drive con 7-zip
                            downloadSuccess = await DownloadGoogleDriveWith7ZipMethod(googleDriveId, installPath, cancellationTokenSource.Token);
                        }
                        
                        if (downloadSuccess) 
                        {
                            LogMessage($"✅ Intento {downloadAttempt} exitoso", COLOR_SUCCESS);
                            break;
                        }
                    }
                    catch (Exception ex)
                    {
                        LogMessage($"❌ Intento {downloadAttempt} falló: {ex.Message}", COLOR_WARNING);
                        
                        if (downloadAttempt < MAX_DOWNLOAD_RETRIES)
                        {
                            int waitTime = downloadAttempt * 10;
                            LogMessage($"⏳ Esperando {waitTime} segundos antes de reintentar...", COLOR_WARNING);
                            UpdateStatus($"Reintentando en {waitTime} segundos...", 5);
                            
                            await Task.Delay(waitTime * 1000, cancellationTokenSource.Token);
                        }
                    }
                }
                
                if (!downloadSuccess)
                {
                    throw new Exception($"No se pudo descargar el archivo después de {MAX_DOWNLOAD_RETRIES} intentos");
                }
                
                // Verificar que se extrajeron archivos
                if (!Directory.Exists(installPath) || Directory.GetFiles(installPath, "*", SearchOption.AllDirectories).Length == 0)
                {
                    throw new Exception("No se extrajeron archivos o el directorio está vacío");
                }
                
                LogMessage($"✅ Descarga y extracción completadas con 7-zip", COLOR_SUCCESS);
                UpdateStatus("Extracción completada", 95);
                
                // Crear archivo de versión
                CreateVersionFile7Zip();
                
                // Crear accesos directos
                if (chkDesktop.Checked || chkMenu.Checked)
                {
                    UpdateStatus("Creando accesos directos...", 97);
                    CreateWindowsShortcuts();
                }
                
                // Completar
                UpdateStatus("Instalación completada", 100);
                LogMessage("✅ ¡Instalación completada exitosamente!", COLOR_SUCCESS);
                LogMessage($"Ubicación: {installPath}");
                
                // Mostrar mensaje de éxito
                this.Invoke(new Action(() =>
                {
                    MessageBox.Show(
                        $"✅ INSTALACIÓN COMPLETADA ({methodText})\n\n" +
                        "Atlas Interactivo se ha instalado exitosamente\n\n" +
                        $"Ubicación:\n{installPath}\n\n" +
                        "Características instaladas:\n" +
                        "• Aplicación principal\n" +
                        "• Archivos de recursos\n" +
                        "• Documentación\n" +
                        "• Accesos directos\n\n" +
                        "¡Gracias por instalar Atlas Interactivo!",
                        "Instalación Completada",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                }));
            }
            catch (OperationCanceledException)
            {
                LogMessage("Instalación cancelada por el usuario", COLOR_WARNING);
                UpdateStatus("Instalación cancelada", 0);
                throw;
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error en instalación: {ex.Message}", COLOR_ERROR);
                throw;
            }
            finally
            {
                progressTimer.Stop();
                isInstalling = false;
                isCancelling = false;
            }
        }


        // ========== NUEVO MÉTODO PARA DESCARGA FTP ==========
        private async Task<bool> DownloadWithFtpMethod(string url, string extractPath, CancellationToken cancellationToken)
        {
            try
            {
                LogMessage($"🌐 Iniciando descarga FTP desde: {url}", COLOR_PRIMARY);
                
                // Crear archivo temporal
                string tempTarPath = Path.Combine(Path.GetTempPath(), $"atlas_ftp_{Guid.NewGuid():N}.tar");
                
                // Verificar si wget está disponible
                string wgetPath = GetWgetPath();
                if (string.IsNullOrEmpty(wgetPath))
                {
                    LogMessage("❌ wget no encontrado. Instala Git Bash o Cygwin para usar FTP.", COLOR_ERROR);
                    return false;
                }
                
                // Descargar usando wget con opciones similares a Linux
                bool downloadSuccess = await DownloadWithWgetResumable(url, tempTarPath, cancellationToken);
                
                if (!downloadSuccess)
                {
                    LogMessage("❌ Falló la descarga FTP", COLOR_ERROR);
                    return false;
                }
                
                // Extraer con 7-zip
                LogMessage("🔧 Extrayendo archivo FTP con 7-zip...", COLOR_PRIMARY);
                bool extractSuccess = await ExtractWith7Zip(tempTarPath, extractPath, cancellationToken);
                
                // Limpiar archivo temporal
                try { File.Delete(tempTarPath); } catch { }
                
                return extractSuccess;
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error en descarga FTP: {ex.Message}", COLOR_ERROR);
                return false;
            }
        }

        // ========== MÉTODO PARA EXTRAER CON 7-ZIP ==========
        private async Task<bool> ExtractWith7Zip(string tarPath, string extractPath, CancellationToken cancellationToken)
        {
            return await Task.Run(() =>
            {
                try
                {
                    string sevenZipPath = Get7ZipPath();
                    
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = $"\"{sevenZipPath}\"",
                        Arguments = $"x \"{tarPath}\" -o\"{extractPath}\" -aoa -y",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };
                    
                    using (Process process = new Process())
                    {
                        process.StartInfo = psi;
                        process.Start();
                        process.WaitForExit(600000); // 10 minutos timeout
                        
                        return process.ExitCode == 0;
                    }
                }
                catch (Exception ex)
                {
                    LogMessage($"❌ Error extrayendo: {ex.Message}", COLOR_ERROR);
                    return false;
                }
            });
        }

        private async Task<bool> Install7ZipIfNeeded()
        {
            try
            {
                // Verificar si 7-zip ya está instalado
                if (Is7ZipInstalled())
                {
                    LogMessage("✅ 7-zip ya está instalado", COLOR_SUCCESS);
                    return true;
                }
                
                LogMessage("⚠️ 7-zip no encontrado, iniciando instalación...", COLOR_WARNING);
                
                // Mostrar mensaje al usuario
                var result = MessageBox.Show(
                    "7-zip no está instalado en su sistema.\n\n" +
                    "Es necesario para extraer los archivos de Atlas Interactivo.\n\n" +
                    "¿Desea instalar 7-zip ahora? (Recomendado)\n\n" +
                    "Si selecciona No, deberá instalar 7-zip manualmente.",
                    "7-zip requerido",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);
                
                if (result == DialogResult.No)
                {
                    LogMessage("❌ Usuario canceló la instalación de 7-zip", COLOR_ERROR);
                    return false;
                }
                
                // Instalar 7-zip
                return await Install7ZipSimple();
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error con 7-zip: {ex.Message}", COLOR_ERROR);
                return false;
            }
        }

        private async Task<bool> DownloadGoogleDriveWith7ZipMethod(string driveId, string extractPath, CancellationToken cancellationToken)
        {
            try
            {
                // Obtener URL directa
                string downloadUrl = await GetDirectGoogleDriveUrl(driveId);
                LogMessage($"🔗 URL de descarga TAR: {downloadUrl}", COLOR_PRIMARY);
                
                // INICIAR PROGRESO DESDE 10%
                UpdateStatus("Obteniendo información del servidor...", 10);
                
                // **USAR LA NUEVA CLASE BufferedTarDownloader (que usa 7-zip)**
                using (var downloader = new BufferedTarDownloader(
                    downloadUrl, 
                    extractPath, 
                    new Progress<int>(p => {
                        // Ajustar progreso: 10-60% para descarga, 60-100% para extracción
                        int progress = 10 + (int)(p * 0.9); // 10% a 100%
                        UpdateProgress(Math.Min(100, Math.Max(10, progress)));
                    }), 
                    cancellationToken))
                {
                    downloader.LogMessage += (sender, msg) => LogMessage(msg);
                    downloader.StatusUpdate += (sender, status) => UpdateStatus(status, progressBar.Value);
                    
                    LogMessage("🚀 Iniciando descarga con BufferedTarDownloader (7-zip)...", COLOR_PRIMARY);
                    UpdateStatus("Iniciando descarga y extracción TAR con 7-zip...", 15);
                    
                    return await downloader.DownloadAndExtractIncremental();
                }
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error descargando TAR: {ex.Message}", COLOR_ERROR);
                return false;
            }
        }

        private void CreateVersionFile7Zip()
        {
            try
            {
                string versionFile = Path.Combine(installPath, ".atlas_version.json");
                
                string json = $@"{{
                ""version"": ""1.0.0"",
                ""installed"": true,
                ""install_path"": ""{installPath.Replace("\\", "\\\\")}"",
                ""install_date"": ""{DateTime.Now:yyyy-MM-ddTHH:mm:ss}"",
                ""file_type"": ""tar"",
                ""download_size"": ""variable"",
                ""download_resumable"": true,
                ""download_attempts"": 1,
                ""extraction_method"": ""7zip_incremental_groups"",
                ""extraction_groups"": 50000,
                ""extraction_tool"": ""7-zip"",
                ""platform"": ""windows"",
                ""installer_version"": ""3.0.0"",
                ""requires_7zip"": true,
                ""requires_tar"": false
            }}";
                
                File.WriteAllText(versionFile, json, Encoding.UTF8);
                LogMessage("✅ Archivo de versión creado (7-zip)", COLOR_SUCCESS);
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ No se pudo crear archivo de versión: {ex.Message}", COLOR_WARNING);
            }
        }


        private void CreateWindowsShortcuts()
        {
            try
            {
                LogMessage("=== CREANDO ACCESOS DIRECTOS DE WINDOWS ===");
                
                // Buscar el ejecutable principal
                string executablePath = FindMainExecutable();
                if (string.IsNullOrEmpty(executablePath))
                {
                    LogMessage("❌ No se encontró el ejecutable principal", COLOR_ERROR);
                    return;
                }
                
                LogMessage($"✅ Ejecutable encontrado: {Path.GetFileName(executablePath)}");
                
                // Buscar icono
                string iconPath = FindIconFile();
                if (string.IsNullOrEmpty(iconPath))
                {
                    iconPath = executablePath; // Usar el ejecutable como icono
                    LogMessage("⚠️ No se encontró icono específico, usando ejecutable como icono");
                }
                else
                {
                    LogMessage($"✅ Icono encontrado: {Path.GetFileName(iconPath)}");
                }
                
                // Crear acceso directo en escritorio
                if (chkDesktop.Checked)
                {
                    string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                    string desktopShortcut = Path.Combine(desktopPath, "Atlas Interactivo.url");
                    
                    CreateShortcut(desktopShortcut, executablePath, iconPath);
                }
                
                // Crear entrada en el menú de inicio
                if (chkMenu.Checked)
                {
                    string startMenuPath = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
                        "Programs",
                        "Atlas Interactivo");
                    
                    Directory.CreateDirectory(startMenuPath);
                    string startMenuShortcut = Path.Combine(startMenuPath, "Atlas Interactivo.url");
                    
                    CreateShortcut(startMenuShortcut, executablePath, iconPath);
                    
                    // También crear un desinstalador simple
                    CreateUninstaller(startMenuPath);
                }
                
                LogMessage("=== ACCESOS DIRECTOS CREADOS EXITOSAMENTE ===", COLOR_SUCCESS);
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Error creando accesos directos: {ex.Message}", COLOR_ERROR);
            }
        }

        private string FindMainExecutable()
        {
            try
            {
                // Buscar archivos .exe en el directorio de instalación
                string[] exeFiles = Directory.GetFiles(installPath, "*.exe", SearchOption.AllDirectories);
                
                if (exeFiles.Length == 0)
                {
                    LogMessage("❌ No se encontraron archivos .exe en: " + installPath, COLOR_ERROR);
                    return null;
                }
                
                // Priorizar nombres específicos
                foreach (string exe in exeFiles)
                {
                    string name = Path.GetFileNameWithoutExtension(exe).ToLower();
                    if (name.Contains("atlas") || name.Contains("main") || name.Contains("launcher"))
                    {
                        return exe;
                    }
                }
                
                // Si no encuentra nombres específicos, usar el primero
                return exeFiles[0];
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error buscando ejecutable: {ex.Message}", COLOR_WARNING);
                return null;
            }
        }

        private string FindIconFile()
        {
            try
            {
                // Buscar iconos en directorios comunes
                string[] iconPaths = {
                    Path.Combine(installPath, "icon.ico"),
                    Path.Combine(installPath, "resources", "icon.ico"),
                    Path.Combine(installPath, "resources", "logos", "icon.ico"),
                    Path.Combine(installPath, "Assets", "icon.ico"),
                    Path.Combine(installPath, "app", "icon.ico"),
                    Path.Combine(installPath, "*.ico") // Buscar cualquier .ico
                };
                
                foreach (string path in iconPaths)
                {
                    if (File.Exists(path))
                    {
                        return path;
                    }
                    
                    // Si es un patrón con wildcard
                    if (path.Contains("*"))
                    {
                        string directory = Path.GetDirectoryName(path);
                        string pattern = Path.GetFileName(path);
                        
                        if (Directory.Exists(directory))
                        {
                            string[] icoFiles = Directory.GetFiles(directory, pattern);
                            if (icoFiles.Length > 0)
                            {
                                return icoFiles[0];
                            }
                        }
                    }
                }
                
                return null; // No se encontró icono
            }
            catch
            {
                return null;
            }
        }

        private void CreateUninstaller(string directory)
        {
            try
            {
                string uninstallerPath = Path.Combine(directory, "Desinstalar Atlas Interactivo.bat");
                
                string batContent = "@echo off\r\n" +
                                "echo ========================================\r\n" +
                                "echo   DESINSTALADOR ATLAS INTERACTIVO\r\n" +
                                "echo ========================================\r\n" +
                                "echo.\r\n" +
                                "echo Esta acción eliminará:\r\n" +
                                "echo   - La carpeta de instalación\r\n" +
                                "echo   - Los accesos directos\r\n" +
                                "echo.\r\n" +
                                "set /p confirm=\"¿Está seguro? (S/N): \"\r\n" +
                                "if /I \"%confirm%\" NEQ \"S\" (\r\n" +
                                "  echo Desinstalación cancelada.\r\n" +
                                "  pause\r\n" +
                                "  exit /b 1\r\n" +
                                ")\r\n" +
                                "echo.\r\n" +
                                "echo Eliminando carpeta de instalación...\r\n" +
                                "rmdir /s /q \"" + installPath + "\"\r\n" +
                                "if %ERRORLEVEL% NEQ 0 (\r\n" +
                                "  echo Error eliminando la carpeta. Puede necesitar permisos de administrador.\r\n" +
                                "  pause\r\n" +
                                "  exit /b 1\r\n" +
                                ")\r\n" +
                                "echo.\r\n" +
                                "echo Eliminando accesos directos...\r\n" +
                                "del \"" + Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Atlas Interactivo.url") + "\" 2>nul\r\n" +
                                "del \"" + Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Atlas Interactivo.bat") + "\" 2>nul\r\n" +
                                "rmdir /s /q \"" + Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.StartMenu), "Programs", "Atlas Interactivo") + "\" 2>nul\r\n" +
                                "echo.\r\n" +
                                "echo ¡Desinstalación completada!\r\n" +
                                "echo.\r\n" +
                                "pause\r\n";
                
                File.WriteAllText(uninstallerPath, batContent, Encoding.ASCII);
                LogMessage($"✅ Desinstalador creado: {Path.GetFileName(uninstallerPath)}", COLOR_SUCCESS);
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ No se pudo crear desinstalador: {ex.Message}", COLOR_WARNING);
            }
        }
        
        private void CreateShortcut(string shortcutPath, string targetPath, string iconPath)
        {
            try
            {
                // Para Mono, usar método simple sin VBS complejo
                if (shortcutPath.EndsWith(".lnk"))
                {
                    shortcutPath = shortcutPath.Replace(".lnk", ".url");
                }
                
                StringBuilder urlBuilder = new StringBuilder();
                urlBuilder.AppendLine("[InternetShortcut]");
                urlBuilder.AppendLine($"URL=file:///{targetPath.Replace('\\', '/')}");
                urlBuilder.AppendLine($"WorkingDirectory={Path.GetDirectoryName(targetPath)}");
                
                if (File.Exists(iconPath))
                {
                    urlBuilder.AppendLine($"IconFile={iconPath}");
                    urlBuilder.AppendLine("IconIndex=0");
                }
                
                File.WriteAllText(shortcutPath, urlBuilder.ToString());
                LogMessage($"✅ Acceso directo creado: {Path.GetFileName(shortcutPath)}", COLOR_SUCCESS);
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error creando acceso directo: {ex.Message}", COLOR_WARNING);
            }
        }        
        
        
        private bool IsDirectoryEmpty(string path)
        {
            if (!Directory.Exists(path))
                return true;
                
            return !Directory.EnumerateFileSystemEntries(path).Any();
        }
        
        


        // ========== PARTE 1: CORREGIR WARNING ==========
        private void BtnExit_Click(object sender, EventArgs e)
        {
            // Usar EXACTAMENTE la misma lógica que MainForm_FormClosing
            if (isInstalling)
            {
                var result = MessageBox.Show(
                    "⚠️ INSTALACIÓN EN PROGRESO\n\n" +
                    "¿Estás seguro de que quieres salir?\n" +
                    "Se cancelará la descarga y se eliminarán los archivos temporales.",
                    "Confirmar salida",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning,
                    MessageBoxDefaultButton.Button2);
                
                if (result == DialogResult.Yes)
                {
                    // Ejecutar la misma lógica que la X
                    isCancelling = true;
                    isInstalling = false;
                    
                    LogMessage("🛑 Cancelando instalación y saliendo...", COLOR_WARNING);
                    
                    // 1. Detener timer
                    if (progressTimer != null)
                    {
                        progressTimer.Stop();
                    }
                    
                    // 2. Cancelar operaciones
                    CancelAllOperations();
                    
                    // 3. Eliminar archivos temporales
                    DeleteTempFilesImmediately();
                    
                    // 4. Pequeña pausa
                    Thread.Sleep(500);
                    
                    // 5. Salir
                    Application.Exit();
                }
                // Si dice No, NO hacer nada (igual que la X)
            }
            else
            {
                // Salida normal
                Application.Exit();
            }
        }


        private void CancelAllOperations()
        {
            try
            {
                LogMessage("🔄 Cancelando todas las operaciones...", COLOR_WARNING);
                
                // 1. Cancelar token (esto cancela las tareas async)
                if (cancellationTokenSource != null)
                {
                    LogMessage("⏹️ Cancelando operaciones en segundo plano...", COLOR_WARNING);
                    cancellationTokenSource.Cancel();
                    
                    // Pequeña pausa
                    Thread.Sleep(200);
                    
                    // Liberar recursos
                    cancellationTokenSource.Dispose();
                    cancellationTokenSource = null;
                }
                
                // 2. Actualizar estado
                isInstalling = false;
                isCancelling = true;
                
                // 3. Restaurar estado de la UI inmediatamente
                if (this.InvokeRequired)
                {
                    this.Invoke(new Action(() => RestoreUIAfterCancel()));
                }
                else
                {
                    RestoreUIAfterCancel();
                }
                
                LogMessage("✅ Operaciones canceladas", COLOR_WARNING);
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error durante la cancelación: {ex.Message}", COLOR_WARNING);
            }
        }

        private void RestoreUIAfterCancel()
        {
            btnInstall.Enabled = true;
            btnBrowse.Enabled = true;
            btnExit.Enabled = true;
            btnAbout.Enabled = true;
            btnClearLog.Enabled = true;
            btnInstall.Text = "INICIAR INSTALACIÓN";
            lblStatus.Text = "Instalación cancelada";
            progressBar.Value = 0;
        }


        private void DeleteTempFilesImmediately()
        {
            try
            {
                LogMessage("🗑️ Eliminando archivos temporales...", COLOR_WARNING);
                
                string tempDir = Path.GetTempPath();
                
                // Buscar y eliminar TODOS los archivos temporales relacionados con Atlas
                string[] patterns = new[] { 
                    "atlas_*.zip", 
                    "atlas_*.zip.*", 
                    "atlas_*.tmp", 
                    "atlas_*.part", 
                    "Atlas_*.zip",
                    "Atlas_*.tmp"
                };
                
                foreach (string pattern in patterns)
                {
                    try
                    {
                        string[] tempFiles = Directory.GetFiles(tempDir, pattern);
                        foreach (string file in tempFiles)
                        {
                            try
                            {
                                File.Delete(file);
                                LogMessage($"   Eliminado: {Path.GetFileName(file)}");
                            }
                            catch (Exception ex)
                            {
                                LogMessage($"   No se pudo eliminar {Path.GetFileName(file)}: {ex.Message}");
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        LogMessage($"⚠️ Error buscando archivos {pattern}: {ex.Message}", COLOR_WARNING);
                    }
                }
                
                LogMessage("✅ Archivos temporales eliminados", COLOR_SUCCESS);
            }
            catch (Exception ex)
            {
                LogMessage($"⚠️ Error eliminando archivos temporales: {ex.Message}", COLOR_WARNING);
            }
        }



        // ========== PARTE 4: ACTUALIZAR MainForm_FormClosing ==========
        private void MainForm_FormClosing(object sender, FormClosingEventArgs e)
        {
            // Si hay una instalación en curso
            if (isInstalling && !isCancelling)
            {
                e.Cancel = true; // IMPORTANTE: Cancelar primero
                
                var result = MessageBox.Show(
                    "⚠️ INSTALACIÓN EN PROGRESO\n\n" +
                    "¿Estás seguro de que quieres salir?\n" +
                    "Se cancelará la descarga y se eliminarán los archivos temporales.",
                    "Confirmar salida",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning,
                    MessageBoxDefaultButton.Button2);
                
                if (result == DialogResult.Yes)
                {
                    // Marcamos que estamos cancelando
                    isCancelling = true;
                    isInstalling = false;
                    
                    // Actualizar UI inmediatamente
                    lblStatus.Text = "Cerrando...";
                    Application.DoEvents();
                    
                    LogMessage("🛑 Cancelando instalación y saliendo...", COLOR_WARNING);
                    
                    // 1. Detener timer
                    if (progressTimer != null)
                    {
                        progressTimer.Stop();
                    }
                    
                    // 2. Cancelar operaciones
                    CancelAllOperations();
                    
                    // 3. Eliminar archivos temporales
                    DeleteTempFilesImmediately();
                    
                    // 4. Pequeña pausa para que se procese todo
                    Thread.Sleep(300);
                    
                    // 5. Ahora permitir el cierre
                    e.Cancel = false;
                    
                    // 6. Forzar cierre si todavía está abierto
                    this.Close();
                }
                else
                {
                    // Si el usuario dice No, restaurar la bandera
                    isCancelling = false;
                }
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
            
            // Configurar manejo de excepciones no controladas
            AppDomain.CurrentDomain.UnhandledException += (sender, e) =>
            {
                MessageBox.Show(
                    $"Error crítico no controlado:\n\n{e.ExceptionObject}",
                    "Error crítico",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            };
            
            Application.ThreadException += (sender, e) =>
            {
                MessageBox.Show(
                    $"Error en el hilo de UI:\n\n{e.Exception.Message}",
                    "Error de UI",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            };
            
            Application.Run(new MainForm());
        }
    }
}
