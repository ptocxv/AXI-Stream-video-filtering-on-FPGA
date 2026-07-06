`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2026 08:13:06 PM
// Design Name: 
// Module Name: sobel_TB
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

module sobel_TB;

    // Clock/reset
    logic clk;
    logic rst;

    // Input stream
    logic [71:0] s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tready;
    logic        s_axis_tuser;
    logic        s_axis_tlast;

    // Output stream
    logic [7:0]  m_axis_tdata;
    logic        m_axis_tvalid;
    logic        m_axis_tready;
    logic        m_axis_tuser;
    logic        m_axis_tlast;

    // DUT
    axis_sobel dut (
        .clk(clk),
        .rst(rst),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast)
    );

    // Clock generation: 100 MHz simulation clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Expected output item
    typedef struct packed {
        logic [7:0] edge_mag;
        logic       user;
        logic       last;
    } exp_t;

    exp_t exp_q[$];

    int pass_count;
    int fail_count;

    // ------------------------------------------------------------
    // Pack 3x3 window, column-major format
    //
    // Window:
    // p00 p01 p02
    // p10 p11 p12
    // p20 p21 p22
    //
    // Packed:
    // {p00, p10, p20, p01, p11, p21, p02, p12, p22}
    // ------------------------------------------------------------
    function automatic logic [71:0] pack_window_col_major(
        input logic [7:0] p00,
        input logic [7:0] p01,
        input logic [7:0] p02,
        input logic [7:0] p10,
        input logic [7:0] p11,
        input logic [7:0] p12,
        input logic [7:0] p20,
        input logic [7:0] p21,
        input logic [7:0] p22
    );
        begin
            pack_window_col_major = {
                p00, p10, p20,
                p01, p11, p21,
                p02, p12, p22
            };
        end
    endfunction

    // ------------------------------------------------------------
    // Golden Sobel reference
    // ------------------------------------------------------------
    function automatic logic [7:0] expected_sobel(
        input logic [7:0] p00,
        input logic [7:0] p01,
        input logic [7:0] p02,
        input logic [7:0] p10,
        input logic [7:0] p11,
        input logic [7:0] p12,
        input logic [7:0] p20,
        input logic [7:0] p21,
        input logic [7:0] p22
    );
        logic signed [11:0] gx;
        logic signed [11:0] gy;
        logic [11:0] abs_gx;
        logic [11:0] abs_gy;
        logic [12:0] magnitude;

        begin
            // Gx = -p00 + p02 -2p10 +2p12 -p20 +p22
            gx = -$signed({4'h0, p00})
                 + $signed({4'h0, p02})
                 - ($signed({4'h0, p10}) <<< 1)
                 + ($signed({4'h0, p12}) <<< 1)
                 - $signed({4'h0, p20})
                 + $signed({4'h0, p22});

            // Gy = -p00 -2p01 -p02 +p20 +2p21 +p22
            gy = -$signed({4'h0, p00})
                 - ($signed({4'h0, p01}) <<< 1)
                 - $signed({4'h0, p02})
                 + $signed({4'h0, p20})
                 + ($signed({4'h0, p21}) <<< 1)
                 + $signed({4'h0, p22});

            if (gx < 0)
                abs_gx = -gx;
            else
                abs_gx = gx;

            if (gy < 0)
                abs_gy = -gy;
            else
                abs_gy = gy;

            magnitude = abs_gx + abs_gy;

            if (magnitude > 13'd255)
                expected_sobel = 8'd255;
            else
                expected_sobel = magnitude[7:0];
        end
    endfunction

    // ------------------------------------------------------------
    // Send one 3x3 window through AXI stream
    // ------------------------------------------------------------
    task automatic send_window(
        input logic [7:0] p00,
        input logic [7:0] p01,
        input logic [7:0] p02,
        input logic [7:0] p10,
        input logic [7:0] p11,
        input logic [7:0] p12,
        input logic [7:0] p20,
        input logic [7:0] p21,
        input logic [7:0] p22,
        input logic       user,
        input logic       last
    );
        exp_t item;
        begin
            item.edge_mag = expected_sobel(
                p00, p01, p02,
                p10, p11, p12,
                p20, p21, p22
            );
            item.user = user;
            item.last = last;

            @(negedge clk);
            s_axis_tdata  <= pack_window_col_major(
                p00, p01, p02,
                p10, p11, p12,
                p20, p21, p22
            );
            s_axis_tvalid <= 1'b1;
            s_axis_tuser  <= user;
            s_axis_tlast  <= last;

            // Wait until input transfer happens
            do begin
                @(posedge clk);
            end while (!(s_axis_tvalid && s_axis_tready));

            exp_q.push_back(item);

            @(negedge clk);
            s_axis_tvalid <= 1'b0;
            s_axis_tdata  <= 72'd0;
            s_axis_tuser  <= 1'b0;
            s_axis_tlast  <= 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Output monitor/checker
    // ------------------------------------------------------------
    always @(posedge clk) begin
        #1;

        if (!rst && m_axis_tvalid && m_axis_tready) begin
            exp_t exp;

            if (exp_q.size() == 0) begin
                $error("[FAIL] Unexpected output: edge=%0d user=%0b last=%0b",
                       m_axis_tdata, m_axis_tuser, m_axis_tlast);
                fail_count++;
            end else begin
                exp = exp_q.pop_front();

                if (m_axis_tdata !== exp.edge_mag ||
                    m_axis_tuser !== exp.user ||
                    m_axis_tlast !== exp.last) begin

                    $error("[FAIL] Expected edge=%0d user=%0b last=%0b, got edge=%0d user=%0b last=%0b",
                           exp.edge_mag, exp.user, exp.last,
                           m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    fail_count++;
                end else begin
                    $display("[PASS] edge=%0d user=%0b last=%0b",
                             m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    pass_count++;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        s_axis_tdata  = 72'd0;
        s_axis_tvalid = 1'b0;
        s_axis_tuser  = 1'b0;
        s_axis_tlast  = 1'b0;
        m_axis_tready = 1'b1;

        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        if (m_axis_tvalid !== 1'b0) begin
            $error("[FAIL] m_axis_tvalid should be 0 after reset");
            fail_count++;
        end else begin
            $display("[PASS] reset clears m_axis_tvalid");
            pass_count++;
        end

        // Test 1: flat window -> edge = 0
        send_window(
            8'd10, 8'd10, 8'd10,
            8'd10, 8'd10, 8'd10,
            8'd10, 8'd10, 8'd10,
            1'b1, 1'b0
        );

        // Test 2: all zero -> edge = 0
        send_window(
            8'd0, 8'd0, 8'd0,
            8'd0, 8'd0, 8'd0,
            8'd0, 8'd0, 8'd0,
            1'b0, 1'b0
        );

        // Test 3: vertical edge, strong positive Gx -> saturates
        send_window(
            8'd0,   8'd0,   8'd255,
            8'd0,   8'd0,   8'd255,
            8'd0,   8'd0,   8'd255,
            1'b0, 1'b0
        );

        // Test 4: vertical edge, strong negative Gx -> saturates
        send_window(
            8'd255, 8'd0, 8'd0,
            8'd255, 8'd0, 8'd0,
            8'd255, 8'd0, 8'd0,
            1'b0, 1'b0
        );

        // Test 5: horizontal edge, strong positive Gy -> saturates
        send_window(
            8'd0,   8'd0,   8'd0,
            8'd0,   8'd0,   8'd0,
            8'd255, 8'd255, 8'd255,
            1'b0, 1'b0
        );

        // Test 6: horizontal edge, strong negative Gy -> saturates
        send_window(
            8'd255, 8'd255, 8'd255,
            8'd0,   8'd0,   8'd0,
            8'd0,   8'd0,   8'd0,
            1'b0, 1'b0
        );

        // Test 7: non-saturated random-ish window
        send_window(
            8'd10,  8'd20,  8'd30,
            8'd40,  8'd50,  8'd60,
            8'd70,  8'd80,  8'd90,
            1'b0, 1'b1
        );

        // Drain outputs
        repeat (10) @(posedge clk);

        if (exp_q.size() != 0) begin
            $error("[FAIL] Expected queue not empty, remaining=%0d", exp_q.size());
            fail_count++;
        end

        // Stall/hold behavior
        test_stall_hold();

        repeat (5) @(posedge clk);

        if (fail_count == 0) begin
            $display("[PASS] axis_sobel_TB completed with %0d checks", pass_count);
            $finish;
        end else begin
            $fatal(1, "[FAIL] axis_sobel_TB completed with %0d failures", fail_count);
        end
    end

    // ------------------------------------------------------------
    // Stall test
    // Check that output holds while m_axis_tready = 0
    // ------------------------------------------------------------
    task automatic test_stall_hold();
        logic [7:0] held_data;
        logic       held_user;
        logic       held_last;
        begin
            $display("[-----INFO-----] Starting stall/hold test");

            @(negedge clk);
            m_axis_tready <= 1'b0;

            send_window(
                8'd0,   8'd0,   8'd255,
                8'd0,   8'd0,   8'd255,
                8'd0,   8'd0,   8'd255,
                1'b1, 1'b1
            );

            wait (m_axis_tvalid === 1'b1);
            #1;

            held_data = m_axis_tdata;
            held_user = m_axis_tuser;
            held_last = m_axis_tlast;

            repeat (3) begin
                @(posedge clk);
                #1;

                if (m_axis_tdata !== held_data ||
                    m_axis_tuser !== held_user ||
                    m_axis_tlast !== held_last ||
                    m_axis_tvalid !== 1'b1) begin

                    $error("[FAIL] Output changed while m_axis_tready=0");
                    fail_count++;
                end
            end

            @(negedge clk);
            m_axis_tready <= 1'b1;

            repeat (3) @(posedge clk);

            $display("[PASS] stall/hold test completed");
            pass_count++;
        end
    endtask

endmodule
