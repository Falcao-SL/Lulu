#!/usr/bin/env python3
"""Sign notarized installers and create one Sparkle feed per CPU architecture."""
import os
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)
version, build = os.environ['VERSION'], os.environ['BUILD']
private_key = os.environ['SPARKLE_ED25519_PRIVATE_KEY'].encode()
signer = str(Path(os.environ['SPARKLE_DIR']) / 'bin' / 'sign_update')
for arch in ('arm64', 'x86_64'):
    dmg = Path('dist') / f'Lulu-{version}-macos-{arch}.dmg'
    sig = subprocess.run([signer, '--ed-key-file', '-', '-p', str(dmg)], input=private_key,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout.decode().strip()
    if not sig or len(sig) > 100:
        raise SystemExit('Invalid update signature')
    rss = ET.Element('rss', {'version': '2.0'})
    channel = ET.SubElement(rss, 'channel')
    ET.SubElement(channel, 'title').text = 'Lulu updates'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = f'Lulu {version}'
    ET.SubElement(item, f'{{{SPARKLE}}}version').text = build
    ET.SubElement(item, f'{{{SPARKLE}}}shortVersionString').text = version
    ET.SubElement(item, f'{{{SPARKLE}}}minimumSystemVersion').text = '14.0'
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/Falcao-SL/Lulu/releases/download/v{version}/{dmg.name}',
        'length': str(dmg.stat().st_size), 'type': 'application/octet-stream',
        f'{{{SPARKLE}}}edSignature': sig,
    })
    ET.ElementTree(rss).write(Path('dist') / f'appcast-{arch}.xml', encoding='utf-8', xml_declaration=True)
    print(f'Created signed {arch} update feed')
