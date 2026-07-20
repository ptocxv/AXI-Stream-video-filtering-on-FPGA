`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/06/2026 11:21:25 AM
// Design Name: 
// Module Name: axis_grayscale
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


module axis_grayscale(
    // clk & rst
    input clk,
    input rst,
    
    // up stream / as-slave side
    input [23:0] s_axis_tdata,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tuser,
    input s_axis_tlast,
    
    // down stream / as-master side
    output reg [7:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input m_axis_tready,
    output reg m_axis_tuser,
    output reg m_axis_tlast
    );
    
    //grayscale calculation
    wire [7:0] r_in;
    wire [7:0] b_in;
    wire [7:0] g_in;
    assign r_in = s_axis_tdata[23:16];
    assign b_in = s_axis_tdata[15:8];
    assign g_in = s_axis_tdata[7:0];
    
    wire [15:0] r_mult;
    wire [15:0] b_mult;
    wire [15:0] g_mult;
    assign r_mult = r_in * 8'd77;
    assign b_mult = b_in * 8'd29;
    assign g_mult = g_in * 8'd150;

    wire [16:0] gray_result;
    assign gray_result = r_mult + g_mult + b_mult;
    
    assign s_axis_tready = (m_axis_tvalid != 1'b1) || (m_axis_tready == 1'b1);
    
    //output register
    always @(posedge clk) begin
        if(!rst) begin
            m_axis_tdata <= 8'h00;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser <= 1'b0;
            m_axis_tlast <= 1'b0;
        end
        else if (s_axis_tready) begin
            m_axis_tdata <= gray_result[15:8];
            m_axis_tvalid <= s_axis_tvalid;
            m_axis_tuser <= s_axis_tuser;
            m_axis_tlast <= s_axis_tlast;
        end
    end
    
endmodule
