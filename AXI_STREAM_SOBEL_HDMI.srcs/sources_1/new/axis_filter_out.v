`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/06/2026 02:49:44 PM
// Design Name: 
// Module Name: axis_filter_out
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


module axis_filter_out(
    input clk,
    input rst_n,
    
    input [23:0] s_axis_tdata,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tuser,
    input s_axis_tlast,
    
    output reg [23:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input m_axis_tready,
    output reg m_axis_tuser,
    output reg m_axis_tlast,
    
    input [23:0] grayscale_data,
    input [23:0] rbg_data,
    
    input [1:0] mode,
    input [7:0] threshold,
    
    output frame_start
    );
    
    assign frame_start = s_axis_tvalid && s_axis_tready && s_axis_tuser;
    
    wire pipeline_ena;
    assign pipeline_ena = !m_axis_tvalid || m_axis_tready;
    assign s_axis_tready = pipeline_ena;
    
    always @(posedge clk) begin
        if(!rst_n) begin
            m_axis_tdata <= 24'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser <= 1'b0;
            m_axis_tlast <= 1'b0;
        end
        else if (pipeline_ena) begin
            case(mode)
                2'b00: begin
                    // m_axis_tdata <= s_axis_tdata;
                    m_axis_tdata <= s_axis_tdata;
                    m_axis_tvalid <= s_axis_tvalid && s_axis_tready;
                    m_axis_tuser <= s_axis_tuser;
                    m_axis_tlast <= s_axis_tlast;
                end
                2'b01: begin
                    m_axis_tdata <= (s_axis_tdata[7:0] > threshold) ? 24'hffffff : 24'h000000;
                    m_axis_tvalid <= s_axis_tvalid && s_axis_tready;
                    m_axis_tuser <= s_axis_tuser;
                    m_axis_tlast <= s_axis_tlast;
                end
                2'b10: begin
                    m_axis_tdata <= grayscale_data;
                    m_axis_tvalid <= s_axis_tvalid && s_axis_tready;
                    m_axis_tuser <= s_axis_tuser;
                    m_axis_tlast <= s_axis_tlast;
                end
                2'b11: begin
                    m_axis_tdata <= rbg_data;
                    m_axis_tvalid <= s_axis_tvalid && s_axis_tready;
                    m_axis_tuser <= s_axis_tuser;
                    m_axis_tlast <= s_axis_tlast;
                end
                default: begin
                    m_axis_tdata <= 24'hbc1501;
                    m_axis_tvalid <= s_axis_tvalid && s_axis_tready;
                    m_axis_tuser <= s_axis_tuser;
                    m_axis_tlast <= s_axis_tlast;
                end
            endcase
        end
    end
    
    
endmodule
