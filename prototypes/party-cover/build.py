"""Build the public offline HTML using the browser's system emoji font."""
from pathlib import Path
root = Path(__file__).resolve().parent
html = (root / 'template.html').read_text()
for name in ('party', 'confetti', 'gift'):
    html = html.replace('{{' + name + '}}', '')
(root / 'index.html').write_text(html)
print(f'Built {root / "index.html"} ({len(html.encode()):,} bytes)')
