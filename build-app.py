"""Build the native application and installer for this Mac's architecture."""
import pathlib
import platform
import plistlib
import re
import shutil
import subprocess

root = pathlib.Path(__file__).resolve().parent
version = (root / 'VERSION').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('VERSION must be X.Y.Z')
arch = platform.machine()
if arch not in ('arm64', 'x86_64'):
    raise SystemExit('Build on macOS arm64 or x86_64')
app = root / 'build/PandaCompanion.app'
if app.exists():
    shutil.rmtree(app)
contents = app / 'Contents'
resources = contents / 'Resources'
resources.mkdir(parents=True)
(contents / 'MacOS').mkdir()
cache = root / 'build/module-cache'
info = dict(CFBundleIdentifier='local.company-direct.app', CFBundleName='熊猫伴行',
            CFBundleDisplayName='熊猫伴行', CFBundleExecutable='PandaCompanion',
            CFBundlePackageType='APPL', CFBundleShortVersionString=version,
            CFBundleVersion=version, LSMinimumSystemVersion='14.0', LSUIElement=True,
            NSHighResolutionCapable=True, CFBundleIconFile='AppIcon')
(contents / 'Info.plist').write_bytes(plistlib.dumps(info))
sources = ['App.swift', 'DesignSystem.swift', 'Configuration.swift', 'AssistantState.swift',
           'SettingsController.swift', 'PandaCompatibility.swift', 'CompatibilityPane.swift']
common = ['xcrun', 'swiftc', '-O', '-swift-version', '5', '-target', f'{arch}-apple-macosx14.0',
          '-module-cache-path', str(cache)]
subprocess.run(common + [str(root/name) for name in sources] + ['-o', str(contents/'MacOS/PandaCompanion'), '-framework', 'AppKit', '-framework', 'SystemConfiguration'], check=True)
subprocess.run(common + [str(root/'Installer.swift'), '-o', str(root/'build/Install')], check=True)
subprocess.run(['xcrun', 'swift', '-module-cache-path', str(cache), str(root/'Icon.swift'), str(root/'build/icon.png')], check=True)
icons = root/'build/AppIcon.iconset'
icons.mkdir(exist_ok=True)
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        filename = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
        subprocess.run(['sips', '-z', str(size*scale), str(size*scale), str(root/'build/icon.png'), '--out', str(icons/filename)], check=True, stdout=subprocess.DEVNULL)
subprocess.run(['iconutil', '-c', 'icns', str(icons), '-o', str(resources/'AppIcon.icns')], check=True)
for name in ('panda-companion', 'config.conf', 'README.md', 'DESIGN.md', 'PERFORMANCE.md', 'LICENSE'):
    shutil.copy2(root/name, resources/name)
(resources/'panda-companion').chmod(0o700)
for target in (app, root/'build/Install'):
    subprocess.run(['codesign', '--force', '--sign', '-', str(target)], check=True)
print(app)
