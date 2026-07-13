# AXI-Stream Sobel HDMI

A real-time FPGA video processing system that receives live HDMI input, converts the active video stream into an AXI-Stream-style pixel pipeline, applies grayscale conversion, 3×3 window generation, and Sobel edge detection, then outputs the processed edge-detected frames back to an HDMI monitor.

## System Overview

The target system flow is:

<img width="348" height="791" alt="SYSTEMOVERVIEW22222" src="https://github.com/user-attachments/assets/80c4142e-57e1-401d-8d61-6d822df1e656" />


## Processing Core Overview

The specific processing flow is:

<img width="348" height="477" alt="PROCESSINGCORE2222" src="https://github.com/user-attachments/assets/bc87fd89-c903-4ac9-a26a-9e409c9b7b88" />

