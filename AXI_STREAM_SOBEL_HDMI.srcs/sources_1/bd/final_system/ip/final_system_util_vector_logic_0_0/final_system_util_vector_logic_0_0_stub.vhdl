-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
-- Date        : Thu Jul 16 12:45:26 2026
-- Host        : DESKTOP-T3NL2RB running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               d:/KU_Leuven/FPGA/.Flagship/AXI_STREAM_SOBEL/AXI_STREAM_SOBEL_HDMI/AXI_STREAM_SOBEL_HDMI.gen/sources_1/bd/final_system/ip/final_system_util_vector_logic_0_0/final_system_util_vector_logic_0_0_stub.vhdl
-- Design      : final_system_util_vector_logic_0_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z020clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity final_system_util_vector_logic_0_0 is
  Port ( 
    Op1 : in STD_LOGIC_VECTOR ( 0 to 0 );
    Res : out STD_LOGIC_VECTOR ( 0 to 0 )
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of final_system_util_vector_logic_0_0 : entity is "final_system_util_vector_logic_0_0,util_vector_logic_v2_0_5_util_vector_logic,{}";
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of final_system_util_vector_logic_0_0 : entity is "final_system_util_vector_logic_0_0,util_vector_logic_v2_0_5_util_vector_logic,{x_ipProduct=Vivado 2025.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=util_vector_logic,x_ipVersion=2.0,x_ipCoreRevision=5,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_OPERATION=not,C_SIZE=1}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of final_system_util_vector_logic_0_0 : entity is "yes";
end final_system_util_vector_logic_0_0;

architecture stub of final_system_util_vector_logic_0_0 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "Op1[0:0],Res[0:0]";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of stub : architecture is "util_vector_logic_v2_0_5_util_vector_logic,Vivado 2025.1";
begin
end;
