`timescale 1ns / 1ps

module axis_sobel_TB;

    // ============================================================
    // Clock and reset
    // ============================================================

    reg clk;
    reg rst;

    // ============================================================
    // Input stream
    // ============================================================

    reg  [71:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tuser;
    reg         s_axis_tlast;

    reg  [23:0] rbg_in;

    // ============================================================
    // Output stream
    // ============================================================

    wire [23:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire        m_axis_tuser;
    wire        m_axis_tlast;

    wire [23:0] grayscale_data;
    wire [23:0] rbg_data;

    // ============================================================
    // Handshake indicators
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

    axis_sobel dut (
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

        .grayscale_data (grayscale_data),

        .rbg_in         (rbg_in),
        .rbg_data       (rbg_data)
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

            s_axis_tdata  = 72'd0;
            s_axis_tvalid = 1'b0;
            s_axis_tuser  = 1'b0;
            s_axis_tlast  = 1'b0;
            rbg_in        = 24'd0;

            m_axis_tready = 1'b1;

            repeat (6) @(posedge clk);

            @(negedge clk);
            rst = 1'b1;

            repeat (2) @(posedge clk);
        end
    endtask

    // ============================================================
    // Send one 3x3 window transaction
    // ============================================================

    task send_window;
        input [71:0] window_value;
        input [23:0] original_value;
        input        user_value;
        input        last_value;

        begin
            @(negedge clk);

            s_axis_tdata  = window_value;
            rbg_in        = original_value;
            s_axis_tvalid = 1'b1;
            s_axis_tuser  = user_value;
            s_axis_tlast  = last_value;

            /*
             * Hold the window and associated signals until accepted.
             */
            @(posedge clk);

            while (!s_axis_tready)
                @(posedge clk);
        end
    endtask

    task stop_input;
        begin
            @(negedge clk);

            s_axis_tdata  = 72'd0;
            rbg_in        = 24'd0;
            s_axis_tvalid = 1'b0;
            s_axis_tuser  = 1'b0;
            s_axis_tlast  = 1'b0;
        end
    endtask

    // ============================================================
    // Directed output backpressure
    // ============================================================

    initial begin : ready_controller

        wait (rst == 1'b1);

        /*
         * Wait until the first completed Sobel result appears.
         */
        wait (m_axis_tvalid == 1'b1);

        @(negedge clk);
        m_axis_tready = 1'b0;

        /*
         * The Sobel output, grayscale output, original output,
         * TVALID, TUSER, and TLAST should freeze.
         */
        repeat (4) @(posedge clk);

        @(negedge clk);
        m_axis_tready = 1'b1;
    end

    // ============================================================
    // Main stimulus
    // ============================================================

    initial begin: main_stimulus
        reg [71:0] flat_window;
        reg [71:0] vertical_edge_window;
        reg [71:0] horizontal_edge_window;
        reg [71:0] gradient_window;

        reset_dut();

        /*
         * axis_sobel bus packing:
         *
         * {
         *   p00, p10, p20,
         *   p01, p11, p21,
         *   p02, p12, p22
         * }
         */

        // --------------------------------------------------------
        // Window 1: Flat image
        //
        // Spatial arrangement:
        //
        // 100 100 100
        // 100 100 100
        // 100 100 100
        //
        // Expected Sobel magnitude: 0
        // Expected grayscale: 100
        // --------------------------------------------------------

        flat_window = {
            8'd100, 8'd100, 8'd100,
            8'd100, 8'd100, 8'd100,
            8'd100, 8'd100, 8'd100
        };

        // --------------------------------------------------------
        // Window 2: Vertical edge
        //
        // Spatial arrangement:
        //
        //   0   0 255
        //   0   0 255
        //   0   0 255
        //
        // Expected Sobel magnitude: saturated to 255
        // Expected grayscale center: 0
        // --------------------------------------------------------

        vertical_edge_window = {
            8'd0,   8'd0,   8'd0,
            8'd0,   8'd0,   8'd0,
            8'd255, 8'd255, 8'd255
        };

        // --------------------------------------------------------
        // Window 3: Horizontal edge
        //
        // Spatial arrangement:
        //
        //   0   0   0
        //   0   0   0
        // 255 255 255
        //
        // Expected Sobel magnitude: saturated to 255
        // --------------------------------------------------------

        horizontal_edge_window = {
            8'd0,   8'd0,   8'd255,
            8'd0,   8'd0,   8'd255,
            8'd0,   8'd0,   8'd255
        };

        // --------------------------------------------------------
        // Window 4: Increasing values
        //
        // Spatial arrangement:
        //
        // 10 20 30
        // 40 50 60
        // 70 80 90
        //
        // Center grayscale = 50
        // --------------------------------------------------------

        gradient_window = {
            8'd10, 8'd40, 8'd70,
            8'd20, 8'd50, 8'd80,
            8'd30, 8'd60, 8'd90
        };

        /*
         * Send windows consecutively so pipeline overlap is visible.
         */
        send_window(
            flat_window,
            24'h112233,
            1'b1,
            1'b0
        );

        send_window(
            vertical_edge_window,
            24'h445566,
            1'b0,
            1'b0
        );

        send_window(
            horizontal_edge_window,
            24'h778899,
            1'b0,
            1'b0
        );

        send_window(
            gradient_window,
            24'hAABBCC,
            1'b0,
            1'b1
        );

        stop_input();

        repeat (30) @(posedge clk);

        $finish;
    end

endmodule