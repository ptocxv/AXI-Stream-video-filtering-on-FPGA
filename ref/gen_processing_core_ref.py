from pathlib import Path
import random

WIDTH = 1280
HEIGHT = 720
SEED = 11021

# Output paths
PROJECT_ROOT = Path(__file__).resolve().parents[1]

OUT_DIR = PROJECT_ROOT / "ref" / "tb_data"
OUT_DIR.mkdir(parents=True, exist_ok=True)

INPUT_FILE = OUT_DIR / "processing_core_input.txt"
EXPECTED_FILE = OUT_DIR / "processing_core_expected.txt"

random.seed(SEED)

#===========================
# Generate random RGB frame
rgb = []

for y in range(HEIGHT):
    row = []
    for x in range(WIDTH):
        r = random.randint(0, 255)
        g = random.randint(0, 255)
        b = random.randint(0, 255)
        row.append((r, b, g))
    rgb.append(row)

#===========================
# Grayscale reference
gray = []

for y in range(HEIGHT):
    row = []
    for x in range(WIDTH):
        r, b, g = rgb[y][x]
        gray_val = (77 * r + 150 * g + 29 * b) >> 8
        row.append(gray_val & 0xFF)
    gray.append(row)

#===========================
# Sobel reference
# Window ending at position (y, x):
def sobel_at(y, x):
    p00 = gray[y - 2][x - 2]
    p01 = gray[y - 2][x - 1]
    p02 = gray[y - 2][x]

    p10 = gray[y - 1][x - 2]
    p11 = gray[y - 1][x - 1]
    p12 = gray[y - 1][x]

    p20 = gray[y][x - 2]
    p21 = gray[y][x - 1]
    p22 = gray[y][x]

    gx = (
        -p00 + p02
        - 2 * p10 + 2 * p12
        - p20 + p22
    )

    gy = (
        -p00 - 2 * p01 - p02
        + p20 + 2 * p21 + p22
    )

    mag = abs(gx) + abs(gy)

    if mag > 255:
        return 255

    return mag & 0xFF

#===========================
# Write input RGB file
# File:
#   processing_core_input.txt
# Format:
#   WIDTH HEIGHT
#   RGB_HEX
#   RGB_HEX
#   ...

with open(INPUT_FILE, "w") as f:
    f.write(f"{WIDTH} {HEIGHT}\n")

    for y in range(HEIGHT):
        for x in range(WIDTH):
            r, b, g = rgb[y][x]
            packed_rgb = (r << 16) | (b << 8) | g
            f.write(f"{packed_rgb:06X}\n")

#===========================
# Write expected output file 
# File: processing_core_expected.txt
# Format:
#   WIDTH HEIGHT NUM_OUTPUTS
#   EDGE USER LAST
#   EDGE USER LAST
# user: 1 only for the first valid output window
# last: 1 for the last valid output of each output line

num_outputs = (WIDTH - 2) * (HEIGHT - 2)

with open(EXPECTED_FILE, "w") as f:
    f.write(f"{WIDTH} {HEIGHT} {num_outputs}\n")

    for y in range(2, HEIGHT):
        for x in range(2, WIDTH):
            edge = sobel_at(y, x)

            user = 1 if (y == 2 and x == 2) else 0
            last = 1 if (x == WIDTH - 1) else 0

            f.write(f"{edge} {user} {last}\n")

# ============================================================
# Summary
# ============================================================

print("Generated processing core test vectors")
print(f"Input file       : {INPUT_FILE}")
print(f"Expected file    : {EXPECTED_FILE}")
print(f"Frame size       : {WIDTH}x{HEIGHT}")
print(f"Input pixels     : {WIDTH * HEIGHT}")
print(f"Expected outputs : {num_outputs}")
print(f"Seed             : {SEED}")