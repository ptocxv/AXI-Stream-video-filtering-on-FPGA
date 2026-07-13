`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/12/2026 01:50:46 PM
// Design Name: 
// Module Name: input_adapter
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


module input_adapter#(
    parameter FRAME_WIDTH = 1280,
    parameter FRAME_HEIGHT = 720
    )(
    input clk, rst,
    
    input [23:0] vid_pData,
    input vid_pVDE,
    input vid_HSync,
    input vid_VSync,
    input pLocked,
    input aPixelClkLcked,
    
    output reg [23:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input m_axis_tready,
    output reg m_axis_tuser,
    output reg m_axis_tlast
    
    );
    wire vid_locked;
    assign vid_locked = pLocked & aPixelClkLcked;
    
    wire vsync_rise;
    wire vsync_active; reg vsync_active_d;
    assign vsync_active = vid_VSync;
    assign vsync_rise = vsync_active & ~vsync_active_d;
    always @(posedge clk) begin
        vsync_active_d <= vsync_active;
    end
    
    localparam COL_W = $clog2(FRAME_WIDTH);
    localparam ROW_W = $clog2(FRAME_HEIGHT);
    reg [COL_W-1:0] cntH;
    reg [ROW_W-1:0] cntV;
    reg sof_pending;
    reg frame_seen;
    
    always @(posedge clk) begin
        if(rst || !vid_locked) begin
            m_axis_tdata <= 24'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser <= 1'b0;
            m_axis_tlast <= 1'b0;
            
            cntH <= 0;
            cntV <= 0;
            sof_pending <= 1'b0;
            frame_seen <= 1'b0;
            
        end
        else begin 
            if(vsync_rise) begin
                cntH <= 0;
                cntV <= 0;
                sof_pending <= 1'b1;
                frame_seen <= 1'b1;
            end
            
            if(vid_pVDE && frame_seen) begin
                m_axis_tdata <= vid_pData;
                m_axis_tvalid <= 1'b1;
                m_axis_tuser <= sof_pending;
                m_axis_tlast <= (cntH == FRAME_WIDTH - 1);
                
                sof_pending <= 1'b0;
                
                //counters update
                if(cntH == FRAME_WIDTH - 1) begin
                    cntH <= 0;
                    if(cntV == FRAME_HEIGHT - 1) begin
                        cntV <= 0;
                    end
                    else begin
                        cntV <= cntV + 1'b1;
                    end
                end
                else begin
                    cntH <= cntH + 1'b1;
                end
            end
            else begin
                m_axis_tvalid <= 1'b0;
                m_axis_tdata <= 24'd0;
                m_axis_tuser <= 1'b0;
                m_axis_tlast <= 1'b0;
            end
        end
    end
    
endmodule
