`timescale 1ns / 1ps

module fir_filter #(
    parameter int NUM_TAPS   = 73,
    parameter int NUM_STEPS  = 37,
    parameter int IN_WIDTH   = 12,
    parameter int COEF_WIDTH = 16,
    parameter int OUT_WIDTH  = 16,
    parameter int SHIFT      = 12
)(
    input  logic                      clk,
    input  logic                      reset,
    input  logic                      in_valid,
    input  logic signed [IN_WIDTH-1:0] data_in,
    
    output logic                      out_valid,
    output logic signed [OUT_WIDTH-1:0] data_out,
    output logic                      ready
);

    localparam int SUM_WIDTH  = IN_WIDTH + 1;             // 13 bits
    localparam int PROD_WIDTH = SUM_WIDTH + COEF_WIDTH;  // 29 bits
    localparam int GUARD_BITS = 6;                       // ceil(log2(37))
    localparam int ACC_WIDTH  = PROD_WIDTH + GUARD_BITS;  // 35 bits
    localparam int TOTAL_STEP = NUM_STEPS + 2;            // 39 cycles

    // Coefficient ROM lookup
    logic [5:0] coeff_addr;
    logic signed [COEF_WIDTH-1:0] coef_val;
    
    coeff_conversion coefficients (
        //.clk(clk),
        .addr  (coeff_addr),
        .coeff (coef_val)
    );

    // Circular Buffer 
    (* ram_style = "distributed" *) logic signed [IN_WIDTH-1:0] sample_buf [0:NUM_TAPS-1];
    logic [6:0] wr_ptr;
    
    // FSM States
     typedef enum logic [2:0] {init, idle, load, fold, out} state_t;
    state_t state, nstate;
    
    logic [6:0] step;
    logic [6:0] addrA, addrB;
    
    logic a_valid, b_valid;
    
    logic signed [SUM_WIDTH-1:0]  sum_reg;
    logic signed [COEF_WIDTH-1:0] coef_reg;
    (* use_dsp = "yes" *) logic signed [PROD_WIDTH-1:0] mult_reg;
    logic signed [ACC_WIDTH-1:0]  acc;
    
    logic step_active;
    logic is_center;
    
    assign step_active = (step < NUM_STEPS);
    assign is_center   = (step == NUM_STEPS - 1);
    assign coeff_addr  = step[5:0];
     
    assign ready       = (state != init);
    
    // Rounding & Saturation Logic
    logic signed [ACC_WIDTH-1:0] rounded;
    logic signed [ACC_WIDTH-1:0] shifted;
    logic signed [OUT_WIDTH-1:0] sat_out;

    assign rounded = acc + (ACC_WIDTH'(1) << (SHIFT - 1));
    assign shifted = rounded >>> SHIFT;

    always_comb begin
        if (shifted > $signed(35'sd32767))
            sat_out = 16'h7FFF;
        else if (shifted < $signed(-35'sd32768))
            sat_out = 16'h8000;
        else
            sat_out = shifted[OUT_WIDTH-1:0];
    end

    // State Register
    always_ff @(posedge clk or negedge reset) begin
        if (!reset)
            state <= init;
        else
            state <= nstate;
    end
            
    // Next State Logic
    always_comb begin
        nstate = state;
        unique case (state)
            init : if (wr_ptr == NUM_TAPS-1)    nstate = idle;
            idle : if (in_valid)                nstate = load;
            load :                              nstate = fold;
            fold : if (step == TOTAL_STEP - 1)  nstate = out;
            out  :                              nstate = idle;
            default:                            nstate = init;
        endcase
    end
    

    // Separate Memory Write Block
       always_ff @(posedge clk) begin
        if (state == init)
            sample_buf[wr_ptr] <= '0;
        else if (state == load)
            sample_buf[wr_ptr] <= data_in;
        end

    // Main Datapath Pipeline
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            wr_ptr    <= '0;
            step      <= '0;
            addrA     <= '0;
            addrB     <= '0;
            a_valid   <= 1'b0;
            b_valid   <= 1'b0;
            sum_reg   <= '0;
            coef_reg  <= '0;
            mult_reg  <= '0;
            acc       <= '0;
            out_valid <= 1'b0;
            data_out  <= '0;
        end else begin
            out_valid <= 1'b0;
                
            unique case (state)
              init: begin
               wr_ptr <= (wr_ptr == NUM_TAPS-1) ? 7'd0 : wr_ptr + 7'd1;
                 end
            
            
                idle: begin
                    a_valid <= 1'b0;
                    b_valid <= 1'b0;
                end
            
                load: begin
                    addrA   <= wr_ptr;
                    addrB   <= (wr_ptr == NUM_TAPS-1) ? 7'd0 : wr_ptr + 7'd1;
                    wr_ptr  <= (wr_ptr == NUM_TAPS-1) ? 7'd0 : wr_ptr + 7'd1;
                    step    <= 7'd0;
                    acc     <= '0;
                    a_valid <= 1'b0; // set 0
                    b_valid <= 1'b0;
                end
                  
                fold: begin
                    // Stage A: Pre-addition
                    if (step_active) begin
                        sum_reg  <= is_center ? $signed(sample_buf[addrA]) 
                                              : ($signed(sample_buf[addrA]) + $signed(sample_buf[addrB]));
                        coef_reg <= coef_val;
                    end
                    a_valid <= step_active;

                    // Stage B: Multiply
                    if (a_valid)
                        mult_reg <= sum_reg * coef_reg;
                    b_valid <= a_valid;

                    // Stage C: Accumulate
                    if (b_valid)
                        acc <= acc + mult_reg;

                    if (step_active) begin
                        addrA <= (addrA == 7'd0) ? 7'd72 : addrA - 7'd1;
                        addrB <= (addrB == 7'd72) ? 7'd0 : addrB + 7'd1;
                    end
                    step <= step + 7'd1;
                end

                out: begin
                    data_out  <= sat_out;
                    out_valid <= 1'b1;
                end
            endcase
        end
    end

endmodule
