`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2026 01:44:04 PM
// Design Name: 
// Module Name: grayscale_TB
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

module grayscale_TB();

    // clk & rst
    logic clk;
    logic rst;

    // up stream / as-slave side
    logic [23:0] s_axis_tdata;
    logic s_axis_tvalid;
    logic s_axis_tready;
    logic s_axis_tuser;
    logic s_axis_tlast;

    // dowm stream / as-master side
    logic [7:0]  m_axis_tdata;
    logic m_axis_tvalid;
    logic m_axis_tready;
    logic m_axis_tuser;
    logic m_axis_tlast;

    // DUT
    grayscale dut (
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
    
    // 100 MHz simulation clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Expected output item
    typedef struct packed {
        logic [7:0] gray;
        logic user;
        logic last;
    } exp_t;

    exp_t exp_q[$];

    int pass_count;
    int fail_count;

    // Reference grayscale function
    function automatic logic [7:0] expected_gray(input logic [23:0] rbg);
        logic [7:0] r;
        logic [7:0] b;
        logic [7:0] g;
        logic [16:0] sum;
        begin
            r = rbg[23:16];
            b = rbg[15:8];
            g = rbg[7:0];

            sum = r * 8'd77 + g * 8'd150 + b * 8'd29;
            expected_gray = sum[15:8];
        end
    endfunction

    // Send one AXI-stream pixel.
    // Drives input before clock edge, waits until accepted.
    task automatic send_pixel(
        input logic [23:0] rbg,
        input logic user,
        input logic last
    );
        exp_t item;
        begin
            item.gray = expected_gray(rbg);
            item.user = user;
            item.last = last;

            @(negedge clk);
            s_axis_tdata <= rbg;
            s_axis_tvalid <= 1'b1;
            s_axis_tuser  <= user;
            s_axis_tlast <= last;

            // Wait until transfer happens
            do begin
                @(posedge clk);
            end while (!(s_axis_tvalid && s_axis_tready));

            exp_q.push_back(item);

            @(negedge clk);
            s_axis_tvalid <= 1'b0;
            s_axis_tdata <= 24'd0;
            s_axis_tuser <= 1'b0;
            s_axis_tlast <= 1'b0;
        end
    endtask

    // Monitor output stream
    always @(posedge clk) begin
        #1;

        if (!rst && m_axis_tvalid && m_axis_tready) begin
            exp_t exp;

            if (exp_q.size() == 0) begin
                $error("[FAIL] Unexpected output: data=%0d user=%0b last=%0b",
                       m_axis_tdata, m_axis_tuser, m_axis_tlast);
                fail_count++;
            end else begin
                exp = exp_q.pop_front();

                if (m_axis_tdata !== exp.gray ||
                    m_axis_tuser !== exp.user ||
                    m_axis_tlast !== exp.last) begin

                    $error("[FAIL] Expected gray=%0d user=%0b last=%0b, got gray=%0d user=%0b last=%0b",
                           exp.gray, exp.user, exp.last,
                           m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    fail_count++;
                end else begin
                    $display("[PASS] gray=%0d user=%0b last=%0b",
                             m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    pass_count++;
                end
            end
        end
    end

    // Main test
    initial begin
        pass_count = 0;
        fail_count = 0;

        s_axis_tdata  = 24'd0;
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

        // Basic directed pixels
        send_pixel(24'h000000, 1'b1, 1'b0); // black, first pixel of frame
        send_pixel(24'hFFFFFF, 1'b0, 1'b0); // white
        send_pixel(24'hFF0000, 1'b0, 1'b0); // red
        send_pixel(24'h00FF00, 1'b0, 1'b0); // green
        send_pixel(24'h0000FF, 1'b0, 1'b1); // blue, end of line

        // Extra values
        send_pixel(24'h123456, 1'b0, 1'b0);
        send_pixel(24'hABCDEF, 1'b0, 1'b1);

        // Allow outputs to drain
        repeat (10) @(posedge clk);

        if (exp_q.size() != 0) begin
            $error("[FAIL] Expected queue not empty, remaining=%0d", exp_q.size());
            fail_count++;
        end

        // Simple stall/hold test
        test_stall_hold();

        repeat (5) @(posedge clk);

        if (fail_count == 0) begin
            $display("[PASS] tb_grayscale completed with %0d passed checks", pass_count);
            $finish;
        end else begin
            $fatal(1, "[FAIL] tb_grayscale completed with %0d failures", fail_count);
        end
    end

    // Test that output holds stable when downstream is not ready
    task automatic test_stall_hold();
        logic [7:0] held_data;
        logic       held_user;
        logic       held_last;
        begin
            $display("[-----INFO-----] Starting stall/hold test");

            @(negedge clk);
            m_axis_tready <= 1'b0;

            // Send one pixel while output register is empty.
            // It should be accepted, then held because downstream is not ready.
            send_pixel(24'h808080, 1'b1, 1'b1);

            // Wait until output becomes valid
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
