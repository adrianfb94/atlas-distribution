# Atlas_Distribution/dev/create_patches.py (COMPLETO)
#!/usr/bin/env python3
"""
SISTEMA DE CREACIÓN DE PARCHES PARA ATLAS
Uso: python create_patches.py [platform]
Platform: windows o linux
"""

import os
import json
import hashlib
import tarfile
import zipfile
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
import sys

class PatchSystem:
    def __init__(self, platform="linux"):
        self.platform = platform
        self.base_folder = f"Atlas_Interactivo-1.0.0-{platform}-x64"
        self.manifest_file = f".manifest_{platform}.json"
        self.patches_dir = f"drive_files/patches/{platform}"
        
        # Crear directorios
        Path(self.patches_dir).mkdir(parents=True, exist_ok=True)
        
    def get_file_hash(self, filepath):
        """Calcula hash MD5 de un archivo"""
        hash_md5 = hashlib.md5()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    
    def load_manifest(self):
        """Carga el manifest anterior"""
        if os.path.exists(self.manifest_file):
            with open(self.manifest_file, 'r') as f:
                return json.load(f)
        return {"files": {}, "version": "0.0.0"}
    
    def create_manifest(self):
        """Crea nuevo manifest de todos los archivos"""
        print(f"🔍 Escaneando {self.base_folder}...")
        manifest = {"version": "1.0.0", "files": {}}
        
        for root, dirs, files in os.walk(self.base_folder):
            for file in files:
                filepath = os.path.join(root, file)
                rel_path = os.path.relpath(filepath, self.base_folder)
                
                # Omitir archivos muy grandes o temporales
                if file.startswith('.') or os.path.getsize(filepath) > 100_000_000:
                    continue
                
                file_hash = self.get_file_hash(filepath)
                manifest["files"][rel_path] = {
                    "hash": file_hash,
                    "size": os.path.getsize(filepath),
                    "modified": os.path.getmtime(filepath)
                }
        
        return manifest
    
    def find_changes(self, old_manifest, new_manifest):
        """Encuentra archivos nuevos/modificados"""
        changes = {"new": [], "modified": [], "deleted": []}
        
        old_files = old_manifest.get("files", {})
        new_files = new_manifest["files"]
        
        # Buscar nuevos y modificados
        for path, info in new_files.items():
            if path not in old_files:
                changes["new"].append(path)
            elif info["hash"] != old_files[path]["hash"]:
                changes["modified"].append(path)
        
        # Buscar eliminados
        for path in old_files:
            if path not in new_files:
                changes["deleted"].append(path)
        
        return changes
    
    def create_patch(self, changes):
        """Crea archivo de parche con los cambios"""
        if not (changes["new"] or changes["modified"]):
            print("✅ No hay cambios para crear parche")
            return None
        
        # Nombre del parche con timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        patch_name = f"patch_{timestamp}"
        
        if self.platform == "linux":
            patch_file = f"{self.patches_dir}/{patch_name}.tar.gz"
            self._create_tar_patch(patch_file, changes)
        else:
            patch_file = f"{self.patches_dir}/{patch_name}.zip"
            self._create_zip_patch(patch_file, changes)
        
        # Calcular tamaño
        size_mb = os.path.getsize(patch_file) / (1024 * 1024)
        
        print(f"✅ Parche creado: {patch_file}")
        print(f"   📊 Archivos nuevos: {len(changes['new'])}")
        print(f"   📊 Archivos modificados: {len(changes['modified'])}")
        print(f"   📦 Tamaño: {size_mb:.2f} MB")
        
        return patch_file
    
    def _create_tar_patch(self, patch_file, changes):
        """Crea parche .tar.gz para Linux"""
        with tarfile.open(patch_file, "w:gz") as tar:
            # Agregar archivos nuevos/modificados
            for path in changes["new"] + changes["modified"]:
                full_path = os.path.join(self.base_folder, path)
                if os.path.exists(full_path):
                    tar.add(full_path, arcname=path)
                    print(f"  + {path}")
            
            # Agregar lista de eliminados
            if changes["deleted"]:
                deleted_file = "/tmp/deleted_files.txt"
                with open(deleted_file, 'w') as f:
                    f.write("\n".join(changes["deleted"]))
                tar.add(deleted_file, arcname=".deleted_files.txt")
                os.remove(deleted_file)
    
    def _create_zip_patch(self, patch_file, changes):
        """Crea parche .zip para Windows"""
        with zipfile.ZipFile(patch_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for path in changes["new"] + changes["modified"]:
                full_path = os.path.join(self.base_folder, path)
                if os.path.exists(full_path):
                    zipf.write(full_path, path)
                    print(f"  + {path}")
            
            if changes["deleted"]:
                deleted_content = "\n".join(changes["deleted"])
                zipf.writestr(".deleted_files.txt", deleted_content)
    
    def upload_to_drive(self, patch_file):
        """Sube parche a Google Drive (semi-automático)"""
        file_name = os.path.basename(patch_file)
        print(f"\n📤 Para subir a Drive:")
        print(f"1. Ve a: https://drive.google.com/drive/folders/TU_FOLDER_ID")
        print(f"2. Arrastra: {file_name}")
        print(f"3. Obtén el ID del archivo (de la URL)")
        print(f"4. Agrega el ID a docs/download.js")
        
        # Podrías automatizar esto con Google Drive API si quieres
        return file_name


def run(self):
    """Ejecuta el proceso completo de creación de parches"""
    print(f"\n{'='*60}")
    print(f"🔄 SISTEMA DE PARCHES - {self.platform.upper()}")
    print(f"{'='*60}")
    
    # 1. Cargar manifest anterior
    old_manifest = self.load_manifest()
    
    # 2. Crear nuevo manifest
    new_manifest = self.create_manifest()
    
    # 3. Encontrar cambios
    changes = self.find_changes(old_manifest, new_manifest)
    
    total_changes = len(changes["new"]) + len(changes["modified"])
    if total_changes == 0:
        print("✅ No hay cambios detectados")
        return None  # ← Cambiar 'return' a 'return None'
    
    print(f"📊 Cambios detectados: {total_changes} archivos")
    
    # 4. Crear parche
    patch_file = self.create_patch(changes)
    
    if patch_file:
        # 5. Subir a Drive
        self.upload_to_drive(patch_file)
        
        # 6. Actualizar manifest
        with open(self.manifest_file, 'w') as f:
            json.dump(new_manifest, f, indent=2)
        
        print(f"\n✅ Manifest actualizado: {self.manifest_file}")
    
    print(f"{'='*60}")
    
    return patch_file  # ← Esto está bien, patch_file será None si no se creó

# ========== PARTE NUEVA: SCRIPT DE CONSTRUCCIÓN COMPLETO ==========
def build_installers():
    """Script para construir los instaladores"""
    print("🔨 CONSTRUYENDO INSTALADORES")
    print("=" * 50)
    
    # 1. Windows (C#)
    print("\n🪟 Compilando instalador Windows...")
    
    cs_source = "AtlasInstaller.cs"
    if os.path.exists(cs_source):
        try:
            # Verificar si existe el compilador de C#
            if shutil.which("csc"):
                print("  Compilando AtlasInstaller.cs con csc...")
                subprocess.run([
                    "csc", "/out:../AtlasInstaller.exe", 
                    "/target:winexe",
                    "/reference:System.Windows.Forms.dll",
                    "/reference:System.Drawing.dll",
                    "/reference:System.Net.Http.dll",
                    "/platform:anycpu",
                    "/optimize",
                    cs_source
                ], check=True)
                print("  ✅ AtlasInstaller.exe creado en directorio principal")
            else:
                print("  ⚠️  csc (C# Compiler) no encontrado.")
                print("  Alternativas:")
                print("  1. Usa Visual Studio: Abre AtlasInstaller.cs y compila")
                print("  2. Instala .NET SDK: dotnet build")
                print("  3. Usa Mono: mcs -target:winexe -out:AtlasInstaller.exe AtlasInstaller.cs")
                
        except subprocess.CalledProcessError as e:
            print(f"  ❌ Error compilando C#: {e}")
    else:
        print(f"  ❌ No se encuentra: {cs_source}")
    
    # 2. Linux (Python + PyInstaller)
    print("\n🐧 Creando AppImage para Linux...")
    
    py_source = "AtlasInstaller.py"
    if os.path.exists(py_source):
        try:
            if shutil.which("pyinstaller"):
                print("  Creando ejecutable con PyInstaller...")
                
                # Primero creamos el ejecutable
                subprocess.run([
                    "pyinstaller", "--onefile", 
                    "--name", "AtlasInstaller",
                    "--add-data", "icon.png:.",
                    "--hidden-import", "requests",
                    "--hidden-import", "tkinter",
                    "--clean",
                    py_source
                ], check=True)
                
                print("  ✅ AtlasInstaller (binario) creado en dist/")
                
                # Crear AppImage (si está appimagetool)
                if shutil.which("appimagetool"):
                    print("  Creando AppImage...")
                    
                    # Crear estructura AppDir
                    appdir = "AtlasInstaller.AppDir"
                    shutil.rmtree(appdir, ignore_errors=True)
                    os.makedirs(f"{appdir}/usr/bin", exist_ok=True)
                    
                    # Copiar ejecutable
                    shutil.copy("dist/AtlasInstaller", f"{appdir}/usr/bin/")
                    
                    # Crear .desktop file
                    desktop_content = """[Desktop Entry]
Name=Atlas Installer
Comment=Instalador de Atlas Interactivo
Exec=AtlasInstaller
Icon=atlas
Terminal=false
Type=Application
Categories=Game;
"""
                    with open(f"{appdir}/atlas.desktop", "w") as f:
                        f.write(desktop_content)
                    
                    # Crear icono
                    icon_content = """<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" xmlns="http://www.w3.org/2000/svg">
<rect width="64" height="64" fill="#2563eb"/>
<text x="32" y="32" font-family="Arial" font-size="24" 
fill="white" text-anchor="middle" dy=".3em">A</text>
</svg>"""
                    with open(f"{appdir}/atlas.svg", "w") as f:
                        f.write(icon_content)
                    
                    # Crear AppRun
                    apprun_content = """#!/bin/bash
cd "$(dirname "$0")"
exec ./usr/bin/AtlasInstaller "$@"
"""
                    with open(f"{appdir}/AppRun", "w") as f:
                        f.write(apprun_content)
                    os.chmod(f"{appdir}/AppRun", 0o755)
                    
                    # Crear AppImage
                    subprocess.run([
                        "appimagetool", appdir, "../AtlasInstaller.AppImage"
                    ], check=True)
                    
                    print("  ✅ AtlasInstaller.AppImage creado")
                    shutil.rmtree(appdir, ignore_errors=True)
                else:
                    print("  ⚠️  appimagetool no encontrado.")
                    print("  Instala: wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage")
                    print("  chmod +x appimagetool-x86_64.AppImage")
                    print("  sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool")
                    
            else:
                print("  ⚠️  PyInstaller no encontrado.")
                print("  Instala: pip install pyinstaller")
                
        except subprocess.CalledProcessError as e:
            print(f"  ❌ Error con PyInstaller: {e}")
    else:
        print(f"  ❌ No se encuentra: {py_source}")
    
    print("\n" + "=" * 50)
    print("📁 ARCHIVOS GENERADOS:")
    print("  Windows: AtlasInstaller.exe (si se pudo compilar)")
    print("  Linux: AtlasInstaller.AppImage (si appimagetool disponible)")
    print("  Linux (alternativo): dist/AtlasInstaller (ejecutable binario)")
    print("\n💡 Sube estos archivos a Google Drive junto con los .zip/.tar.gz")
    print("=" * 50)

# ========== PARTE NUEVA: APLICADOR DE PARCHES (PARA USUARIOS) ==========
class PatchApplier:
    """Sistema para aplicar parches (incluido en los instaladores)"""
    
    @staticmethod
    def apply_patch(patch_file, target_dir, platform):
        """Aplica un parche al directorio de instalación"""
        print(f"\n🔧 Aplicando parche: {os.path.basename(patch_file)}")
        
        # Extraer parche a temporal
        temp_dir = "temp_patch_extract"
        shutil.rmtree(temp_dir, ignore_errors=True)
        os.makedirs(temp_dir, exist_ok=True)
        
        try:
            # Extraer según plataforma
            if platform == "linux" and patch_file.endswith(".tar.gz"):
                with tarfile.open(patch_file, "r:gz") as tar:
                    tar.extractall(temp_dir)
            elif platform == "windows" and patch_file.endswith(".zip"):
                with zipfile.ZipFile(patch_file, 'r') as zipf:
                    zipf.extractall(temp_dir)
            else:
                print(f"❌ Formato de parche no soportado: {patch_file}")
                return False
            
            # Leer metadatos
            metadata_file = os.path.join(temp_dir, ".patch_metadata.json")
            if os.path.exists(metadata_file):
                with open(metadata_file, 'r') as f:
                    metadata = json.load(f)
                print(f"  Parche: {metadata.get('patch_name', 'N/A')}")
                print(f"  Cambios: +{metadata['changes']['new']} ✏️{metadata['changes']['modified']} -{metadata['changes']['deleted']}")
            
            # Aplicar cambios (copiar archivos)
            patch_content_dir = os.path.join(temp_dir, os.listdir(temp_dir)[0] 
                                           if os.listdir(temp_dir) else "")
            
            if os.path.exists(patch_content_dir):
                # Copiar todos los archivos
                for root, dirs, files in os.walk(patch_content_dir):
                    for file in files:
                        if file.startswith('.'):  # Omitir archivos ocultos/metadata
                            continue
                        
                        src_path = os.path.join(root, file)
                        rel_path = os.path.relpath(src_path, patch_content_dir)
                        dst_path = os.path.join(target_dir, rel_path)
                        
                        # Crear directorio si no existe
                        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
                        shutil.copy2(src_path, dst_path)
                        
                print(f"  ✅ Archivos copiados: {sum(len(files) for _, _, files in os.walk(patch_content_dir))}")
            
            # Procesar eliminados
            deleted_file = os.path.join(temp_dir, ".deleted_files.txt")
            if os.path.exists(deleted_file):
                with open(deleted_file, 'r') as f:
                    deleted_files = [line.strip() for line in f if line.strip()]
                
                for rel_path in deleted_files:
                    file_to_delete = os.path.join(target_dir, rel_path)
                    if os.path.exists(file_to_delete):
                        os.remove(file_to_delete)
                        print(f"  🗑️  Eliminado: {rel_path}")
            
            # Actualizar versión
            version_file = os.path.join(target_dir, ".version.json")
            version_data = {"last_updated": datetime.now().isoformat()}
            if os.path.exists(metadata_file):
                with open(metadata_file, 'r') as f:
                    metadata = json.load(f)
                version_data["version"] = metadata.get("version_to", "1.0.0")
            
            with open(version_file, 'w') as f:
                json.dump(version_data, f, indent=2)
            
            print(f"✅ Parche aplicado exitosamente")
            return True
            
        except Exception as e:
            print(f"❌ Error aplicando parche: {e}")
            import traceback
            traceback.print_exc()
            return False
            
        finally:
            # Limpiar
            shutil.rmtree(temp_dir, ignore_errors=True)

# ========== MAIN ==========
if __name__ == "__main__":
    # Determinar qué hacer basado en argumentos
    if len(sys.argv) > 1:
        if sys.argv[1] == "build":
            build_installers()
        elif sys.argv[1] in ["windows", "linux"]:
            patch_system = PatchSystem(platform=sys.argv[1])
            patch_system.run()
        else:
            print("Uso:")
            print("  Para crear parches: python create_patches.py [windows|linux]")
            print("  Para construir instaladores: python create_patches.py build")
    else:
        print("📁 SISTEMA DE PARCHES Y CONSTRUCCIÓN")
        print("=" * 40)
        print("Opciones:")
        print("  1. Crear parche para Windows: python create_patches.py windows")
        print("  2. Crear parche para Linux: python create_patches.py linux")
        print("  3. Construir instaladores: python create_patches.py build")
        print("\nPrimero crea los parches, luego construye los instaladores.")