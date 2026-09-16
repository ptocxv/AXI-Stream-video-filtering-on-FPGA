`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/14/2026 01:05:04 PM
// Design Name: 
// Module Name: axis_ila_package
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


module axis_ila_package(
    input [23:0] s_axis_tdata,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tuser,
    input s_axis_tlast,
    
    output [23:0] m_axis_tdata,
    output m_axis_tvalid,
    input m_axis_tready,
    output m_axis_tuser,
    output m_axis_tlast,
    
    output [23:0] axis_data_out,
    output [3:0] axis_control_out
    
    );
    
    assign m_axis_tdata = s_axis_tdata;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tuser = s_axis_tuser;
    assign m_axis_tlast = s_axis_tlast;
    
    assign axis_data_out = s_axis_tdata;
    assign axis_control_out = {s_axis_tvalid, s_axis_tready, s_axis_tuser, s_axis_tlast};
    
endmodule
