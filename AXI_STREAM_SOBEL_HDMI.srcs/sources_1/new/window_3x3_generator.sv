`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2026 11:20:47 PM
// Design Name: 
// Module Name: window_3x3_generator
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


module window_3x3_generator #(
        parameter int FRAME_WIDTH = 640,
        parameter int FRAME_HEIGHT = 480
    )(
    
    input clk,
    input rst,
        
    // up stream / as-slave side
    input logic [7:0] s_axis_tdata,
    input logic s_axis_tvalid,
    input logic s_axis_tuser,
    input logic s_axis_tlast,
    output logic s_axis_tready,
    
    // down stream / as-master side
    output logic [71:0] m_axis_tdata,
    output logic m_axis_tvalid,
    output logic m_axis_tuser,
    output logic m_axis_tlast,
    input logic m_axis_tready
    );
    
    localparam int COL_W = (FRAME_WIDTH  <= 1) ? 1 : $clog2(FRAME_WIDTH);
    localparam int ROW_W = (FRAME_HEIGHT <= 1) ? 1 : $clog2(FRAME_HEIGHT);
    
    // Line buffers
    // BRAM0 -> previous
    // BRAM1 -> two-lines-ago
    (* ram_style = "block" *) logic [7:0] BRAM0 [0:FRAME_WIDTH-1];
    (* ram_style = "block" *) logic [7:0] BRAM1 [0:FRAME_WIDTH-1];
    
    // Horizontal + Vertical counters
    logic [COL_W-1:0] cntH;
    logic [ROW_W-1:0] cntV;
    
    // BRAM read stage - synchronous -> need to be registered
    // rr0 -> pixel from two lines ago
    // rr1 -> pixel from previous line
    // rr2 -> current pixel
    logic [7:0] rr0, rr1, rr2; // last column
    logic [COL_W-1:0] rCol; // processing column
    logic [ROW_W-1:0] rRow; // processing row
    logic rValid, rUser, rLast; // registered s_valid, s_user, s_last
    
    // Shift registers
    // first 2 columns
    logic [7:0] r00, r01;
    logic [7:0] r10, r11;
    logic [7:0] r20, r21;
    
    // Define new valid, user, last
    logic window_valid;
    logic window_user;
    logic window_last;
    always_comb begin
        window_valid = rValid && (rRow >= 2) && (rCol >= 2); 
        window_user = window_valid && (rRow == 2) && (rCol == 2); 
        window_last = window_valid && rLast;
    end
    
    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cntH <= 0; cntV <= 0;
            rr0 <= 8'd0; rr1 <= 8'd0; rr2 <= 8'd0;
            rCol <= 0; rRow <= 0;
            rValid <= 1'b0; rUser <= 1'b0; rLast <= 1'b0; 
            r00 <= 8'd0; r01 <= 8'd0; r10 <= 8'd0; r11 <= 8'd0; r20 <= 8'd0; r21 <= 8'd0; 
            m_axis_tdata  <= 72'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser  <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end
        else if (s_axis_tready) begin
            m_axis_tdata <= {
                r00, r10, r20,
                r01, r11, r21,
                rr0, rr1, rr2
            };
            m_axis_tvalid <= window_valid;
            m_axis_tuser <= window_user;
            m_axis_tlast <= window_last;
            
            if(rValid) begin // rValid = 1 only after input is accepted -> useful shifting happens
                r00 <= r01; r01 <= rr0;
                r10 <= r11; r11 <= rr1;
                r20 <= r21; r21 <= rr2;
            end
            
            // BRAM0 read is synchronous -> need to write BRAM1 1 cycle later
            if(rValid) begin
                BRAM1[rCol] <= rr1;
            end
            
            if(s_axis_tready && s_axis_tvalid) begin // accepted input
                rr0 <= BRAM1[cntH];
                rr1 <= BRAM0[cntH];
                rr2 <= s_axis_tdata;
                rCol <= cntH;
                rRow <= cntV;
                rValid <= 1'b1;
                rUser <= s_axis_tuser;
                rLast <= s_axis_tlast;
                
                // update BRAM0
                BRAM0[cntH] <= s_axis_tdata;
                
                // update counters
                if(s_axis_tuser) begin
                    cntV <= 0; // new frame, start again from row 0
                    if(s_axis_tlast) cntH <= 0; // if the frame has width 1 -> after tuser, the column keeps being 0
                    else cntH <= 1; // after tuser, moves to the next column
                end
                else if(s_axis_tlast) begin
                    cntH <= 0; // after reaching last, moves to next line at first column
                    cntV <= cntV + 1; // move to next line
                end
                else begin
                    cntH <= cntH + 1;    
                end
            end
            else begin // no accepted input
                rValid <= 1'b0;
                rUser <= 1'b0;
                rLast <= 1'b0;
                rr0 <= 8'd0; rr1 <= 8'd0; rr2 <= 8'd0;
                rCol <= 0; rRow <= 0;
            end
        end
    end
    
    
endmodule
