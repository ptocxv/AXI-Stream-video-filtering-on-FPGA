# PS-controlled 1080p60 FPGA Video Processor
A real-time FPGA video pipeline that captures live HDMI input, converts it into a custom AXI-Stream pixel bus, and runs grayscale conversion + Sobel edge detection on every frame — with the output mode and edge threshold controllable at runtime from the Zynq PS over UART.

Built on a **PYNQ-Z2** board (Xilinx Zynq-7020, `xc7z020clg400-1`) in Vivado, mixing hand-written Verilog datapath IP with Xilinx/Digilent video IP (`dvi2rgb`, `rgb2dvi`, `v_tc`, `v_axi4s_vid_out`) and the Zynq Processing System.

## Features

- **Live HDMI passthrough pipeline** — HDMI Rx → AXI-Stream video → processing core → AXI-Stream video → HDMI Tx, entirely in the PL.
- **4 selectable output modes**, switchable on the fly without reconfiguring the bitstream:
  | Mode | Value | Output |
  |------|-------|--------|
  | Sobel magnitude | `0b00` | Full-range gradient magnitude |
  | Thresholded Sobel | `0b01` | Binarized edges (white/black) against an adjustable threshold |
  | Grayscale | `0b10` | Grayscale passthrough (no edge detection) |
  | Original | `0b11` | Unmodified RGB passthrough |
- **Runtime control from software** — a custom AXI-Lite peripheral (`video_control_axi`) exposes mode and threshold registers; a bare-metal C program running on the Zynq PS lets you change them interactively over a UART terminal.
- **Safe, glitch-free config updates across clock domains** — mode/threshold changes are handshaked from the AXI clock domain into the pixel clock domain and applied atomically at the start of a frame (`video_config_cdc.v`, `frame_start.v`), so you never see a config change mid-frame.
- **Pipelined, BRAM-based 3×3 window generator** — two line buffers (`BRAM style="block"`) generate a full 3×3 pixel neighborhood per cycle for arbitrary frame sizes (parameterized `FRAME_WIDTH` / `FRAME_HEIGHT`).
- **5-stage pipelined Sobel core** computing `Gx`, `Gy`, `|Gx| + |Gy|` (approximate magnitude) with saturation to 8 bits.
- **SystemVerilog testbenches** for the grayscale, window-generator, and Sobel stages, plus a Python golden-reference generator for full-pipeline verification.
- **Two prebuilt hardware exports** (`.xsa`) for Vitis, targeting 720p and 1080p configurations.

## Architecture

### System overview

The full system: HDMI in → AXI-Stream conversion → processing core → AXI-Stream conversion → HDMI out, with the Zynq PS supervising configuration over AXI-Lite.

### Processing core

The core pixel pipeline instantiated inside the system above:

```
                         ┌────────────┐
   HDMI Rx ──dvi2rgb──▶  │ v_axi4s_   │  AXI-Stream video
   (TMDS)                │ vid_in     │ ────────────┐
                         └────────────┘              │
                                                      ▼
                                          ┌───────────────────────┐
                                          │  axis_grayscale        │  8-bit luma
                                          └───────────┬───────────┘
                                                      ▼
                                          ┌───────────────────────┐
                                          │ axis_window_3x3_       │  72-bit 3x3
                                          │ generator (line bufs)  │  window
                                          └───────────┬───────────┘
                                                      ▼
                                          ┌───────────────────────┐
                                          │  axis_sobel             │  24-bit
                                          │  (5-stage pipeline)     │  magnitude
                                          └───────────┬───────────┘
                                                      ▼
                                          ┌───────────────────────┐
                                          │  axis_filter_out        │◀── mode/threshold
                                          │  (mode mux)             │    (from CDC)
                                          └───────────┬───────────┘
                                                      ▼
                         ┌────────────┐   AXI-Stream video
   HDMI Tx ◀──rgb2dvi──  │ v_axi4s_   │ ◀────────────┘
   (TMDS)                │ vid_out    │
                         └────────────┘

   Zynq PS ──AXI-Lite──▶ video_control_axi ──cfg_req/ack (toggle, CDC)──▶ video_config_cdc
                                                                              │
                                                                              ▼
                                                                     active_mode / active_threshold
                                                                     (applied at frame_start)
```

## Repository layout

```
AXI_STREAM_SOBEL_HDMI.srcs/
├── sources_1/
│   ├── new/                     # Hand-written Verilog datapath modules
│   │   ├── axis_grayscale.v
│   │   ├── axis_window_3x3_generator.v
│   │   ├── axis_sobel.v
│   │   ├── axis_filter_out.v
│   │   ├── video_config_cdc.v
│   │   ├── frame_start.v
│   │   └── logic0.v / logic1.v  # tie-off helper IP
│   └── bd/
│       ├── processing_core/     # Block design: the pixel-processing datapath
│       └── final_system/        # Block design: full system incl. Zynq PS, HDMI IP
├── constrs_1/new/
│   └── axis_stream_sobel_hdmi.xdc   # PYNQ-Z2 pin/clock constraints
└── sim_1/new/
    ├── grayscale_TB.sv
    ├── window_3x3_generator_TB.sv
    └── sobel_TB.sv

ip_repo/
├── video_control_axi_1_0/       # Custom AXI-Lite control peripheral (HDL + drivers + GUI)
└── vivado-library-master/       # Digilent IP library (dvi2rgb, rgb2dvi, etc. used from here)

software/
└── main.c                       # Bare-metal (standalone/Vitis) UART control application

export/
├── PS_sobel_hdmi.xsa             # Hardware platform export (720p)
└── PS_sobel_hdmi_1080p.xsa       # Hardware platform export (1080p)

ref/
├── gen_processing_core_ref.py    # Generates golden input/expected vectors for the core
└── tb_data/                      # Vectors consumed by the SV testbenches

AXI_STREAM_SOBEL_HDMI.xpr         # Vivado project file
```

## Datapath modules

| Module | Role |
|---|---|
| `axis_grayscale.v` | Converts 24-bit RGB AXI-Stream pixels to 8-bit luma. |
| `axis_window_3x3_generator.v` | Buffers two prior lines in BRAM and streams out a registered 3×3 neighborhood (`72'b` = 9 × 8-bit taps) per accepted pixel, alongside a delayed copy of the original RGB pixel. Parameterized by `FRAME_WIDTH` / `FRAME_HEIGHT`. |
| `axis_sobel.v` | 5-stage pipeline: computes `Gx`/`Gy` from the 3×3 window, takes `|Gx| + |Gy|`, saturates to 8 bits, and forwards the grayscale and original-RGB pixels in lockstep for the mode mux downstream. |
| `axis_filter_out.v` | Final AXI-Stream mux — selects Sobel magnitude, thresholded Sobel, grayscale, or original RGB based on the currently active (CDC'd) mode/threshold. Also derives `frame_start` from `tuser`. |
| `video_config_cdc.v` | Two-flop synchronizer + toggle handshake that safely crosses `mode`/`threshold` writes from the AXI-Lite clock domain into the pixel clock domain, applying them atomically on the next `frame_start`. |
| `frame_start.v` | Detects the first active pixel of a frame (`tvalid && tready && tuser`). |
| `video_config_cdc` handshake partner | `video_control_axi` (in `ip_repo/`) — see register map below. |

## AXI-Lite control interface (`video_control_axi`)

Memory-mapped over AXI-Lite at `XPAR_VIDEO_CONTROL_AXI_0_BASEADDR`.

| Offset | Register | Description |
|---|---|---|
| `0x00` | `CONTROL_SHADOW` | Shadow copy of the requested mode (bits `[2:1]`). Written before issuing `APPLY_CONFIG`. |
| `0x04` | `THRESHOLD_SHADOW` | Shadow copy of the requested threshold (bits `[7:0]`). |
| `0x08` | `COMMAND` | Write `0x1` (`APPLY_CONFIG`) to request the shadow config be pushed to the pixel domain. |
| `0x10` | `STATUS` | Bit 0 = `BUSY` — set while a request is crossing clock domains / awaiting frame boundary. |
| `0x14` | `ACTIVE_CONFIG` | Currently active mode/threshold in the pixel domain (read back to confirm application). |
| `0x1C` | `CORE_ID` | Fixed identifier (`0x534F424C`, ASCII `"SOBL"`) — sanity-checked by software at boot. |

Flow: write `CONTROL_SHADOW`/`THRESHOLD_SHADOW` → write `COMMAND = APPLY_CONFIG` → poll `STATUS.BUSY` until clear → read back `ACTIVE_CONFIG` to confirm.

## Software control app (`software/main.c`)

A bare-metal Vitis/standalone application that:

1. Reads `CORE_ID` at boot and halts if it doesn't match `video_control_axi`, confirming the expected peripheral is present.
2. Prints an interactive UART menu (via `xil_printf` / `inbyte`, e.g. over PuTTY):

   ```
   0  - Sobel magnitude
   1  - Thresholded Sobel
   2  - Grayscale
   3  - Original
   +  - Increase threshold by 10
   -  - Decrease threshold by 10
   s  - Show active configuration
   h  - Show this help menu
   ```
3. On each command, writes the new mode/threshold through the register sequence above and verifies the change was actually applied before reporting success.

## Verification

- **Unit-level SystemVerilog testbenches** (`sim_1/new/`) exercise `axis_grayscale`, `axis_window_3x3_generator`, and `axis_sobel` in isolation.
- **`ref/gen_processing_core_ref.py`** generates a reproducible (seeded) synthetic RGB frame plus the expected grayscale/Sobel output, writing both to `ref/tb_data/` as vectors the testbench (`processing_core_TB`) can check against — a lightweight golden-model approach to catch pipeline/timing bugs before hardware bring-up.

## Getting started

**Prerequisites:** Vivado (matching the version used to create `AXI_STREAM_SOBEL_HDMI.xpr`), a PYNQ-Z2 board, and Vitis if you want to rebuild the software application.

1. Clone the repo and open `AXI_STREAM_SOBEL_HDMI.xpr` in Vivado.
2. Vivado should pick up `ip_repo/` automatically as an IP repository; if not, add it manually (`Tools → Settings → IP → Repository`).
3. Generate the block design outputs, run synthesis + implementation, and generate the bitstream for the `impl_1` run (target part `xc7z020clg400-1`).
4. Export hardware (include bitstream) to produce an `.xsa`, or use the prebuilt `export/PS_sobel_hdmi.xsa` (720p) / `export/PS_sobel_hdmi_1080p.xsa` (1080p) directly.
5. In Vitis, create a platform from the `.xsa` and a new application project pointing at `software/main.c`.
6. Connect an HDMI source to the board's HDMI Rx port and a monitor to HDMI Tx, plus a UART terminal (115200 baud) to interact with the control app.
7. Program the board, open the UART terminal, and use the `0`–`3`/`+`/`-`/`s`/`h` commands to switch modes and tune the edge threshold live.

## Hardware target

- **Board:** Digilent PYNQ-Z2
- **Part:** `xc7z020clg400-1` (Zynq-7020)
- **Video I/O:** Dual HDMI (Rx via `dvi2rgb`, Tx via `rgb2dvi`, both from the Digilent `vivado-library`)
- Pixel clock and the Zynq's AXI clock (`clk_fpga_0`) are treated as asynchronous (`set_clock_groups -asynchronous`), which is why the config CDC path exists.

## License

No license file is currently included for this project's own sources. `ip_repo/vivado-library-master/` (Digilent's IP) carries its own `License.txt`; see that file for terms covering the HDMI IP.
