#!/usr/bin/env python3
"""Generates game art with Google's image models, for Jennifer to review.

    python3 tool/generate_art.py tool/art_jobs/docks.json            # everything not made yet
    python3 tool/generate_art.py tool/art_jobs/docks.json posts       # only this view
    python3 tool/generate_art.py tool/art_jobs/docks.json posts --redo "more seaweed"

Pictures are written to ~/Downloads/WhispersofJoppa-art-review/<job>/ and
NOWHERE else: nothing reaches the game until Jennifer approves it (then
tool/accept_art.py files it for the art pipeline).

The key is read from .env (GOOGLE_AI_API_KEY) and is never printed.
A view with "after"/"before" is made twice: the restored "after" picture
first, then that exact picture edited into its neglected "before" state, so
the two line up. A view with "prompt" is a single picture.
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.expanduser('~/Downloads/WhispersofJoppa-art-review')
API = 'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent'


def api_key():
    with open(os.path.join(ROOT, '.env')) as f:
        for line in f:
            if line.startswith('GOOGLE_AI_API_KEY='):
                return line.split('=', 1)[1].strip()
    sys.exit('GOOGLE_AI_API_KEY is not set in .env')


def image_part(path):
    mime = 'image/png' if path.lower().endswith('.png') else 'image/jpeg'
    with open(path, 'rb') as f:
        return {'inline_data': {'mime_type': mime, 'data': base64.b64encode(f.read()).decode()}}


def generate(model, prompt, images, aspect):
    """Returns the bytes of one generated picture."""
    body = {
        'contents': [{'parts': [{'text': prompt}] + [image_part(p) for p in images]}],
        'generationConfig': {
            'responseModalities': ['IMAGE'],
            'imageConfig': {'aspectRatio': aspect},
        },
    }
    request = urllib.request.Request(
        API.format(model=model),
        data=json.dumps(body).encode(),
        headers={'Content-Type': 'application/json', 'x-goog-api-key': api_key()},
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                reply = json.load(response)
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors='replace')[:400]
            if e.code in (429, 500, 503) and attempt < 2:
                time.sleep(20 * (attempt + 1))
                continue
            sys.exit(f'Google refused the request ({e.code}): {detail}')
        for candidate in reply.get('candidates', []):
            for part in candidate.get('content', {}).get('parts', []):
                data = part.get('inlineData') or part.get('inline_data')
                if data:
                    return base64.b64decode(data['data'])
        if attempt < 2:
            time.sleep(5)
    sys.exit('Google returned no picture: ' + json.dumps(reply)[:400])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    redo = None
    if '--redo' in sys.argv:
        redo = sys.argv[sys.argv.index('--redo') + 1]
        args = [a for a in args if a != redo]
    if not args:
        sys.exit(__doc__)
    with open(args[0]) as f:
        job = json.load(f)
    only = set(args[1:])
    out_dir = os.path.join(REVIEW, job['folder'])
    os.makedirs(out_dir, exist_ok=True)
    refs = [os.path.join(ROOT, r) for r in job.get('style_references', [])]
    anchor = None  # the first picture made, shown to later ones for consistency

    for view in job['views']:
        if only and view['id'] not in only:
            first = os.path.join(out_dir, f"{view['label']} - after.png")
            if anchor is None and os.path.exists(first):
                anchor = first
            continue
        note = f"\n\nChange requested by the art director: {redo}" if redo else ''
        if 'prompt' in view:
            # A single picture (an item, a generator, a background).
            single = os.path.join(out_dir, f"{view['label']}.png")
            if redo or not os.path.exists(single):
                extra = [os.path.join(ROOT, r) for r in view.get('references', [])]
                prompt = (
                    job['style'] + '\n\n' + job.get('rules', '')
                    + f"\n\nThis picture: {view['prompt']}" + note
                    + '\n\nThe attached pictures show the art style to match exactly.'
                )
                data = generate(job['model'], prompt, refs + extra, view.get('aspect', job['aspect']))
                with open(single, 'wb') as f:
                    f.write(data)
                print('made', os.path.basename(single), flush=True)
            continue
        after = os.path.join(out_dir, f"{view['label']} - after.png")
        before = os.path.join(out_dir, f"{view['label']} - before.png")

        if redo or not os.path.exists(after):
            same = [anchor] if anchor else []
            prompt = (
                job['style'] + '\n\n' + job['scene'] + '\n\n' + job['after_rules']
                + f"\n\nThis view: {view['after']}" + note
                + '\n\nThe attached pictures show the art style to match exactly'
                + (' (the last one is another view of this same place: keep its '
                   'wood, stone, water and colours identical).' if same else '.')
            )
            data = generate(job['model'], prompt, refs + same, job['aspect'])
            with open(after, 'wb') as f:
                f.write(data)
            print('made', os.path.basename(after), flush=True)
        if anchor is None:
            anchor = after

        if job.get('before_rules') and (redo or not os.path.exists(before)):
            prompt = (
                job['style'] + '\n\n' + job['before_rules']
                + f"\n\nWhat is different in this view: {view['before']}" + note
            )
            data = generate(job['model'], prompt, [after], job['aspect'])
            with open(before, 'wb') as f:
                f.write(data)
            print('made', os.path.basename(before), flush=True)


if __name__ == '__main__':
    main()
