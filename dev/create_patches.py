# Atlas_Distribution/dev/create_patches.py (MODIFICADO - SOLO WINDOWS C# Y LINUX QT)
#!/usr/bin/env python3
"""
SISTEMA DE CREACIÓN DE PARCHES Y CONSTRUCCIÓN DE INSTALADORES
Uso: python create_patches.py [platform|build]
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

# ========== NUEVA FUNCIÓN: CONSTRUIR INSTALADOR LINUX QT ==========

def build_linux_qt():
    """Construye el instalador Linux Qt usando el script bash"""
    print("\n🐧 Construyendo instalador Linux Qt...")
    
    # Verificar que exista el script de construcción Qt
    qt_script = "build_qt_linux1.sh"
    if not os.path.exists(qt_script):
        print(f"  ❌ No se encuentra: {qt_script}")
        print(f"  💡 Crea primero el script de construcción Qt")
        return False
    
    try:
        # Dar permisos de ejecución
        os.chmod(qt_script, 0o755)
        
        # Ejecutar el script de construcción Qt
        print(f"  🛠️  Ejecutando {qt_script}...")
        result = subprocess.run(
            [f"./{qt_script}"],
            capture_output=True,
            text=True,
            shell=True
        )
        
        if result.returncode == 0:
            print("  ✅ Instalador Qt construido exitosamente")
            print("output:\n", result.stdout)
            os.system('rm build_qt_linux1.sh')
            print('build_qt_linux1.sh eliminado')
            print()
            
            # Verificar si se creó el archivo
            if os.path.exists("../AtlasInstallerQt"):
                size_bytes = os.path.getsize("../AtlasInstallerQt")
                size_mb = size_bytes / (1024 * 1024)
                print(f"  📦 Archivo: ../AtlasInstallerQt ({size_mb:.2f} MB)")
                return True
            else:
                print("  ⚠️  No se encontró ../AtlasInstallerQt")
                return False
        else:
            print(f"  ❌ Error construyendo instalador Qt:")
            if result.stdout:
                print(f"  Salida: {result.stdout[:200]}")
            if result.stderr:
                print(f"  Error: {result.stderr[:200]}")
            return False
                
    except Exception as e:
        print(f"  ❌ Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        return False

# ========== FUNCIÓN PRINCIPAL DE CONSTRUCCIÓN (WINDOWS C# + LINUX QT) ==========

def build_installers(compiler='mono'):
    """Construye ambos instaladores: Windows C# y Linux Qt"""
    print("🔨 CONSTRUYENDO INSTALADORES (Windows C# + Linux Qt)")
    print("=" * 50)
    
    # 1. Windows (C#)
    print("\n🪟 Construyendo instalador Windows C#...")
    
    cs_source = "AtlasInstaller1.cs"
    if os.path.exists(cs_source):
        try:
            # Usar Mono si está disponible
            if shutil.which("mcs") and compiler == 'mono':
                print("  Compilando con Mono (mcs)...")
                subprocess.run([
                    "mcs", "-target:winexe",
                    "-out:../AtlasInstaller.exe",
                    "-r:System.Windows.Forms",
                    "-r:System.Drawing",
                    "-r:System.Net.Http",
                    "-r:System.IO.Compression",
                    "-r:System.IO.Compression.FileSystem",
                    "-optimize",
                    cs_source
                ], check=True)
                print("  ✅ AtlasInstaller.exe creado")
                
            elif shutil.which("dotnet") and compiler == 'dotnet':
                print("  Compilando con .NET SDK en Linux...")
                
                # Crear directorio temporal para .NET
                temp_dir = "temp_dotnet_build"
                if os.path.exists(temp_dir):
                    shutil.rmtree(temp_dir)
                os.makedirs(temp_dir)
                
                # Crear archivo .csproj para Linux
                csproj_content = '''<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <UseWindowsForms>true</UseWindowsForms>
    <Nullable>enable</Nullable>
    <PublishSingleFile>true</PublishSingleFile>
    <SelfContained>false</SelfContained>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
    <EnableWindowsFormsLoading>true</EnableWindowsFormsLoading>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="System.IO.Compression.ZipFile" Version="4.3.0" />
    <PackageReference Include="Microsoft.Windows.Compatibility" Version="8.0.0" />
  </ItemGroup>
</Project>'''
                
                with open(os.path.join(temp_dir, "AtlasInstaller.csproj"), "w") as f:
                    f.write(csproj_content)
                
                # Copiar y adaptar archivo fuente
                with open(cs_source, 'r') as src_file:
                    cs_content = src_file.read()
                
                if 'static class Program' in cs_content and '[STAThread]' in cs_content:
                    program_content = cs_content
                else:
                    program_content = f'''using System;
using System.IO;
using System.Net;
using System.Windows.Forms;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.IO.Compression;

namespace AtlasInstaller
{{
    static class Program
    {{
        [STAThread]
        static void Main()
        {{
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            if (Environment.OSVersion.Platform == PlatformID.Win32NT)
            {{
                try
                {{
                    SetProcessDPIAware();
                }}
                catch {{ }}
            }}
            
            Application.Run(new MainForm());
        }}
        
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();
    }}
    
    {cs_content[cs_content.find('public partial class MainForm'):]}
}}'''
                
                with open(os.path.join(temp_dir, "Program.cs"), "w") as f:
                    f.write(program_content)
                
                # Restaurar y compilar
                print("  📦 Restaurando paquetes...")
                restore_result = subprocess.run(
                    ["dotnet", "restore"],
                    cwd=temp_dir,
                    capture_output=True,
                    text=True
                )
                
                if restore_result.returncode != 0:
                    print(f"  ⚠️  Advertencia en restore: {restore_result.stderr[:200]}")
                
                # Compilar
                print("  🔧 Ejecutando dotnet publish...")
                publish_result = subprocess.run(
                    ["dotnet", "publish", 
                     "-c", "Release", 
                     "--self-contained", "false",
                     "-o", "publish",
                     "-r", "win-x64",
                     "--verbosity", "quiet"],
                    cwd=temp_dir,
                    capture_output=True,
                    text=True
                )
                
                if publish_result.returncode == 0:
                    publish_dir = os.path.join(temp_dir, "publish")
                    if os.path.exists(publish_dir):
                        exe_files = [f for f in os.listdir(publish_dir) if f.endswith('.exe')]
                        if exe_files:
                            exe_path = os.path.join(publish_dir, exe_files[0])
                            shutil.copy(exe_path, "../AtlasInstaller_dotnet.exe")
                            
                            size_mb = os.path.getsize("../AtlasInstaller_dotnet.exe") / (1024 * 1024)
                            print(f"  ✅ AtlasInstaller_dotnet.exe creado ({size_mb:.1f} MB)")
                            
                            if os.path.exists("../AtlasInstaller.exe"):
                                os.remove("../AtlasInstaller.exe")
                            shutil.copy("../AtlasInstaller_dotnet.exe", "../AtlasInstaller.exe")
                            print(f"  🔗 También copiado como AtlasInstaller.exe")
                
                # Limpiar
                shutil.rmtree(temp_dir, ignore_errors=True)
                
            else:
                print("  ⚠️  No se encontró compilador de C# solicitado")
                print(f"  Buscando: {compiler}")
                
        except subprocess.CalledProcessError as e:
            print(f"  ❌ Error de compilación: {e}")
        except Exception as e:
            print(f"  ❌ Error inesperado: {e}")
    else:
        print(f"  ❌ No se encuentra: {cs_source}")
    
    # 2. Linux (Qt) - REEMPLAZA PYINSTALLER POR QT
    build_linux_qt()
    
    # 3. Mostrar resumen
    print("\n" + "=" * 50)
    print("📁 ARCHIVOS GENERADOS:")
    
    # Windows C#
    if os.path.exists("../AtlasInstaller.exe"):
        try:
            size_bytes = os.path.getsize("../AtlasInstaller.exe")
            size_mb = size_bytes / (1024 * 1024)
            print(f"  ✅ Windows: AtlasInstaller.exe ({size_mb:.2f} MB) - C# GUI")
        except:
            print(f"  ✅ Windows: AtlasInstaller.exe - C# GUI")
    else:
        print("  ❌ Windows: No se pudo compilar AtlasInstaller.exe")
    
    # Linux Qt
    if os.path.exists("../AtlasInstallerQt"):
        try:
            size_bytes = os.path.getsize("../AtlasInstallerQt")
            size_mb = size_bytes / (1024 * 1024)
            print(f"  ✅ Linux: AtlasInstallerQt ({size_mb:.2f} MB) - Qt GUI")
        except:
            print(f"  ✅ Linux: AtlasInstallerQt - Qt GUI")
    else:
        print("  ❌ Linux: No se pudo compilar AtlasInstallerQt")
    
    print("\n💡 INSTRUCCIONES:")
    print("  1. Windows: Usa AtlasInstaller.exe (requiere .NET Runtime)")
    print("  2. Linux: Usa AtlasInstallerQt (requiere Qt5 libraries)")
    print("  3. Sube ambos a Google Drive/GitHub")
    print("  4. Actualiza los IDs en docs/download.js")
    print("=" * 50)

# ========== APLICADOR DE PARCHES (MANTENIDO) ==========
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
            
            # Aplicar cambios
            patch_content_dir = os.path.join(temp_dir, os.listdir(temp_dir)[0] 
                                           if os.listdir(temp_dir) else "")
            
            if os.path.exists(patch_content_dir):
                for root, dirs, files in os.walk(patch_content_dir):
                    for file in files:
                        if file.startswith('.'):
                            continue
                        
                        src_path = os.path.join(root, file)
                        rel_path = os.path.relpath(src_path, patch_content_dir)
                        dst_path = os.path.join(target_dir, rel_path)
                        
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
            
            with open(version_file, 'w') as f:
                json.dump(version_data, f, indent=2)
            
            print(f"✅ Parche aplicado exitosamente")
            return True
            
        except Exception as e:
            print(f"❌ Error aplicando parche: {e}")
            return False
            
        finally:
            # Limpiar
            shutil.rmtree(temp_dir, ignore_errors=True)

# ========== MAIN ==========
if __name__ == "__main__":
    # Determinar qué hacer basado en argumentos
    if len(sys.argv) > 1:
        if sys.argv[1] == "build":
            build_installers(compiler='mono')
        elif sys.argv[1] == "build-dotnet":
            build_installers(compiler='dotnet')
        elif sys.argv[1] == "build-mono":
            build_installers(compiler='mono')
        elif sys.argv[1] in ["windows", "linux"]:
            patch_system = PatchSystem(platform=sys.argv[1])
            patch_system.run()
        else:
            print("Uso:")
            print("  Para crear parches: python create_patches.py [windows|linux]")
            print("  Para construir instaladores: python create_patches.py build")
            print("  Para .NET SDK: python create_patches.py build-dotnet")
            print("  Para Mono: python create_patches.py build-mono")
    else:
        print("📁 SISTEMA DE PARCHES Y CONSTRUCCIÓN")
        print("=" * 40)
        print("Opciones:")
        print("  1. Crear parche para Windows: python create_patches.py windows")
        print("  2. Crear parche para Linux: python create_patches.py linux")
        print("  3. Construir ambos instaladores: python create_patches.py build")
        print("  4. Construir con .NET SDK: python create_patches.py build-dotnet")
        print("  5. Construir con Mono: python create_patches.py build-mono")
        print("\nNota: Ahora solo construye:")
        print("  - Windows: AtlasInstaller.exe (C# GUI)")
        print("  - Linux: AtlasInstallerQt (Qt GUI)")
        print("\nPrimero crea los parches, luego construye los instaladores.")





# convert -size 64x64 xc:#2563eb -fill white -pointsize 24   -gravity center -draw "text 0,0 'Atlas'" icon.png