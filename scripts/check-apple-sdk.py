"""Compile the adapter against pinned upstream interfaces; publishes no binaries."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PINS = [
    ('SwarmCloudKit', 'https://web3lab.b-cdn.net/apple/3.6.1/SwarmCloudKit.xcframework.zip', '0acb5fdb8695aae5e9bbb8a5052771c0345d6fe2ee2e873788e8c5f030afc5cd'),
    ('datachannel_wrapper', 'https://web3lab.b-cdn.net/apple/libDC/1.0.232/datachannel_wrapper.xcframework.zip', '6244e4da6c6901639e58014771ec4a86cf46f1c371a9ad6802bc190e54b4e466'),
]

def check():
    if not shutil.which('xcodebuild'):
        raise SystemExit('Apple compilation requires Xcode; no build or support qualification performed.')
    with tempfile.TemporaryDirectory(prefix='optimserve-apple-check-') as temporary:
        root = Path(temporary)
        source = root / 'OptimServe'
        shutil.copytree(ROOT / 'integrations/apple', source, ignore=shutil.ignore_patterns('Vendor', '.build', '.swiftpm'))
        vendor = source / 'Vendor'
        vendor.mkdir()
        for name, url, expected in PINS:
            request = urllib.request.Request(url, headers={'User-Agent': 'OptimServe SDK compile check'})
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read(100_000_001)
            if len(payload) > 100_000_000 or hashlib.sha256(payload).hexdigest() != expected:
                raise ValueError('Pinned Apple dependency checksum mismatch: ' + name)
            archive_path = root / (name + '.zip')
            archive_path.write_bytes(payload)
            with zipfile.ZipFile(archive_path) as archive:
                for entry in archive.infolist():
                    parts = Path(entry.filename).parts
                    if entry.filename.startswith('__MACOSX/'):
                        continue
                    if '..' in parts or Path(entry.filename).is_absolute() or not parts or parts[0] != name + '.xcframework' or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                        raise ValueError('Unsafe Apple dependency member')
                    archive.extract(entry, vendor)
        for label, destination in [('ios', 'generic/platform=iOS Simulator'), ('tvos', 'generic/platform=tvOS Simulator'), ('macos', 'platform=macOS')]:
            subprocess.run(['xcodebuild', '-scheme', 'OptimServe', '-destination', destination,
                            '-derivedDataPath', str(root / ('derived-' + label)), 'CODE_SIGNING_ALLOWED=NO', 'build'], cwd=source, check=True)
        print('Apple adapter compiled for iOS/tvOS simulators and macOS; no media transfer or device qualification claimed.')

if __name__ == '__main__':
    check()
