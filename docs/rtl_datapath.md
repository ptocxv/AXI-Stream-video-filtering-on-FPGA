# RTL Datapath
This document focuses on the video processing core calculations and per-stage responsibilities. Detailed information about clock-domain-crossing configuration with video_control_axi peripheral is in ["cdc_configuration.md"](cdc_configuration.md).

## 1. Grayscale conversion

The grayscale stage uses fixed-point integer arithmetic:

```text
Gray = (77 × Red + 150 × Green + 29 × Blue) >> 8
```

The coefficients approximate:

```text
0.299 × Red + 0.587 × Green + 0.114 × Blue
```

The implementation avoids floating-point arithmetic and is pipelined for streaming operation.

## 2. Window 3x3 generation

The window generator reconstructs:

```text
p00  p01  p02
p10  p11  p12
p20  p21  p22
```

The newest accepted input pixel is `p22`, while the Sobel result represents the center pixel `p11`.

For an input completing a window at coordinate `(row, column)`:

```text
p22 = (row, column)
p11 = (row - 1, column - 1)
p00 = (row - 2, column - 2)
```

### Grayscale line buffers

```text
Current grayscale pixel
        │
        ├──────────────────────────────→ rr2
        │
        ▼
      BRAM0
        │
        └──────────────────────────────→ rr1
        │
        ▼
      BRAM1
        │
        └──────────────────────────────→ rr0
```

The registered vertical column is:

```text
rr0 = two rows earlier, current column
rr1 = one row earlier, current column
rr2 = current row, current column
```

The previous two horizontal columns are retained by shift registers:

```text
r00  r01  rr0
r10  r11  rr1
r20  r21  rr2
```

### Registered coordinates

The module maintains two coordinate pairs:

```text
cntH and cntV
→ coordinate of the next accepted input transaction

rCol and rRow
→ coordinate associated with the registered rr0/rr1/rr2 transaction
```

Window completeness is calculated from the registered coordinates:

```verilog
window_valid =
    rValid &&
    (rRow >= 2) &&
    (rCol >= 2);
```

Using `rCol` and `rRow` prevents the current input coordinate from being mixed with the preceding registered window.

### Original-pixel alignment

The original-pixel path uses one line delay and one horizontal delay:

```text
Current original pixel
        │
        ▼
RBG_BRAM
        │
        ▼
rbg12
previous row, current column
        │
        ▼
rbg11
previous row, previous column
        │
        ▼
rbg_out
aligned window-center output
```

At the first complete window:

```text
p0   p1   p2
p4   p5   p6
p8   p9   p10
```

the aligned original output is `p5`.

### Border policy

A complete 3x3 window exists only when:

```text
row >= 2 && column >= 2
```

The first two rows and first two columns are therefore output as black.

The design does not discard border transactions:

```text
1920 × 1080 accepted input pixels
→ 1920 × 1080 output transactions
```

Preserving the full transaction count keeps the active frame dimensions compatible with downstream video timing.

## 3. Sobel processing

The Sobel kernels are:

```text
    (Gx)                (Gy)

-1   0   1           -1  -2  -1
-2   0   2            0   0   0
-1   0   1            1   2   1
```

The RTL calculates:

```text
Gx = -p00 + p02
    -2p10 + 2p12
    -p20 + p22
```

```text
Gy = -p00 - 2p01 - p02
    +p20 + 2p21 + p22
```

The magnitude approximation is:

```text
Magnitude = |Gx| + |Gy|
```

Values greater than `255` are saturated to `255`.

The arithmetic is split into registered stages:

```text
Partial gradient terms
→ complete Gx and Gy
→ absolute values
→ magnitude addition
→ saturation and output registration
```

This division allows the pipeline to sustain one pixel per enabled clock at approximately 148.5 MHz.

## 4. Filter out

The `axis_filter_out` module receives the aligned outputs from the processing chain, together with the active mode and threshold values from `video_config_cdc`.

Based on the active configuration, the module selects the final AXI4-Stream pixel sent toward the HDMI output:

```text
case(mode)
        2'b00: begin
            m_axis_tdata <= s_axis_tdata;
            // ...control signals update
        end
        2'b01: begin
            m_axis_tdata <= (s_axis_tdata[7:0] > threshold) ? 24'hffffff : 24'h000000;
            // ...control signals update
        end
        2'b10: begin
            m_axis_tdata <= grayscale_data;
            // ...control signal update
        end
        2'b11: begin
            m_axis_tdata <= rbg_data;
            // ...control signal update
        end
        default: begin
            m_axis_tdata <= 24'hbc1501;
            // ...control signal update
        end
endcase
```

The active mode determines which processing result is selected. The active threshold is used when thresholded Sobel mode is selected.

The module also generates an accepted frame-start event:

```verilog
assign sof_out = s_axis_tvalid && s_axis_tready && s_axis_tuser;
```

This event is fed back to `video_config_cdc` as `sof_fire`:

```text
if (config_pending_pixel && sof_fire) begin
        // update active data
        active_mode_pixel <= pending_mode_pixel;
        active_threshold_pixel <= pending_threshold_pixel;
        
        // reset pending config mark
        config_pending_pixel <= 1'b0;
        
        // acknowledge the request that has now become active.
        cfg_ack_toggle_pixel <= req_seen_pixel;
end
```

Using `TVALID`, `TREADY`, and `TUSER` ensures that configuration activation is tied to the actual AXI4-Stream handshake of the first frame pixel. A presented but stalled start-of-frame transaction does not activate the pending configuration until the transaction is accepted.
