#!/usr/bin/env python3
"""Stage the shared TV launcher; optionally sign it using Tizen Studio."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', help='Existing Samsung certificate profile name')
    parser.add_argument('--prepare-only', action='store_true',
                        help='Create widget sources and an unsigned archive without the SDK')
    parser.add_argument('--output', type=Path, default=root / 'build' / 'tizen')
    parser.add_argument('--cli', default='tizen', help='Path to the Tizen Studio CLI')
    args = parser.parse_args()
    if not args.prepare_only and not args.profile:
        parser.error('Supply --profile NAME to sign, or --prepare-only to stage sources.')
    if args.prepare_only and args.profile:
        parser.error('--prepare-only and --profile cannot be combined.')
    if not args.prepare_only and not shutil.which(args.cli):
        parser.error('Tizen CLI missing. Install Tizen Studio Web CLI or use --prepare-only.')

    output = args.output.resolve()
    widget = output / 'widget'
    # Never clear a caller-provided directory. Only replace the known staged files.
    widget.mkdir(parents=True, exist_ok=True)
    (widget / 'config.xml').write_bytes((root / 'tizen' / 'config.xml').read_bytes())
    html = (root / 'webos' / 'index.html').read_text(encoding='utf-8')
    html = html.replace('data-platform="webos"', 'data-platform="tizen"')
    html = html.replace('<small>LG TV</small>', '<small>Samsung TV</small>')
    (widget / 'index.html').write_text(html, encoding='utf-8')
    for name in ('launcher.js', 'launcher.css'):
        shutil.copyfile(root / 'webos' / name, widget / name)
    # Use the existing 192px brand icon; the launcher also shows this image.
    for name in ('icon.png', 'largeIcon.png'):
        shutil.copyfile(root / 'web' / 'icons' / 'Icon-192.png', widget / name)
    # Compile the same server-owned HTML/CSS/JS constants into the local widget.
    assets = (root / 'lib/capabilities/web_playback/web_playback_assets.dart').read_text(encoding='utf-8')
    tv_assets = (root / 'lib/capabilities/web_playback/web_playback_tv_assets.dart').read_text(encoding='utf-8')
    def extract(source, name):
        match = re.search(r"const " + name + r" = r'''(.*?)''';", source, re.S)
        if not match:
            raise RuntimeError(f'Missing raw asset: {name}')
        return match.group(1)
    player = extract(assets, 'webPlaybackHtml')
    for name in ('app.css', 'app.js', 'tv.css', 'tv.js'):
        player = player.replace('/' + name, name)
    player = player.replace('<script src="app.js"', '<script src="client-config.js" defer></script><script src="app.js"')
    player = player.replace('<title>', """<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self'; connect-src http:; media-src http:; object-src 'none'; base-uri 'none'"><title>""")
    (widget / 'player.html').write_text(player, encoding='utf-8')
    for name, source, constant in [('app.css', assets, 'webPlaybackCss'),
                                   ('app.js', assets, 'webPlaybackJs'),
                                   ('tv.css', tv_assets, 'webPlaybackTvCss'),
                                   ('tv.js', tv_assets, 'webPlaybackTvJs')]:
        (widget / name).write_text(extract(source, constant), encoding='utf-8')
    shutil.copyfile(root / 'tizen/client-config.js', widget / 'client-config.js')
    files = ('player.html', 'client-config.js', 'app.css', 'app.js', 'tv.css', 'tv.js', 'config.xml', 'index.html', 'launcher.js', 'launcher.css',
             'icon.png', 'largeIcon.png')
    archive = output / 'OpenPlayX-tizen-unsigned.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in files:
            package.write(widget / name, name)
    print(f'Prepared: {archive} (source archive; cannot be installed before signing)')
    if args.prepare_only:
        return
    # Package a fresh copy, excluding stale signatures or caller-added files.
    import tempfile
    with tempfile.TemporaryDirectory(prefix='opx-tizen-') as staging:
        for name in files:
            shutil.copyfile(widget / name, Path(staging) / name)
        subprocess.run([args.cli, 'package', '-t', 'wgt', '-s', args.profile,
                        '--', staging], check=True)
        packages = list(Path(staging).glob('*.wgt'))
        if len(packages) != 1:
            raise RuntimeError('Tizen CLI did not produce exactly one signed .wgt')
        destination = output / 'OpenPlayX.wgt'
        shutil.copyfile(packages[0], destination)
        print(f'Signed: {destination}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'Tizen build failed: {error}', file=sys.stderr)
        sys.exit(1)
