"""Download a TDengine package and invoke its standard ./install.sh -e no flow."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.error
import urllib.parse
import urllib.request


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def download(url, directory, expected=''):
    if urllib.parse.urlsplit(url).scheme not in {'http', 'https'}:
        raise RuntimeError('Package URL must use HTTP or HTTPS')
    if expected and not re.fullmatch(r'[0-9a-fA-F]{64}', expected):
        raise RuntimeError('TSBS_TDENGINE_SHA256 must contain exactly 64 hex digits')
    archive = directory / 'package.tar.gz'
    receipt = directory / 'download.json'
    if archive.exists() and receipt.exists():
        digest = sha(archive)
        if digest != json.loads(receipt.read_text())['sha256']:
            raise RuntimeError('Cached package hash mismatch; preserve and remove this cache before retrying')
    else:
        partial = directory / 'package.part'
        try:
            # Do not print URLs: private download links may contain credentials.
            with urllib.request.urlopen(url, timeout=60) as source, partial.open('wb') as target:
                if urllib.parse.urlsplit(source.geturl()).scheme not in {'http', 'https'}:
                    raise RuntimeError('Unsupported download redirect')
                shutil.copyfileobj(source, target, length=4 * 1024 * 1024)
            digest = sha(partial)
            if expected and digest.lower() != expected.lower():
                raise RuntimeError('Downloaded package SHA-256 differs from configured value')
            partial.replace(archive)
            receipt.write_text(json.dumps({'sha256': digest}) + '\n')
        except Exception as error:
            if isinstance(error, urllib.error.HTTPError):
                error.close()
            partial.unlink(missing_ok=True)
            raise RuntimeError('Package download failed; check URL, connectivity and configured SHA-256') from None
    if expected and digest.lower() != expected.lower():
        raise RuntimeError('Cached package SHA-256 differs from configured value')
    return archive, digest


def extract(archive, destination):
    """Extract regular files first; allow only links whose targets stay inside."""
    root = destination.resolve()
    with tarfile.open(archive, 'r:*') as source:
        members = source.getmembers()
        for item in members:
            path = root / item.name
            if Path(item.name).is_absolute() or not path.resolve().is_relative_to(root):
                raise RuntimeError('Unsafe package member path')
            if not (item.isfile() or item.isdir() or item.issym() or item.islnk()):
                raise RuntimeError('Unsupported package member type')
            if item.issym() or item.islnk():
                target = path.parent / item.linkname if item.issym() else root / item.linkname
                if Path(item.linkname).is_absolute() or not target.resolve().is_relative_to(root):
                    raise RuntimeError('Unsafe package link')
        for item in members:
            path = root / item.name
            if item.isdir():
                path.mkdir(parents=True, exist_ok=True)
            elif item.isfile():
                path.parent.mkdir(parents=True, exist_ok=True)
                with source.extractfile(item) as src, path.open('wb') as dst:
                    shutil.copyfileobj(src, dst)
                path.chmod(item.mode & 0o777)
        for item in members:
            path = root / item.name
            if item.issym() or item.islnk():
                path.parent.mkdir(parents=True, exist_ok=True)
                if item.issym():
                    path.symlink_to(item.linkname)
                else:
                    os.link(root / item.linkname, path)


def unpack(archive, destination):
    extract(archive, destination)
    installers = list(destination.rglob('install.sh'))
    candidates = [p.parent for p in installers if (p.parent / 'bin/taosd').is_file()]
    if not candidates:
        # Some official releases carry the server payload inside taos.tar.gz.
        for installer in installers:
            payload = installer.parent / 'taos.tar.gz'
            if payload.is_file():
                extract(payload, installer.parent)
        candidates = [p.parent for p in installers if (p.parent / 'bin/taosd').is_file()]
    if len(candidates) != 1:
        raise RuntimeError('Expected exactly one enterprise server package with install.sh and bin/taosd')
    package = candidates[0]
    with (package / 'bin/taosd').open('rb') as stream:
        header = stream.read(20)
    if header[:5] != b'\x7fELF\x02' or header[5:6] != b'\x01' or header[18:20] != b'\xb7\x00':
        raise RuntimeError('Package taosd must be Linux ARM64 (AArch64 ELF64)')
    if not (package / 'inc/taos.h').is_file():
        raise RuntimeError('Package is missing inc/taos.h')
    return package


def link_drivers(installed, directory):
    drivers = list((installed / 'driver').glob('lib*.so*'))
    if not any(p.name.startswith('libtaos.so') for p in drivers):
        raise RuntimeError('Installed package is missing libtaos.so')
    directory.mkdir(exist_ok=True)
    links = {p.name: p.resolve() for p in drivers if p.is_file()}
    for name in ['libtaos.so', 'libtaosnative.so']:
        matches = sorted((installed / 'driver').glob(name + '*'))
        if matches:
            links[name] = matches[0].resolve()
    # Only replace links managed by this benchmark, never regular user files.
    for name in links:
        target = directory / name
        if target.exists() and not target.is_symlink():
            raise RuntimeError('Refusing to replace regular library file: ' + str(target))
    for name, source in links.items():
        target = directory / name
        target.unlink(missing_ok=True)
        target.symlink_to(source)


def main():
    if platform.system() != 'Linux' or platform.machine() != 'aarch64':
        raise SystemExit('Package setup requires Linux ARM64')
    if os.geteuid() != 0:
        raise SystemExit('Run package setup as root for the standard system installation')
    root = Path(os.environ['TSBS_BENCH_ROOT']).resolve()
    root.mkdir(parents=True, exist_ok=True)
    with (root / 'cpu-oneclick.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        pidfile = root / 'taosd.pid'
        if pidfile.exists() and Path('/proc/' + pidfile.read_text().strip()).exists():
            raise RuntimeError('Benchmark server is still running; stop its verified PID before installing')
        url = os.environ['TSBS_TDENGINE_URL']
        key = hashlib.sha256(url.encode()).hexdigest()
        directory = root / 'packages' / key
        directory.mkdir(parents=True, exist_ok=True)
        print('Downloading/verifying package cache: ' + str(directory), flush=True)
        archive, digest = download(url, directory, os.environ.get('TSBS_TDENGINE_SHA256', ''))
        with tempfile.TemporaryDirectory(prefix='unpack-', dir=directory) as temporary:
            package = unpack(archive, Path(temporary))
            package_server_sha256 = sha(package / 'bin/taosd')
            (root / 'package-preparation.json').unlink(missing_ok=True)
            print('Running package installer: ./install.sh -e no', flush=True)
            with (root / 'package-install.log').open('ab') as log:
                subprocess.run(['./install.sh', '-e', 'no'], cwd=package, stdout=log,
                               stderr=subprocess.STDOUT, check=True, stdin=subprocess.DEVNULL)
        installed = Path(os.environ.get('TSBS_TAOSD_BIN', '/usr/local/taos/bin/taosd')).resolve().parents[1]
        if not (installed / 'bin/taosd').is_file():
            raise RuntimeError('Installed taosd not found; check TSBS_TAOSD_BIN and package-install.log')
        if sha(installed / 'bin/taosd') != package_server_sha256:
            raise RuntimeError('Installed taosd differs from downloaded package; check installer log and TSBS_TAOSD_BIN')
        link_drivers(installed, root / 'lib')
        metadata = dict(url_sha256=key, archive_sha256=digest, installer_args=['./install.sh', '-e', 'no'],
                        installed_server=str(installed / 'bin/taosd'), server_sha256=sha(installed / 'bin/taosd'))
        (root / 'package-preparation.json').write_text(json.dumps(metadata, indent=2) + '\n')
        print('Installed. Next run build.sh, then run.sh with the same config.', flush=True)


if __name__ == '__main__':
    main()
