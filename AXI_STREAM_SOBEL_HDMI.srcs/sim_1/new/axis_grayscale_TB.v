`timescale 1ns / 1ps

module axis_grayscale_TB;

    // ============================================================
    // Clock and reset
    // ============================================================

    reg clk;
    reg rst;

    // ============================================================
    // Input stream
    // ============================================================

    reg  [23:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tuser;
    reg         s_axis_tlast;

    // ============================================================
    // Output stream
    // ============================================================

    wire [7:0]  m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire        m_axis_tuser;
    wire        m_axis_tlast;

    wire [23:0] rbg_out;

    // ============================================================
    // Handshake indicators for waveform inspection
    // ============================================================

    wire input_fire;
    wire output_fire;
    wire output_stall;

    assign input_fire =
        s_axis_tvalid && s_axis_tready;

    assign output_fire =
        m_axis_tvalid && m_axis_tready;

    assign output_stall =
        m_axis_tvalid && !m_axis_tready;

    // ============================================================
    // DUT
    // ============================================================

    axis_grayscale dut (
        .clk            (clk),
        .rst            (rst),

        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tuser   (s_axis_tuser),
        .s_axis_tlast   (s_axis_tlast),

        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tuser   (m_axis_tuser),
        .m_axis_tlast   (m_axis_tlast),

        .rbg_out        (rbg_out)
    );

    // ============================================================
    // Clock generation
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Reset
    // ============================================================

    task reset_dut;
        begin
            rst = 1'b0;

            s_axis_tdata  = 24'd0;
            s_axis_tvalid = 1'b0;
            s_axis_tuser  = 1'b0;
            s_axis_tlast  = 1'b0;

            m_axis_tready = 1'b1;

            repeat (5) @(posedge clk);

            @(negedge clk);
            rst = 1'b1;

            repeat (2) @(posedge clk);
        end
    endtask

    // ============================================================
    // Send one pixel
    // ============================================================

    task send_pixel;
        input [23:0] pixel;
        input        user_value;
        input        last_value;

        begin
            @(negedge clk);

            s_axis_tdata  = pixel;
            s_axis_tvalid = 1'b1;
            s_axis_tuser  = user_value;
            s_axis_tlast  = last_value;

            /*
             * Keep the complete input transaction stable until
             * the DUT accepts it.
             */
            @(posedge clk);

            while (!s_axis_tready)
                @(posedge clk);
        end
    endtask

    task stop_input;
        begin
            @(negedge clk);

            s_axis_tdata  = 24'd0;
            s_axis_tvalid = 1'b0;
            s_axis_tuser  = 1'b0;
            s_axis_tlast  = 1'b0;
        end
    endtask

    // ============================================================
    // Directed output backpressure
    // ============================================================

    initial begin : ready_controller

        /*
         * Wait until reset is released.
         */
        wait (rst == 1'b1);

        /*
         * Wait until the DUT presents the first valid output.
         */
        wait (m_axis_tvalid == 1'b1);

        /*
         * Deassert ready before the next rising edge.
         */
        @(negedge clk);
        m_axis_tready = 1'b0;

        /*
         * Hold the output blocked for four clock cycles.
         */
        repeat (4) @(posedge clk);

        /*
         * Release the pending output transaction.
         */
        @(negedge clk);
        m_axis_tready = 1'b1;
    end

    // ============================================================
    // Main stimulus
    // ============================================================

    initial begin

        reset_dut();

        /*
         * Current channel order:
         *
         * [23:16] = red
         * [15:8]  = blue
         * [7:0]   = green
         */

        send_pixel(24'hFF0000, 1'b1, 1'b0); // Red
        send_pixel(24'h0000FF, 1'b0, 1'b0); // Green
        send_pixel(24'h00FF00, 1'b0, 1'b0); // Blue
        send_pixel(24'hFFFFFF, 1'b0, 1'b0); // White
        send_pixel(24'h808080, 1'b0, 1'b0); // Mid-level
        send_pixel(24'h123456, 1'b0, 1'b1); // Final test pixel

        stop_input();

        repeat (20) @(posedge clk);

        $finish;
    end

endmodule