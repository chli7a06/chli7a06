"""Build deterministic transparent foam and water-drop textures for the wash's vehicle surfaces."""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = Path(__file__).resolve().parents[1] / 'crimson-mechanic/textures'
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 256
rng = random.Random(16749)
edge = Image.new('L', (SIZE, SIZE))
edge.putdata([
    round(255 * max(0., min(1., (1. - math.hypot((x - 128) / 126, (y - 128) / 126)) * 5)))
    for y in range(SIZE) for x in range(SIZE)
])
noise = Image.new('L', (24, 24))
noise.putdata([rng.randrange(95, 245) for _ in range(24 * 24)])
alpha = noise.resize((SIZE, SIZE), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(2))
foam = Image.new('RGBA', (SIZE, SIZE), (248, 252, 255, 255))
foam.putalpha(alpha)
draw = ImageDraw.Draw(foam)
for _ in range(180):
    x, y = rng.uniform(12, 244), rng.uniform(12, 244)
    r = rng.uniform(1.2, 7.5)
    draw.ellipse((x-r, y-r, x+r, y+r), fill=(218, 234, 242, 90), outline=(255, 255, 255, 235), width=1)
    draw.arc((x-r+1, y-r+1, x+r-1, y+r-1), 190, 290, fill=(255, 255, 255, 250), width=1)
foam.putalpha(ImageChops.multiply(foam.getchannel('A'), edge))
foam.save(OUT / 'wash_foam.png')

water = Image.new('RGBA', (SIZE, SIZE), (200, 225, 255, 8))
draw = ImageDraw.Draw(water)
for _ in range(85):
    x, y = rng.uniform(12, 244), rng.uniform(12, 244)
    r = rng.uniform(.8, 2.4)
    h = rng.uniform(2, 12)
    draw.ellipse((x-r, y-h, x+r, y+h), fill=(210, 235, 255, rng.randrange(50, 130)))
    draw.line((x-r*.4, y-h*.6, x-r*.4, y+h*.15), fill=(255, 255, 255, 210), width=1)
water.putalpha(ImageChops.multiply(water.getchannel('A'), edge))
water.save(OUT / 'wash_water.png')
print('Created transparent foam and water-drop surface textures')
