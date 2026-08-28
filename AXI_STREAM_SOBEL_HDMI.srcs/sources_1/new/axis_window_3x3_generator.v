`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/06/2026 11:16:40 AM
// Design Name: 
// Module Name: axis_window_3x3_generator
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


module axis_window_3x3_generator#(
        parameter FRAME_WIDTH = 1920,
        parameter FRAME_HEIGHT = 1080
    )(
        input clk,
        input rstn,
            
        // up stream / as-slave side
        input [7:0] s_axis_tdata,
        input s_axis_tvalid,
        input s_axis_tuser,
        input s_axis_tlast,
        output s_axis_tready,
        
        // down stream / as-master side
        output reg [71:0] m_axis_tdata,
        output reg m_axis_tvalid,
        output reg m_axis_tuser,
        output reg m_axis_tlast,
        input m_axis_tready,
        
        // original pixels
        input [23:0] rbg_in,
        output reg [23:0] rbg_out
        
    );
    
    localparam COL_W = $clog2(FRAME_WIDTH);
    localparam ROW_W = $clog2(FRAME_HEIGHT);
    
    // line buffers for 3x3 windows
    // BRAM0 -> previous
    // BRAM1 -> two-lines-ago
    (* ram_style = "block" *) reg [7:0] BRAM0 [0:FRAME_WIDTH-1];
    (* ram_style = "block" *) reg [7:0] BRAM1 [0:FRAME_WIDTH-1];
    
    // horizontal + vertical counters
    reg [COL_W-1:0] cntH;
    reg [ROW_W-1:0] cntV;
    
    // rr0 -> pixel from two lines ago
    // rr1 -> pixel from previous line
    // rr2 -> current pixel
    reg [7:0] rr0, rr1, rr2; // last column
    reg [COL_W-1:0] rCol; // processing column
    reg [ROW_W-1:0] rRow; // processing row
    reg rValid, rUser, rLast; // registered s_valid, s_user, s_last
    
    // Shift registers
    // first 2 columns
    reg [7:0] r00, r01;
    reg [7:0] r10, r11;
    reg [7:0] r20, r21;
    
    // define window valid
    wire window_valid;
    assign window_valid = rValid && (rRow >= 2) && (rCol >= 2);
    
    // original frames BRAM
    (* ram_style = "block" *) reg [23:0] RBG_BRAM [0:FRAME_WIDTH-1];
    
    // pipelined rbg_out regs
    reg [23:0] rbg12; // corresponding p12
    reg [23:0] rbg11; // taken pixel (corresponding window-centered) -> rbg_out
    
    wire pipeline_ena;
    assign pipeline_ena = !m_axis_tvalid || m_axis_tready;
    assign s_axis_tready = pipeline_ena;
    
    always @(posedge clk) begin
        if(!rstn) begin
            cntH <= 0; cntV <= 0;
            rCol <= 0; rRow <= 0;
            rValid <= 1'b0; rUser <= 1'b0; rLast <= 1'b0;
            m_axis_tdata  <= 72'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser  <= 1'b0;
            m_axis_tlast  <= 1'b0;
            
            rr0 <= 8'd0; rr1 <= 8'd0; rr2 <= 8'd0;
            r00 <= 8'd0; r01 <= 8'd0; r10 <= 8'd0;
            r11 <= 8'd0; r20 <= 8'd0; r21 <= 8'd0;            
            rbg12  <= 24'd0;
            rbg11  <= 24'd0;
            rbg_out <= 24'd0;
        end
        else if (pipeline_ena) begin
                    
            // stage 1 - inputs accepted
            if(s_axis_tready && s_axis_tvalid) begin
                
                // read current data
                rr0 <= BRAM1[cntH];
                rr1 <= BRAM0[cntH];
                rr2 <= s_axis_tdata;
                rbg12 <= RBG_BRAM[cntH];
                
                // update BRAM0
                BRAM0[cntH] <= s_axis_tdata;
                
                // update orginal pixels BRAM
                RBG_BRAM[cntH] <= rbg_in;
                
                // read metadata
                rCol <= cntH;
                rRow <= cntV;
                rValid <= 1'b1; //s_axis_tready && s_axis_tvalid
                rUser <= s_axis_tuser;
                rLast <= s_axis_tlast;
                
                // update counters
                if(s_axis_tuser) begin
                    cntV <= 0; // new frame, start again from row 0
                    if(s_axis_tlast) cntH <= 0; // if the frame has width 1 -> after tuser, the column keeps being 0
                    else cntH <= cntH + 1; // after tuser, moves to the next column
                end
                else if(s_axis_tlast || cntH == FRAME_WIDTH - 1) begin
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
            end
            
            // stage 2 - shifting after accepting inputs
            if(rValid) begin               
                //window columns shifted
                r00 <= r01; r01 <= rr0;
                r10 <= r11; r11 <= rr1;
                r20 <= r21; r21 <= rr2;
                
                // update BRAM1
                BRAM1[rCol] <= rr1;
                
                //orginal pixels BRAM alignment - 
                rbg11 <= rbg12;                
            end
            
            // stage 2 - update output regs
            if(window_valid) begin
                m_axis_tdata <= {
                    r00, r01, rr1,
                    r10, r11, rr2,
                    r20, r21, rr2
                };
                rbg_out <= rbg11;
            end
            else begin
                m_axis_tdata <= 72'd0;
                rbg_out <= 24'd0;
            end   
            m_axis_tvalid <= rValid;
            m_axis_tuser <= rUser & rValid;
            m_axis_tlast <= rLast & rValid;
        end
    end
    
endmodule
