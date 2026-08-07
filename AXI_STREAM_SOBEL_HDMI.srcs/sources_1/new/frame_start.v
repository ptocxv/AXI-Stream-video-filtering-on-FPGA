`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/07/2026 03:34:45 PM
// Design Name: 
// Module Name: frame_start
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module frame_start (
    input  wire s_axis_tvalid,
    input  wire s_axis_tready,
    input  wire s_axis_tuser,
    output wire frame_start_fire
);

    assign frame_start_fire =
        s_axis_tvalid &&
        s_axis_tready &&
        s_axis_tuser;

endmodule
