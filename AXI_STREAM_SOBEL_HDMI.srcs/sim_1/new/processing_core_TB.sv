`timescale 1ns / 1ps

module processing_core_TB;

    // ============================================================
    // Simulation configuration
    // ============================================================

    /*
     * 1080p60 pixel clock:
     *
     * 148.5 MHz -> approximately 6.734 ns.
     *
     * The testbench remains functionally valid at another frequency,
     * but using the real period better represents the implemented
     * video clock.
     */
    parameter real CLK_PERIOD_NS = 6.734;

    /*
     * Set to 1 after the always-ready test passes.
     *
     * This randomly deasserts m_axis_0_tready and verifies that the
     * complete output transaction remains stable during backpressure.
     */
    parameter bit ENABLE_RANDOM_BACKPRESSURE = 1'b0;


    // ============================================================
    // Clock and reset
    // ============================================================

    logic clk;
    logic rst_n;


    // ============================================================
    // Input AXI4-Stream interface
    // ============================================================

    logic [23:0] s_axis_0_tdata;
    logic        s_axis_0_tvalid;
    logic        s_axis_0_tuser;
    logic        s_axis_0_tlast;

    wire         s_axis_0_tready;


    // ============================================================
    // Output AXI4-Stream interface
    // ============================================================

    wire [23:0]  m_axis_0_tdata;
    wire         m_axis_0_tvalid;
    wire         m_axis_0_tuser;
    wire         m_axis_0_tlast;

    logic        m_axis_0_tready;


    // ============================================================
    // Aligned auxiliary outputs
    // ============================================================

    wire [23:0] grayscale_data_0;
    wire [23:0] rbg_data_0;


    // ============================================================
    // DUT
    // ============================================================

    processing_core_wrapper dut (
        .clk_0              (clk),
        .rst_0              (rst_n),

        .s_axis_0_tdata     (s_axis_0_tdata),
        .s_axis_0_tvalid    (s_axis_0_tvalid),
        .s_axis_0_tready    (s_axis_0_tready),
        .s_axis_0_tuser     (s_axis_0_tuser),
        .s_axis_0_tlast     (s_axis_0_tlast),

        .m_axis_0_tdata     (m_axis_0_tdata),
        .m_axis_0_tvalid    (m_axis_0_tvalid),
        .m_axis_0_tready    (m_axis_0_tready),
        .m_axis_0_tuser     (m_axis_0_tuser),
        .m_axis_0_tlast     (m_axis_0_tlast),

        .grayscale_data_0   (grayscale_data_0),
        .rbg_data_0         (rbg_data_0)
    );


    // ============================================================
    // Clock generation
    // ============================================================

    initial begin
        clk = 1'b0;

        forever begin
            #(CLK_PERIOD_NS / 2.0);
            clk = ~clk;
        end
    end


    // ============================================================
    // Expected output transaction
    // ============================================================

    typedef struct packed {
        logic [23:0] sobel_rgb;
        logic [23:0] grayscale_rgb;
        logic [23:0] original_rgb;
        logic        user;
        logic        last;
    } exp_t;

    exp_t exp_q[$];


    // ============================================================
    // Verification counters
    // ============================================================

    int pass_count;
    int fail_count;
    int assertion_fail_count;
    int output_count;

    bit input_complete;


    // ============================================================
    // Reset task
    // ============================================================

    task automatic reset_dut();
        begin
            s_axis_0_tdata  <= 24'd0;
            s_axis_0_tvalid <= 1'b0;
            s_axis_0_tuser  <= 1'b0;
            s_axis_0_tlast  <= 1'b0;

            m_axis_0_tready <= 1'b0;

            rst_n <= 1'b0;

            repeat (8) @(posedge clk);

            rst_n <= 1'b1;

            repeat (4) @(posedge clk);

            m_axis_0_tready <= 1'b1;
        end
    endtask


    // ============================================================
    // Send one AXI4-Stream RGB transaction
    // ============================================================

    task automatic send_pixel(
        input logic [23:0] rgb,
        input logic        user,
        input logic        last
    );
        begin
            /*
             * Present data on the falling edge so the transaction is
             * stable before the next positive sampling edge.
             */
            @(negedge clk);

            s_axis_0_tdata  <= rgb;
            s_axis_0_tvalid <= 1'b1;
            s_axis_0_tuser  <= user;
            s_axis_0_tlast  <= last;

            /*
             * Hold all signals stable until the DUT accepts the
             * transaction.
             */
            do begin
                @(posedge clk);
            end
            while (!(s_axis_0_tvalid && s_axis_0_tready));
        end
    endtask


    // ============================================================
    // Stop the input stream
    // ============================================================

    task automatic stop_input();
        begin
            @(negedge clk);

            s_axis_0_tdata  <= 24'd0;
            s_axis_0_tvalid <= 1'b0;
            s_axis_0_tuser  <= 1'b0;
            s_axis_0_tlast  <= 1'b0;
        end
    endtask


    // ============================================================
    // Output scoreboard
    // ============================================================

    always @(posedge clk) begin : output_monitor
        exp_t expected;

        /*
         * Wait one simulation time unit so the monitor observes
         * values updated by nonblocking assignments at this edge.
         */
        #1;

        if (rst_n && m_axis_0_tvalid && m_axis_0_tready) begin

            if (exp_q.size() == 0) begin
                $error(
                    "[SCOREBOARD] Unexpected output at time %0t",
                    $time
                );

                $display(
                    "             Sobel    = %06h",
                    m_axis_0_tdata
                );

                $display(
                    "             Grayscale = %06h",
                    grayscale_data_0
                );

                $display(
                    "             Original  = %06h",
                    rbg_data_0
                );

                $display(
                    "             TUSER=%0b TLAST=%0b",
                    m_axis_0_tuser,
                    m_axis_0_tlast
                );

                fail_count++;
            end
            else begin
                expected = exp_q.pop_front();

                if (m_axis_0_tdata !== expected.sobel_rgb) begin
                    $error(
                        "[SOBEL] Mismatch at output %0d, time %0t",
                        output_count,
                        $time
                    );

                    $display(
                        "        Expected = %06h",
                        expected.sobel_rgb
                    );

                    $display(
                        "        Actual   = %06h",
                        m_axis_0_tdata
                    );

                    fail_count++;
                end

                if (grayscale_data_0 !== expected.grayscale_rgb) begin
                    $error(
                        "[GRAYSCALE] Mismatch at output %0d, time %0t",
                        output_count,
                        $time
                    );

                    $display(
                        "            Expected = %06h",
                        expected.grayscale_rgb
                    );

                    $display(
                        "            Actual   = %06h",
                        grayscale_data_0
                    );

                    fail_count++;
                end

                if (rbg_data_0 !== expected.original_rgb) begin
                    $error(
                        "[ORIGINAL] Mismatch at output %0d, time %0t",
                        output_count,
                        $time
                    );

                    $display(
                        "           Expected = %06h",
                        expected.original_rgb
                    );

                    $display(
                        "           Actual   = %06h",
                        rbg_data_0
                    );

                    fail_count++;
                end

                if (m_axis_0_tuser !== expected.user) begin
                    $error(
                        "[TUSER] Mismatch at output %0d: expected=%0b actual=%0b",
                        output_count,
                        expected.user,
                        m_axis_0_tuser
                    );

                    fail_count++;
                end

                if (m_axis_0_tlast !== expected.last) begin
                    $error(
                        "[TLAST] Mismatch at output %0d: expected=%0b actual=%0b",
                        output_count,
                        expected.last,
                        m_axis_0_tlast
                    );

                    fail_count++;
                end

                if (
                    (m_axis_0_tdata === expected.sobel_rgb) &&
                    (grayscale_data_0 === expected.grayscale_rgb) &&
                    (rbg_data_0 === expected.original_rgb) &&
                    (m_axis_0_tuser === expected.user) &&
                    (m_axis_0_tlast === expected.last)
                ) begin
                    pass_count++;

                    /*
                     * Do not print every pixel for a large frame.
                     */
                    if (
                        (output_count < 10) ||
                        ((output_count % 50000) == 0)
                    ) begin
                        $display(
                            "[PASS] output=%0d sobel=%06h gray=%06h original=%06h user=%0b last=%0b",
                            output_count,
                            m_axis_0_tdata,
                            grayscale_data_0,
                            rbg_data_0,
                            m_axis_0_tuser,
                            m_axis_0_tlast
                        );
                    end
                end

                output_count++;
            end
        end
    end


    // ============================================================
    // SystemVerilog Assertions
    // ============================================================

    /*
     * AXI4-Stream rule:
     *
     * If the output is valid but the receiver is not ready, the
     * complete transaction must remain valid and unchanged on the
     * following cycle.
     *
     * The aligned grayscale and original RGB outputs are included
     * because they belong to the same logical output transaction.
     */
    property p_output_stable_during_stall;
        @(posedge clk)
        disable iff (!rst_n)

        m_axis_0_tvalid && !m_axis_0_tready
        |=> m_axis_0_tvalid &&
            $stable({
                m_axis_0_tdata,
                m_axis_0_tuser,
                m_axis_0_tlast,
                grayscale_data_0,
                rbg_data_0
            });
    endproperty

    assert property (p_output_stable_during_stall)
    else begin
        $error(
            "[ASSERTION] Output transaction changed during backpressure"
        );

        assertion_fail_count++;
    end


    /*
     * The upstream source must also retain the complete transaction
     * while the DUT is not ready.
     *
     * This primarily verifies the testbench driver, but the same
     * requirement applies to any real AXI4-Stream source.
     */
    property p_input_stable_during_stall;
        @(posedge clk)
        disable iff (!rst_n)

        s_axis_0_tvalid && !s_axis_0_tready
        |=> s_axis_0_tvalid &&
            $stable({
                s_axis_0_tdata,
                s_axis_0_tuser,
                s_axis_0_tlast
            });
    endproperty

    assert property (p_input_stable_during_stall)
    else begin
        $error(
            "[ASSERTION] Input transaction changed during backpressure"
        );

        assertion_fail_count++;
    end


    /*
     * TUSER identifies the first pixel of a frame and must not be
     * asserted without a valid output transaction.
     */
    property p_output_tuser_requires_tvalid;
        @(posedge clk)
        disable iff (!rst_n)

        m_axis_0_tuser |-> m_axis_0_tvalid;
    endproperty

    assert property (p_output_tuser_requires_tvalid)
    else begin
        $error(
            "[ASSERTION] Output TUSER asserted without TVALID"
        );

        assertion_fail_count++;
    end


    /*
     * TLAST identifies the final pixel of a line and must not be
     * asserted without a valid output transaction.
     */
    property p_output_tlast_requires_tvalid;
        @(posedge clk)
        disable iff (!rst_n)

        m_axis_0_tlast |-> m_axis_0_tvalid;
    endproperty

    assert property (p_output_tlast_requires_tvalid)
    else begin
        $error(
            "[ASSERTION] Output TLAST asserted without TVALID"
        );

        assertion_fail_count++;
    end


    /*
     * Check that output control signals never become X or Z after
     * reset has been released.
     */
    property p_output_control_known;
        @(posedge clk)
        disable iff (!rst_n)

        !$isunknown({
            m_axis_0_tvalid,
            m_axis_0_tready,
            m_axis_0_tuser,
            m_axis_0_tlast
        });
    endproperty

    assert property (p_output_control_known)
    else begin
        $error(
            "[ASSERTION] Unknown value detected on output control signals"
        );

        assertion_fail_count++;
    end


    /*
     * Check that input control signals never become X or Z after
     * reset has been released.
     */
    property p_input_control_known;
        @(posedge clk)
        disable iff (!rst_n)

        !$isunknown({
            s_axis_0_tvalid,
            s_axis_0_tready,
            s_axis_0_tuser,
            s_axis_0_tlast
        });
    endproperty

    assert property (p_input_control_known)
    else begin
        $error(
            "[ASSERTION] Unknown value detected on input control signals"
        );

        assertion_fail_count++;
    end


    // ============================================================
    // Optional randomized backpressure
    // ============================================================

    /*
     * Only this block controls m_axis_0_tready after reset.
     *
     * With random backpressure disabled, the downstream interface
     * remains continuously ready.
     */
    always @(negedge clk) begin
        if (!rst_n) begin
            m_axis_0_tready <= 1'b0;
        end
        else if (ENABLE_RANDOM_BACKPRESSURE) begin
            /*
             * Approximately 80 percent ready.
             */
            m_axis_0_tready <=
                ($urandom_range(0, 9) < 8);
        end
        else begin
            m_axis_0_tready <= 1'b1;
        end
    end


    // ============================================================
    // Wait until expected outputs drain
    // ============================================================

    task automatic wait_for_outputs_to_drain(
        input int timeout_cycles
    );
        int timeout;

        begin
            timeout = 0;

            while (
                (exp_q.size() != 0) &&
                (timeout < timeout_cycles)
            ) begin
                @(posedge clk);
                timeout++;
            end

            /*
             * Allow time for accidental extra output transactions.
             */
            repeat (20) @(posedge clk);

            if (exp_q.size() != 0) begin
                $error(
                    "[SCOREBOARD] Expected queue not empty after timeout, remaining=%0d",
                    exp_q.size()
                );

                fail_count++;
            end
        end
    endtask


    // ============================================================
    // Load Python-generated expected output
    // ============================================================

    /*
     * Expected file format:
     *
     * WIDTH HEIGHT NUM_OUTPUTS
     * SOBEL_RGB_HEX GRAYSCALE_RGB_HEX ORIGINAL_RGB_HEX USER LAST
     * SOBEL_RGB_HEX GRAYSCALE_RGB_HEX ORIGINAL_RGB_HEX USER LAST
     * ...
     *
     * Example:
     *
     * 1920 1080 2073600
     * 000000 000000 000000 1 0
     * 000000 000000 000000 0 0
     * 121212 808080 A1B2C3 0 0
     */
    task automatic load_expected_file(
        output int width,
        output int height,
        output int num_outputs
    );
        int exp_fd;
        int scan_status;
        int i;

        logic [23:0] sobel_rgb;
        logic [23:0] grayscale_rgb;
        logic [23:0] original_rgb;

        int user_int;
        int last_int;

        exp_t item;

        begin
            exp_q.delete();

            exp_fd = $fopen(
                "processing_core_expected.txt",
                "r"
            );

            if (exp_fd == 0) begin
                $fatal(
                    1,
                    "[FILE] Could not open processing_core_expected.txt"
                );
            end

            scan_status = $fscanf(
                exp_fd,
                "%d %d %d\n",
                width,
                height,
                num_outputs
            );

            if (scan_status != 3) begin
                $fatal(
                    1,
                    "[FILE] Could not read expected-file header"
                );
            end

            $display(
                "[INFO] Expected file: width=%0d height=%0d outputs=%0d",
                width,
                height,
                num_outputs
            );

            for (i = 0; i < num_outputs; i++) begin
                scan_status = $fscanf(
                    exp_fd,
                    "%h %h %h %d %d\n",
                    sobel_rgb,
                    grayscale_rgb,
                    original_rgb,
                    user_int,
                    last_int
                );

                if (scan_status != 5) begin
                    $fatal(
                        1,
                        "[FILE] Could not read expected output line %0d",
                        i
                    );
                end

                item.sobel_rgb     = sobel_rgb;
                item.grayscale_rgb = grayscale_rgb;
                item.original_rgb  = original_rgb;
                item.user          = user_int[0];
                item.last          = last_int[0];

                exp_q.push_back(item);
            end

            $fclose(exp_fd);

            $display(
                "[INFO] Loaded %0d expected transactions",
                exp_q.size()
            );
        end
    endtask


    // ============================================================
    // Drive Python-generated RGB frame
    // ============================================================

    /*
     * Input file format:
     *
     * WIDTH HEIGHT
     * RGB_HEX
     * RGB_HEX
     * ...
     *
     * Example:
     *
     * 1920 1080
     * FF0000
     * 00FF00
     * 0000FF
     */
    task automatic drive_input_file(
        input int expected_width,
        input int expected_height
    );
        int in_fd;
        int scan_status;

        int width;
        int height;

        int row;
        int col;

        logic [23:0] rgb;
        logic        user_value;
        logic        last_value;

        begin
            in_fd = $fopen(
                "processing_core_input.txt",
                "r"
            );

            if (in_fd == 0) begin
                $fatal(
                    1,
                    "[FILE] Could not open processing_core_input.txt"
                );
            end

            scan_status = $fscanf(
                in_fd,
                "%d %d\n",
                width,
                height
            );

            if (scan_status != 2) begin
                $fatal(
                    1,
                    "[FILE] Could not read input-file header"
                );
            end

            $display(
                "[INFO] Input file: width=%0d height=%0d",
                width,
                height
            );

            if (
                (width != expected_width) ||
                (height != expected_height)
            ) begin
                $fatal(
                    1,
                    "[FILE] Input dimensions %0dx%0d do not match expected dimensions %0dx%0d",
                    width,
                    height,
                    expected_width,
                    expected_height
                );
            end

            for (row = 0; row < height; row++) begin
                for (col = 0; col < width; col++) begin

                    scan_status = $fscanf(
                        in_fd,
                        "%h\n",
                        rgb
                    );

                    if (scan_status != 1) begin
                        $fatal(
                            1,
                            "[FILE] Could not read input pixel at row=%0d col=%0d",
                            row,
                            col
                        );
                    end

                    user_value =
                        (row == 0) &&
                        (col == 0);

                    last_value =
                        (col == width - 1);

                    send_pixel(
                        rgb,
                        user_value,
                        last_value
                    );
                end
            end

            $fclose(in_fd);

            stop_input();

            input_complete = 1'b1;

            $display(
                "[INFO] Finished driving input frame"
            );
        end
    endtask


    // ============================================================
    // Main Python-reference test
    // ============================================================

    task automatic test_python_reference();
        int width;
        int height;
        int num_outputs;
        int timeout_cycles;

        begin
            $display("");
            $display("================================================");
            $display("[TEST] Processing-core Python-reference test");
            $display("================================================");

            reset_dut();

            load_expected_file(
                width,
                height,
                num_outputs
            );

            drive_input_file(
                width,
                height
            );

            /*
             * Provide several cycles per expected output plus a
             * generous pipeline margin.
             */
            timeout_cycles =
                (num_outputs * 5) + 10000;

            wait_for_outputs_to_drain(
                timeout_cycles
            );

            $display(
                "[INFO] Python-reference test completed"
            );
        end
    endtask


    // ============================================================
    // Main simulation sequence
    // ============================================================

    initial begin
        pass_count            = 0;
        fail_count            = 0;
        assertion_fail_count  = 0;
        output_count          = 0;
        input_complete        = 1'b0;

        s_axis_0_tdata        = 24'd0;
        s_axis_0_tvalid       = 1'b0;
        s_axis_0_tuser        = 1'b0;
        s_axis_0_tlast        = 1'b0;

        m_axis_0_tready       = 1'b0;

        rst_n                 = 1'b0;

        repeat (3) @(posedge clk);

        test_python_reference();

        repeat (50) @(posedge clk);

        $display("");
        $display("================================================");
        $display(" Processing-Core Verification Summary");
        $display("================================================");
        $display(
            "Accepted outputs     : %0d",
            output_count
        );
        $display(
            "Fully correct outputs: %0d",
            pass_count
        );
        $display(
            "Scoreboard failures  : %0d",
            fail_count
        );
        $display(
            "Assertion failures   : %0d",
            assertion_fail_count
        );
        $display(
            "Remaining expected   : %0d",
            exp_q.size()
        );
        $display("================================================");

        if (
            (fail_count == 0) &&
            (assertion_fail_count == 0) &&
            (exp_q.size() == 0)
        ) begin
            $display("");
            $display("[PASS] PROCESSING CORE TEST PASSED");
            $display(
                "[PASS] RTL matches the Python reference"
            );
            $display(
                "[PASS] AXI4-Stream assertions passed"
            );
            $display("");

            $finish;
        end
        else begin
            $fatal(
                1,
                "[FAIL] Test completed with %0d scoreboard failures and %0d assertion failures",
                fail_count,
                assertion_fail_count
            );
        end
    end

endmodule