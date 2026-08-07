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
    input  wire       pixel_clk,
    input  wire       pixel_resetn,

    // Frozen payload from AXI domain
    input  wire [1:0] cfg_mode_axi,
    input  wire [7:0] cfg_threshold_axi,
    input  wire       cfg_req_toggle_axi,

    // Transaction acknowledgement back to AXI domain
    output reg        cfg_ack_toggle_pixel,

    // Accepted first pixel of output frame
    input  wire       frame_start_fire,

    // Active video-domain controls
    output reg  [1:0] active_mode_pixel,
    output reg  [7:0] active_threshold_pixel
);

    // Request synchronizer
    (* ASYNC_REG = "TRUE" *) reg req_sync1_pixel;
    (* ASYNC_REG = "TRUE" *) reg req_sync2_pixel;

    // Last request already captured
    reg req_seen_pixel;

    // Pending configuration
    reg [1:0] pending_mode_pixel;
    reg [7:0] pending_threshold_pixel;
    reg       config_pending_pixel;

    always @(posedge pixel_clk)
    begin
        if (!pixel_resetn)
        begin
            req_sync1_pixel <= 1'b0;
            req_sync2_pixel <= 1'b0;
        end
        else
        begin
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
        else
        begin
            /*
             * Detect a new synchronized request and capture
             * the stable bundled payload.
             */
            if (req_sync2_pixel != req_seen_pixel)
            begin
                pending_mode_pixel <=
                    cfg_mode_axi;

                pending_threshold_pixel <=
                    cfg_threshold_axi;

                config_pending_pixel <= 1'b1;
                req_seen_pixel       <= req_sync2_pixel;
            end

            /*
             * Apply the complete pending configuration at
             * an accepted frame-start transaction.
             */
            if (
                config_pending_pixel &&
                frame_start_fire
            )
            begin
                active_mode_pixel <=
                    pending_mode_pixel;

                active_threshold_pixel <=
                    pending_threshold_pixel;

                config_pending_pixel <= 1'b0;

                /*
                 * Acknowledge the request that has now
                 * become active.
                 */
                cfg_ack_toggle_pixel <=
                    req_seen_pixel;
            end
        end
    end

endmodule
