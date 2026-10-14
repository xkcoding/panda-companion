"""Create and validate a native macOS distribution without touching live settings."""
import hashlib
import json
import os
import pathlib
import platform
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile

root = pathlib.Path(__file__).resolve().parent
version = (root/'VERSION').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('VERSION must be X.Y.Z')
if os.environ.get('GITHUB_REF_TYPE') == 'tag' and os.environ.get('GITHUB_REF_NAME') != 'v' + version:
    raise SystemExit('Release tag must match VERSION')
arch = platform.machine()
app = root/'build/PandaCompanion.app'
installer = root/'build/Install'
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['CFBundleShortVersionString'] == version
assert info['LSMinimumSystemVersion'] == '14.0'
assert info['CFBundleExecutable'] == 'PandaCompanion'
for binary in (app/'Contents/MacOS/PandaCompanion', installer):
    actual = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip()
    assert actual == arch, (actual, arch)
    subprocess.run(['codesign', '--verify', '--strict', str(binary)], check=True)
    build_info = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(binary)], text=True)
    assert re.search(r'\bminos\s+14\.0(?:\.0)?\b', build_info), build_info
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
assert not any(line.startswith('domain=') for line in (app/'Contents/Resources/config.conf').read_text().splitlines())
name = f'PandaCompanion-{version}-macOS-{arch}'
dist = root/'dist'
dist.mkdir(exist_ok=True)
archive = dist/(name + '.zip')
with tempfile.TemporaryDirectory(prefix='panda-package-') as tmp:
    stage = pathlib.Path(tmp)/name
    stage.mkdir()
    shutil.copytree(app, stage/app.name)
    shutil.copy2(installer, stage/'Install')
    shutil.copy2(root/'Install.command', stage/'Install.command')
    shutil.copy2(root/'LICENSE', stage/'LICENSE')
    (stage/'安装说明.txt').write_text('熊猫伴行 Panda Companion\n\n1. 退出正在运行的熊猫伴行。\n2. 双击 Install.command 安装到当前用户。无需 Python 或编译工具链。\n3. 从 ~/Applications/熊猫伴行.app 打开。\n\n个人配置与自动维护状态会保留。新用户请先添加规则，再开启维护。\n当前应用与安装器仅临时签名，未经 Apple 公证。请遵循系统安全确认流程。\n')
    (stage/'manifest.json').write_text(json.dumps({'version': version, 'architecture': arch, 'minimum_macos': '14.0', 'source_commit': os.environ.get('GITHUB_SHA', ''), 'notarized': False}, indent=2) + '\n')
    subprocess.run(['ditto', '-c', '-k', '--keepParent', str(stage), str(archive)], check=True)
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.testzip() is None
        names = zipped.namelist()
        for required in ['Install', 'Install.command', 'LICENSE', 'manifest.json', 'PandaCompanion.app/Contents/MacOS/PandaCompanion', 'PandaCompanion.app/Contents/Resources/panda-companion']:
            assert name + '/' + required in names, required
        assert not any('/.git/' in item or '/diagnostics/' in item or item.endswith('changes.log') for item in names)
    unpacked = pathlib.Path(tmp)/'unpacked'
    subprocess.run(['ditto', '-x', '-k', str(archive), str(unpacked)], check=True)
    payload = unpacked/name
    fake_home = pathlib.Path(tmp)/'home'
    command = [str(payload/'Install'), str(payload/'PandaCompanion.app'), '--home', str(fake_home)]
    subprocess.run(command, check=True)
    base = fake_home/'Library/Application Support/CompanyDirect'
    config = base/'config.conf'
    assert 'domain=' not in config.read_text()
    config.write_text(config.read_text() + 'domain=example.com\n')
    guard = fake_home/'Library/LaunchAgents/local.company-direct.guard.plist'
    custom_guard = plistlib.loads(guard.read_bytes())
    custom_guard['StartInterval'] = 60
    guard.write_bytes(plistlib.dumps(custom_guard))
    original_guard = guard.read_bytes()
    (base/'company-direct').write_text('#!/bin/zsh\nexit 0\n')
    subprocess.run(command, check=True)
    assert 'domain=example.com' in config.read_text()
    assert guard.read_bytes() == original_guard
    assert 'panda-companion' in (base/'company-direct').read_text()
    installed = fake_home/'Applications/熊猫伴行.app'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(installed)], check=True)
    menu = plistlib.loads((fake_home/'Library/LaunchAgents/local.company-direct.menu.plist').read_bytes())
    assert menu['ProgramArguments'][0] == str(installed/'Contents/MacOS/PandaCompanion')
    # An unrelated app at the destination must be rejected before settings are changed.
    installed_info = installed/'Contents/Info.plist'
    unrelated = plistlib.loads(installed_info.read_bytes())
    unrelated['CFBundleIdentifier'] = 'org.example.unrelated'
    installed_info.write_bytes(plistlib.dumps(unrelated))
    before_config = config.read_bytes()
    rejected = subprocess.run(command, capture_output=True)
    assert rejected.returncode != 0
    assert config.read_bytes() == before_config
    assert plistlib.loads(installed_info.read_bytes())['CFBundleIdentifier'] == 'org.example.unrelated'
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(dist/(name + '.sha256')).write_text(checksum + '  ' + archive.name + '\n')
print('PASS: architecture, version, signatures, archive, isolated install and upgrade')
print(archive)
