#!/usr/bin/env python3
"""Inline styles and scripts into one self-contained file: FinTrack-Prototype.html.
Run: python3 prototype/build.py  (no dependencies). index.html stays the editable source."""
import pathlib, re
root = pathlib.Path(__file__).parent
html = (root / 'index.html').read_text()
html = html.replace('<link rel="stylesheet" href="styles.css">', '<style>\n' + (root / 'styles.css').read_text() + '\n</style>')
for js in ('data.js', 'screens.js', 'app.js'):
    html = html.replace(f'<script src="{js}"></script>', '<script>\n' + (root / js).read_text() + '\n</script>')
# The artifact host supplies the document skeleton; browsers also accept the page without it.
html = re.sub(r'<!doctype html>\s*<html lang="en">\s*<head>\s*', '', html, flags=re.I)
html = re.sub(r'<meta charset="utf-8">\s*<meta name="viewport"[^>]*>\s*', '', html)
html = html.replace('</head>\n<body>\n', '').replace('</body>\n</html>\n', '')
(root / 'FinTrack-Prototype.html').write_text('<meta charset="utf-8">\n' + html)
print('wrote', root / 'FinTrack-Prototype.html', len(html), 'bytes')
