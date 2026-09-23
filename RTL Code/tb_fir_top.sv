`timescale 1ns / 1ps

module tb_fir_top;

    localparam time CLK_PERIOD  = 10ns;
    localparam int  NUM_SAMPLES = 100;

    logic        clk;
    logic        reset;
    logic        btn_start;
    logic [6:0]  sw_addr;
    logic [15:0] led_data;
    logic        led_busy;

    fir_top uut (
        .clk       (clk),
        .reset     (reset),
        .btn_start (btn_start),
        .sw_addr   (sw_addr),
        .led_data  (led_data),
        .led_busy  (led_busy)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // Golden reference
    logic [15:0] expected [0:NUM_SAMPLES-1];
    initial $readmemh("expected_output.mem", expected);

    int pass_count;
    int fail_count;

    initial begin
        clk        = 1'b0;
        reset      = 1'b0;
        btn_start  = 1'b0;
        sw_addr    = 7'd0;
        pass_count = 0;
        fail_count = 0;

        #(CLK_PERIOD * 5);
        reset = 1'b1;
        #(CLK_PERIOD * 5);

        $display("--------------------------------------------------");
        $display("[%0t ns] Reset released. Filter warming up (s_init)...", $time);
        $display("--------------------------------------------------");

        @(posedge clk);
        btn_start = 1'b1;
        @(posedge clk);
        btn_start = 1'b0;

        wait(led_busy == 1'b1);
        $display("[%0t ns] FIR Filter Processing Started (led_busy high)...", $time);

        wait(led_busy == 1'b0);
        $display("[%0t ns] FIR Filter Processing Finished (led_busy low).", $time);
        $display("--------------------------------------------------");

        #(CLK_PERIOD * 5);

        $display("Reading Output Memory via sw_addr (0 to 99) -- compared against expected_output.mem:");
        $display("--------------------------------------------------");

        for (int i = 0; i < NUM_SAMPLES; i++) begin
            sw_addr = i[6:0];
            @(posedge clk);
            #1;

            if (led_data === expected[i]) begin
                pass_count++;
                $display("ADDR [%02d] | HEX: 0x%04X | SIGNED DEC: %0d | EXPECTED: 0x%04X | PASS",
                          i, led_data, $signed(led_data), expected[i]);
            end else begin
                fail_count++;
                $display("ADDR [%02d] | HEX: 0x%04X | SIGNED DEC: %0d | EXPECTED: 0x%04X | *** FAIL ***",
                          i, led_data, $signed(led_data), expected[i]);
            end
        end

        $display("--------------------------------------------------");
        $display("RESULT: %0d PASS / %0d FAIL out of %0d samples", pass_count, fail_count, NUM_SAMPLES);
        if (fail_count == 0)
            $display("*** OVERALL: PASS -- all outputs match the C golden model ***");
        else
            $display("*** OVERALL: FAIL -- %0d mismatch(es) found ***", fail_count);
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
