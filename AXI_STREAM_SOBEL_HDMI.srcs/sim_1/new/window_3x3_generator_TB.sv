`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/05/2026 11:05:04 PM
// Design Name: 
// Module Name: window_3x3_generator_TB
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



module window_3x3_generator_TB;

    localparam int FRAME_WIDTH  = 4;
    localparam int FRAME_HEIGHT = 4;
    localparam int NUM_PIXELS   = FRAME_WIDTH * FRAME_HEIGHT;

    // Clock/reset
    logic clk;
    logic rst;

    // Input stream
    logic [7:0]  s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tuser;
    logic        s_axis_tlast;
    logic        s_axis_tready;

    // Output stream
    logic [71:0] m_axis_tdata;
    logic        m_axis_tvalid;
    logic        m_axis_tuser;
    logic        m_axis_tlast;
    logic        m_axis_tready;

    // DUT
    axis_window_3x3_generator #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT)
    ) dut (
        .clk(clk),
        .rst(rst),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tready(m_axis_tready)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Test image memory
    logic [7:0] img [0:NUM_PIXELS-1];

    // Expected output item
    typedef struct packed {
        logic [71:0] window;
        logic        user;
        logic        last;
    } exp_t;

    exp_t exp_q[$];

    int pass_count;
    int fail_count;

    // ------------------------------------------------------------
    // Window:
    // p00 p01 p02
    // p10 p11 p12
    // p20 p21 p22
    //
    // Packed:
    // {p00,p10,p20, p01,p11,p21, p02,p12,p22}
    // ------------------------------------------------------------
    function automatic logic [71:0] pack_window(
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
            pack_window = {
                p00, p10, p20,
                p01, p11, p21,
                p02, p12, p22
            };
        end
    endfunction

    // Expected window ending at current pixel row,col
    function automatic logic [71:0] expected_window(
        input int row,
        input int col
    );
        logic [7:0] p00, p01, p02;
        logic [7:0] p10, p11, p12;
        logic [7:0] p20, p21, p22;
        begin
            p00 = img[(row-2)*FRAME_WIDTH + (col-2)];
            p01 = img[(row-2)*FRAME_WIDTH + (col-1)];
            p02 = img[(row-2)*FRAME_WIDTH + (col)];

            p10 = img[(row-1)*FRAME_WIDTH + (col-2)];
            p11 = img[(row-1)*FRAME_WIDTH + (col-1)];
            p12 = img[(row-1)*FRAME_WIDTH + (col)];

            p20 = img[(row)*FRAME_WIDTH + (col-2)];
            p21 = img[(row)*FRAME_WIDTH + (col-1)];
            p22 = img[(row)*FRAME_WIDTH + (col)];

            expected_window = pack_window(
                p00, p01, p02,
                p10, p11, p12,
                p20, p21, p22
            );
        end
    endfunction

    // Push expected output if input pixel creates a valid 3x3 window
    task automatic push_expected(
        input int row,
        input int col,
        input logic in_last
    );
        exp_t item;
        begin
            if ((row >= 2) && (col >= 2)) begin
                item.window = expected_window(row, col);
                item.user   = ((row == 2) && (col == 2));
                item.last   = in_last;

                exp_q.push_back(item);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Send one pixel with valid/ready handshake
    // ------------------------------------------------------------
    task automatic send_pixel(
        input logic [7:0] pix,
        input logic       user,
        input logic       last,
        input int         row,
        input int         col
    );
        begin
            @(negedge clk);
            s_axis_tdata  <= pix;
            s_axis_tvalid <= 1'b1;
            s_axis_tuser  <= user;
            s_axis_tlast  <= last;

            // Wait until accepted
            do begin
                @(posedge clk);
            end while (!(s_axis_tvalid && s_axis_tready));

            push_expected(row, col, last);
        end
    endtask

    // ------------------------------------------------------------
    // Output monitor
    // ------------------------------------------------------------
    always @(posedge clk) begin
        #1;

        if (!rst && m_axis_tvalid && m_axis_tready) begin
            exp_t exp;

            if (exp_q.size() == 0) begin
                $error("[FAIL] Unexpected output: window=%h user=%0b last=%0b",
                       m_axis_tdata, m_axis_tuser, m_axis_tlast);
                fail_count++;
            end else begin
                exp = exp_q.pop_front();

                if (m_axis_tdata !== exp.window ||
                    m_axis_tuser !== exp.user ||
                    m_axis_tlast !== exp.last) begin

                    $error("[FAIL] Window mismatch");
                    $display("       Expected window=%h user=%0b last=%0b",
                             exp.window, exp.user, exp.last);
                    $display("       Got      window=%h user=%0b last=%0b",
                             m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    fail_count++;
                end else begin
                    $display("[PASS] window=%h user=%0b last=%0b",
                             m_axis_tdata, m_axis_tuser, m_axis_tlast);
                    pass_count++;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // Fill 4x4 image:
        // 1   2   3   4
        // 5   6   7   8
        // 9   10  11  12
        // 13  14  15  16
        for (int i = 0; i < NUM_PIXELS; i++) begin
            img[i] = i + 1;
        end

        s_axis_tdata  = 8'd0;
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

        // Send full 4x4 frame continuously
        for (int row = 0; row < FRAME_HEIGHT; row++) begin
            for (int col = 0; col < FRAME_WIDTH; col++) begin
                int idx;
                logic user;
                logic last;

                idx  = row * FRAME_WIDTH + col;
                user = (row == 0) && (col == 0);
                last = (col == FRAME_WIDTH-1);

                send_pixel(img[idx], user, last, row, col);
            end
        end

        // Deassert valid after frame
        @(negedge clk);
        s_axis_tvalid <= 1'b0;
        s_axis_tdata  <= 8'd0;
        s_axis_tuser  <= 1'b0;
        s_axis_tlast  <= 1'b0;

        // Let remaining pipeline outputs drain
        repeat (20) @(posedge clk);

        if (exp_q.size() != 0) begin
            $error("[FAIL] Expected queue not empty, remaining=%0d", exp_q.size());
            fail_count++;
        end

        if (fail_count == 0) begin
            $display("[PASS] window_3x3_generator_TB completed with %0d checks", pass_count);
            $finish;
        end else begin
            $fatal(1, "[FAIL] window_3x3_generator_TB completed with %0d failures", fail_count);
        end
    end

endmodule
