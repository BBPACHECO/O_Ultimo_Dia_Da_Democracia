#!/usr/bin/env python3
"""Verifica estrutura, arquitetura e permissões do APK nativo gerado."""
import os
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile


def require(condition, message):
    if not condition:
        raise SystemExit('APK inválido: ' + message)


apk = Path(sys.argv[1])
aapt = Path(os.environ['ANDROID_HOME']) / 'build-tools/35.0.1/aapt'
badging = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True)
permissions = subprocess.check_output([str(aapt), 'dump', 'permissions', str(apk)], text=True)
manifest = subprocess.check_output([str(aapt), 'dump', 'xmltree', str(apk), 'AndroidManifest.xml'], text=True)
require("package: name='com.bbpacheco.ultimodiademocracia'" in badging, 'identificador incorreto')
# O template 4.6 usa activity-alias. O aapt legado não inclui aliases em
# "launchable-activity"; valide a intenção de lançamento no manifesto real.
launcher = None
lines = manifest.splitlines()
for index, line in enumerate(lines):
    match = re.match(r'(\s*)E: (activity|activity-alias)\s', line)
    if not match:
        continue
    indent = len(match[1])
    block = []
    for following in lines[index + 1:]:
        if following.strip() and len(following) - len(following.lstrip()) <= indent:
            break
        block.append(following)
    text = '\n'.join(block)
    if ('android.intent.action.MAIN' in text and 'android.intent.category.LAUNCHER' in text
            and re.search(r'android:exported[^\n]*0xffffffff', text)):
        name = re.search(r'android:name[^\n]*?="([^"]+)"', text)
        if name:
            launcher = name[1]
            if match[2] == 'activity-alias':
                target = re.search(r'android:targetActivity[^\n]*?="([^"]+)"', text)
                require(target is not None and target[1] == 'com.godot.game.GodotApp', 'alias aponta para atividade incorreta')
            break
require(launcher is not None, 'sem atividade inicial exportada com MAIN/LAUNCHER')
require("versionName='0.2.0'" in badging and "versionCode='2'" in badging, 'versão inesperada')
require('android.permission.INTERNET' not in permissions, 'permissão de internet presente')
require('android.permission.ACCESS_NETWORK_STATE' not in permissions, 'permissão de rede presente')
with zipfile.ZipFile(apk) as z:
    names = z.namelist()
    require(z.testzip() is None, 'CRC incorreto')
    require('classes.dex' in names and 'AndroidManifest.xml' in names, 'não é aplicativo Android')
    require('assets/project.binary' in names and 'assets/scenes/third_person.tscn.remap' in names, 'cena 3D inicial ausente')
    remap = z.read('assets/scenes/third_person.tscn.remap').decode('utf-8')
    scene = re.search(r'path="res://([^"]+)"', remap)
    require(scene is not None and 'assets/' + scene[1] in names, 'cena compilada ausente')
    for script in ['game_3d', 'city_world', 'player_3d', 'touch_controls', 'mission_state', 'radar_3d']:
        require('assets/scripts/' + script + '.gdc' in names, 'módulo 3D ausente: ' + script)
    require('assets/data/story.json' in names, 'narrativa ausente')
    require('assets/assets/fonts/LICENSE-DejaVu.txt' in names, 'licença das fontes ausente')
    story = json.loads(z.read('assets/data/story.json'))
    require(len(story.get('chapters', [])) == 8, 'narrativa incompleta')
    for abi in ['arm64-v8a', 'armeabi-v7a']:
        require('lib/' + abi + '/libgodot_android.so' in names, 'engine nativo ausente: ' + abi)
    require(not any(n.endswith(('.html', '.htm', '.js')) for n in names), 'recurso de navegador encontrado')
    require(not any(n.startswith(('assets/tests/', 'assets/tools/')) for n in names), 'ferramentas de teste incluídas')
for line in badging.splitlines():
    if line.startswith(('package:', 'sdkVersion:', 'targetSdkVersion:', 'native-code:', 'launchable-activity:')):
        print(line)
print('APK validado: engine nativo ARM, atividade inicial e nenhuma permissão de rede.')
print('Atividade inicial (alias):', launcher)
