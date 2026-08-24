`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/06/2026 11:11:35 AM
// Design Name: 
// Module Name: axis_sobel
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


module axis_sobel(

    //clk & rst
    input clk,
    input rst,
    
    // up stream / as-slave side
    input [71:0] s_axis_tdata,
    input s_axis_tvalid,
    input s_axis_tuser,
    input s_axis_tlast,
    output s_axis_tready,
    
    // down stream / as-master side
    output reg [23:0] m_axis_tdata,
    output reg m_axis_tvalid,
    output reg m_axis_tuser,
    output reg m_axis_tlast,
    input m_axis_tready,
    
    // grayscale
    output reg [23:0] grayscale_data,
    // original
    input [23:0] rbg_in,
    output reg [23:0] rbg_data
    
    );
    
    // retrieve window
    // p00 p01 p02
    // p10 p11 p12
    // p20 p21 p22
    wire [7:0] p00, p01, p02, p10, p11, p12, p20, p21, p22;
    assign p00 = s_axis_tdata [71:64];
    assign p10 = s_axis_tdata [63:56];
    assign p20 = s_axis_tdata [55:48];
    assign p01 = s_axis_tdata [47:40];
    assign p11 = s_axis_tdata [39:32];
    assign p21 = s_axis_tdata [31:24];
    assign p02 = s_axis_tdata [23:16];
    assign p12 = s_axis_tdata [15:8];
    assign p22 = s_axis_tdata [7:0];
    
    // pipeline stage 1 regs
    reg signed [11:0] rgx0;
    reg signed [11:0] rgx2;
    reg signed [11:0] rgy0;
    reg signed [11:0] rgy2;
    
    // pipeline stage 2 regs
    reg signed [11:0] gx;
    reg signed [11:0] gy;
    
    // pipeline stage 3 regs
    reg [11:0] abs_gx;
    reg [11:0] abs_gy;
    
    // pipeline stage 4 regs
    reg [12:0] mag;
    
    // metadata 4 stages regs
    reg rValid0, rUser0, rLast0;
    reg rValid1, rUser1, rLast1;
    reg rValid2, rUser2, rLast2;
    reg rValid3, rUser3, rLast3;
    
    // grayscale 4 stages regs
    reg [23:0] rGray0, rGray1, rGray2, rGray3;
    // orginal frames 4 stages regs
    reg [23:0] rbg0, rbg1, rbg2, rbg3;    
    
    
    //saturation
    wire [7:0] edge_mag;
    assign edge_mag = (mag > 13'd255) ? 8'd255 : mag[7:0];
    
    
    wire pipeline_ena;
    assign pipeline_ena = !m_axis_tvalid || m_axis_tready;
    assign s_axis_tready = pipeline_ena;
    
    //output register
    always @(posedge clk) begin
        if(!rst) begin
            //pipeline stage 1
            rgx0 <= 12'd0;
            rgx2 <= 12'd0;
            rgy0 <= 12'd0;
            rgy2 <= 12'd0;
            rUser0 <= 1'b0;
            rValid0 <= 1'b0;
            rLast0 <= 1'b0;
            rGray0 <= 24'd0;
            rbg0 <= 24'd0;
            
            //pipeline stage 2
            gx <= 12'd0;
            gy <= 12'd0;
            rUser1 <= 1'b0;
            rValid1 <= 1'b0;
            rLast1 <= 1'b0;
            rGray1 <= 24'd0;
            rbg1 <= 24'd0;
            
            //pipeline stage 3
            abs_gx <= 12'd0;
            abs_gy <= 12'd0;
            rUser2 <= 1'b0;
            rValid2 <= 1'b0;
            rLast2 <= 1'b0;
            rGray2 <= 24'd0;
            rbg2 <= 24'd0;
            
            //pipeline stage 4
            mag <= 13'd0;
            rUser3 <= 1'b0;
            rValid3 <= 1'b0;
            rLast3 <= 1'b0;
            rGray3 <= 24'd0;
            rbg3 <= 24'd0;

            //pipeline stage 5
            m_axis_tdata <= 24'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser <= 1'b0;
            m_axis_tlast <= 1'b0;
            grayscale_data <= 24'd0;
            rbg_data <= 24'd0;
            
        end
        else if (pipeline_ena) begin
            
            //pipeline stage 1
            rgx0 <= -$signed({4'h0, p00})
                 - ($signed({4'h0, p10}) <<< 1)
                 - $signed({4'h0, p20});
            rgx2 <= + $signed({4'h0, p02})
                 + ($signed({4'h0, p12}) <<< 1)
                 + $signed({4'h0, p22});
            rgy0 <= -$signed({4'h0, p00})
                 - ($signed({4'h0, p01}) <<< 1)
                 - $signed({4'h0, p02});
            rgy2 <= + $signed({4'h0, p20})
                 + ($signed({4'h0, p21}) <<< 1)
                 + $signed({4'h0, p22});
            rValid0 <= s_axis_tvalid && s_axis_tready;
            rUser0 <= s_axis_tuser;
            rLast0 <= s_axis_tlast;
            rGray0 <= {p11,p11,p11};
            rbg0 <= rbg_in;
            
            //pipeline stage 2
            gx <= rgx0 + rgx2;
            gy <= rgy0 + rgy2;
            rValid1 <= rValid0;
            rUser1 <= rUser0;
            rLast1 <= rLast0;
            rGray1 <= rGray0;
            rbg1 <= rbg0;
            
            //pipeline stage 3
            abs_gx <= (gx < 0) ? -gx : gx;
            abs_gy <= (gy < 0) ? -gy : gy;
            rValid2 <= rValid1;
            rUser2 <= rUser1;
            rLast2 <= rLast1;
            rGray2 <= rGray1;
            rbg2 <= rbg1;
            
            //pipeline stage 4
            mag <= abs_gx + abs_gy;
            rValid3 <= rValid2;
            rUser3 <= rUser2;
            rLast3 <= rLast2;
            rGray3 <= rGray2;
            rbg3 <= rbg2;
            
            //pipeline stage 5
            m_axis_tdata <= {edge_mag, edge_mag, edge_mag};
            m_axis_tvalid <= rValid3;
            m_axis_tuser <= rUser3;
            m_axis_tlast <= rLast3;
            grayscale_data <= rGray3;
            rbg_data <= rbg3;
            
        end
    end
    
endmodule
