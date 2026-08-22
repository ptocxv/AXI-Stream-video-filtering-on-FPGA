`timescale 1ns / 1ps

module axis_window_3x3_generator_TB;

    parameter FRAME_WIDTH  = 4;
    parameter FRAME_HEIGHT = 4;

    // ============================================================
    // Clock and reset
    // ============================================================

    reg clk;
    reg rst;

    // ============================================================
    // Input stream
    // ============================================================

    reg  [7:0]  s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tuser;
    reg         s_axis_tlast;

    reg  [23:0] rbg_in;

    // ============================================================
    // Output stream
    // ============================================================

    wire [71:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;
    wire        m_axis_tuser;
    wire        m_axis_tlast;

    wire [23:0] rbg_out;

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
    // Unpacked output-window wires for waveform readability
    // ============================================================

    wire [7:0] out_p00;
    wire [7:0] out_p01;
    wire [7:0] out_p02;

    wire [7:0] out_p10;
    wire [7:0] out_p11;
    wire [7:0] out_p12;

    wire [7:0] out_p20;
    wire [7:0] out_p21;
    wire [7:0] out_p22;

    assign out_p00 = m_axis_tdata[71:64];
    assign out_p10 = m_axis_tdata[63:56];
    assign out_p20 = m_axis_tdata[55:48];

    assign out_p01 = m_axis_tdata[47:40];
    assign out_p11 = m_axis_tdata[39:32];
    assign out_p21 = m_axis_tdata[31:24];

    assign out_p02 = m_axis_tdata[23:16];
    assign out_p12 = m_axis_tdata[15:8];
    assign out_p22 = m_axis_tdata[7:0];

    // ============================================================
    // DUT
    // ============================================================

    axis_window_3x3_generator #(
        .FRAME_WIDTH  (FRAME_WIDTH),
        .FRAME_HEIGHT (FRAME_HEIGHT)
    ) dut (
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

        .rbg_in         (rbg_in),
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

            s_axis_tdata  = 8'd0;
            s_axis_tvalid = 1'b0;
            s_axis_tuser  = 1'b0;
            s_axis_tlast  = 1'b0;
            rbg_in        = 24'd0;

            m_axis_tready = 1'b1;

            repeat (5) @(posedge clk);

            @(negedge clk);
            rst = 1'b1;

            repeat (2) @(posedge clk);
        end
    endtask

    // ============================================================
    // Send one grayscale and original-pixel transaction
    // ============================================================

    task send_pixel;
        input [7:0]  gray_value;
        input [23:0] original_value;
        input        user_value;
        input        last_value;

        begin
            @(negedge clk);

            s_axis_tdata  = gray_value;
            rbg_in        = original_value;
            s_axis_tvalid = 1'b1;
            s_axis_tuser  = user_value;
            s_axis_tlast  = last_value;

            /*
             * Hold the pixel and metadata until accepted.
             */
            @(posedge clk);

            while (!s_axis_tready)
                @(posedge clk);
        end
    endtask

    task stop_input;
        begin
            @(negedge clk);

            s_axis_tdata  = 8'd0;
            rbg_in        = 24'd0;
            s_axis_tvalid = 1'b0;
            s_axis_tuser  = 1'b0;
            s_axis_tlast  = 1'b0;
        end
    endtask

    // ============================================================
    // Directed backpressure
    // ============================================================

    initial begin : ready_controller

        wait (rst == 1'b1);

        /*
         * Let the pipeline produce several outputs before stalling.
         * The first output transactions are border outputs.
         */
        repeat (7) @(posedge clk);

        /*
         * Wait for a valid output, then block it.
         */
        wait (m_axis_tvalid == 1'b1);

        @(negedge clk);
        m_axis_tready = 1'b0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        m_axis_tready = 1'b1;
    end

    // ============================================================
    // Main stimulus
    // ============================================================

    initial begin: main_stimulus
        integer row;
        integer col;
        integer value;

        reset_dut();

        value = 1;

        for (
            row = 0;
            row < FRAME_HEIGHT;
            row = row + 1
        ) begin
            for (
                col = 0;
                col < FRAME_WIDTH;
                col = col + 1
            ) begin
                /*
                 * Original data uses the same numeric value in the
                 * lowest byte so p11 alignment is easy to observe.
                 */
                send_pixel(
                    value[7:0],
                    value[23:0],
                    (row == 0 && col == 0),
                    (col == FRAME_WIDTH - 1)
                );

                value = value + 1;
            end
        end

        stop_input();

        repeat (30) @(posedge clk);

        $finish;
    end

endmodule