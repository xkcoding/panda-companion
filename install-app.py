"""Install the companion while preserving existing configuration and guard state."""
import datetime
import pathlib
import plistlib
import shutil

root = pathlib.Path(__file__).resolve().parent
home = pathlib.Path.home()
base = home/'Library/Application Support/CompanyDirect'
base.mkdir(parents=True, exist_ok=True, mode=0o700)
destination = home/'Applications/熊猫伴行.app'
old = home/'Applications/公司直连.app'
destination.parent.mkdir(exist_ok=True)
for candidate in (destination, old):
    if candidate.exists():
        info = plistlib.loads((candidate/'Contents/Info.plist').read_bytes())
        if info.get('CFBundleIdentifier') != 'local.company-direct.app':
            raise RuntimeError(f'Refusing to replace unrelated app: {candidate}')
shutil.copytree(root/'build/CompanyDirect.app', destination, dirs_exist_ok=True)
for name in ('README.md', 'DESIGN.md', 'PERFORMANCE.md'):
    shutil.copy2(root/name, base/name)
shutil.copy2(root/'company-direct', base/'company-direct')
(base/'company-direct').chmod(0o700)
if not (base/'config.conf').exists():
    shutil.copy2(root/'config.conf', base/'config.conf')
    (base/'config.conf').chmod(0o600)
agent_dir = home/'Library/LaunchAgents'
agent_dir.mkdir(parents=True, exist_ok=True)
guard = agent_dir/'local.company-direct.guard.plist'
if not guard.exists():
    # New installs start inactive; the user enables maintenance in the app.
    guard.write_bytes(plistlib.dumps({
        'Label': 'local.company-direct.guard',
        'ProgramArguments': ['/bin/zsh', str(base/'company-direct'), 'check'],
        'RunAtLoad': True, 'StartInterval': 10, 'ThrottleInterval': 2,
        'WatchPaths': ['/Library/Preferences/SystemConfiguration/preferences.plist'],
        'ProcessType': 'Background', 'LowPriorityIO': True,
        'LimitLoadToSessionType': 'Aqua',
    }))
    guard.chmod(0o600)
agent = agent_dir/'local.company-direct.menu.plist'
agent.write_bytes(plistlib.dumps({
    'Label': 'local.company-direct.menu',
    'ProgramArguments': [str(destination/'Contents/MacOS/CompanyDirect'), '--background'],
    'RunAtLoad': True, 'LimitLoadToSessionType': 'Aqua',
}))
agent.chmod(0o600)
if old.exists():
    # Keep a recoverable copy without registering a second app with the same ID.
    archives = base/'PreviousVersions'
    archives.mkdir(exist_ok=True, mode=0o700)
    archive = archives/('company-direct-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '.zip')
    shutil.make_archive(str(archive.with_suffix('')), 'zip', old.parent, old.name)
    shutil.rmtree(old)
print('Installed:', destination)
print('Configuration and automatic maintenance state preserved.')
