#!/usr/bin/env python3
"""Files approved art from the review folder into the art pipeline.

    python3 tool/accept_art.py tool/art_jobs/docks.json          # every view
    python3 tool/accept_art.py tool/art_jobs/docks.json posts     # only these

Run only after Jennifer has approved the pictures. Each one is copied from
~/Downloads/WhispersofJoppa-art-review/<job>/ into assets_incoming/<kind>/
under the name the game uses; then run `dart run tool/process_assets.dart`.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.expanduser('~/Downloads/WhispersofJoppa-art-review')


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    with open(sys.argv[1]) as f:
        job = json.load(f)
    only = set(sys.argv[2:])
    source = os.path.join(REVIEW, job['folder'])
    copied = 0
    for view in job['views']:
        if only and view['id'] not in only:
            continue
        dest = os.path.join(ROOT, 'assets_incoming', view.get('kind', job['kind']))
        os.makedirs(dest, exist_ok=True)
        if 'prompt' in view:
            pairs = [(f"{view['label']}.png", f"{view['game']}.png")]
        else:
            pairs = [
                (f"{view['label']} - {state}.png", f"{view['game']}_{state}.png")
                for state in ('before', 'after')
            ]
        for shown, game in pairs:
            path = os.path.join(source, shown)
            if not os.path.exists(path):
                print('missing, skipped:', shown)
                continue
            shutil.copyfile(path, os.path.join(dest, game))
            copied += 1
    print(f'Copied {copied} picture(s) into assets_incoming.')


if __name__ == '__main__':
    main()
