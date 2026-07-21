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
    input m_axis_tready
    
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
    
    // sobel calculation
    reg signed [11:0] gx;
    reg signed [11:0] gy;
    reg signed [11:0] rgx0;
    reg signed [11:0] rgx2;
    reg signed [11:0] rgy0;
    reg signed [11:0] rgy2;
    
    reg [11:0] abs_gx;
    reg [11:0] abs_gy;
    reg [12:0] mag;

    wire [7:0] edge_mag;
    reg rValid1, rUser1, rLast1;
    reg rValid2, rUser2, rLast2;
    
    //saturation
    assign edge_mag = (mag > 13'd255) ? 8'd255 : mag[7:0];
    
    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;
    //output register
    always @(posedge clk) begin
        if(!rst) begin
            //pipeline stage 1
            abs_gx <= 12'd0;
            abs_gy <= 12'd0;
            rUser1 <= 1'b0;
            rValid1 <= 1'b0;
            rLast1 <= 1'b0;
            
            //pipeline stage 2
            mag <= 8'd0;
            rUser1 <= 1'b0;
            rValid1 <= 1'b0;
            rLast1 <= 1'b0;

            //pipeline stage 3
            m_axis_tdata <= 24'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser <= 1'b0;
            m_axis_tlast <= 1'b0;
        end
        else if (s_axis_tready) begin
            
            rgx0 <= -$signed({4'h0, p00})
                 - ($signed({4'h0, p10}) <<< 1)
                 - $signed({4'h0, p20});
            rgx2 <= + $signed({4'h0, p02})
                 + ($signed({4'h0, p12}) <<< 1)
                 + $signed({4'h0, p22});
            gx <= rgx0 + rgx2;
            
            rgy0 <= -$signed({4'h0, p00})
             - ($signed({4'h0, p01}) <<< 1)
             - $signed({4'h0, p02});
            rgy2 <= + $signed({4'h0, p20})
             + ($signed({4'h0, p21}) <<< 1)
             + $signed({4'h0, p22});
            gy <= rgy0 + rgy2;
            
            //pipeline stage 2
            abs_gx <= (gx < 0) ? -gx : gx;
            abs_gy <= (gy < 0) ? -gy : gy;
            rValid1 <= s_axis_tvalid;
            rUser1 <= s_axis_tuser;
            rLast1 <= s_axis_tlast;
            
            //pipeline stage 3
            mag <= abs_gx + abs_gy;
            rValid2 <= rValid1;
            rUser2 <= rUser1;
            rLast2 <= rLast1;
            
            //pipeline stage 4
            m_axis_tdata <= {edge_mag, edge_mag, edge_mag};
            m_axis_tvalid <= rValid2;
            m_axis_tuser <= rUser2;
            m_axis_tlast <= rLast2;
        end
    end
    
endmodule
