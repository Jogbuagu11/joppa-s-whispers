#!/usr/bin/env python3
"""Makes every app icon size from one square picture.

    python3 tool/make_app_icons.py assets_incoming/items/app_icon_naomi_20261006114249.jpg

Writes, from that one picture:
  - assets/ui/app_icon.png                      the 1024 x 1024 master copy
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/*   every size iOS asks for
  - android/app/src/main/res/mipmap-*/ic_launcher.png  the classic Android icon
  - android/.../mipmap-*/ic_launcher_foreground.png + mipmap-anydpi-v26/ic_launcher.xml
                                                the modern (adaptive) Android icon
  - dist/store/play_icon_512.png                the icon Google Play asks for
  - dist/store/app_store_icon_1024.png          the icon App Store Connect asks for

Uses macOS's own `sips` to resize, so it needs nothing installed. Run it again
whenever the icon picture changes. The picture should be square, with the
subject in the middle: modern Android crops icons to a circle or rounded
square showing roughly the middle two thirds.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_SET = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
ANDROID_RES = os.path.join(ROOT, 'android/app/src/main/res')
# Android screen densities: classic icon size and adaptive layer size, in pixels.
DENSITIES = {'mdpi': (48, 108), 'hdpi': (72, 162), 'xhdpi': (96, 216),
             'xxhdpi': (144, 324), 'xxxhdpi': (192, 432)}
# Shown only if a launcher slides the picture aside; matches the icon's night sky.
BACKGROUND = '#1F1B3D'


def resize(source, size, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    result = subprocess.run(
        ['sips', '-s', 'format', 'png', '-z', str(size), str(size), source, '--out', out],
        capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f'Could not make {out}: {result.stderr.strip()}')


def size_of(path):
    out = subprocess.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', path],
                         capture_output=True, text=True).stdout
    numbers = [int(line.split()[-1]) for line in out.splitlines() if 'pixel' in line]
    return tuple(numbers) if len(numbers) == 2 else None


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = os.path.abspath(sys.argv[1])
    dimensions = size_of(source)
    if dimensions is None:
        sys.exit(f'{source} is not a picture this tool can read.')
    if dimensions[0] != dimensions[1]:
        sys.exit(f'The icon picture must be square; this one is {dimensions[0]} x {dimensions[1]}.')
    if dimensions[0] < 1024:
        print(f'Note: the picture is {dimensions[0]} px wide; 1024 or more gives a sharper icon.')

    master = os.path.join(ROOT, 'assets/ui/app_icon.png')
    resize(source, 1024, master)
    made = 1

    with open(os.path.join(IOS_SET, 'Contents.json')) as f:
        contents = json.load(f)
    for image in contents['images']:
        name = image.get('filename')
        if not name:
            continue
        points = float(image['size'].split('x')[0])
        scale = int(image['scale'].rstrip('x'))
        resize(master, int(round(points * scale)), os.path.join(IOS_SET, name))
        made += 1

    for density, (classic, layer) in DENSITIES.items():
        folder = os.path.join(ANDROID_RES, f'mipmap-{density}')
        resize(master, classic, os.path.join(folder, 'ic_launcher.png'))
        resize(master, layer, os.path.join(folder, 'ic_launcher_foreground.png'))
        made += 2

    adaptive = os.path.join(ANDROID_RES, 'mipmap-anydpi-v26')
    os.makedirs(adaptive, exist_ok=True)
    with open(os.path.join(adaptive, 'ic_launcher.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<!-- Written by tool/make_app_icons.py. -->\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    values = os.path.join(ANDROID_RES, 'values')
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, 'ic_launcher_background.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<!-- Written by tool/make_app_icons.py. -->\n'
                '<resources>\n'
                f'    <color name="ic_launcher_background">{BACKGROUND}</color>\n'
                '</resources>\n')

    store = os.path.join(ROOT, 'dist/store')
    resize(master, 512, os.path.join(store, 'play_icon_512.png'))
    resize(master, 1024, os.path.join(store, 'app_store_icon_1024.png'))
    made += 2
    print(f'Made {made} icon pictures from {os.path.basename(source)}.')


if __name__ == '__main__':
    main()
