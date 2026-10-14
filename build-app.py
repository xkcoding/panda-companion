import pathlib, plistlib, subprocess
root = pathlib.Path(__file__).resolve().parent
app = root / 'build/CompanyDirect.app'
contents = app / 'Contents'
(contents / 'Resources').mkdir(parents=True, exist_ok=True)
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
info = dict(CFBundleIdentifier='local.company-direct.app', CFBundleName='熊猫伴行',
            CFBundleDisplayName='熊猫伴行', CFBundleExecutable='CompanyDirect',
            CFBundlePackageType='APPL', CFBundleShortVersionString='1.2',
            CFBundleVersion='4', LSMinimumSystemVersion='14.0', LSUIElement=True,
            NSHighResolutionCapable=True, CFBundleIconFile='AppIcon')
(contents / 'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['xcrun','swiftc','-O','-swift-version','5',str(root/'App.swift'),str(root/'DesignSystem.swift'),str(root/'Configuration.swift'),str(root/'AssistantState.swift'),str(root/'SettingsController.swift'),str(root/'PandaCompatibility.swift'),str(root/'CompatibilityPane.swift'),'-o',str(contents/'MacOS/CompanyDirect'),'-framework','AppKit','-framework','SystemConfiguration','-module-cache-path','/tmp/company-direct-swift-cache'], check=True)
subprocess.run(['xcrun','swift', '-module-cache-path','/tmp/company-direct-swift-cache',str(root/'Icon.swift'),str(root/'build/icon.png')], check=True)
icons = root/'build/AppIcon.iconset'
icons.mkdir(exist_ok=True)
for size in (16,32,128,256,512):
    for scale in (1,2):
        filename = f'icon_{size}x{size}' + ('@2x' if scale==2 else '') + '.png'
        subprocess.run(['sips','-z',str(size*scale),str(size*scale),str(root/'build/icon.png'),'--out',str(icons/filename)], check=True, stdout=subprocess.DEVNULL)
subprocess.run(['iconutil','-c','icns',str(icons),'-o',str(contents/'Resources/AppIcon.icns')],check=True)
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
print(app)
