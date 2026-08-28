`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/07/2026 03:13:55 PM
// Design Name: 
// Module Name: video_config_cdc
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


`timescale 1ns / 1ps

module video_config_cdc (
    input pixel_clk,
    input pixel_resetn,

    // frozen payload from PS domain
    input [1:0] cfg_mode_axi,
    input [7:0] cfg_threshold_axi,
    input cfg_req_toggle_axi,

    // acknowledgement back to PS domain
    output reg cfg_ack_toggle_pixel,

    // sof mark
    input sof_fire,

    // active video-domain controls
    output reg  [1:0] active_mode_pixel,
    output reg  [7:0] active_threshold_pixel
);

    // request synchronizer
    (* ASYNC_REG = "TRUE" *) reg req_sync1_pixel;
    (* ASYNC_REG = "TRUE" *) reg req_sync2_pixel;

    // last request captured
    reg req_seen_pixel;

    // pending data
    reg [1:0] pending_mode_pixel;
    reg [7:0] pending_threshold_pixel;
    reg config_pending_pixel;

    always @(posedge pixel_clk)
    begin
        if (!pixel_resetn)
        begin
            req_sync1_pixel <= 1'b0;
            req_sync2_pixel <= 1'b0;
        end
        else begin
            req_sync1_pixel <= cfg_req_toggle_axi;
            req_sync2_pixel <= req_sync1_pixel;
        end
    end

    always @(posedge pixel_clk)
    begin
        if (!pixel_resetn)
        begin
            req_seen_pixel          <= 1'b0;
            pending_mode_pixel      <= 2'b00;
            pending_threshold_pixel <= 8'd100;
            config_pending_pixel    <= 1'b0;
            active_mode_pixel       <= 2'b00;
            active_threshold_pixel  <= 8'd100;
            cfg_ack_toggle_pixel    <= 1'b0;
        end
        else begin
            // detect a new synchronized request and capture the stable bundled payload.
            if (req_sync2_pixel != req_seen_pixel) begin
                // update pending data
                pending_mode_pixel <= cfg_mode_axi;
                pending_threshold_pixel <= cfg_threshold_axi;
                
                // set pending config mark
                config_pending_pixel <= 1'b1;
                
                // update last captured req
                req_seen_pixel <= req_sync2_pixel;
            end

            // update active data on sof after pending data is configured.
            if (config_pending_pixel && sof_fire) begin
                // update active data
                active_mode_pixel <= pending_mode_pixel;
                active_threshold_pixel <= pending_threshold_pixel;
                
                // reset pending config mark
                config_pending_pixel <= 1'b0;

                // acknowledge the request that has now become active.
                cfg_ack_toggle_pixel <= req_seen_pixel;
            end
        end
    end

endmodule
