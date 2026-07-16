`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/14/2026 01:54:13 PM
// Design Name: 
// Module Name: output_adapter
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


module output_adapter#(
    parameter H_ACTIVE = 1280,
    parameter H_FP = 110,
    parameter H_SYNC = 40,
    parameter H_BP = 220,
    parameter V_ACTIVE = 720,
    parameter V_FP = 5,
    parameter V_SYNC = 5,
    parameter V_BP = 20,
    
    parameter H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP,
    parameter V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP
    )(
    input clk, rst,
    input [7:0] s_axis_tdata,
    input s_axis_tvalid,
    input s_axis_tuser,
    input s_axis_tlast,
    output s_axis_tready,
    
    output [23:0] vid_pData,
    output vid_pVDE,
    output hsync,
    output vsync
    );
    
    wire [23:0] edge_pixel;
    assign edge_pixel = {s_axis_tdata, s_axis_tdata, s_axis_tdata};
    
    localparam HW = $clog2(H_TOTAL);
    localparam VW = $clog2(V_TOTAL);
    
    reg [HW-1:0] cntH;
    reg [VW-1:0] cntV;
    
    wire active_region;
    assign active_region = (cntH < H_ACTIVE) && (cntV < V_ACTIVE);
    assign hsync = (rst) ? 0 : ((cntH < H_ACTIVE + H_FP) || (cntH >= H_TOTAL - H_BP));
    assign vsync = (rst) ? 0 : ((cntV < V_ACTIVE + V_FP) || (cntV >= V_TOTAL - V_BP));
    
    reg stream_synced;
    assign s_axis_tready = (!stream_synced) ? 1'b1 : active_region;
    
    assign vid_pData = (rst || !s_axis_tvalid || !stream_synced || !active_region) ? 0 : edge_pixel;
    assign vid_pVDE = (rst) ? 0 : (s_axis_tvalid && active_region);
    
    always @(posedge clk) begin
        if(rst) begin
            cntH <= 0;
            cntV <= 0;    
            stream_synced <= 1'b0;
        end
        else begin
            if(s_axis_tready && s_axis_tvalid && s_axis_tuser) begin
                cntV <= 0; // new frame, start again from row 0
                if(s_axis_tlast) cntH <= 0; // if the frame has width 1 -> after tuser, the column keeps being 0
                else cntH <= 1; // after tuser, moves to the next column
                stream_synced <= 1'b1;
            end
            else if(stream_synced) begin
                if(cntH == H_TOTAL - 1) begin
                    cntH <= 0; // after reaching last, moves to next line at first column
                    if(cntV == V_TOTAL - 1) cntV <= 0;
                    else cntV <= cntV + 1;
                end
                else begin
                    cntH <= cntH + 1;    
                end
            end
        end
    end
    
endmodule
