#!/usr/bin/python

import json
import math
import os
import wave

from PyTexturePacker import Packer
from PIL import Image, ImageOps

AUDIO_PATH = "./sounds/"
GRAPHICS_PATH = "./images/"
GRAPHICS_OUTPUT_PATH = "./packed_images/"
OUTPUT_FILE = "./packed.hex"

BLOCK_SIZE = 512

TEXTUREMAP_WIDTH = 512
TEXTUREMAP_HEIGHT = 256

audio_assets = []
graphics_assets = []
packed_asset_filenames = []

texturemaps = []

# list of individual texturemap properties
texturemap_properties_list = []

# create an 8-bit palette
# TODO actually get colormapping working
palette = []

for i in range(256):
    palette.extend(((i & 0b11100000) << 0, (i & 0b00011100) << 2, (i & 0b00000011) << 6))

assert len(palette) == 768

def rgba_to_8bit(r, g, b, a):
    return (r & 0b11100000) | ((g & 0b11100000) >> 3) | ((b & 0b11000000) >> 6)

# create folder for packed graphics assets
if not os.path.exists(GRAPHICS_OUTPUT_PATH):
    os.makedirs(GRAPHICS_OUTPUT_PATH)

# pack graphics assets
packer = Packer.create(max_width=TEXTUREMAP_WIDTH, max_height=TEXTUREMAP_HEIGHT, enable_rotated=False, \
                       border_padding=0, shape_padding=0, atlas_format="json")

# TODO also include image filenames to packed_asset_filenames
# TODO do we need to quantize to 255 so we can make the background black? idk
background = Image.new(mode="RGBA", size=(TEXTUREMAP_WIDTH, TEXTUREMAP_HEIGHT), color=(0, 0, 0, 255))

# TODO needs to be able to take in multiple folders and outupt a texturemap for each
# TODO test with an image where the texturepack is not majority black (0x000000FF)
# convert packed textures into texturemap
for directory in os.listdir(GRAPHICS_PATH):
    # HACK this is terrible
    # get the texturepack id from directory name
    texturepack_id = directory[:3]
    packer.pack(GRAPHICS_PATH + directory, GRAPHICS_OUTPUT_PATH + texturepack_id + "_texturepack")

    with Image.open(GRAPHICS_OUTPUT_PATH + texturepack_id + "_texturepack.png", mode='r') as texturepack:
        texturepack_expanded = Image.new("RGBA", (TEXTUREMAP_WIDTH, TEXTUREMAP_HEIGHT))
        texturepack_expanded.paste(texturepack, (0, 0))

        texturemap = Image.alpha_composite(background, texturepack_expanded)
        # texturemap = texturemap.quantize()
        # texturemap = texturemap.quantize()
        # texturemap.putpalette(palette)
        texturemap_8bit = texturemap.tobytes()
        texturemap_8bit = [rgba_to_8bit(r, g, b, a) for r, g, b, a in zip(*[iter(texturemap.tobytes())] * 4)]

        # palette_bytes = texturemap.palette.tobytes()
        # palette_bytes = [palette_bytes[i : i + 3] for i in range(0, len(palette_bytes), 3)]
        # texturemap_bytes = texturemap.tobytes()

        # texturemap.save("texturepack_8bit.png")

    # texturemaps.append((texturemap_bytes, palette_bytes))
    texturemaps.append(texturemap_8bit)

    print("texturepack " + texturepack_id)

    with open(GRAPHICS_OUTPUT_PATH + texturepack_id + "_texturepack.json") as texturemap_atlas_file:
        texturemap_properties = {}
        texturemap_atlas = json.load(texturemap_atlas_file)

        for filename, data in texturemap_atlas['frames'].items():
            # FIXME this is a terrible hack, probably
            index = int(filename[:2])
            texturemap_properties[index] = (data['frame']['x'], data['frame']['y'],
                                            data['frame']['w'], data['frame']['h'])
            
            print("└─ " + filename)
            packed_asset_filenames.append(filename)

        print()
        texturemap_properties_list.append(texturemap_properties)

# pack audio assets
for file in os.listdir(AUDIO_PATH):
    try:
        with wave.open(AUDIO_PATH + file, 'rb') as sound:
            print(file)
            packed_asset_filenames.append(file)

            if sound.getparams()[:3] != (1, 1, 44100):
                raise Exception("audio must be mono, 8-bit signed, 44.1kHz")
            
            # read entire file
            sound_bytes = sound.readframes(sound.getnframes())

            audio_assets.append(sound_bytes)

    except wave.Error:
        continue

# TOC format: (4 bytes of START, 4 bytes of END; both must be BLOCK_SIZE aligned)
# graphics TOC goes in 0x000-0x0FF
# audio TOC goes in 0x100-0x1FF

# data starts at 0x20000 bytes past beginning of file, just because it's easier and allows for extensions
DATA_START_ADDRESS = 0x20000
TEXTUREMAP_PROPERTIES_START_ADDRESS = 0x1000

audio_toc = []

with open(OUTPUT_FILE, 'wb') as f:
    head_addr = DATA_START_ADDRESS

    def write_with_padding(data):
        bytes_required = math.ceil(len(data) / 512) * 512

        f.write(data)
        if bytes_required != len(data):
            f.write(bytes([0]) * (bytes_required - len(data)))

        return bytes_required

    f.seek(DATA_START_ADDRESS)

    # write graphics here
    # for texturemap, palette in texturemaps:
    # HACK remove two bytes from the beginning to fix a graphical glitch
    for texturemap in texturemaps:
        # print(palette[0][0])
        # bytes_written = write_with_padding(bytes(texturemap[8:]) + bytes(texturemap[:8]))
        # bytes_written = write_with_padding(bytes(texturemap[-8:]) + bytes(texturemap[:-8]))
        bytes_written = write_with_padding(bytes(texturemap))

        head_addr += bytes_written

    for asset in audio_assets:
        bytes_written = write_with_padding(asset)

        audio_toc.append((head_addr, head_addr + bytes_written))
        head_addr += bytes_written

    f.seek(0)
    # TODO change this to adapt to audio taking up all 512 bytes

    # audio starts in the middle of the first block
    f.seek(256)

    for start, end in audio_toc:
        f.write(start.to_bytes(4, 'little'))
        f.write(end.to_bytes(4, 'little'))
    
    # FIXME
    # f.seek(0x1000)      # texturemap properties start here
    for i, texturemap_properties in enumerate(texturemap_properties_list):
        for j, (x, y, w, h) in texturemap_properties.items():
            f.seek(0x1000 + j * 8 + i * 512)
            f.write(x.to_bytes(2, 'little'))
            f.write(y.to_bytes(2, 'little'))
            f.write(w.to_bytes(2, 'little'))
            f.write(h.to_bytes(2, 'little'))

print(f'\npacked {len(packed_asset_filenames)} files!')
# print(*packed_asset_filenames, sep="\n")