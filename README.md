# AXI-Stream Sobel HDMI

A real-time FPGA video processing project using an AXI-Stream-style architecture. The goal is to rebuild a previous coordinate-based Sobel/video design into a cleaner, more reusable streaming pipeline that can later adapt to real HDMI or camera input.

## System Overview

The target system flow is:

<img width="348" height="791" alt="SYSTEMOVERVIEW22222" src="https://github.com/user-attachments/assets/80c4142e-57e1-401d-8d61-6d822df1e656" />


## Processing Core Overview

The specific processing flow is:

<img width="348" height="477" alt="PROCESSINGCORE2222" src="https://github.com/user-attachments/assets/bc87fd89-c903-4ac9-a26a-9e409c9b7b88" />

