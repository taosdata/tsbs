"""Package workflow tests using a local HTTP server and a fixture installer."""
from contextlib import contextmanager
import functools
import http.server
import io
import os
from pathlib import Path
import tarfile
import tempfile
import threading
import unittest
from unittest.mock import patch

import setup_package as setup


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


@contextmanager
def serve(directory):
    handler = functools.partial(QuietHandler, directory=str(directory))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield 'http://127.0.0.1:%d/package.tar.gz' % server.server_port
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


def archive(path, files):
    with tarfile.open(path, 'w:gz') as stream:
        for name, value in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(value)
            info.mode = 0o755 if name.endswith('install.sh') else 0o644
            stream.addfile(info, io.BytesIO(value))


def package(path, machine=b'\xb7\x00', installer=None):
    header = bytearray(20)
    header[:6] = b'\x7fELF\x02\x01'
    header[18:20] = machine
    script = installer or b'''#!/bin/sh
set -eu
[ "$#" = 2 ] && [ "$1" = -e ] && [ "$2" = no ]
dest="$(dirname "$(dirname "$TSBS_TAOSD_BIN")")"
mkdir -p "$dest/bin" "$dest/driver" "$dest/include"
cp bin/taosd "$dest/bin/taosd"
cp driver/* "$dest/driver/"
cp inc/* "$dest/include/"
echo installed > "$TSBS_BENCH_ROOT/installer-called"
'''
    archive(path, {'release/install.sh': script, 'release/bin/taosd': bytes(header),
                   'release/inc/taos.h': b'header',
                   'release/driver/libtaos.so.3.4.3.8': b'client'})


class SetupTests(unittest.TestCase):
    def test_actual_enterprise_version_format(self):
        with patch.dict(os.environ, {'TSBS_BENCH_ROOT': tempfile.gettempdir()}):
            from benchmark import validate_server_version
        for version in ['3.4.3.7.enterprise', '3.4.3.7 enterprise']:
            validate_server_version([{'server_version()': version}], '3.4.3.7')
        validate_server_version([{'server_version()': '3.4.3.8.enterprise'}], '3.4.3.8')
        for version in ['3.4.3.8.enterprise', '3.4.3.70.enterprise', '3.4.3.7.1.enterprise', '3.4.3.7 oss']:
            with self.subTest(version=version), self.assertRaises(RuntimeError):
                validate_server_version([{'server_version()': version}], '3.4.3.7')

    def test_url_install_and_cached_repeat(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            package(base / 'package.tar.gz')
            with serve(base) as url, patch.dict(os.environ, {
                'TSBS_BENCH_ROOT': str(base / 'bench'),
                'TSBS_TDENGINE_URL': url,
                'TSBS_TDENGINE_SHA256': setup.sha(base / 'package.tar.gz'),
                'TSBS_TAOSD_BIN': str(base / 'installed/bin/taosd'),
            }), patch.object(setup.platform, 'system', return_value='Linux'), \
                    patch.object(setup.platform, 'machine', return_value='aarch64'), \
                    patch.object(setup.os, 'geteuid', return_value=0):
                setup.main()
                (base / 'package.tar.gz').unlink()  # Cached rerun cannot download again.
                setup.main()
            self.assertTrue((base / 'bench/installer-called').exists())
            self.assertEqual((base / 'bench/lib/libtaos.so').read_bytes(), b'client')
            self.assertTrue((base / 'bench/package-preparation.json').exists())

    def test_hash_and_corrupted_cache_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            package(base / 'package.tar.gz')
            cache = base / 'cache'
            cache.mkdir()
            with serve(base) as url:
                with self.assertRaises(RuntimeError):
                    setup.download(url, cache, '0' * 64)
                self.assertFalse((cache / 'package.tar.gz').exists())
                setup.download(url, cache)
                (cache / 'package.tar.gz').write_bytes(b'corrupted')
                with self.assertRaisesRegex(RuntimeError, 'Cached package hash mismatch'):
                    setup.download(url, cache)

    def test_missing_url_and_http_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            with self.assertRaisesRegex(RuntimeError, 'HTTP or HTTPS'):
                setup.download('file:///tmp/package.tar.gz', base)
            with serve(base) as url:
                with self.assertRaisesRegex(RuntimeError, 'download failed'):
                    setup.download(url, base)

    def test_reject_wrong_architecture(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            package(base / 'package.tar.gz', machine=b'\x3e\x00')
            with self.assertRaisesRegex(RuntimeError, 'ARM64'):
                setup.unpack(base / 'package.tar.gz', base / 'unpack')

    def test_reject_path_and_link_escape(self):
        for name, link in [('../escaped', None), ('release/link', '../../escaped')]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                base = Path(temp)
                with tarfile.open(base / 'bad.tar.gz', 'w:gz') as stream:
                    info = tarfile.TarInfo(name)
                    if link:
                        info.type = tarfile.SYMTYPE
                        info.linkname = link
                    stream.addfile(info)
                with self.assertRaisesRegex(RuntimeError, 'Unsafe package'):
                    setup.extract(base / 'bad.tar.gz', base / 'unpack')
                self.assertFalse((base / 'escaped').exists())

    def test_nested_official_payload(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            package(base / 'inner.tar.gz')
            with tarfile.open(base / 'inner.tar.gz') as inner:
                files = {m.name.removeprefix('release/'): inner.extractfile(m).read()
                         for m in inner.getmembers() if m.name != 'release/install.sh'}
            archive(base / 'payload.tar.gz', files)
            archive(base / 'outer.tar.gz', {'release/install.sh': b'#!/bin/sh\n',
                                           'release/taos.tar.gz': (base / 'payload.tar.gz').read_bytes()})
            self.assertEqual(setup.unpack(base / 'outer.tar.gz', base / 'unpack').name, 'release')

    def test_xz_official_package(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            package(base / 'package.tar.gz')
            with tarfile.open(base / 'package.tar.gz') as source, tarfile.open(base / 'package.tar.xz', 'w:xz') as target:
                for member in source.getmembers():
                    target.addfile(member, source.extractfile(member))
            self.assertEqual(setup.unpack(base / 'package.tar.xz', base / 'unpack').name, 'release')

    def test_failed_installer_does_not_publish_success(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            package(base / 'package.tar.gz', installer=b'#!/bin/sh\necho installer-failed\nexit 42\n')
            with serve(base) as url, patch.dict(os.environ, {
                'TSBS_BENCH_ROOT': str(base / 'bench'),
                'TSBS_TDENGINE_URL': url, 'TSBS_TDENGINE_SHA256': '',
            }), patch.object(setup.platform, 'system', return_value='Linux'), \
                    patch.object(setup.platform, 'machine', return_value='aarch64'), \
                    patch.object(setup.os, 'geteuid', return_value=0):
                with self.assertRaises(setup.subprocess.CalledProcessError):
                    setup.main()
            self.assertFalse((base / 'bench/package-preparation.json').exists())
            self.assertIn('installer-failed', (base / 'bench/package-install.log').read_text())


if __name__ == '__main__':
    unittest.main()
