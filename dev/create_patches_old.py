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

def ensure_icon_exists():
    """Asegura que exista un icono válido (icon.png o atlas.png)"""
    if os.path.exists("icon.png"):
        print("  ✅ Icono encontrado: icon.png")
        return True
    elif os.path.exists("atlas.png"):
        print("  ✅ Icono encontrado: atlas.png")
        # Crear icon.png a partir de atlas.png si no existe
        if not os.path.exists("icon.png"):
            try:
                shutil.copy("atlas.png", "icon.png")
                print("  📋 Copiado atlas.png a icon.png para PyInstaller")
                return True
            except:
                return False
        return True
    else:
        print("  ⚠️  No se encontró icon.png ni atlas.png")
        print("  💡 Crea un icono de 64x64 llamado icon.png o atlas.png")
        print("     Puedes usar: convert -size 64x64 xc:#2563eb -fill white")
        print("     -pointsize 24 -gravity center -draw \"text 0,0 'A'\" icon.png")
        return False

def build_installers(compiler='mono'):
    """Script para construir los instaladores"""
    print("🔨 CONSTRUYENDO INSTALADORES")
    print("=" * 50)
    
    # 1. Windows (C#)
    print("\n🪟 Compilando instalador Windows...")
    
    cs_source = "AtlasInstaller.cs"
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
                
                # 1. Crear archivo .csproj ESPECIAL para Linux
                # Para compilar Windows Forms en Linux necesitamos EnableWindowsTargeting
                csproj_content = '''<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <UseWindowsForms>true</UseWindowsForms>
    <Nullable>enable</Nullable>
    <PublishSingleFile>true</PublishSingleFile>
    <SelfContained>false</SelfContained>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <!-- ESTA ES LA CLAVE PARA LINUX -->
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
    <!-- También desactivar validaciones específicas de Windows -->
    <EnableWindowsFormsLoading>true</EnableWindowsFormsLoading>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="System.IO.Compression.ZipFile" Version="4.3.0" />
    <PackageReference Include="Microsoft.Windows.Compatibility" Version="8.0.0" />
  </ItemGroup>
</Project>'''
                
                with open(os.path.join(temp_dir, "AtlasInstaller.csproj"), "w") as f:
                    f.write(csproj_content)
                
                # 2. Copiar archivo fuente
                with open(cs_source, 'r') as src_file:
                    cs_content = src_file.read()
                
                # Asegurarnos de que el archivo tenga la estructura correcta para .NET
                # En .NET SDK, el archivo debe tener el namespace completo
                if 'static class Program' in cs_content and '[STAThread]' in cs_content:
                    # Ya tiene la estructura correcta
                    program_content = cs_content
                else:
                    # Necesitamos agregar la clase Program
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
            
            // Configurar alta compatibilidad DPI solo en Windows
            if (Environment.OSVersion.Platform == PlatformID.Win32NT)
            {{
                try
                {{
                    SetProcessDPIAware();
                }}
                catch {{ /* Ignorar si falla */ }}
            }}
            
            Application.Run(new MainForm());
        }}
        
        // Solo incluir en Windows
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();
    }}
    
    {cs_content[cs_content.find('public partial class MainForm'):]}
}}'''
                
                with open(os.path.join(temp_dir, "Program.cs"), "w") as f:
                    f.write(program_content)
                
                # 3. Restaurar paquetes primero
                print("  📦 Restaurando paquetes...")
                restore_result = subprocess.run(
                    ["dotnet", "restore"],
                    cwd=temp_dir,
                    capture_output=True,
                    text=True
                )
                
                if restore_result.returncode != 0:
                    print(f"  ⚠️  Advertencia en restore: {restore_result.stderr[:200]}")
                
                # 4. Compilar con opciones específicas para Linux
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
                    # 5. Buscar y mover ejecutable
                    publish_dir = os.path.join(temp_dir, "publish")
                    if os.path.exists(publish_dir):
                        exe_files = [f for f in os.listdir(publish_dir) if f.endswith('.exe')]
                        if exe_files:
                            exe_path = os.path.join(publish_dir, exe_files[0])
                            shutil.copy(exe_path, "../AtlasInstaller_dotnet.exe")
                            
                            size_mb = os.path.getsize("../AtlasInstaller_dotnet.exe") / (1024 * 1024)
                            print(f"  ✅ AtlasInstaller_dotnet.exe creado ({size_mb:.1f} MB)")
                            
                            # También crear enlace simbólico
                            if os.path.exists("../AtlasInstaller.exe"):
                                os.remove("../AtlasInstaller.exe")
                            shutil.copy("../AtlasInstaller_dotnet.exe", "../AtlasInstaller.exe")
                            print(f"  🔗 También copiado como AtlasInstaller.exe")
                        else:
                            print("  ⚠️  No se encontró archivo .exe en publish/")
                    else:
                        print("  ⚠️  No se creó directorio publish/")
                else:
                    print(f"  ❌ Error en dotnet publish: {publish_result.stderr[:300]}")
                    
                    # Intentar con build normal como fallback
                    print("  🔄 Intentando con dotnet build...")
                    build_result = subprocess.run(
                        ["dotnet", "build", "-c", "Release", "--verbosity", "quiet"],
                        cwd=temp_dir,
                        capture_output=True,
                        text=True
                    )
                    
                    if build_result.returncode == 0:
                        # Buscar en bin/Release
                        release_dir = os.path.join(temp_dir, "bin", "Release", "net8.0-windows", "win-x64")
                        if os.path.exists(release_dir):
                            exe_files = [f for f in os.listdir(release_dir) if f.endswith('.exe')]
                            if exe_files:
                                exe_path = os.path.join(release_dir, exe_files[0])
                                shutil.copy(exe_path, "../AtlasInstaller_dotnet.exe")
                                size_mb = os.path.getsize("../AtlasInstaller_dotnet.exe") / (1024 * 1024)
                                print(f"  ✅ AtlasInstaller_dotnet.exe creado con build ({size_mb:.1f} MB)")
                                shutil.copy("../AtlasInstaller_dotnet.exe", "../AtlasInstaller.exe")
                
                # 6. Limpiar
                shutil.rmtree(temp_dir, ignore_errors=True)
                
            else:
                print("  ⚠️  No se encontró compilador de C# solicitado")
                print(f"  Buscando: {compiler}")
                
                if compiler == 'dotnet' and not shutil.which("dotnet"):
                    print("  💡 Instala .NET SDK: sudo apt install dotnet-sdk-8.0")
                elif compiler == 'mono' and not shutil.which("mcs"):
                    print("  💡 Instala Mono: sudo apt install mono-devel mono-complete")
                
        except subprocess.CalledProcessError as e:
            print(f"  ❌ Error de compilación: {e}")
            if hasattr(e, 'stdout') and e.stdout:
                print(f"  Salida: {e.stdout[:200]}")
            if hasattr(e, 'stderr') and e.stderr:
                print(f"  Error: {e.stderr[:200]}")
        except Exception as e:
            print(f"  ❌ Error inesperado: {e}")
            import traceback
            traceback.print_exc()
    else:
        print(f"  ❌ No se encuentra: {cs_source}")
    

    # 2. Linux (Python + PyInstaller)
    print("\n🐧 Creando AppImage para Linux...")

    py_source = "AtlasInstaller.py"
    if os.path.exists(py_source):
        # Asegurar que exista un icono
        if not ensure_icon_exists():
            print("  ⚠️  Continuando sin icono...")

        try:
            if shutil.which("pyinstaller"):

                # print("  Creando ejecutable con PyInstaller...")
                
                # # Primero creamos el ejecutable
                # subprocess.run([
                #     "pyinstaller", "--onefile", 
                #     "--name", "AtlasInstaller",
                #     "--add-data", "icon.png:.",
                #     "--hidden-import", "requests",
                #     "--hidden-import", "tkinter",
                #     "--clean",
                #     py_source
                # ], check=True)
                

                print("  Creando ejecutable optimizado con PyInstaller...")

                # OPCIONES OPTIMIZADAS:
                pyinstaller_cmd = [
                    "pyinstaller", "--onefile", 
                    "--name", "AtlasInstaller",
                    "--add-data", "icon.png:.",
                    "--hidden-import", "requests",
                    "--hidden-import", "tkinter",
                    "--exclude-module", "numpy",          # Excluir módulos pesados
                    "--exclude-module", "pandas",
                    "--exclude-module", "matplotlib",
                    "--exclude-module", "scipy",
                    "--clean",
                    "--noupx",                            # Deshabilitar UPX si causa problemas
                    "--strip",                            # Strippear símbolos
                    "--optimize", "2",                    # Máxima optimización
                    py_source
                ]

                # Si tienes UPX instalado, mantenlo habilitado
                if shutil.which("upx"):
                    pyinstaller_cmd.extend(["--upx-exclude", "vcruntime140.dll"])
                else:
                    print("  💡 Instala UPX para compresión adicional: sudo apt install upx")

                subprocess.run(pyinstaller_cmd, check=True)

                print("  ✅ AtlasInstaller (binario) creado en dist/")
                
                # Crear AppImage (si está appimagetool)
                if shutil.which("appimagetool"):
                    print("  Creando AppImage...")
                    
                    # Crear estructura AppDir
                    appdir = "AtlasInstaller.AppDir"
                    shutil.rmtree(appdir, ignore_errors=True)
                    os.makedirs(f"{appdir}/usr/bin", exist_ok=True)

                    # ========== PASO 1: COPIAR EJECUTABLE ==========
                    shutil.copy("dist/AtlasInstaller", f"{appdir}/usr/bin/AtlasInstaller")
                    os.chmod(f"{appdir}/usr/bin/AtlasInstaller", 0o755)
                    print("  ✅ Ejecutable copiado")

                    # ========== PASO 2: CREAR ARCHIVOS NECESARIOS ==========
                    print("  📁 Creando archivos del AppDir...")
                    
                    # 1. Archivo .desktop (CRÍTICO)
                    desktop_content = """[Desktop Entry]
Name=Atlas Installer
Comment=Instalador de Atlas Interactivo
Exec=AtlasInstaller
Icon=atlas
Terminal=false
Type=Application
Categories=Game;
X-AppImage-Name=Atlas Installer
"""
                    with open(f"{appdir}/atlas.desktop", "w") as f:
                        f.write(desktop_content)
                    print("  ✅ Archivo .desktop creado")
                    
                    # 2. AppRun (CRÍTICO)
                    apprun_content = """#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="$HERE/usr/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
cd "$HERE"
exec "$HERE/usr/bin/AtlasInstaller" "$@"
"""
                    with open(f"{appdir}/AppRun", "w") as f:
                        f.write(apprun_content)
                    os.chmod(f"{appdir}/AppRun", 0o755)
                    print("  ✅ AppRun creado")
                    
                    # ========== PASO 3: MANEJAR ICONOS ==========
                    # Copiar icono como atlas.png (CRÍTICO)
                    if os.path.exists("icon.png"):
                        shutil.copy("icon.png", f"{appdir}/atlas.png")
                        print("  ✅ Icono copiado como atlas.png")
                    elif os.path.exists("atlas.png"):
                        shutil.copy("atlas.png", f"{appdir}/atlas.png")
                        print("  ✅ Icono atlas.png copiado")
                    else:
                        # Crear icono SVG simple
                        print("  🎨 Creando icono SVG...")
                        icon_svg = """<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" xmlns="http://www.w3.org/2000/svg">
<rect width="64" height="64" fill="#2563eb"/>
<text x="32" y="40" font-family="Arial" font-size="32" 
fill="white" text-anchor="middle" font-weight="bold">A</text>
</svg>"""
                        with open(f"{appdir}/atlas.svg", "w") as f:
                            f.write(icon_svg)
                        print("  ✅ Icono SVG creado")
                    
                    # Crear .DirIcon (opcional pero recomendado)
                    if os.path.exists(f"{appdir}/atlas.png"):
                        shutil.copy(f"{appdir}/atlas.png", f"{appdir}/.DirIcon")
                        print("  ✅ .DirIcon creado desde atlas.png")
                    elif os.path.exists(f"{appdir}/atlas.svg"):
                        # Intentar convertir SVG a PNG para .DirIcon
                        try:
                            subprocess.run([
                                "convert", "-size", "64x64", f"{appdir}/atlas.svg",
                                f"{appdir}/.DirIcon"
                            ], check=False, capture_output=True)
                            print("  ✅ .DirIcon creado desde atlas.svg")
                        except:
                            pass
                    
                    # ========== PASO 4: VERIFICAR CONTENIDO ANTES DE CREAR ==========
                    print("  🔍 Verificando contenido del AppDir:")
                    required_files = [
                        "atlas.desktop",
                        "AppRun", 
                        "usr/bin/AtlasInstaller"
                    ]
                    
                    missing_files = []
                    for req_file in required_files:
                        req_path = os.path.join(appdir, req_file)
                        if os.path.exists(req_path):
                            print(f"    ✅ {req_file}")
                        else:
                            print(f"    ❌ FALTA: {req_file}")
                            missing_files.append(req_file)
                    
                    if missing_files:
                        print(f"  ❌ Faltan archivos críticos: {', '.join(missing_files)}")
                        print("  💡 Verifica que se estén creando correctamente")
                        # Intentar crear los que faltan
                        for missing in missing_files:
                            if missing == "atlas.desktop":
                                with open(os.path.join(appdir, "atlas.desktop"), "w") as f:
                                    f.write(desktop_content)
                                print(f"    🔧 Creado: {missing}")
                            elif missing == "AppRun":
                                with open(os.path.join(appdir, "AppRun"), "w") as f:
                                    f.write(apprun_content)
                                os.chmod(os.path.join(appdir, "AppRun"), 0o755)
                                print(f"    🔧 Creado: {missing}")
                                            

                    # ========== PASO 5: CREAR APPIMAGE ==========
                    print("  🔧 Creando AppImage con appimagetool...")
                    try:
                        # Primero verificar que appimagetool existe
                        appimagetool_path = shutil.which("appimagetool")
                        if not appimagetool_path:
                            raise FileNotFoundError("appimagetool no encontrado")
                        
                        print(f"  📍 Usando appimagetool en: {appimagetool_path}")
                        
                        # Crear AppImage con opciones explícitas
                        result = subprocess.run([
                            "appimagetool", 
                            "--no-appstream",       # Evitar advertencia de metadata
                            # "--comp", "gzip",       # Especificar compresión gzip
                            "--comp", "xz",       # xz comprime mejor que gzip
                            "--verbose",            # Mostrar detalles
                            appdir, 
                            "../AtlasInstaller.AppImage"
                        ], capture_output=True, text=True, check=True)
                        
                        print(f"  📝 Salida de appimagetool:")
                        for line in result.stdout.split('\n')[:10]:
                            if line.strip():
                                print(f"    {line}")
                        
                        if result.stderr:
                            print(f"  ⚠️  Advertencias:")
                            for line in result.stderr.split('\n')[:5]:
                                if line.strip():
                                    print(f"    {line}")

                        if os.path.exists("../AtlasInstaller.AppImage"):
                            size_bytes = os.path.getsize("../AtlasInstaller.AppImage")
                            size_mb = size_bytes / (1024 * 1024)
                            print(f"  ✅ AppImage creado ({size_mb:.2f} MB)")
                                                        

                        # ========== PASO 6: VERIFICAR APPIMAGE CREADO (VERSIÓN CORREGIDA) ==========
                        print("  🔍 Verificando AppImage creado...")
                        appimage_path = "../AtlasInstaller.AppImage"

                        if os.path.exists(appimage_path):
                            # 1. Verificación básica
                            size_mb = os.path.getsize(appimage_path) / (1024 * 1024)
                            print(f"    ✅ AppImage creado: {size_mb:.2f} MB")
                            
                            # 2. Verificar magic AppImage Type 2
                            try:
                                with open(appimage_path, 'rb') as f:
                                    f.seek(8)
                                    magic = f.read(3)
                                    if magic == b'AI\x02':
                                        print("    ✅ Magic AppImage Type 2 válido")
                                    else:
                                        print(f"    ⚠️  Magic no reconocido: {magic}")
                            except Exception as e:
                                print(f"    ⚠️  No se pudo leer magic: {e}")
                            
                            # 3. Verificación simple (sin extracción problemática)
                            print("    🔍 Verificación rápida del contenido...")
                            
                            # Crear ruta ABSOLUTA para evitar problemas
                            abs_appimage_path = os.path.abspath(appimage_path)
                            
                            # Método 1: Usar file para verificar tipo
                            try:
                                file_result = subprocess.run(
                                    ["file", abs_appimage_path],
                                    capture_output=True,
                                    text=True
                                )
                                if "ELF" in file_result.stdout and "executable" in file_result.stdout:
                                    print("    ✅ Es un ejecutable ELF válido")
                            except:
                                pass
                            
                            # Método 2: Probar con --appimage-version (si existe)
                            try:
                                version_result = subprocess.run(
                                    [abs_appimage_path, "--appimage-version"],
                                    capture_output=True,
                                    text=True,
                                    timeout=5
                                )
                                if version_result.returncode == 0:
                                    print(f"    ✅ Versión AppImage: {version_result.stdout.strip()}")
                            except subprocess.TimeoutExpired:
                                print("    ⏱️  Timeout (normal para GUI)")
                            except Exception:
                                # Si falla, no es crítico
                                pass
                            
                            # 4. VERIFICACIÓN ALTERNATIVA SEGURA (sin cambiar directorio)
                            print("    📦 Verificación alternativa segura...")
                            
                            # Usar método que NO cambia el directorio de trabajo
                            import tempfile
                            temp_dir = tempfile.mkdtemp(prefix="appimage_verify_")
                            
                            try:
                                # Copiar AppImage al directorio temporal
                                temp_appimage = os.path.join(temp_dir, "AtlasInstaller.AppImage")
                                shutil.copy(abs_appimage_path, temp_appimage)
                                os.chmod(temp_appimage, 0o755)
                                
                                # Ejecutar desde el directorio temporal
                                extract_result = subprocess.run(
                                    [temp_appimage, "--appimage-extract"],
                                    cwd=temp_dir,
                                    capture_output=True,
                                    text=True,
                                    timeout=15
                                )
                                
                                squashfs_dir = os.path.join(temp_dir, "squashfs-root")
                                if os.path.exists(squashfs_dir):
                                    print("    ✅ Extracción exitosa")
                                    
                                    # Contar archivos
                                    files = []
                                    for root, dirs, filenames in os.walk(squashfs_dir):
                                        for filename in filenames:
                                            files.append(os.path.join(root, filename))
                                    
                                    print(f"    📁 Total archivos: {len(files)}")
                                    
                                    # Mostrar archivos principales (sin rutas completas)
                                    print("    📄 Archivos principales:")
                                    main_files = ["AppRun", "atlas.desktop", "atlas.png", ".DirIcon", "usr/bin/AtlasInstaller"]
                                    for main_file in main_files:
                                        full_path = os.path.join(squashfs_dir, main_file)
                                        if os.path.exists(full_path):
                                            size = os.path.getsize(full_path)
                                            print(f"      ✅ {main_file} ({size} bytes)")
                                        else:
                                            print(f"      ❌ {main_file} (faltante)")
                                
                                elif extract_result.returncode != 0:
                                    print(f"    ⚠️  Extracción falló con código: {extract_result.returncode}")
                                    
                            except subprocess.TimeoutExpired:
                                print("    ⏱️  Timeout en extracción (puede ser normal)")
                            except Exception as e:
                                print(f"    ⚠️  Error en verificación: {str(e)[:100]}")
                            
                            finally:
                                # Limpiar SIEMPRE
                                try:
                                    shutil.rmtree(temp_dir, ignore_errors=True)
                                except:
                                    pass

                        else:
                            print("    ❌ No se creó el archivo AppImage")

                    except subprocess.CalledProcessError as e:
                        print(f"  ❌ Error con appimagetool:")
                        print(f"    Salida: {e.stdout[:200]}")
                        print(f"    Error: {e.stderr[:200]}")
                        
                        # Intentar método alternativo más simple
                        print("  🔄 Intentando método alternativo...")
                        try:
                            result = subprocess.run([
                                "appimagetool", appdir, "../AtlasInstaller.AppImage"
                            ], capture_output=True, text=True)
                            if result.returncode == 0:
                                print("  ✅ AppImage creado (método alternativo)")
                            else:
                                print(f"  ❌ También falló método alternativo: {result.stderr[:200]}")
                        except:
                            print("  ❌ Método alternativo también falló")
                        
                    finally:
                        # Limpiar
                        if os.path.exists(appdir):
                            shutil.rmtree(appdir, ignore_errors=True)
                            print("  🧹 AppDir eliminado")


                else:
                    print("  ⚠️  appimagetool no encontrado.")
                    print("  💡 Instala:")
                    print("    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage")
                    print("    chmod +x appimagetool-x86_64.AppImage")
                    print("    sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool")
                    
            else:
                print("  ⚠️  PyInstaller no encontrado.")
                print("  💡 Instala: pip install pyinstaller")
                
        except subprocess.CalledProcessError as e:
            print(f"  ❌ Error con PyInstaller: {e}")
            if hasattr(e, 'stderr') and e.stderr:
                print(f"  Detalles: {e.stderr[:200]}")
        except Exception as e:
            print(f"  ❌ Error inesperado: {e}")
            import traceback
            traceback.print_exc()
    else:  # Este else corresponde al IF de arriba: if os.path.exists(py_source):
        print(f"  ❌ No se encuentra: {py_source}")



    print("\n" + "=" * 50)
    print("📁 ARCHIVOS GENERADOS:")
    
    # Mostrar archivos creados
    if os.path.exists("../AtlasInstaller.exe"):
        # size = os.path.getsize("../AtlasInstaller.exe") / (1024 * 1024)
        # print(f"  ✅ Windows: AtlasInstaller.exe ({size:.1f} MB)")

        try:
            size_bytes = os.path.getsize("../AtlasInstaller.exe")
            size_mb = size_bytes / (1024 * 1024)
            print(f"  ✅ Windows: AtlasInstaller.exe ({size_mb:.2f} MB)")
        except Exception as e:
            print(f"  ✅ Windows: AtlasInstaller.exe (error calculando tamaño: {e})")

    else:
        print("  ❌ Windows: No se pudo compilar")
    
    if os.path.exists("../AtlasInstaller.AppImage"):
        # size = os.path.getsize("../AtlasInstaller.AppImage") / (1024 * 1024)
        # print(f"  ✅ Linux: AtlasInstaller.AppImage ({size:.1f} MB)")
        try:
            size_bytes = os.path.getsize("../AtlasInstaller.AppImage")
            size_mb = size_bytes / (1024 * 1024)
            print(f"  ✅ Linux: AtlasInstaller.AppImage ({size_mb:.2f} MB)")
        except Exception as e:
            print(f"  ✅ Linux: AtlasInstaller.AppImage")

    elif os.path.exists("dist/AtlasInstaller"):
        # size = os.path.getsize("dist/AtlasInstaller") / (1024 * 1024)
        # print(f"  ✅ Linux: dist/AtlasInstaller ({size:.1f} MB)")
        try:
            size_bytes = os.path.getsize("dist/AtlasInstaller")
            size_mb = size_bytes / (1024 * 1024)
            print(f"  ✅ Linux: dist/AtlasInstaller ({size_mb:.2f} MB)")
        except Exception as e:
            print(f"  ✅ Linux: dist/AtlasInstaller")

    else:
        print("  ❌ Linux: No se pudo compilar")
    
    print("\n💡 INSTRUCCIONES:")
    print("  1. Para Windows: Usa AtlasInstaller.exe (solo en Windows o con Wine)")
    print("  2. Para Linux: Usa AtlasInstaller.AppImage o dist/AtlasInstaller")
    print("  3. Sube estos archivos a Google Drive")
    print("  4. Actualiza los IDs en docs/download.js")
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
            build_installers(compiler='mono')
        elif sys.argv[1] == "build-dotnet":
            # Forzar compilación con .NET SDK
            build_installers(compiler='dotnet')
        elif sys.argv[1] == "build-mono":
            # Forzar compilación con Mono
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
        print("  3. Construir instaladores: python create_patches.py build")
        print("  4. Construir con .NET SDK: python create_patches.py build-dotnet")
        print("  5. Construir con Mono: python create_patches.py build-mono")
        print("\nPrimero crea los parches, luego construye los instaladores.")


# convert -size 64x64 xc:#2563eb -fill white -pointsize 24   -gravity center -draw "text 0,0 'Atlas'" icon.png