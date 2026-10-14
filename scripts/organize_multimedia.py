import os, shutil
import numpy as np
import scipy.ndimage as ndi
from PIL import Image, ImageDraw, ImageFilter

src_jpg = '/home/joberthix/.gemini/antigravity/brain/1c56f3b4-bc76-4319-b9f6-0e94c02fea9a/jolinx_logo_growth_1791829130592.jpg'
src_png = 'assets/images/jolinx_logo.png'
base_dir = 'multimedia/branding/logo'

os.makedirs(f'{base_dir}/master_psd', exist_ok=True)
os.makedirs(f'{base_dir}/individual_layers', exist_ok=True)
os.makedirs(f'{base_dir}/exports/transparent_png', exist_ok=True)
os.makedirs(f'{base_dir}/exports/high_res', exist_ok=True)
os.makedirs(f'{base_dir}/vector', exist_ok=True)

# 1. Copy Master PSD
shutil.copy2('jolinx_logo_master.psd', f'{base_dir}/master_psd/jolinx_logo_master.psd')
print('Copied PSD to multimedia directory.')

# 2. Decompose and save all 16 individual layers as transparent PNGs
orig = Image.open(src_jpg).convert('RGBA')
arr = np.array(orig)
h, w, _ = arr.shape

corners_mask = (arr[:,:,0] > 240) & (arr[:,:,1] > 240) & (arr[:,:,2] > 240)
labeled_corners, _ = ndi.label(corners_mask)
outer_bg_mask = np.zeros((h, w), dtype=bool)
for corner in [(0,0), (0, w-1), (h-1, 0), (h-1, w-1)]:
    lbl_id = labeled_corners[corner[0], corner[1]]
    if lbl_id > 0:
        outer_bg_mask |= (labeled_corners == lbl_id)
badge_mask = ~outer_bg_mask

badge_alpha = ndi.gaussian_filter(badge_mask.astype(float), sigma=1.0)
badge_alpha = np.clip(badge_alpha * 255, 0, 255).astype(np.uint8)

r, g, b = arr[:,:,0].astype(int), arr[:,:,1].astype(int), arr[:,:,2].astype(int)
bright = (r > 190) & (g > 190) & (b > 190) & badge_mask
bright_lbl, n_bright = ndi.label(bright)
sizes = ndi.sum(bright, bright_lbl, range(1, n_bright + 1))

major_indices = [i+1 for i, s in enumerate(sizes) if s > 1000]
boxes = [ndi.find_objects(bright_lbl == idx)[0] for idx in major_indices]
sorted_shapes = sorted(zip(boxes, major_indices), key=lambda x: x[0][1].start)

idx_bar1 = sorted_shapes[0][1]
idx_hook = sorted_shapes[1][1]
idx_bar2 = sorted_shapes[2][1]
idx_stem_arrow = sorted_shapes[3][1]

stem_arrow_mask = (bright_lbl == idx_stem_arrow)
arrow_mask = stem_arrow_mask & (np.arange(h)[:, None] < 360)
stem_mask = stem_arrow_mask & (np.arange(h)[:, None] >= 360)

def mask_to_layer(mask, rgb_src=arr, blur_alpha=1.2, boost_bright=True):
    layer = np.zeros((h, w, 4), dtype=np.uint8)
    dilated = ndi.binary_dilation(mask, iterations=2)
    alpha = ndi.gaussian_filter(dilated.astype(float), sigma=blur_alpha)
    alpha_u8 = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    layer[:, :, :3] = rgb_src[:, :, :3]
    if boost_bright:
        for c in range(3):
            layer[mask, c] = np.clip(rgb_src[mask, c].astype(int) + 20, 0, 255).astype(np.uint8)
    layer[:, :, 3] = alpha_u8
    return Image.fromarray(layer, 'RGBA')

layer_bar1 = mask_to_layer(bright_lbl == idx_bar1)
layer_bar2 = mask_to_layer(bright_lbl == idx_bar2)
layer_hook = mask_to_layer(bright_lbl == idx_hook)
layer_stem = mask_to_layer(stem_mask)
layer_arrow = mask_to_layer(arrow_mask)

particle_mask = np.zeros((h, w), dtype=bool)
for i, s in enumerate(sizes):
    idx = i + 1
    if s <= 1000 and idx not in [idx_bar1, idx_bar2, idx_hook, idx_stem_arrow]:
        particle_mask |= (bright_lbl == idx)
        
rows_grid = np.arange(h)[:, None]
cols_grid = np.arange(w)[None, :]
particles_upper = particle_mask & (rows_grid < 550) & (cols_grid > 450)
particles_ambient = particle_mask & ~particles_upper

layer_particles_ascent = mask_to_layer(particles_upper, blur_alpha=0.8, boost_bright=True)
layer_particles_ambient = mask_to_layer(particles_ambient, blur_alpha=0.8, boost_bright=True)

neon_mask = (g > 140) & (g > r + 20) & (b > 70) & ~bright & badge_mask
layer_neon_glow = mask_to_layer(neon_mask, blur_alpha=3.0, boost_bright=False)

ultra_white_mask = (r > 235) & (g > 235) & (b > 235) & badge_mask
layer_white_core = mask_to_layer(ultra_white_mask, blur_alpha=0.8, boost_bright=True)

badge_container_arr = np.zeros((h, w, 4), dtype=np.uint8)
badge_container_arr[:, :, :3] = arr[:, :, :3]
badge_container_arr[:, :, 3] = badge_alpha
layer_badge_container = Image.fromarray(badge_container_arr, 'RGBA')

white_mat_arr = np.zeros((h, w, 4), dtype=np.uint8)
white_mat_arr[outer_bg_mask] = [255, 255, 255, 255]
layer_white_mat = Image.fromarray(white_mat_arr, 'RGBA')

layer_dark_canvas = Image.new('RGBA', (w, h), (6, 16, 40, 255))

bevel_img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
bevel_draw = ImageDraw.Draw(bevel_img)
for offset in range(8):
    alpha = int(40 - offset * 4)
    bevel_draw.rounded_rectangle([20+offset, 20+offset, w-20-offset, h-20-offset], radius=180, outline=(255, 255, 255, alpha), width=2)
layer_bevel = bevel_img.filter(ImageFilter.GaussianBlur(2))

wordmark_img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
wm_draw = ImageDraw.Draw(wordmark_img)
wm_draw.text((w//2, h - 80), 'JOLINX', fill=(255, 255, 255, 230), anchor='mm')

tagline_img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
tag_draw = ImageDraw.Draw(tagline_img)
tag_draw.text((w//2, h - 45), 'BUSINESS OS', fill=(0, 229, 163, 200), anchor='mm')

layers_dict = {
    '01_canvas_dark_navy_base.png': layer_dark_canvas,
    '02_canvas_studio_white_mat.png': layer_white_mat,
    '03_badge_royal_blue_squircle.png': layer_badge_container,
    '04_badge_specular_glass_bevel.png': layer_bevel,
    '05_aura_emerald_neon_glow.png': layer_neon_glow,
    '06_emblem_growth_bar_1_short.png': layer_bar1,
    '07_emblem_growth_bar_2_medium.png': layer_bar2,
    '08_emblem_j_hook_curve.png': layer_hook,
    '09_emblem_j_stem_ascending.png': layer_stem,
    '10_emblem_apex_arrowhead.png': layer_arrow,
    '11_highlight_metallic_white_shimmer.png': layer_white_core,
    '12_particles_upper_ascent_sparkles.png': layer_particles_ascent,
    '13_particles_ambient_light_flecks.png': layer_particles_ambient,
    '14_typography_jolinx_wordmark.png': wordmark_img,
    '15_typography_business_os_tagline.png': tagline_img,
    '16_reference_master_composite.png': orig
}

for fname, img in layers_dict.items():
    img.save(f'{base_dir}/individual_layers/{fname}')

print(f'Exported {len(layers_dict)} individual layers as PNG.')

# 3. Export Transparent Emblem sizes
transparent_master = Image.open(src_png).convert('RGBA')
sizes = [1024, 512, 256, 128, 64, 32]
for s in sizes:
    resized = transparent_master.resize((s, s), Image.Resampling.LANCZOS)
    resized.save(f'{base_dir}/exports/transparent_png/jolinx_emblem_{s}x{s}.png')

# Full badge high-res exports
orig.save(f'{base_dir}/exports/high_res/jolinx_badge_master_1024x1024.png')
orig.resize((512, 512), Image.Resampling.LANCZOS).save(f'{base_dir}/exports/high_res/jolinx_badge_512x512.png')

print('All exports created successfully.')
