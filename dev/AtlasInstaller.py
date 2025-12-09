# Atlas_Distribution/dev/AtlasInstaller.py (VERSIÓN COMPLETA CON GUI)
#!/usr/bin/env python3

import sys
import os
import tarfile
import zipfile
import hashlib
import json
import subprocess
import tempfile
import shutil
import threading
import time
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError
from datetime import datetime

# Importar tkinter para GUI
try:
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog, scrolledtext
    from tkinter.font import Font
    HAS_GUI = True
except ImportError:
    HAS_GUI = False
    print("Tkinter no disponible, ejecutando en modo consola")

# ========== CLASE PRINCIPAL ==========
class AtlasInstaller:
    def __init__(self, root=None):
        self.root = root
        self.home = str(Path.home())
        self.install_dir = os.path.join(self.home, "Atlas_Interactivo")
        self.temp_dir = tempfile.mkdtemp(prefix="atlas_install_")
        
        # Configuración de Drive
        self.drive_files = {
            "linux": "TU_FILE_ID_LINUX_TAR_GZ",  # Cambiar por tu ID real
            "windows": "TU_FILE_ID_WINDOWS_ZIP"
        }
        
        self.patches_folder = "TU_FOLDER_ID_PATCHES"
        
        # Variables de estado
        self.is_downloading = False
        self.is_extracting = False
        self.total_files = 0
        self.processed_files = 0
        self.download_speed = 0
        self.start_time = None
        
    # ========== MÉTODOS DE DESCARGA ==========
    def download_with_progress(self, url, destination, progress_callback=None):
        """Descarga archivo con callback de progreso"""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
                'Accept': '*/*'
            }
            
            req = Request(url, headers=headers)
            
            with urlopen(req) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                block_size = 8192
                downloaded = 0
                self.start_time = time.time()
                
                if progress_callback:
                    progress_callback(0, 0, total_size, 0)
                
                with open(destination, 'wb') as f:
                    while True:
                        buffer = response.read(block_size)
                        if not buffer:
                            break
                        
                        downloaded += len(buffer)
                        f.write(buffer)
                        
                        # Calcular velocidad
                        elapsed = time.time() - self.start_time
                        speed = downloaded / elapsed if elapsed > 0 else 0
                        
                        if progress_callback:
                            percent = (downloaded / total_size * 100) if total_size > 0 else 0
                            progress_callback(percent, downloaded, total_size, speed)
                
                return True
                
        except URLError as e:
            print(f"Error de conexión: {e}")
            return False
        except Exception as e:
            print(f"Error: {e}")
            return False
    
    def extract_tar_gz_with_progress(self, archive_path, extract_to, progress_callback=None):
        """Extrae .tar.gz con callback de progreso"""
        try:
            with tarfile.open(archive_path, 'r:gz') as tar:
                members = tar.getmembers()
                self.total_files = len(members)
                self.processed_files = 0
                
                for member in members:
                    dest_path = os.path.join(extract_to, member.name)
                    
                    if member.isdir():
                        os.makedirs(dest_path, exist_ok=True)
                    else:
                        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                        
                        with tar.extractfile(member) as source, open(dest_path, 'wb') as dest:
                            shutil.copyfileobj(source, dest)
                    
                    self.processed_files += 1
                    
                    if progress_callback:
                        percent = (self.processed_files / self.total_files) * 100
                        progress_callback(percent, self.processed_files, self.total_files)
                
                return True
                
        except Exception as e:
            print(f"Error extrayendo: {e}")
            return False
    
    # ========== MÉTODOS DE INSTALACIÓN ==========
    def check_disk_space(self):
        """Verifica espacio en disco disponible"""
        stat = shutil.disk_usage(self.home)
        free_gb = stat.free / (1024**3)
        required_gb = 15  # 15GB mínimo
        
        if free_gb < required_gb:
            return False, f"Espacio insuficiente. Necesitas {required_gb}GB, tienes {free_gb:.1f}GB"
        return True, f"Espacio suficiente: {free_gb:.1f}GB libres"
    
    def install_full_version(self, progress_callback=None, status_callback=None):
        """Instala la versión completa"""
        try:
            # Verificar espacio
            has_space, space_msg = self.check_disk_space()
            if not has_space:
                return False, space_msg
            
            if status_callback:
                status_callback("Creando directorio de instalación...")
            
            os.makedirs(self.install_dir, exist_ok=True)
            
            # Descargar
            if status_callback:
                status_callback("Descargando Atlas desde Google Drive...")
            
            file_id = self.drive_files["linux"]
            download_url = f"https://drive.google.com/uc?id={file_id}&export=download"
            archive_path = os.path.join(self.temp_dir, "Atlas_Linux.tar.gz")
            
            # Función para callback de progreso de descarga
            def dl_progress(percent, downloaded, total, speed):
                if progress_callback:
                    progress_callback(percent, f"Descargando...")
                if status_callback:
                    downloaded_mb = downloaded / (1024*1024)
                    total_mb = total / (1024*1024) if total > 0 else 0
                    speed_mbps = speed / (1024*1024)
                    status_callback(f"Descarga: {downloaded_mb:.1f}/{total_mb:.1f} MB ({speed_mbps:.1f} MB/s)")
            
            if not self.download_with_progress(download_url, archive_path, dl_progress):
                return False, "Error en la descarga"
            
            # Extraer
            if status_callback:
                status_callback("Extrayendo archivos...")
            
            # Función para callback de progreso de extracción
            def ex_progress(percent, processed, total):
                if progress_callback:
                    progress_callback(percent, f"Extrayendo...")
                if status_callback:
                    status_callback(f"Extraídos: {processed}/{total} archivos")
            
            if not self.extract_tar_gz_with_progress(archive_path, self.install_dir, ex_progress):
                return False, "Error extrayendo archivos"
            
            # Limpiar archivo temporal
            os.remove(archive_path)
            
            # Hacer ejecutable
            atlas_binary = os.path.join(self.install_dir, "Atlas_Interactivo")
            if os.path.exists(atlas_binary):
                os.chmod(atlas_binary, 0o755)
            
            # Crear archivos de sistema
            self.create_version_file()
            self.create_desktop_launcher()
            
            return True, "Instalación completada exitosamente"
            
        except Exception as e:
            return False, f"Error durante la instalación: {str(e)}"
    
    def create_version_file(self):
        """Crea archivo de versión"""
        version_info = {
            "version": "1.0.0",
            "installed": True,
            "install_date": datetime.now().isoformat(),
            "install_path": self.install_dir,
            "total_files": self.count_files()
        }
        
        version_file = os.path.join(self.install_dir, ".atlas_version.json")
        with open(version_file, 'w') as f:
            json.dump(version_info, f, indent=2)
    
    def count_files(self):
        """Cuenta archivos en la instalación"""
        count = 0
        for root, dirs, files in os.walk(self.install_dir):
            count += len(files)
        return count
    
    def create_desktop_launcher(self):
        """Crea lanzador .desktop"""
        desktop_dir = os.path.join(self.home, "Desktop")
        os.makedirs(desktop_dir, exist_ok=True)
        
        desktop_file = os.path.join(desktop_dir, "Atlas_Interactivo.desktop")
        
        desktop_content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name=Atlas Interactivo
Comment=Software meteorológico interactivo
Exec={self.install_dir}/Atlas_Interactivo
Path={self.install_dir}
Icon={self.install_dir}/icon.png
Terminal=false
Categories=Education;Science;Geography;
StartupNotify=true
"""
        
        with open(desktop_file, 'w') as f:
            f.write(desktop_content)
        
        os.chmod(desktop_file, 0o755)
    
    # ========== MÉTODOS DE ACTUALIZACIÓN ==========
    def check_for_updates(self):
        """Verifica parches disponibles"""
        version_file = os.path.join(self.install_dir, ".atlas_version.json")
        if not os.path.exists(version_file):
            return []
        
        with open(version_file, 'r') as f:
            current_info = json.load(f)
        
        # En implementación real, consultarías Drive API
        # Simulamos algunos parches
        available_patches = [
            {
                "id": "patch_20240115",
                "name": "Actualización de mapas",
                "size": "150MB",
                "file_id": "PATCH_ID_1",
                "version": "1.0.1",
                "date": "2024-01-15"
            },
            {
                "id": "patch_20240110", 
                "name": "Nuevos datos climáticos",
                "size": "120MB",
                "file_id": "PATCH_ID_2",
                "version": "1.0.2",
                "date": "2024-01-10"
            }
        ]
        
        return available_patches
    
    def apply_patch(self, patch_info, progress_callback=None, status_callback=None):
        """Aplica un parche"""
        try:
            # Descargar parche
            patch_url = f"https://drive.google.com/uc?id={patch_info['file_id']}&export=download"
            patch_path = os.path.join(self.temp_dir, f"patch_{patch_info['id']}.tar.gz")
            
            if status_callback:
                status_callback(f"Descargando {patch_info['name']}...")
            
            if not self.download_with_progress(patch_url, patch_path, progress_callback):
                return False, "Error descargando parche"
            
            # Aplicar parche
            if status_callback:
                status_callback(f"Aplicando {patch_info['name']}...")
            
            if not self.extract_tar_gz_with_progress(patch_path, self.install_dir, progress_callback):
                return False, "Error aplicando parche"
            
            # Actualizar versión
            self.update_version(patch_info['version'])
            
            # Limpiar
            os.remove(patch_path)
            
            return True, f"Parche {patch_info['name']} aplicado exitosamente"
            
        except Exception as e:
            return False, f"Error aplicando parche: {str(e)}"
    
    def update_version(self, new_version):
        """Actualiza archivo de versión"""
        version_file = os.path.join(self.install_dir, ".atlas_version.json")
        
        if os.path.exists(version_file):
            with open(version_file, 'r') as f:
                info = json.load(f)
            
            info["version"] = new_version
            info["last_update"] = datetime.now().isoformat()
            
            with open(version_file, 'w') as f:
                json.dump(info, f, indent=2)
    
    def cleanup(self):
        """Limpia archivos temporales"""
        if os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)

# ========== INTERFAZ GRÁFICA ==========
class InstallerGUI:
    def __init__(self, root):
        self.root = root
        self.installer = AtlasInstaller(root)
        self.setup_ui()
        
    def setup_ui(self):
        # Configurar ventana principal
        self.root.title("Atlas Interactivo - Instalador")
        self.root.geometry("600x500")
        self.root.resizable(False, False)
        
        # Estilos
        self.root.configure(bg='#f0f0f0')
        
        # Fuentes
        title_font = Font(family="Helvetica", size=24, weight="bold")
        normal_font = Font(family="Helvetica", size=10)
        
        # Frame principal
        main_frame = tk.Frame(self.root, bg='#f0f0f0', padx=20, pady=20)
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Título
        title_label = tk.Label(
            main_frame,
            text="🌍 Atlas Interactivo",
            font=title_font,
            bg='#f0f0f0',
            fg='#2c3e50'
        )
        title_label.pack(pady=(0, 5))
        
        subtitle_label = tk.Label(
            main_frame,
            text="Software meteorológico profesional",
            font=normal_font,
            bg='#f0f0f0',
            fg='#7f8c8d'
        )
        subtitle_label.pack(pady=(0, 20))
        
        # Ruta de instalación
        path_frame = tk.Frame(main_frame, bg='#f0f0f0')
        path_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            path_frame,
            text="Ruta de instalación:",
            font=normal_font,
            bg='#f0f0f0'
        ).pack(anchor=tk.W)
        
        self.path_var = tk.StringVar(value=self.installer.install_dir)
        path_entry = tk.Entry(
            path_frame,
            textvariable=self.path_var,
            font=normal_font,
            width=50
        )
        path_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 10))
        
        browse_btn = tk.Button(
            path_frame,
            text="Examinar",
            command=self.browse_directory,
            font=normal_font
        )
        browse_btn.pack(side=tk.RIGHT)
        
        # Opciones
        options_frame = tk.Frame(main_frame, bg='#f0f0f0')
        options_frame.pack(fill=tk.X, pady=(0, 20))
        
        self.create_desktop_var = tk.BooleanVar(value=True)
        desktop_cb = tk.Checkbutton(
            options_frame,
            text="Crear acceso directo en el escritorio",
            variable=self.create_desktop_var,
            font=normal_font,
            bg='#f0f0f0'
        )
        desktop_cb.pack(anchor=tk.W)
        
        # Barra de progreso
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(
            main_frame,
            variable=self.progress_var,
            maximum=100,
            length=560,
            mode='determinate'
        )
        self.progress_bar.pack(pady=(0, 10))
        
        # Etiquetas de estado
        self.status_label = tk.Label(
            main_frame,
            text="Listo para instalar",
            font=normal_font,
            bg='#f0f0f0',
            fg='#2c3e50'
        )
        self.status_label.pack(pady=(0, 5))
        
        self.detail_label = tk.Label(
            main_frame,
            text="",
            font=Font(family="Helvetica", size=9),
            bg='#f0f0f0',
            fg='#7f8c8d'
        )
        self.detail_label.pack(pady=(0, 20))
        
        # Botones
        button_frame = tk.Frame(main_frame, bg='#f0f0f0')
        button_frame.pack()
        
        self.install_btn = tk.Button(
            button_frame,
            text="Instalar Atlas",
            command=self.start_installation,
            font=Font(family="Helvetica", size=11, weight="bold"),
            bg='#3498db',
            fg='white',
            padx=30,
            pady=10,
            cursor='hand2'
        )
        self.install_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        self.update_btn = tk.Button(
            button_frame,
            text="Buscar Actualizaciones",
            command=self.check_updates,
            font=normal_font,
            state=tk.DISABLED
        )
        self.update_btn.pack(side=tk.LEFT)
        
        # Frame de completado (oculto inicialmente)
        self.complete_frame = tk.Frame(main_frame, bg='#f0f0f0')
        
        tk.Label(
            self.complete_frame,
            text="✅ ¡Instalación Completada!",
            font=Font(family="Helvetica", size=20, weight="bold"),
            bg='#f0f0f0',
            fg='#27ae60'
        ).pack(pady=(50, 20))
        
        tk.Label(
            self.complete_frame,
            text=f"Atlas se ha instalado en:\n{self.installer.install_dir}",
            font=normal_font,
            bg='#f0f0f0'
        ).pack(pady=(0, 30))
        
        launch_btn = tk.Button(
            self.complete_frame,
            text="🎯 Ejecutar Atlas",
            command=self.launch_atlas,
            font=Font(family="Helvetica", size=11, weight="bold"),
            bg='#2ecc71',
            fg='white',
            padx=20,
            pady=10
        )
        launch_btn.pack(pady=(0, 10))
        
        open_btn = tk.Button(
            self.complete_frame,
            text="📁 Abrir Carpeta",
            command=self.open_folder,
            font=normal_font
        )
        open_btn.pack()
        
    def browse_directory(self):
        """Abre diálogo para seleccionar directorio"""
        directory = filedialog.askdirectory(
            initialdir=self.installer.home,
            title="Selecciona la carpeta para instalar Atlas"
        )
        if directory:
            self.path_var.set(directory)
            self.installer.install_dir = directory
    
    def start_installation(self):
        """Inicia la instalación en un hilo separado"""
        self.install_btn.config(state=tk.DISABLED)
        self.progress_var.set(0)
        self.status_label.config(text="Iniciando instalación...")
        
        # Actualizar ruta de instalación
        self.installer.install_dir = self.path_var.get()
        
        # Crear directorio si no existe
        os.makedirs(self.installer.install_dir, exist_ok=True)
        
        # Iniciar instalación en hilo separado
        thread = threading.Thread(target=self.run_installation)
        thread.daemon = True
        thread.start()
    
    def run_installation(self):
        """Ejecuta la instalación (en hilo separado)"""
        def progress_callback(percent, status):
            self.root.after(0, lambda: self.update_progress(percent, status))
        
        def status_callback(message):
            self.root.after(0, lambda: self.update_status(message))
        
        success, message = self.installer.install_full_version(
            progress_callback=progress_callback,
            status_callback=status_callback
        )
        
        self.root.after(0, lambda: self.installation_complete(success, message))
    
    def update_progress(self, percent, status):
        """Actualiza la barra de progreso"""
        self.progress_var.set(percent)
        self.status_label.config(text=status)
    
    def update_status(self, message):
        """Actualiza mensaje detallado"""
        self.detail_label.config(text=message)
    
    def installation_complete(self, success, message):
        """Maneja la finalización de la instalación"""
        if success:
            # Mostrar frame de completado
            for widget in self.root.winfo_children()[0].winfo_children():
                if widget != self.complete_frame:
                    widget.pack_forget()
            
            self.complete_frame.pack(fill=tk.BOTH, expand=True)
            self.update_btn.config(state=tk.NORMAL)
        else:
            messagebox.showerror("Error", message)
            self.install_btn.config(state=tk.NORMAL)
    
    def check_updates(self):
        """Verifica actualizaciones disponibles"""
        patches = self.installer.check_for_updates()
        
        if patches:
            # Mostrar diálogo de actualizaciones
            UpdateDialog(self.root, self.installer, patches)
        else:
            messagebox.showinfo("Actualizaciones", "No hay actualizaciones disponibles.")
    
    def launch_atlas(self):
        """Ejecuta Atlas"""
        atlas_path = os.path.join(self.installer.install_dir, "Atlas_Interactivo")
        if os.path.exists(atlas_path):
            try:
                subprocess.Popen([atlas_path])
                self.root.quit()
            except Exception as e:
                messagebox.showerror("Error", f"No se pudo ejecutar Atlas: {e}")
        else:
            messagebox.showerror("Error", "No se encontró el ejecutable de Atlas.")
    
    def open_folder(self):
        """Abre la carpeta de instalación"""
        if os.path.exists(self.installer.install_dir):
            subprocess.Popen(['xdg-open', self.installer.install_dir])

# ========== DIÁLOGO DE ACTUALIZACIONES ==========
class UpdateDialog:
    def __init__(self, parent, installer, patches):
        self.installer = installer
        self.patches = patches
        
        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Actualizaciones Disponibles")
        self.dialog.geometry("500x400")
        self.dialog.resizable(False, False)
        self.dialog.transient(parent)
        self.dialog.grab_set()
        
        self.setup_ui()
    
    def setup_ui(self):
        # Frame principal
        main_frame = tk.Frame(self.dialog, padx=20, pady=20)
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        tk.Label(
            main_frame,
            text="📦 Actualizaciones Disponibles",
            font=Font(family="Helvetica", size=14, weight="bold")
        ).pack(pady=(0, 20))
        
        # Lista de parches
        list_frame = tk.Frame(main_frame)
        list_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 20))
        
        # Scrollbar
        scrollbar = tk.Scrollbar(list_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Listbox con scroll
        self.listbox = tk.Listbox(
            list_frame,
            selectmode=tk.MULTIPLE,
            yscrollcommand=scrollbar.set,
            height=10
        )
        self.listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.listbox.yview)
        
        # Agregar parches a la lista
        for patch in self.patches:
            self.listbox.insert(
                tk.END,
                f"{patch['name']} ({patch['size']}) - {patch['date']}"
            )
            self.listbox.itemconfig(tk.END, {'fg': '#2c3e50'})
        
        # Botones
        button_frame = tk.Frame(main_frame)
        button_frame.pack()
        
        tk.Button(
            button_frame,
            text="Aplicar Seleccionados",
            command=self.apply_selected,
            bg='#3498db',
            fg='white',
            padx=20,
            pady=5
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        tk.Button(
            button_frame,
            text="Cancelar",
            command=self.dialog.destroy
        ).pack(side=tk.LEFT)
    
    def apply_selected(self):
        """Aplica los parches seleccionados"""
        selected = self.listbox.curselection()
        if not selected:
            messagebox.showwarning("Selección", "Selecciona al menos un parche.")
            return
        
        # Crear diálogo de progreso
        progress_dialog = tk.Toplevel(self.dialog)
        progress_dialog.title("Aplicando Actualizaciones")
        progress_dialog.geometry("400x150")
        progress_dialog.transient(self.dialog)
        
        tk.Label(
            progress_dialog,
            text="Aplicando parches...",
            font=Font(family="Helvetica", size=12)
        ).pack(pady=(20, 10))
        
        progress_var = tk.DoubleVar()
        progress_bar = ttk.Progressbar(
            progress_dialog,
            variable=progress_var,
            maximum=100,
            length=300
        )
        progress_bar.pack(pady=(0, 20))
        
        status_label = tk.Label(progress_dialog, text="")
        status_label.pack()
        
        # Aplicar parches en hilo separado
        def apply_thread():
            total = len(selected)
            for i, idx in enumerate(selected):
                patch = self.patches[idx]
                
                def progress_callback(percent, status):
                    progress_dialog.after(0, lambda: progress_var.set(percent))
                    progress_dialog.after(0, lambda: status_label.config(text=status))
                
                success, message = self.installer.apply_patch(
                    patch,
                    progress_callback=progress_callback,
                    status_callback=lambda msg: progress_dialog.after(0, lambda: status_label.config(text=msg))
                )
                
                if not success:
                    progress_dialog.after(0, lambda: messagebox.showerror("Error", message))
                    break
            
            progress_dialog.after(0, progress_dialog.destroy)
            self.dialog.after(0, self.dialog.destroy)
            messagebox.showinfo("Éxito", "Actualizaciones aplicadas correctamente.")
        
        thread = threading.Thread(target=apply_thread)
        thread.daemon = True
        thread.start()

# ========== MODO CONSOLA ==========
def run_cli():
    """Ejecuta el instalador en modo consola"""
    installer = AtlasInstaller()
    
    print("🌍 Atlas Interactivo - Instalador")
    print("=" * 40)
    
    while True:
        print("\nOpciones:")
        print("1. Instalar versión completa")
        print("2. Verificar actualizaciones")
        print("3. Salir")
        
        try:
            choice = input("\nSelecciona opción (1-3): ").strip()
            
            if choice == "1":
                print("\n🚀 Iniciando instalación...")
                
                # Verificar espacio
                has_space, space_msg = installer.check_disk_space()
                if not has_space:
                    print(f"❌ {space_msg}")
                    continue
                
                print(f"✅ {space_msg}")
                print(f"📁 Instalando en: {installer.install_dir}")
                
                # Instalar
                success, message = installer.install_full_version(
                    progress_callback=lambda p, s: print(f"\rProgreso: {p:.1f}% - {s}", end=""),
                    status_callback=lambda m: print(f"\n{m}")
                )
                
                if success:
                    print(f"\n✅ {message}")
                    print(f"📁 Carpeta: {installer.install_dir}")
                    print(f"🚀 Ejecuta: {os.path.join(installer.install_dir, 'Atlas_Interactivo')}")
                else:
                    print(f"\n❌ {message}")
            
            elif choice == "2":
                patches = installer.check_for_updates()
                if patches:
                    print(f"\n📋 {len(patches)} actualizaciones disponibles:")
                    for i, patch in enumerate(patches, 1):
                        print(f"  {i}. {patch['name']} ({patch['size']}) - {patch['date']}")
                    
                    apply = input("\n¿Aplicar todas las actualizaciones? (s/n): ").lower()
                    if apply == 's':
                        for patch in patches:
                            print(f"\n🔄 Aplicando {patch['name']}...")
                            success, message = installer.apply_patch(patch)
                            if success:
                                print(f"✅ {message}")
                            else:
                                print(f"❌ {message}")
                else:
                    print("✅ Ya tienes la última versión")
            
            elif choice == "3":
                break
            
            else:
                print("❌ Opción inválida")
        
        except KeyboardInterrupt:
            print("\n\n⏹️  Instalación cancelada")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}")
    
    installer.cleanup()

# ========== PUNTO DE ENTRADA ==========
def main():
    """Función principal"""
    if len(sys.argv) > 1 and sys.argv[1] == "--cli":
        run_cli()
    elif HAS_GUI:
        root = tk.Tk()
        app = InstallerGUI(root)
        
        # Manejar cierre de ventana
        def on_closing():
            app.installer.cleanup()
            root.destroy()
        
        root.protocol("WM_DELETE_WINDOW", on_closing)
        root.mainloop()
    else:
        print("Tkinter no está disponible. Ejecutando en modo consola...")
        run_cli()

if __name__ == "__main__":
    main()