`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2026 07:24:34 PM
// Design Name: 
// Module Name: sobel
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


module sobel(

    //clk & rst
    input clk,
    input rst,
    
    // up stream / as-slave side
    input logic [71:0] s_axis_tdata,
    input logic s_axis_tvalid,
    input logic s_axis_tuser,
    input logic s_axis_tlast,
    output logic s_axis_tready,
    
    // down stream / as-master side
    output logic [7:0] m_axis_tdata,
    output logic m_axis_tvalid,
    output logic m_axis_tuser,
    output logic m_axis_tlast,
    input logic m_axis_tready
    
    );
    
    // retrieve window
    // p00 p01 p02
    // p10 p11 p12
    // p20 p21 p22
    logic [7:0] p00, p01, p02, p10, p11, p12, p20, p21, p22;
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
    logic signed [11:0] gx;
    logic signed [11:0] gy;

    logic [11:0] abs_gx;
    logic [11:0] abs_gy;
    logic [12:0] mag;

    logic [7:0] edge_mag;

    always_comb begin
        // Gx = - p00 + p02 - 2p10 + 2p12 - p20 + p22
        gx = -$signed({4'h0, p00})
             + $signed({4'h0, p02})
             - ($signed({4'h0, p10}) <<< 1)
             + ($signed({4'h0, p12}) <<< 1)
             - $signed({4'h0, p20})
             + $signed({4'h0, p22});

        // Gy = - p00 - 2p01 - p02 + p20 + 2p21 + p22
        gy = -$signed({4'h0, p00})
             - ($signed({4'h0, p01}) <<< 1)
             - $signed({4'h0, p02})
             + $signed({4'h0, p20})
             + ($signed({4'h0, p21}) <<< 1)
             + $signed({4'h0, p22});

        abs_gx = (gx < 0) ? -gx : gx;
        abs_gy = (gy < 0) ? -gy : gy;
        mag = abs_gx + abs_gy;
        
        //saturation
        if (mag > 13'd255) edge_mag = 8'd255;
        else edge_mag = mag[7:0];
    end
    
    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;
    //output register
    always_ff @(posedge clk) begin
        if(rst) begin
            m_axis_tdata <= 8'h00;
            m_axis_tvalid <= 1'b0;
            m_axis_tuser <= 1'b0;
            m_axis_tlast <= 1'b0;
        end
        else if (s_axis_tready) begin
            m_axis_tdata <= edge_mag;
            m_axis_tvalid <= s_axis_tvalid;
            m_axis_tuser <= s_axis_tuser;
            m_axis_tlast <= s_axis_tlast;
        end
    end
    
    
endmodule
