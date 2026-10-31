#!/usr/bin/env python3
from PIL import Image
im=Image.open('Resources/OpenstratorMark.png').convert('RGBA')
for p in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)]:
    assert im.getpixel(p)[3] == 0, f'nontransparent corner {p}: {im.getpixel(p)}'
print('icon alpha OK')
