"""Developer utility: regenerate the bundled font after adding Japanese copy.
Usage: python tools/subset_font.py /path/to/NotoSansCJK-Regular.ttc
Requires the official fonttools Python package. Normal builds do not need it.
"""
from pathlib import Path
import argparse, base64
from fontTools.ttLib import TTFont
from fontTools import subset

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('source_font', type=Path)
args = parser.parse_args()
text = ''.join(p.read_text() for p in (root/'game').rglob('*.gd'))
text += (root/'game/web_shell.html').read_text()
text += ''.join(chr(i) for i in range(32, 127)) + '▶Ⅱ←→？♯〜↻'
font = TTFont(str(args.source_font), fontNumber=0)
options = subset.Options()
options.name_IDs = ['*']
options.name_languages = ['*']
options.recommended_glyphs = True
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
# Rename this modified subset while retaining the upstream licensing records.
for record in font['name'].names:
    names = {1:'Moon Sans', 2:'Regular', 3:'MoonSans-Regular-2026', 4:'Moon Sans Regular', 6:'MoonSans-Regular'}
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding())
if 'CFF ' in font:
    cff = font['CFF '].cff
    cff.fontNames[0] = 'MoonSans-Regular'
    top = cff.topDictIndex[0]
    top.FullName = 'Moon Sans Regular'
    top.FamilyName = 'Moon Sans'
output = root/'game/assets/fonts/MoonSans.ttf' 
font.save(output)
(output.with_name(output.name+'.b64')).write_text(base64.b64encode(output.read_bytes()).decode()+'\n')
print(f'Updated {output.name}: {output.stat().st_size:,} bytes')
