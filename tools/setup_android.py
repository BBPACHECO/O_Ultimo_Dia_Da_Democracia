#!/usr/bin/env python3
"""Instala somente os componentes necessários à exportação APK não-Gradle.

Fontes: release oficial Godot 4.6.3 (SHA512-SUMS.txt) e metadados oficiais
https://dl.google.com/android/repository/repository2-1.xml (checksums SHA-1).
Não recompilamos o engine: NDK, CMake, Gradle e Node não são necessários.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(os.environ['GAME_TOOL_ROOT'])
DOWNLOADS = ROOT / 'downloads'
SDK = Path(os.environ['ANDROID_HOME'])
TEMPLATES = Path(os.environ['XDG_DATA_HOME']) / 'godot/export_templates/4.6.3.stable'


def checksum(path, algorithm):
    h = hashlib.new(algorithm)
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def download(url, expected, algorithm):
    destination = DOWNLOADS / url.rsplit('/', 1)[-1]
    if destination.exists() and checksum(destination, algorithm) == expected:
        return destination
    print('Baixando e verificando:', destination.name, flush=True)
    temporary = destination.with_suffix(destination.suffix + '.part')
    subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error',
                    '--retry', '2', '--max-time', '900', '--output', str(temporary), url], check=True)
    if checksum(temporary, algorithm) != expected:
        temporary.unlink()
        raise RuntimeError('Checksum inválido: ' + destination.name)
    temporary.replace(destination)
    return destination


def extract(archive, destination, prefix):
    with zipfile.ZipFile(archive) as z:
        for member in z.infolist():
            if not member.filename.startswith(prefix):
                continue
            relative = Path(member.filename[len(prefix):])
            if relative.is_absolute() or '..' in relative.parts:
                raise RuntimeError('Caminho inválido no arquivo')
            target = destination / relative
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with z.open(member) as source, target.open('wb') as output:
                    shutil.copyfileobj(source, output)
                mode = (member.external_attr >> 16) & 0o777
                if mode:
                    target.chmod(mode)


def sdk_package(name, filename, sha1, prefix):
    destination = SDK / name
    marker = destination / '.democracia-verified'
    if marker.exists() and marker.read_text().strip() == sha1:
        return
    if destination.exists():
        raise RuntimeError('Diretório já existente sem marcador de instalação: ' + str(destination))
    archive = download('https://dl.google.com/android/repository/' + filename, sha1, 'sha1')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=ROOT) as staging:
        extract(archive, Path(staging), prefix)
        shutil.move(staging, destination)
    marker.write_text(sha1 + '\n')


def templates():
    marker = TEMPLATES / '.democracia-verified.json'
    if marker.exists():
        hashes = json.loads(marker.read_text())
        if all((TEMPLATES / n).exists() and checksum(TEMPLATES / n, 'sha512') == h
               for n, h in hashes.items()) and len(hashes) == 2:
            return
    archive = download(
        'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/'
        'Godot_v4.6.3-stable_export_templates.tpz',
        'da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404f'
        'aa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68', 'sha512')
    TEMPLATES.mkdir(parents=True, exist_ok=True)
    hashes = {}
    with zipfile.ZipFile(archive) as z:
        for name in ['android_debug.apk', 'android_release.apk']:
            target = TEMPLATES / name
            with z.open('templates/' + name) as source, target.open('wb') as output:
                shutil.copyfileobj(source, output)
            hashes[name] = checksum(target, 'sha512')
    marker.write_text(json.dumps(hashes, indent=2) + '\n')


def editor_settings():
    config = Path(os.environ['XDG_CONFIG_HOME']) / 'godot/editor_settings-4.6.tres'
    config.parent.mkdir(parents=True, exist_ok=True)
    text = config.read_text() if config.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    for name, value in {
        'export/android/android_sdk_path': str(SDK),
        'export/android/java_sdk_path': os.environ['JAVA_HOME'],
    }.items():
        line = name + ' = ' + json.dumps(value)
        pattern = '^' + re.escape(name) + r'\s*=.*$'
        if re.search(pattern, text, flags=re.M):
            text = re.sub(pattern, lambda _: line, text, flags=re.M)
        else:
            text += line + '\n'
    config.write_text(text)


def main():
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    sdk_package('build-tools/35.0.1', 'build-tools_r35.0.1_linux.zip',
                'e009a9b188cfeb1d2b4c318ab5cb4f1ddc368861', 'android-15/')
    sdk_package('platform-tools', 'platform-tools_r37.0.1-linux.zip',
                '477254aa5f903c15cf51001717bdf347fb6b53e0', 'platform-tools/')
    templates()
    editor_settings()
    print('Ferramentas de exportação Android prontas.', flush=True)


if __name__ == '__main__':
    main()
