`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/08/2026 05:13:35 PM
// Design Name: 
// Module Name: processing_core_TB
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

module processing_core_TB;

    // ------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------
    logic clk;
    logic rst_n;

    // ------------------------------------------------------------
    // Input AXI-style stream to processing core
    // ------------------------------------------------------------
    logic [23:0] s_axis_0_tdata;
    logic        s_axis_0_tvalid;
    logic        s_axis_0_tready;
    logic        s_axis_0_tuser;
    logic        s_axis_0_tlast;

    // ------------------------------------------------------------
    // Output AXI-style stream from processing core
    // ------------------------------------------------------------
    logic [23:0]  m_axis_0_tdata;
    logic        m_axis_0_tvalid;
    logic        m_axis_0_tready;
    logic        m_axis_0_tuser;
    logic        m_axis_0_tlast;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    processing_core_wrapper dut (
        .clk(clk),

        .s_axis_0_tdata(s_axis_0_tdata),
        .s_axis_0_tlast(s_axis_0_tlast),
        .s_axis_0_tready(s_axis_0_tready),
        .s_axis_0_tuser(s_axis_0_tuser),
        .s_axis_0_tvalid(s_axis_0_tvalid),

        .m_axis_0_tdata(m_axis_0_tdata),
        .m_axis_0_tlast(m_axis_0_tlast),
        .m_axis_0_tready(m_axis_0_tready),
        .m_axis_0_tuser(m_axis_0_tuser),
        .m_axis_0_tvalid(m_axis_0_tvalid),

        .rst_n(rst_n)
    );

    // ------------------------------------------------------------
    // Clock generation: 100 MHz simulation clock
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Expected output item
    // ------------------------------------------------------------
    typedef struct packed {
        logic [7:0] edge_mag;
        logic       user;
        logic       last;
    } exp_t;

    exp_t exp_q[$];

    int pass_count;
    int fail_count;
    int output_count;

    // ------------------------------------------------------------
    // Reset DUT
    // ------------------------------------------------------------
    task automatic reset_dut();
        begin
            s_axis_0_tdata  <= 24'd0;
            s_axis_0_tvalid <= 1'b0;
            s_axis_0_tuser  <= 1'b0;
            s_axis_0_tlast  <= 1'b0;

            m_axis_0_tready <= 1'b1;

            rst_n <= 1'b0;
            repeat (8) @(posedge clk);
            rst_n <= 1'b1;
            repeat (4) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // Send one RGB pixel with valid/ready handshake
    // ------------------------------------------------------------
    task automatic send_pixel(
        input logic [23:0] rgb,
        input logic        user,
        input logic        last
    );
        begin
            @(negedge clk);
            s_axis_0_tdata  <= rgb;
            s_axis_0_tvalid <= 1'b1;
            s_axis_0_tuser  <= user;
            s_axis_0_tlast  <= last;

            do begin
                @(posedge clk);
            end while (!(s_axis_0_tvalid && s_axis_0_tready));
        end
    endtask

    // ------------------------------------------------------------
    // Stop driving input stream
    // ------------------------------------------------------------
    task automatic stop_input();
        begin
            @(negedge clk);
            s_axis_0_tdata  <= 24'd0;
            s_axis_0_tvalid <= 1'b0;
            s_axis_0_tuser  <= 1'b0;
            s_axis_0_tlast  <= 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Output monitor / checker
    // ------------------------------------------------------------
    always @(posedge clk) begin
        #1;

        if (rst_n && m_axis_0_tvalid && m_axis_0_tready) begin
            exp_t exp;

            if (exp_q.size() == 0) begin
                $error("[FAIL] Unexpected output: edge=%0d user=%0b last=%0b at time=%0t",
                       m_axis_0_tdata[7:0], m_axis_0_tuser, m_axis_0_tlast, $time);
                fail_count++;
            end else begin
                exp = exp_q.pop_front();

                if (m_axis_0_tdata[7:0] !== exp.edge_mag ||
                    m_axis_0_tuser !== exp.user ||
                    m_axis_0_tlast !== exp.last) begin

                    $error("[FAIL] Output mismatch at output_count=%0d time=%0t",
                           output_count, $time);
                    $display("       Expected: edge=%0d user=%0b last=%0b",
                             exp.edge_mag, exp.user, exp.last);
                    $display("       Got     : edge=%0d user=%0b last=%0b",
                             m_axis_0_tdata[7:0], m_axis_0_tuser, m_axis_0_tlast);
                    fail_count++;
                end else begin
                    pass_count++;

                    // Avoid printing hundreds of thousands of lines.
                    if (output_count < 10 || (output_count % 50000) == 0) begin
                        $display("[PASS] output_count=%0d edge=%0d user=%0b last=%0b",
                                 output_count, m_axis_0_tdata[7:0],
                                 m_axis_0_tuser, m_axis_0_tlast);
                    end
                end

                output_count++;
            end
        end
    end

    // ------------------------------------------------------------
    // Wait until expected output queue is empty
    // ------------------------------------------------------------
    task automatic wait_for_outputs_to_drain(input int timeout_cycles);
        int timeout;
        begin
            timeout = 0;

            while (exp_q.size() != 0 && timeout < timeout_cycles) begin
                @(posedge clk);
                timeout++;
            end

            repeat (20) @(posedge clk);

            if (exp_q.size() != 0) begin
                $error("[FAIL] Expected queue not empty after timeout, remaining=%0d",
                       exp_q.size());
                fail_count++;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Load expected output from Python-generated file
    //
    // Expected file format:
    // WIDTH HEIGHT NUM_OUTPUTS
    // EDGE USER LAST
    // EDGE USER LAST
    // ...
    // ------------------------------------------------------------
    task automatic load_expected_file(
        output int width,
        output int height,
        output int num_outputs
    );
        int exp_fd;
        int scan_status;
        int i;

        int edge_int;
        int user_int;
        int last_int;

        exp_t item;

        begin
            exp_q.delete();

            exp_fd = $fopen("processing_core_expected.txt", "r");

            if (exp_fd == 0) begin
                $fatal(1, "[FAIL] Could not open processing_core_expected.txt");
            end

            scan_status = $fscanf(exp_fd, "%d %d %d\n",
                                  width, height, num_outputs);

            if (scan_status != 3) begin
                $fatal(1, "[FAIL] Could not read expected file header");
            end

            $display("[INFO] Expected file header: width=%0d height=%0d num_outputs=%0d",
                     width, height, num_outputs);

            for (i = 0; i < num_outputs; i++) begin
                scan_status = $fscanf(exp_fd, "%d %d %d\n",
                                      edge_int, user_int, last_int);

                if (scan_status != 3) begin
                    $fatal(1, "[FAIL] Could not read expected output line %0d", i);
                end

                item.edge_mag = edge_int[7:0];
                item.user = user_int[0];
                item.last = last_int[0];

                exp_q.push_back(item);
            end

            $fclose(exp_fd);

            $display("[INFO] Loaded %0d expected outputs", exp_q.size());
        end
    endtask

    // ------------------------------------------------------------
    // Drive input frame from Python-generated file
    //
    // Input file format:
    // WIDTH HEIGHT
    // RGB_HEX
    // RGB_HEX
    // ...
    // ------------------------------------------------------------
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
        logic        user;
        logic        last;

        begin
            in_fd = $fopen("processing_core_input.txt", "r");

            if (in_fd == 0) begin
                $fatal(1, "[FAIL] Could not open processing_core_input.txt");
            end

            scan_status = $fscanf(in_fd, "%d %d\n", width, height);

            if (scan_status != 2) begin
                $fatal(1, "[FAIL] Could not read input file header");
            end

            $display("[INFO] Input file header: width=%0d height=%0d",
                     width, height);

            if (width != expected_width || height != expected_height) begin
                $fatal(1,
                       "[FAIL] Input dimensions do not match expected file dimensions. input=%0dx%0d expected=%0dx%0d",
                       width, height, expected_width, expected_height);
            end

            for (row = 0; row < height; row++) begin
                for (col = 0; col < width; col++) begin
                    scan_status = $fscanf(in_fd, "%h\n", rgb);

                    if (scan_status != 1) begin
                        $fatal(1,
                               "[FAIL] Could not read input pixel at row=%0d col=%0d",
                               row, col);
                    end

                    user = (row == 0 && col == 0);
                    last = (col == width - 1);

                    send_pixel(rgb, user, last);
                end
            end

            $fclose(in_fd);

            stop_input();

            $display("[INFO] Finished driving input frame");
        end
    endtask

    // ------------------------------------------------------------
    // Main full-core Python-reference test
    // ------------------------------------------------------------
    task automatic test_python_reference();
        int width;
        int height;
        int num_outputs;

        begin
            $display("========================================");
            $display("[TEST] Processing core Python-reference test");
            $display("========================================");

            reset_dut();

            load_expected_file(width, height, num_outputs);

            drive_input_file(width, height);

            // This timeout is intentionally large.
            wait_for_outputs_to_drain(2_000_000);

            $display("[INFO] Python-reference test completed");
        end
    endtask

    // ------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------
    initial begin
        pass_count   = 0;
        fail_count   = 0;
        output_count = 0;

        s_axis_0_tdata  = 24'd0;
        s_axis_0_tvalid = 1'b0;
        s_axis_0_tuser  = 1'b0;
        s_axis_0_tlast  = 1'b0;

        m_axis_0_tready = 1'b1;

        rst_n = 1'b0;
        repeat (3) @(posedge clk);

        test_python_reference();

        repeat (50) @(posedge clk);

        if (fail_count == 0) begin
            $display("========================================");
            $display("[PASS] processing_core_wrapper_TB completed");
            $display("[PASS] Total checked outputs = %0d", pass_count);
            $display("========================================");
            $finish;
        end else begin
            $fatal(1,
                   "[FAIL] processing_core_wrapper_TB completed with %0d failures",
                   fail_count);
        end
    end

endmodule
