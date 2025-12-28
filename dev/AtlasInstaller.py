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
import argparse
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError
from datetime import datetime


from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
import io


# Importar tkinter para GUI
try:
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog, scrolledtext
    from tkinter.font import Font
    import tkinter.simpledialog as simpledialog
    HAS_GUI = True
except ImportError:
    HAS_GUI = False
    print("Tkinter no disponible, ejecutando en modo consola")
        
class AtlasInstaller:
    def __init__(self, root=None):
        self.root = root
        self.home = str(Path.home())
        self.install_dir = os.path.join(self.home, "Atlas_Interactivo")
        self.temp_dir = tempfile.mkdtemp(prefix="atlas_install_")
        
        # Configuración de Drive
        self.drive_files = {
            "linux": "1vzAxSaKRXIPSNf937v6xjuBhRyrCiVRF",
            "windows": "TU_FILE_ID_WINDOWS_ZIP"
        }
        
        self.patches_folder = "1oAIQGUoR44KKXcaU0IJxsUi7jWyumwiM"
        self.service = None
        
        # Variables de estado
        self.is_downloading = False
        self.is_extracting = False
        self.total_files = 0
        self.processed_files = 0
        self.download_speed = 0
        self.start_time = None

    # ========== NUEVAS FUNCIONES CLI ==========
    
    def show_version(self):
        """Muestra la versión del instalador"""
        version_info = {
            "AtlasInstaller": "2.0.0",
            "AtlasInteractivo": "1.0.0",
            "Python": sys.version.split()[0],
            "Sistema": os.uname().sysname if hasattr(os, 'uname') else "Windows"
        }
        
        print("🌍 Atlas Interactivo - Información de Versión")
        print("=" * 50)
        for key, value in version_info.items():
            print(f"{key:<20}: {value}")
        
        # Verificar si ya está instalado
        version_file = os.path.join(self.home, "Atlas_Interactivo", ".atlas_version.json")
        if os.path.exists(version_file):
            try:
                with open(version_file, 'r') as f:
                    installed_info = json.load(f)
                print("\n📦 Información de instalación:")
                print(f"  Versión instalada: {installed_info.get('version', 'Desconocida')}")
                print(f"  Ruta: {installed_info.get('install_path', 'Desconocida')}")
                print(f"  Fecha instalación: {installed_info.get('install_date', 'Desconocida')}")
                print(f"  Archivos: {installed_info.get('total_files', 0):,}")
            except:
                print("\nℹ️  Atlas Interactivo está instalado pero no se pudo leer la información.")
        else:
            print("\nℹ️  Atlas Interactivo no está instalado.")

    def check_updates_cli(self):
        """Verifica actualizaciones desde CLI"""
        print("🔄 Verificando actualizaciones...")
        
        # Verificar si está instalado
        version_file = os.path.join(self.home, "Atlas_Interactivo", ".atlas_version.json")
        if not os.path.exists(version_file):
            print("❌ Atlas Interactivo no está instalado.")
            print("💡 Ejecuta sin argumentos para instalar.")
            return
        
        with open(version_file, 'r') as f:
            current_info = json.load(f)
        
        current_version = current_info.get('version', '1.0.0')
        
        # Simular verificación de actualizaciones
        # En producción, esto se conectaría a una API o archivo remoto
        print(f"\n📊 Versión actual: v{current_version}")
        
        available_updates = [
            {"version": "1.0.1", "size": "150MB", "description": "Parche de mapas actualizados"},
            {"version": "1.0.2", "size": "120MB", "description": "Nuevos datos climáticos"},
        ]
        
        # Filtrar solo actualizaciones posteriores
        newer_updates = [u for u in available_updates if u["version"] > current_version]
        
        if newer_updates:
            print(f"\n📦 {len(newer_updates)} actualización(es) disponible(s):")
            for i, update in enumerate(newer_updates, 1):
                print(f"  {i}. v{update['version']} ({update['size']}) - {update['description']}")
            
            print("\n💡 Para actualizar, ejecuta el instalador normalmente.")
        else:
            print("✅ Ya tienes la última versión.")
        
        # También mostrar parches disponibles
        patches = self.check_for_updates()
        if patches:
            print(f"\n🔧 {len(patches)} parche(s) disponible(s):")
            for patch in patches:
                print(f"  • {patch['name']} ({patch['size']}) - v{patch['version']}")
        else:
            print("\n✅ No hay parches pendientes.")

    def show_help(self):
        """Muestra ayuda de línea de comandos"""
        help_text = """
🌍 Atlas Interactivo - Instalador

USO:
  ./AtlasInstaller [OPCIONES]

OPCIONES:
  --help, -h          Muestra esta ayuda
  --version, -v       Muestra información de versión
  --cli               Modo consola interactivo
  --check-updates     Verifica actualizaciones disponibles
  --install-dir DIR   Especifica directorio de instalación (ej: /opt/atlas)
  --skip-desktop      No crear accesos directos
  --no-gui            Forzar modo consola incluso si GUI está disponible

EJEMPLOS:
  # Instalar con GUI (por defecto)
  ./AtlasInstaller
  
  # Instalar en modo consola interactivo
  ./AtlasInstaller --cli
  
  # Verificar actualizaciones
  ./AtlasInstaller --check-updates
  
  # Instalar en directorio específico sin GUI
  ./AtlasInstaller --install-dir /opt/Atlas --no-gui
  
  # Mostrar versión
  ./AtlasInstaller --version

CARACTERÍSTICAS:
  • Descarga ~13GB de datos desde Google Drive
  • Extracción automática y verificación
  • Creación de accesos directos en escritorio/menú
  • Sistema de actualización automática
  • Instalación completamente offline una vez completada
"""
        print(help_text)

    def install_cli(self, install_dir=None, skip_desktop=False):
        """Instalación desde línea de comandos sin interacción"""
        if install_dir:
            self.install_dir = install_dir
        
        print(f"🚀 Iniciando instalación en: {self.install_dir}")
        
        # Verificar espacio
        has_space, space_msg = self.check_disk_space()
        if not has_space:
            print(f"❌ {space_msg}")
            return False
        
        print(f"✅ {space_msg}")
        
        # Crear directorio
        os.makedirs(self.install_dir, exist_ok=True)
        
        # Instalar
        def cli_progress(percent, status):
            bar_length = 40
            filled = int(bar_length * percent / 100)
            bar = '█' * filled + '░' * (bar_length - filled)
            print(f"\r{status}: [{bar}] {percent:.1f}%", end='', flush=True)
        
        def cli_status(message):
            print(f"\n{message}")
        
        print("\n⏳ Descargando Atlas Interactivo...")
        success, message = self.install_full_version(
            progress_callback=cli_progress,
            status_callback=cli_status
        )
        
        if success:
            # Crear accesos directos si no se especifica skip_desktop
            if not skip_desktop:
                self.create_desktop_launcher()
            
            print(f"\n\n{'=' * 50}")
            print("✅ INSTALACIÓN COMPLETADA EXITOSAMENTE")
            print(f"{'=' * 50}")
            print(f"\n📁 Carpeta de instalación: {self.install_dir}")
            
            if not skip_desktop:
                print("📋 Accesos creados: Escritorio y menú de aplicaciones")
            
            print(f"\n🚀 Para ejecutar: {self.install_dir}/Atlas_Interactivo")
            print("💡 O busca 'Atlas Interactivo' en tu menú de aplicaciones")
            print("\n🎉 ¡Disfruta de Atlas Interactivo!")
            return True
        else:
            print(f"\n\n❌ ERROR: {message}")
            return False


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
            with tarfile.open(archive_path, 'r:gz') as tar:  # 'r:gz' para .tar.gz
                members = tar.getmembers()
                self.total_files = len(members)
                self.processed_files = 0
                
                print(f"📦 Total de miembros en el tar.gz: {self.total_files}")
                
                for member in members:
                    dest_path = os.path.join(extract_to, member.name)
                    
                    # Saltar si no es archivo ni directorio
                    if not member.isfile() and not member.isdir():
                        continue
                    
                    if member.isdir():
                        os.makedirs(dest_path, exist_ok=True)
                    else:
                        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                        
                        try:
                            with tar.extractfile(member) as source, open(dest_path, 'wb') as dest:
                                shutil.copyfileobj(source, dest)
                        except (AttributeError, KeyError) as e:
                            print(f"⚠️  Saltando {member.name}: {e}")
                            continue
                    
                    self.processed_files += 1
                    
                    if progress_callback:
                        percent = (self.processed_files / self.total_files) * 100
                        progress_callback(percent, self.processed_files, self.total_files)
                    
                    if self.processed_files % 100 == 0:
                        print(f"📁 Procesados: {self.processed_files}/{self.total_files} archivos")
                
                print(f"✅ Extracción completada: {self.processed_files} archivos")
                return True
                
        except Exception as e:
            print(f"❌ Error extrayendo .tar.gz: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
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
    

    def extract_archive_with_progress(self, archive_path, extract_to, progress_callback=None):
        """Extrae archivo detectando automáticamente si es .tar o .tar.gz"""
        try:
            # Verificar que el archivo existe
            if not os.path.exists(archive_path):
                print(f"❌ Archivo no encontrado: {archive_path}")
                return False
            
            print(f"📦 Extrayendo: {archive_path}")
            print(f"   Tamaño: {os.path.getsize(archive_path) / (1024*1024):.2f} MB")
            print(f"   Destino: {extract_to}")
            
            # Detectar tipo de archivo por extensión
            if archive_path.endswith('.tar.gz') or archive_path.endswith('.tgz'):
                print("🔍 Detectado: archivo .tar.gz comprimido")
                return self.extract_tar_gz_with_progress(archive_path, extract_to, progress_callback)
            elif archive_path.endswith('.tar'):
                print("🔍 Detectado: archivo .tar simple")
                return self.extract_tar_with_progress(archive_path, extract_to, progress_callback)
            elif archive_path.endswith('.zip'):
                print("🔍 Detectado: archivo .zip")
                # Si no tienes esta función, comenta esta línea o implementa extract_zip_with_progress
                # return self.extract_zip_with_progress(archive_path, extract_to, progress_callback)
                print("⚠️  Extracción de ZIP no implementada, intentando como tar...")
                return self.extract_tar_with_progress(archive_path, extract_to, progress_callback)
            else:
                print(f"⚠️  Extensión no reconocida: {archive_path}")
                # Intentar como tar simple
                print("🔄 Intentando extraer como .tar simple...")
                return self.extract_tar_with_progress(archive_path, extract_to, progress_callback)
                
        except Exception as e:
            print(f"❌ Error en extracción automática: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            return False


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

            # CAMBIA ESTO: Quita el .gz porque tu archivo es .tar simple
            archive_path = os.path.join(self.temp_dir, "Atlas_Linux.tar")  # Sin .gz
            
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
            
            # Función para callback de progreso de extracción - ¡DEFINIRLA ANTES DE USARLA!
            def ex_progress(percent, processed, total):
                if progress_callback:
                    progress_callback(percent, f"Extrayendo...")
                if status_callback:
                    status_callback(f"Extraídos: {processed}/{total} archivos")
            
            # Usa la función automática que detecta el tipo
            success = self.extract_archive_with_progress(archive_path, self.install_dir, ex_progress)
            
            if not success:
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

    def extract_tar_with_progress(self, archive_path, extract_to, progress_callback=None):
        """Extrae .tar simple (sin comprimir) con callback de progreso"""
        try:
            # Abre como .tar simple, no .tar.gz
            with tarfile.open(archive_path, 'r:') as tar:  # 'r:' para tar simple
                members = tar.getmembers()
                self.total_files = len(members)
                self.processed_files = 0
                
                # Opcional: filtrar archivos muy pequeños o innecesarios
                # members = [m for m in members if m.size > 0 or m.isdir()]
                
                print(f"📦 Total de miembros en el tar: {self.total_files}")
                
                for member in members:
                    dest_path = os.path.join(extract_to, member.name)
                    
                    # Saltar si es un enlace simbólico o dispositivo especial
                    if not member.isfile() and not member.isdir():
                        continue
                    
                    # Crear directorios necesarios
                    if member.isdir():
                        os.makedirs(dest_path, exist_ok=True)
                    else:
                        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                        
                        try:
                            with tar.extractfile(member) as source, open(dest_path, 'wb') as dest:
                                shutil.copyfileobj(source, dest)
                        except (AttributeError, KeyError) as e:
                            # Algunos miembros pueden no tener contenido (como enlaces)
                            print(f"⚠️  Saltando {member.name}: {e}")
                            continue
                    
                    self.processed_files += 1
                    
                    if progress_callback:
                        percent = (self.processed_files / self.total_files) * 100
                        progress_callback(percent, self.processed_files, self.total_files)
                    
                    # Mostrar progreso cada 100 archivos
                    if self.processed_files % 100 == 0:
                        print(f"📁 Procesados: {self.processed_files}/{self.total_files} archivos")
                
                print(f"✅ Extracción completada: {self.processed_files} archivos")
                return True
                
        except tarfile.ReadError as e:
            print(f"❌ Error leyendo archivo tar: {e}")
            print(f"   Ruta: {archive_path}")
            print(f"   Tamaño: {os.path.getsize(archive_path) / (1024*1024):.2f} MB")
            return False
        except Exception as e:
            print(f"❌ Error extrayendo: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            return False

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
        desktop_dir = os.path.join(self.home, ".local", "share", "applications")
        os.makedirs(desktop_dir, exist_ok=True)
        
        desktop_file = os.path.join(desktop_dir, "atlas-interactivo.desktop")
        
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
        
        # También en Desktop si el usuario quiere
        desktop_link = os.path.join(self.home, "Desktop", "Atlas Interactivo.desktop")
        try:
            shutil.copy(desktop_file, desktop_link)
            os.chmod(desktop_link, 0o755)
        except:
            pass  # No hay Desktop o permisos
    
    # ========== MÉTODOS DE ACTUALIZACIÓN ==========
    def init_drive_service(self):
        """Inicializa el servicio de Google Drive"""
        try:
            # Crea un archivo credentials.json en tu proyecto
            # Obtén credenciales de: https://console.cloud.google.com/apis/credentials
            credentials_path = "credentials.json"
            
            if os.path.exists(credentials_path):
                credentials = service_account.Credentials.from_service_account_file(
                    credentials_path,
                    scopes=['https://www.googleapis.com/auth/drive.readonly']
                )
                self.service = build('drive', 'v3', credentials=credentials)
                return True
        except Exception as e:
            print(f"Error inicializando Drive: {e}")
        return False
    
    def list_patches(self):
        """Lista parches disponibles en la carpeta"""
        if not self.service:
            if not self.init_drive_service():
                return []
        
        try:
            query = f"'{self.patches_folder}' in parents and trashed=false"
            results = self.service.files().list(
                q=query,
                fields="files(id, name, size, modifiedTime)",
                orderBy="modifiedTime desc"
            ).execute()
            
            patches = []
            for file in results.get('files', []):
                patches.append({
                    'id': file['id'],
                    'name': file['name'],
                    'size': f"{int(file.get('size', 0)) / (1024*1024):.1f}MB",
                    'date': file['modifiedTime'][:10],  # Solo fecha
                    'version': self.extract_version_from_name(file['name'])
                })
            
            return patches
            
        except Exception as e:
            print(f"Error listando parches: {e}")
            return []
    
    def extract_version_from_name(self, filename):
        """Extrae versión del nombre del archivo"""
        # Ejemplo: "atlas_patch_v1.0.1.tar.gz" -> "1.0.1"
        import re
        match = re.search(r'v?(\d+\.\d+\.\d+)', filename)
        return match.group(1) if match else "1.0.0"
    
    def download_patch(self, patch_id, destination, progress_callback=None):
        """Descarga un parche específico"""
        if not self.service:
            if not self.init_drive_service():
                return False, "Servicio Drive no disponible"
        
        try:
            request = self.service.files().get_media(fileId=patch_id)
            
            with open(destination, 'wb') as fh:
                downloader = MediaIoBaseDownload(fh, request)
                
                done = False
                while not done:
                    status, done = downloader.next_chunk()
                    
                    if progress_callback and status:
                        percent = int(status.progress() * 100)
                        progress_callback(percent, "Descargando parche...")
                
            return True, "Parche descargado"
            
        except Exception as e:
            return False, f"Error descargando: {e}"


    def check_for_updates(self):
        """Verifica parches disponibles"""
        # Primero verificar si Atlas está instalado
        version_file = os.path.join(self.install_dir, ".atlas_version.json")
        if not os.path.exists(version_file):
            return []
        
        try:
            with open(version_file, 'r') as f:
                current_info = json.load(f)
            
            current_version = current_info.get('version', '1.0.0')
            
            # Obtener parches reales de Drive
            available_patches = self.list_patches()
            
            # Filtrar solo parches con versión mayor
            newer_patches = []
            for patch in available_patches:
                if patch['version'] > current_version:
                    newer_patches.append(patch)
            
            return newer_patches
            
        except Exception as e:
            print(f"Error verificando actualizaciones: {e}")
            return []



    def apply_patch(self, patch_info, progress_callback=None, status_callback=None):
        """Aplica un parche"""
        try:
            # Descargar parche
            patch_url = f"https://drive.google.com/uc?id={patch_info['id']}&export=download"  # Cambia 'file_id' por 'id'
            patch_path = os.path.join(self.temp_dir, f"patch_{patch_info['id']}.tar")  # Sin .gz
            
            if status_callback:
                status_callback(f"Descargando {patch_info['name']}...")
            
            if not self.download_with_progress(patch_url, patch_path, progress_callback):
                return False, "Error descargando parche"
            
            # Aplicar parche
            if status_callback:
                status_callback(f"Aplicando {patch_info['name']}...")
            
            # Usa la función automática
            if not self.extract_archive_with_progress(patch_path, self.install_dir, progress_callback):
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

# ========== INTERFAZ GRÁFICA MEJORADA ==========
class InstallerGUI:
    def __init__(self, root):
        self.root = root
        self.installer = AtlasInstaller(root)
        
        # Configuración de la ventana principal
        self.setup_window()
        self.setup_ui()
        self.center_window()
        
    def setup_window(self):
        """Configura la ventana principal"""
        # Obtener dimensiones de pantalla
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        
        # Calcular tamaño óptimo (75% de la pantalla)
        width = int(screen_width * 0.75)
        height = int(screen_height * 0.75)
        
        # Establecer tamaño mínimo y máximo
        min_width = 800
        min_height = 600
        max_width = screen_width
        max_height = screen_height
        
        self.root.title("🌍 Atlas Interactivo - Instalador")
        self.root.geometry(f"{width}x{height}")
        self.root.minsize(min_width, min_height)
        self.root.maxsize(max_width, max_height)
        
        # Hacer la ventana resizable
        self.root.resizable(True, True)
        
        # Establecer ícono (si existe)
        try:
            self.root.iconphoto(False, tk.PhotoImage(file='icon.png'))
        except:
            pass
        
    def center_window(self):
        """Centra la ventana en la pantalla"""
        self.root.update_idletasks()
        width = self.root.winfo_width()
        height = self.root.winfo_height()
        x = (self.root.winfo_screenwidth() // 2) - (width // 2)
        y = (self.root.winfo_screenheight() // 2) - (height // 2)
        self.root.geometry(f'{width}x{height}+{x}+{y}')
    
    def setup_ui(self):
        """Configura la interfaz de usuario"""
        # Configurar grid para que se expanda
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        
        # Frame principal con scrollbar
        self.main_frame = tk.Frame(self.root, bg='#f0f0f0')
        self.main_frame.grid(row=0, column=0, sticky="nsew", padx=20, pady=20)
        
        # Configurar grid del main_frame
        self.main_frame.columnconfigure(0, weight=1)
        for i in range(6):  # 6 filas principales
            self.main_frame.rowconfigure(i, weight=0)
        self.main_frame.rowconfigure(6, weight=1)  # Espacio de separación
        self.main_frame.rowconfigure(7, weight=0)  # Barra de progreso
        self.main_frame.rowconfigure(8, weight=0)  # Estado
        self.main_frame.rowconfigure(9, weight=0)  # Botones
        
        # Fuentes escalables
        title_font_size = max(18, int(self.root.winfo_screenheight() / 50))
        normal_font_size = max(10, int(self.root.winfo_screenheight() / 80))
        
        self.title_font = Font(family="Helvetica", size=title_font_size, weight="bold")
        self.normal_font = Font(family="Helvetica", size=normal_font_size)
        self.small_font = Font(family="Helvetica", size=normal_font_size-2)
        
        # ========== TÍTULO ==========
        self.title_label = tk.Label(
            self.main_frame,
            text="🌍 Atlas Interactivo",
            font=self.title_font,
            bg='#f0f0f0',
            fg='#2c3e50'
        )
        self.title_label.grid(row=0, column=0, pady=(0, 5), sticky="w")
        
        self.subtitle_label = tk.Label(
            self.main_frame,
            text="Software meteorológico y de mapas interactivo profesional",
            font=self.small_font,
            bg='#f0f0f0',
            fg='#7f8c8d'
        )
        self.subtitle_label.grid(row=1, column=0, pady=(0, 20), sticky="w")
        
        # ========== ESPACIO EN DISCO ==========
        self.space_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        self.space_frame.grid(row=2, column=0, pady=(0, 20), sticky="ew")
        self.space_frame.columnconfigure(0, weight=1)
        
        has_space, space_msg = self.installer.check_disk_space()
        space_color = '#27ae60' if has_space else '#e74c3c'
        
        self.space_label = tk.Label(
            self.space_frame,
            text=f"📊 {space_msg}",
            font=self.normal_font,
            bg='#f0f0f0',
            fg=space_color
        )
        self.space_label.grid(row=0, column=0, sticky="w")
        
        # ========== RUTA DE INSTALACIÓN ==========
        path_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        path_frame.grid(row=3, column=0, pady=(0, 10), sticky="ew")
        path_frame.columnconfigure(0, weight=1)
        
        tk.Label(
            path_frame,
            text="📁 Ruta de instalación:",
            font=self.normal_font,
            bg='#f0f0f0'
        ).grid(row=0, column=0, sticky="w")
        
        self.path_var = tk.StringVar(value=self.installer.install_dir)
        self.path_entry = tk.Entry(
            path_frame,
            textvariable=self.path_var,
            font=self.normal_font,
            bg='white',
            relief=tk.SOLID,
            borderwidth=1
        )
        self.path_entry.grid(row=1, column=0, sticky="ew", pady=(5, 0))
        
        self.browse_btn = tk.Button(
            path_frame,
            text="Examinar...",
            command=self.browse_directory,
            font=self.small_font,
            bg='#ecf0f1',
            relief=tk.RAISED,
            borderwidth=1,
            cursor='hand2'
        )
        self.browse_btn.grid(row=1, column=1, padx=(10, 0), pady=(5, 0), sticky="ew")
        
        # ========== OPCIONES ==========
        options_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        options_frame.grid(row=4, column=0, pady=(0, 20), sticky="w")
        
        self.create_desktop_var = tk.BooleanVar(value=True)
        self.desktop_cb = tk.Checkbutton(
            options_frame,
            text="📋 Crear acceso directo en el escritorio",
            variable=self.create_desktop_var,
            font=self.normal_font,
            bg='#f0f0f0',
            cursor='hand2',
            selectcolor='#ecf0f1'
        )
        self.desktop_cb.pack(anchor="w")
        
        self.create_menu_var = tk.BooleanVar(value=True)
        self.menu_cb = tk.Checkbutton(
            options_frame,
            text="📋 Agregar al menú de aplicaciones",
            variable=self.create_menu_var,
            font=self.normal_font,
            bg='#f0f0f0',
            cursor='hand2',
            selectcolor='#ecf0f1'
        )
        self.menu_cb.pack(anchor="w")
        
        # ========== INFO ADICIONAL ==========
        info_frame = tk.Frame(self.main_frame, bg='#e8f4f8', relief=tk.RIDGE, borderwidth=2)
        info_frame.grid(row=5, column=0, pady=(0, 20), sticky="ew", ipadx=10, ipady=10)
        info_frame.columnconfigure(0, weight=1)
        
        tk.Label(
            info_frame,
            text="ℹ️  Información de la instalación:",
            font=self.small_font,
            bg='#e8f4f8',
            fg='#2980b9'
        ).grid(row=0, column=0, sticky="w", pady=(0, 5))
        
        info_text = """
• Tamaño aproximado: 13 GB
• Espacio requerido: 15 GB
• Tiempo estimado: Depende de tu conexión a internet
• Una vez instalado, funciona completamente offline
• Incluye mapas, datos climáticos y herramientas de análisis
        """
        
        self.info_label = tk.Label(
            info_frame,
            text=info_text,
            font=self.small_font,
            bg='#e8f4f8',
            fg='#2c3e50',
            justify=tk.LEFT
        )
        self.info_label.grid(row=1, column=0, sticky="w")
        
        # ========== BARRA DE PROGRESO ==========
        progress_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        progress_frame.grid(row=7, column=0, pady=(20, 10), sticky="ew")
        progress_frame.columnconfigure(0, weight=1)
        
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(
            progress_frame,
            variable=self.progress_var,
            maximum=100,
            mode='determinate',
            length=200  # Será expandido por grid
        )
        self.progress_bar.grid(row=0, column=0, sticky="ew")
        
        # ========== ETIQUETAS DE ESTADO ==========
        status_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        status_frame.grid(row=8, column=0, pady=(0, 20), sticky="ew")
        status_frame.columnconfigure(0, weight=1)
        
        self.status_label = tk.Label(
            status_frame,
            text="👋 Bienvenido. Selecciona una ruta y haz clic en 'Instalar' para comenzar.",
            font=self.normal_font,
            bg='#f0f0f0',
            fg='#2c3e50',
            wraplength=500
        )
        self.status_label.grid(row=0, column=0, sticky="w", pady=(0, 5))
        
        self.detail_label = tk.Label(
            status_frame,
            text="",
            font=self.small_font,
            bg='#f0f0f0',
            fg='#7f8c8d',
            wraplength=500
        )
        self.detail_label.grid(row=1, column=0, sticky="w")
        
        # ========== BOTONES ==========
        button_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        button_frame.grid(row=9, column=0, pady=(0, 10), sticky="ew")
        button_frame.columnconfigure(0, weight=1)
        button_frame.columnconfigure(1, weight=1)
        
        self.install_btn = tk.Button(
            button_frame,
            text="🚀 Instalar Atlas",
            command=self.start_installation,
            font=Font(family="Helvetica", size=normal_font_size+2, weight="bold"),
            bg='#3498db',
            fg='white',
            padx=30,
            pady=12,
            cursor='hand2',
            relief=tk.RAISED,
            borderwidth=2
        )
        self.install_btn.grid(row=0, column=0, padx=(0, 10), sticky="ew")
        
        self.update_btn = tk.Button(
            button_frame,
            text="🔄 Buscar Actualizaciones",
            command=self.check_updates,
            font=self.normal_font,
            bg='#ecf0f1',
            state=tk.DISABLED,
            padx=20,
            pady=8,
            cursor='hand2'
        )
        self.update_btn.grid(row=0, column=1, sticky="ew")
        
        # Botón de salir abajo a la derecha
        exit_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        exit_frame.grid(row=10, column=0, sticky="e")
        
        self.exit_btn = tk.Button(
            exit_frame,
            text="✖ Salir",
            command=self.on_closing,
            font=self.small_font,
            bg='#e74c3c',
            fg='white',
            padx=15,
            pady=5,
            cursor='hand2'
        )
        self.exit_btn.pack()
        
        # Frame de completado (oculto inicialmente)
        self.complete_frame = tk.Frame(self.main_frame, bg='#f0f0f0')
        
        # Configurar eventos de redimensionamiento
        self.root.bind('<Configure>', self.on_window_resize)
    
    def on_window_resize(self, event):
        """Ajusta la UI cuando se redimensiona la ventana"""
        if event.widget == self.root:
            # Ajustar wraplength de las etiquetas
            new_width = event.width - 40  # Considerar padding
            self.status_label.config(wraplength=new_width)
            self.detail_label.config(wraplength=new_width)
            self.info_label.config(wraplength=new_width)
    
    def browse_directory(self):
        """Abre diálogo para seleccionar directorio"""
        directory = filedialog.askdirectory(
            initialdir=self.installer.home,
            title="Selecciona la carpeta para instalar Atlas"
        )
        if directory:
            self.path_var.set(directory)
            self.installer.install_dir = directory
            
            # Verificar espacio nuevamente
            has_space, space_msg = self.installer.check_disk_space()
            space_color = '#27ae60' if has_space else '#e74c3c'
            self.space_label.config(text=f"📊 {space_msg}", fg=space_color)
            
            if has_space:
                self.install_btn.config(state=tk.NORMAL, bg='#3498db')
            else:
                self.install_btn.config(state=tk.DISABLED, bg='#95a5a6')
    
    def start_installation(self):
        """Inicia la instalación en un hilo separado"""
        self.install_btn.config(state=tk.DISABLED, text="⏳ Instalando...", bg='#f39c12')
        self.update_btn.config(state=tk.DISABLED)
        self.browse_btn.config(state=tk.DISABLED)
        self.progress_var.set(0)
        self.status_label.config(text="⏳ Iniciando instalación...")
        
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
            self.show_completion_screen()
            self.update_btn.config(state=tk.NORMAL, bg='#ecf0f1')
        else:
            messagebox.showerror("❌ Error", message, parent=self.root)
            self.install_btn.config(state=tk.NORMAL, text="🚀 Reintentar Instalación", bg='#3498db')
            self.update_btn.config(state=tk.NORMAL)
            self.browse_btn.config(state=tk.NORMAL)
    
    def show_completion_screen(self):
        """Muestra la pantalla de instalación completada"""
        # Ocultar todos los widgets excepto el frame de completado
        for widget in self.main_frame.winfo_children():
            if widget != self.complete_frame:
                widget.grid_remove()
        
        # Configurar frame de completado
        self.complete_frame.grid(row=0, column=0, sticky="nsew", rowspan=11)
        self.complete_frame.columnconfigure(0, weight=1)
        
        # Contenido del frame de completado
        tk.Label(
            self.complete_frame,
            text="✅ ¡Instalación Completada!",
            font=Font(family="Helvetica", size=24, weight="bold"),
            bg='#f0f0f0',
            fg='#27ae60'
        ).grid(row=0, column=0, pady=(50, 20))
        
        tk.Label(
            self.complete_frame,
            text=f"Atlas Interactivo se ha instalado exitosamente en:",
            font=self.normal_font,
            bg='#f0f0f0',
            fg='#2c3e50'
        ).grid(row=1, column=0, pady=(0, 10))
        
        # Mostrar ruta en un frame con scroll
        path_frame = tk.Frame(self.complete_frame, bg='white', relief=tk.SUNKEN, borderwidth=1)
        path_frame.grid(row=2, column=0, pady=(0, 20), sticky="ew", padx=50)
        
        path_text = tk.Text(
            path_frame,
            height=2,
            font=self.small_font,
            bg='white',
            fg='#2c3e50',
            wrap=tk.WORD,
            relief=tk.FLAT
        )
        path_text.insert(1.0, self.installer.install_dir)
        path_text.config(state=tk.DISABLED)
        path_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        # Botones de acción
        button_frame = tk.Frame(self.complete_frame, bg='#f0f0f0')
        button_frame.grid(row=3, column=0, pady=(20, 10))
        
        tk.Button(
            button_frame,
            text="🎯 Ejecutar Atlas",
            command=self.launch_atlas,
            font=Font(family="Helvetica", size=self.normal_font.cget("size")+2, weight="bold"),
            bg='#2ecc71',
            fg='white',
            padx=30,
            pady=15,
            cursor='hand2'
        ).pack(side=tk.LEFT, padx=5)
        
        tk.Button(
            button_frame,
            text="📁 Abrir Carpeta",
            command=self.open_folder,
            font=self.normal_font,
            bg='#3498db',
            fg='white',
            padx=20,
            pady=10,
            cursor='hand2'
        ).pack(side=tk.LEFT, padx=5)
        
        tk.Button(
            button_frame,
            text="🔙 Volver al Inicio",
            command=self.show_main_screen,
            font=self.normal_font,
            bg='#ecf0f1',
            padx=20,
            pady=10,
            cursor='hand2'
        ).pack(side=tk.LEFT, padx=5)
    
    def show_main_screen(self):
        """Vuelve a mostrar la pantalla principal"""
        self.complete_frame.grid_remove()
        
        # Mostrar todos los widgets nuevamente
        for widget in self.main_frame.winfo_children():
            widget.grid()
        
        # Actualizar estado
        self.status_label.config(text="✅ Instalación completada. Puedes instalar en otra ubicación si lo deseas.")
        self.detail_label.config(text="")
        self.progress_var.set(0)
        self.install_btn.config(state=tk.NORMAL, text="🚀 Instalar Atlas", bg='#3498db')
        self.update_btn.config(state=tk.NORMAL)
        self.browse_btn.config(state=tk.NORMAL)
    
    def check_updates(self):
        """Verifica actualizaciones disponibles"""
        # Esto sería la implementación real
        messagebox.showinfo("🔄 Actualizaciones", 
                          "La verificación de actualizaciones se implementará en la versión final.\n\n"
                          "Por ahora, descarga los parches manualmente desde la página web.",
                          parent=self.root)
    
    def launch_atlas(self):
        """Ejecuta Atlas"""
        atlas_path = os.path.join(self.installer.install_dir, "Atlas_Interactivo")
        if os.path.exists(atlas_path):
            try:
                subprocess.Popen([atlas_path], start_new_session=True)
                self.on_closing()
            except Exception as e:
                messagebox.showerror("❌ Error", f"No se pudo ejecutar Atlas:\n{e}", parent=self.root)
        else:
            # Buscar cualquier ejecutable en la carpeta
            executables = []
            for root, dirs, files in os.walk(self.installer.install_dir):
                for file in files:
                    if file.lower().endswith(('.appimage', '.sh', '')) and os.access(os.path.join(root, file), os.X_OK):
                        executables.append(os.path.join(root, file))
            
            if executables:
                try:
                    subprocess.Popen([executables[0]], start_new_session=True)
                    self.on_closing()
                except Exception as e:
                    messagebox.showerror("❌ Error", f"No se pudo ejecutar el archivo:\n{e}", parent=self.root)
            else:
                messagebox.showerror("❌ Error", 
                                   "No se encontró el ejecutable de Atlas en la carpeta de instalación.\n\n"
                                   f"Por favor, verifica que la carpeta {self.installer.install_dir} contiene Atlas_Interactivo",
                                   parent=self.root)
    
    def open_folder(self):
        """Abre la carpeta de instalación"""
        if os.path.exists(self.installer.install_dir):
            try:
                subprocess.Popen(['xdg-open', self.installer.install_dir])
            except:
                # Fallback para sistemas sin xdg-open
                try:
                    subprocess.Popen(['nautilus', self.installer.install_dir])
                except:
                    try:
                        subprocess.Popen(['dolphin', self.installer.install_dir])
                    except:
                        messagebox.showinfo("📁 Carpeta", 
                                          f"La carpeta de instalación es:\n{self.installer.install_dir}",
                                          parent=self.root)
        else:
            messagebox.showerror("❌ Error", "La carpeta de instalación no existe.", parent=self.root)
    
    def on_closing(self):
        """Maneja el cierre de la ventana"""
        self.installer.cleanup()
        self.root.destroy()

# ========== DIÁLOGO DE ACTUALIZACIONES ==========
class UpdateDialog:
    def __init__(self, parent, installer, patches):
        self.installer = installer
        self.patches = patches
        
        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Actualizaciones Disponibles")
        self.dialog.geometry("600x500")
        self.dialog.resizable(True, True)
        self.dialog.transient(parent)
        self.dialog.grab_set()
        
        # Centrar
        self.dialog.update_idletasks()
        x = parent.winfo_x() + (parent.winfo_width() // 2) - (600 // 2)
        y = parent.winfo_y() + (parent.winfo_height() // 2) - (500 // 2)
        self.dialog.geometry(f"+{x}+{y}")
        
        self.setup_ui()
    
    def setup_ui(self):
        # Configurar grid
        self.dialog.columnconfigure(0, weight=1)
        self.dialog.rowconfigure(0, weight=0)
        self.dialog.rowconfigure(1, weight=1)
        self.dialog.rowconfigure(2, weight=0)
        
        # Título
        tk.Label(
            self.dialog,
            text="📦 Actualizaciones Disponibles",
            font=Font(family="Helvetica", size=14, weight="bold")
        ).grid(row=0, column=0, pady=(20, 10), sticky="w", padx=20)
        
        # Frame para lista con scroll
        list_frame = tk.Frame(self.dialog)
        list_frame.grid(row=1, column=0, sticky="nsew", padx=20, pady=(0, 20))
        
        list_frame.columnconfigure(0, weight=1)
        list_frame.rowconfigure(0, weight=1)
        
        # Treeview para mostrar parches
        columns = ("#", "Nombre", "Tamaño", "Fecha", "Versión")
        self.tree = ttk.Treeview(list_frame, columns=columns, show="headings", height=10)
        
        # Configurar columnas
        self.tree.heading("#", text="#")
        self.tree.heading("Nombre", text="Nombre")
        self.tree.heading("Tamaño", text="Tamaño")
        self.tree.heading("Fecha", text="Fecha")
        self.tree.heading("Versión", text="Versión")
        
        self.tree.column("#", width=30, anchor="center")
        self.tree.column("Nombre", width=200)
        self.tree.column("Tamaño", width=80, anchor="center")
        self.tree.column("Fecha", width=100, anchor="center")
        self.tree.column("Versión", width=80, anchor="center")
        
        # Scrollbar
        scrollbar = ttk.Scrollbar(list_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)
        
        self.tree.grid(row=0, column=0, sticky="nsew")
        scrollbar.grid(row=0, column=1, sticky="ns")
        
        # Agregar datos
        for i, patch in enumerate(self.patches, 1):
            self.tree.insert("", "end", values=(
                i,
                patch['name'],
                patch['size'],
                patch['date'],
                patch['version']
            ))
        
        # Frame de botones
        button_frame = tk.Frame(self.dialog)
        button_frame.grid(row=2, column=0, pady=(0, 20), padx=20)
        
        tk.Button(
            button_frame,
            text="🔄 Aplicar Seleccionados",
            command=self.apply_selected,
            bg='#3498db',
            fg='white',
            padx=20,
            pady=8
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        tk.Button(
            button_frame,
            text="❌ Cancelar",
            command=self.dialog.destroy,
            bg='#e74c3c',
            fg='white',
            padx=20,
            pady=8
        ).pack(side=tk.LEFT)
    
    def apply_selected(self):
        """Aplica los parches seleccionados"""
        selected = self.tree.selection()
        if not selected:
            messagebox.showwarning("Selección", "Selecciona al menos un parche.")
            return
        
        self.dialog.destroy()
        # Aquí iría la lógica para aplicar parches

# ========== MODO CONSOLA ==========
def run_cli():
    """Ejecuta el instalador en modo consola"""
    installer = AtlasInstaller()
    
    print("🌍 Atlas Interactivo - Instalador")
    print("=" * 50)
    
    while True:
        print("\nOpciones:")
        print("1. Instalar versión completa")
        print("2. Verificar actualizaciones")
        print("3. Salir")
        
        try:
            choice = input("\nSelecciona opción (1-3): ").strip()
            
            if choice == "1":
                print("\n" + "=" * 50)
                print("🚀 INICIANDO INSTALACIÓN")
                print("=" * 50)
                
                # Verificar espacio
                has_space, space_msg = installer.check_disk_space()
                if not has_space:
                    print(f"\n❌ {space_msg}")
                    continue
                
                print(f"\n✅ {space_msg}")
                print(f"📁 Instalando en: {installer.install_dir}")
                print("\n⚠️  Esta operación descargará aproximadamente 13 GB de datos.")
                confirm = input("¿Continuar? (s/n): ").lower()
                
                if confirm != 's':
                    print("Instalación cancelada.")
                    continue
                
                print("\n⏳ Iniciando descarga...")
                
                # Instalar con barra de progreso en consola
                def console_progress(percent, status):
                    bar_length = 40
                    filled = int(bar_length * percent / 100)
                    bar = '█' * filled + '░' * (bar_length - filled)
                    print(f"\r{status}: [{bar}] {percent:.1f}%", end='', flush=True)
                
                def console_status(message):
                    print(f"\n{message}")
                
                success, message = installer.install_full_version(
                    progress_callback=console_progress,
                    status_callback=console_status
                )
                
                if success:
                    print(f"\n\n{'=' * 50}")
                    print("✅ INSTALACIÓN COMPLETADA EXITOSAMENTE")
                    print(f"{'=' * 50}")
                    print(f"\n📁 Carpeta de instalación: {installer.install_dir}")
                    print(f"🚀 Para ejecutar: cd {installer.install_dir} && ./Atlas_Interactivo")
                    print("\n🎉 ¡Disfruta de Atlas Interactivo!")
                else:
                    print(f"\n\n❌ ERROR: {message}")
            
            elif choice == "2":
                patches = installer.check_for_updates()
                if patches:
                    print(f"\n📋 {len(patches)} actualizaciones disponibles:")
                    for i, patch in enumerate(patches, 1):
                        print(f"  {i}. {patch['name']} ({patch['size']}) - {patch['date']} - v{patch['version']}")
                    
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
                print("\n👋 ¡Hasta luego!")
                break
            
            else:
                print("❌ Opción inválida. Por favor, selecciona 1, 2 o 3.")
        
        except KeyboardInterrupt:
            print("\n\n⏹️  Instalación cancelada por el usuario")
            break
        except Exception as e:
            print(f"\n❌ Error inesperado: {e}")
    
    installer.cleanup()


# ========== PUNTO DE ENTRADA ACTUALIZADO ==========
def parse_arguments():
    """Parsea los argumentos de línea de comandos"""
    parser = argparse.ArgumentParser(
        description='Instalador de Atlas Interactivo',
        add_help=False  # Manejaremos --help manualmente
    )
    
    parser.add_argument('--help', '-h', action='store_true', 
                       help='Muestra esta ayuda')
    parser.add_argument('--version', '-v', action='store_true',
                       help='Muestra información de versión')
    parser.add_argument('--cli', action='store_true',
                       help='Modo consola interactivo')
    parser.add_argument('--check-updates', action='store_true',
                       help='Verifica actualizaciones disponibles')
    parser.add_argument('--install-dir',
                       help='Directorio de instalación personalizado')
    parser.add_argument('--skip-desktop', action='store_true',
                       help='No crear accesos directos en escritorio/menú')
    parser.add_argument('--no-gui', action='store_true',
                       help='Forzar modo consola')
    
    return parser.parse_args()

def main():
    """Función principal actualizada"""
    args = parse_arguments()
    installer = AtlasInstaller()
    
    # Manejar argumentos
    if args.help:
        installer.show_help()
        return
    
    if args.version:
        installer.show_version()
        return
    
    if args.check_updates:
        installer.check_updates_cli()
        return
    
    # Modo instalación CLI directa
    if args.install_dir or args.skip_desktop:
        installer.install_cli(
            install_dir=args.install_dir,
            skip_desktop=args.skip_desktop
        )
        return
    
    # Modo CLI interactivo
    if args.cli or args.no_gui or not HAS_GUI:
        run_cli()
        return
    
    # Modo GUI por defecto
    if HAS_GUI:
        root = tk.Tk()
        
        # Configurar tema más moderno si está disponible
        try:
            root.tk.call('source', '/usr/share/themes/Adwaita/gtk-3.0/gtk.css')
        except:
            pass
        
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