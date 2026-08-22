from pathlib import Path
import random


# ============================================================
# Test configuration
# ============================================================

WIDTH = 1920
HEIGHT = 1080
SEED = 11025


# ============================================================
# Output paths
# ============================================================

# Assumption:
# This script is located somewhere under the project directory
# such that parents[1] points to the repository root.
PROJECT_ROOT = Path(__file__).resolve().parents[1]

OUT_DIR = PROJECT_ROOT / "ref" / "tb_data"
OUT_DIR.mkdir(parents=True, exist_ok=True)

INPUT_FILE = OUT_DIR / "processing_core_input.txt"
EXPECTED_FILE = OUT_DIR / "processing_core_expected.txt"


# ============================================================
# Helper functions
# ============================================================

def pack_rbg(red, blue, green):
    """
    Pack a pixel according to the current RTL channel order:

        bits [23:16] = red
        bits [15:8]  = blue
        bits [7:0]   = green

    This is RBG ordering, matching the current axis_grayscale RTL.
    """

    return (
        ((red & 0xFF) << 16)
        | ((blue & 0xFF) << 8)
        | (green & 0xFF)
    )


def replicate_gray(value):
    """
    Replicate an 8-bit grayscale value across a 24-bit pixel:

        {gray, gray, gray}
    """

    value = value & 0xFF

    return (
        (value << 16)
        | (value << 8)
        | value
    )


def calculate_gray(red, blue, green):
    """
    Match the fixed-point RTL grayscale calculation:

        gray = (77*R + 150*G + 29*B) >> 8
    """

    gray_value = (
        77 * red
        + 150 * green
        + 29 * blue
    ) >> 8

    return gray_value & 0xFF


def calculate_sobel(
    gray_row_minus_2,
    gray_row_minus_1,
    gray_current_row,
    x
):
    """
    Calculate Sobel magnitude for the 3x3 window ending at
    coordinate (y, x).

    Window mapping:

        p00 p01 p02
        p10 p11 p12
        p20 p21 p22

    The current input pixel is p22.
    The Sobel result represents the center pixel p11.
    """

    p00 = gray_row_minus_2[x - 2]
    p01 = gray_row_minus_2[x - 1]
    p02 = gray_row_minus_2[x]

    p10 = gray_row_minus_1[x - 2]
    p11 = gray_row_minus_1[x - 1]
    p12 = gray_row_minus_1[x]

    p20 = gray_current_row[x - 2]
    p21 = gray_current_row[x - 1]
    p22 = gray_current_row[x]

    gx = (
        -p00
        + p02
        - 2 * p10
        + 2 * p12
        - p20
        + p22
    )

    gy = (
        -p00
        - 2 * p01
        - p02
        + p20
        + 2 * p21
        + p22
    )

    magnitude = abs(gx) + abs(gy)

    if magnitude > 255:
        magnitude = 255

    return magnitude & 0xFF


# ============================================================
# Generate random frame and reference files
# ============================================================

random.seed(SEED)

num_outputs = WIDTH * HEIGHT

# Only the previous two grayscale rows and one previous RGB row
# are retained. This is more memory-efficient than retaining a
# complete 1080p frame in Python.
gray_row_minus_2 = None
gray_row_minus_1 = None
rbg_row_minus_1 = None


with INPUT_FILE.open("w", encoding="utf-8") as input_file, \
        EXPECTED_FILE.open("w", encoding="utf-8") as expected_file:

    # ------------------------------------------------------------
    # File headers
    # ------------------------------------------------------------

    input_file.write(
        "{} {}\n".format(WIDTH, HEIGHT)
    )

    expected_file.write(
        "{} {} {}\n".format(
            WIDTH,
            HEIGHT,
            num_outputs
        )
    )

    # ------------------------------------------------------------
    # Generate frame row by row
    # ------------------------------------------------------------

    for y in range(HEIGHT):

        current_rbg_row = []
        current_gray_row = []

        # --------------------------------------------------------
        # Generate the input pixels for this row
        # --------------------------------------------------------

        for x in range(WIDTH):

            red = random.randint(0, 255)
            blue = random.randint(0, 255)
            green = random.randint(0, 255)

            current_rbg_row.append(
                (red, blue, green)
            )

            gray_value = calculate_gray(
                red,
                blue,
                green
            )

            current_gray_row.append(
                gray_value
            )

            packed_input = pack_rbg(
                red,
                blue,
                green
            )

            input_file.write(
                "{:06X}\n".format(packed_input)
            )

        # --------------------------------------------------------
        # Generate the expected outputs for this row
        # --------------------------------------------------------

        for x in range(WIDTH):

            if (
                y >= 2
                and x >= 2
                and gray_row_minus_2 is not None
                and gray_row_minus_1 is not None
                and rbg_row_minus_1 is not None
            ):
                # ------------------------------------------------
                # Sobel output for window ending at (y, x)
                # ------------------------------------------------

                edge_value = calculate_sobel(
                    gray_row_minus_2,
                    gray_row_minus_1,
                    current_gray_row,
                    x
                )

                sobel_rgb = replicate_gray(
                    edge_value
                )

                # ------------------------------------------------
                # Aligned grayscale output
                #
                # The window center p11 is at:
                #
                #     (y - 1, x - 1)
                # ------------------------------------------------

                center_gray = gray_row_minus_1[x - 1]

                grayscale_rgb = replicate_gray(
                    center_gray
                )

                # ------------------------------------------------
                # Aligned original RBG output
                # ------------------------------------------------

                center_red, center_blue, center_green = (
                    rbg_row_minus_1[x - 1]
                )

                original_rgb = pack_rbg(
                    center_red,
                    center_blue,
                    center_green
                )

            else:
                # Match the current RTL border behavior.
                sobel_rgb = 0
                grayscale_rgb = 0
                original_rgb = 0

            # TUSER marks the first output transaction.
            if y == 0 and x == 0:
                user = 1
            else:
                user = 0

            # TLAST marks the final output pixel of every line.
            if x == WIDTH - 1:
                last = 1
            else:
                last = 0

            expected_file.write(
                "{:06X} {:06X} {:06X} {} {}\n".format(
                    sobel_rgb,
                    grayscale_rgb,
                    original_rgb,
                    user,
                    last
                )
            )

        # --------------------------------------------------------
        # Advance reference line buffers
        # --------------------------------------------------------

        gray_row_minus_2 = gray_row_minus_1
        gray_row_minus_1 = current_gray_row
        rbg_row_minus_1 = current_rbg_row


# ============================================================
# Validate generated file lengths
# ============================================================

expected_input_lines = num_outputs + 1
expected_output_lines = num_outputs + 1


with INPUT_FILE.open("r", encoding="utf-8") as input_file:
    actual_input_lines = sum(1 for _ in input_file)


with EXPECTED_FILE.open("r", encoding="utf-8") as expected_file:
    actual_output_lines = sum(1 for _ in expected_file)


if actual_input_lines != expected_input_lines:
    raise RuntimeError(
        "Incorrect input-file line count: "
        "generated={}, expected={}".format(
            actual_input_lines,
            expected_input_lines
        )
    )


if actual_output_lines != expected_output_lines:
    raise RuntimeError(
        "Incorrect expected-file line count: "
        "generated={}, expected={}".format(
            actual_output_lines,
            expected_output_lines
        )
    )


# ============================================================
# Validate the file headers
# ============================================================

with INPUT_FILE.open("r", encoding="utf-8") as input_file:
    input_header = input_file.readline().strip()


with EXPECTED_FILE.open("r", encoding="utf-8") as expected_file:
    expected_header = expected_file.readline().strip()


required_input_header = "{} {}".format(
    WIDTH,
    HEIGHT
)

required_expected_header = "{} {} {}".format(
    WIDTH,
    HEIGHT,
    num_outputs
)


if input_header != required_input_header:
    raise RuntimeError(
        "Incorrect input header: generated='{}', expected='{}'".format(
            input_header,
            required_input_header
        )
    )


if expected_header != required_expected_header:
    raise RuntimeError(
        "Incorrect expected header: generated='{}', expected='{}'".format(
            expected_header,
            required_expected_header
        )
    )


# ============================================================
# Summary
# ============================================================

print()
print("Generated processing-core test vectors")
print("======================================")
print("Input file       : {}".format(INPUT_FILE))
print("Expected file    : {}".format(EXPECTED_FILE))
print("Frame dimensions : {} x {}".format(WIDTH, HEIGHT))
print("Input pixels     : {:,}".format(num_outputs))
print("Expected outputs : {:,}".format(num_outputs))
print("Random seed      : {}".format(SEED))
print()
print("Input lines      : {:,}".format(actual_input_lines))
print("Expected lines   : {:,}".format(actual_output_lines))
print()
print("Input header     : {}".format(input_header))
print("Expected header  : {}".format(expected_header))
print()
print("Expected-file fields:")
print(
    "  SOBEL_RGB GRAYSCALE_RGB ORIGINAL_RGB USER LAST"
)
print()
print("Pixel channel order:")
print("  bits [23:16] = red")
print("  bits [15:8]  = blue")
print("  bits [7:0]   = green")
print()
print("Generation completed successfully.")