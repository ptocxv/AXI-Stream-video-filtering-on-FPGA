-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
-- Date        : Thu Jul 16 12:45:26 2026
-- Host        : DESKTOP-T3NL2RB running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode funcsim
--               d:/KU_Leuven/FPGA/.Flagship/AXI_STREAM_SOBEL/AXI_STREAM_SOBEL_HDMI/AXI_STREAM_SOBEL_HDMI.gen/sources_1/bd/final_system/ip/final_system_util_vector_logic_0_0/final_system_util_vector_logic_0_0_sim_netlist.vhdl
-- Design      : final_system_util_vector_logic_0_0
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xc7z020clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity final_system_util_vector_logic_0_0 is
  port (
    Op1 : in STD_LOGIC_VECTOR ( 0 to 0 );
    Res : out STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of final_system_util_vector_logic_0_0 : entity is true;
  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of final_system_util_vector_logic_0_0 : entity is "final_system_util_vector_logic_0_0,util_vector_logic_v2_0_5_util_vector_logic,{}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of final_system_util_vector_logic_0_0 : entity is "yes";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of final_system_util_vector_logic_0_0 : entity is "util_vector_logic_v2_0_5_util_vector_logic,Vivado 2025.1";
end final_system_util_vector_logic_0_0;

architecture STRUCTURE of final_system_util_vector_logic_0_0 is
begin
\Res[0]_INST_0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => Op1(0),
      O => Res(0)
    );
end STRUCTURE;
