#!/usr/bin/env python3
"""
Jolinx Business OS — Adobe Photoshop (.psd) Master File Generator
Generates a 1024x1024 300-DPI layered Photoshop Document for Option 2 ("Rising Growth J").
"""

import os
import struct
from PIL import Image, ImageDraw, ImageFilter

def build_jolinx_psd(source_jpg_path, source_png_path, out_psd_path):
    master_img = Image.open(source_jpg_path).convert('RGBA')
    width, height = 1024, 1024
    if master_img.size != (width, height):
        master_img = master_img.resize((width, height), Image.Resampling.LANCZOS)
    
    # Layer 1: Dark Sapphire Background
    bg_img = Image.new('RGBA', (width, height), (6, 16, 40, 255))
    
    # Layer 2: Ambient Radial Glow
    aura_img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura_img)
    for r in range(400, 50, -20):
        alpha = int(35 * (1.0 - (r / 400.0)))
        aura_draw.ellipse(
            [width//2 - r, height//2 - r, width//2 + r, height//2 + r],
            fill=(0, 229, 163, alpha)
        )
    aura_img = aura_img.filter(ImageFilter.GaussianBlur(30))
    
    # Layer 3: Squircle Badge
    badge_img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    badge_draw = ImageDraw.Draw(badge_img)
    margin = 160
    badge_draw.rounded_rectangle(
        [margin, margin, width - margin, height - margin],
        radius=140,
        fill=(13, 71, 161, 255)
    )
    
    # Layer 4: Transparent Logo Emblem
    logo_transparent = Image.open(source_png_path).convert('RGBA')
    logo_transparent = logo_transparent.resize((width, height), Image.Resampling.LANCZOS)
    
    # Layer 5: Master Artwork Composite
    artwork_composite = master_img.copy()
    
    layers_data = [
        ('1. Background Canvas', bg_img),
        ('2. Ambient Radial Glow', aura_img),
        ('3. Royal Blue Squircle Badge', badge_img),
        ('4. Rising Growth J Emblem', logo_transparent),
        ('5. Master Composite Logo', artwork_composite),
    ]
    
    header = struct.pack('>4sH6sHIIHH', b'8BPS', 1, b'\x00'*6, 4, height, width, 8, 3)
    color_mode = struct.pack('>I', 0)
    
    # 300 DPI ResolutionInfo
    res_data = struct.pack('>IHHIHH', 300 << 16, 1, 1, 300 << 16, 1, 1)
    res_block = struct.pack('>4sH2sI', b'8BIM', 0x03ED, b'\x00\x00', len(res_data)) + res_data
    image_resources = struct.pack('>I', len(res_block)) + res_block
    
    num_layers = len(layers_data)
    layer_records = b''
    channel_image_data = b''
    
    for name, img in layers_data:
        r, g, b, a = img.split()
        rect = struct.pack('>iiii', 0, 0, height, width)
        channels_count = struct.pack('>H', 4)
        ch_len = 2 + height * width
        channel_info = (
            struct.pack('>hI', 0, ch_len) +
            struct.pack('>hI', 1, ch_len) +
            struct.pack('>hI', 2, ch_len) +
            struct.pack('>hI', -1, ch_len)
        )
        blend_fields = struct.pack('>4s4sBBBB', b'8BIM', b'norm', 255, 0, 0, 0)
        
        name_bytes = name.encode('ascii', 'replace')
        name_len = len(name_bytes)
        pascal_name = struct.pack('B', name_len) + name_bytes
        pad = (4 - (len(pascal_name) % 4)) % 4
        pascal_name += b'\x00' * pad
        
        extra_content = struct.pack('>II', 0, 0) + pascal_name
        extra_len = struct.pack('>I', len(extra_content))
        
        layer_records += rect + channels_count + channel_info + blend_fields + extra_len + extra_content
        
        channel_image_data += (
            struct.pack('>H', 0) + r.tobytes() +
            struct.pack('>H', 0) + g.tobytes() +
            struct.pack('>H', 0) + b.tobytes() +
            struct.pack('>H', 0) + a.tobytes()
        )
        
    layer_info_content = struct.pack('>h', num_layers) + layer_records + channel_image_data
    if len(layer_info_content) % 2 != 0:
        layer_info_content += b'\x00'
    layer_info_block = struct.pack('>I', len(layer_info_content)) + layer_info_content
    layer_mask_section = struct.pack('>I', len(layer_info_block)) + layer_info_block
    
    mr, mg, mb, ma = artwork_composite.split()
    composite_data = struct.pack('>H', 0) + mr.tobytes() + mg.tobytes() + mb.tobytes() + ma.tobytes()
    
    os.makedirs(os.path.dirname(os.path.abspath(out_psd_path)), exist_ok=True)
    with open(out_psd_path, 'wb') as f:
        f.write(header)
        f.write(color_mode)
        f.write(image_resources)
        f.write(layer_mask_section)
        f.write(composite_data)
        
    print(f'Successfully built master PSD: {out_psd_path}')

if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    jpg = os.path.expanduser('~/.gemini/antigravity/brain/1c56f3b4-bc76-4319-b9f6-0e94c02fea9a/jolinx_logo_growth_1791829130592.jpg')
    png = os.path.join(root, 'assets/images/jolinx_logo.png')
    out = os.path.join(root, 'jolinx_logo_master.psd')
    build_jolinx_psd(jpg, png, out)
