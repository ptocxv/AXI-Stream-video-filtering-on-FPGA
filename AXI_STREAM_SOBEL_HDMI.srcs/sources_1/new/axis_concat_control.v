`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/14/2026 01:01:24 PM
// Design Name: 
// Module Name: axis_concat_control
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


module axis_concat_control(
    
    input axis_tvalid,
    input axis_tready,
    input axis_tuser,
    input axis_tlast,
    
    output [3:0] axis_concat_control_out
        
    );
    
    assign axis_concat_control_out = {axis_tvalid, axis_tready, axis_tuser, axis_tlast};
    
endmodule
