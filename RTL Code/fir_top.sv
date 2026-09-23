`timescale 1ns / 1ps

module fir_top (
    input  logic        clk,        
    input  logic        reset,      // active low reset
    input  logic        btn_start,  
    input  logic [6:0]  sw_addr,    
    output logic [15:0] led_data,   
    output logic        led_busy    
);

    localparam int NUM_SAMPLES   = 100;
    localparam int SAMPLE_CYCLES = 50;   // 50 cycles @ 100MHz = 500ns = 2 MSps

    //variables for the sample rom
    logic [6:0]          rom_addr;
    logic signed [11:0]  rom_data;

    sample_rom inputs (
        .addr (rom_addr),
        .data (rom_data)
    );

    // for clean pulse per press
    logic btn_sync0, btn_sync1, btn_sync2;
    always_ff @(posedge clk) begin
        btn_sync0 <= btn_start;
        btn_sync1 <= btn_sync0;
        btn_sync2 <= btn_sync1;
    end
    logic btn_pulse;
    assign btn_pulse = btn_sync1 & ~btn_sync2;   // rising edge, one cycle wide

    // FSM
    typedef enum logic [1:0] {IDLE, RUN, DONE} dstate_t;
    dstate_t dstate;

    logic [6:0] rd_idx;         
    logic [6:0] cyc_cnt;

    logic        fir_in_valid;
    logic signed [11:0] fir_data_in;
    
    logic        fir_ready;
    logic        start_pending;

    assign rom_addr = rd_idx;   

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            dstate       <= IDLE;
            rd_idx         <= '0;
            cyc_cnt      <= '0;
            fir_in_valid <= 1'b0;
            fir_data_in  <= '0;
            start_pending <= 1'b0;
        end else begin
            fir_in_valid <= 1'b0;   // no new sample this cycle

            case (dstate)
                IDLE: begin
                         if (btn_pulse)
                               start_pending <= 1'b1;
                   
                         if (start_pending && fir_ready) begin
                                dstate        <= RUN;
                                rd_idx          <= '0;
                                cyc_cnt       <= '0;
                                start_pending <= 1'b0;
                           end
                   end

                RUN: begin
                    if (cyc_cnt == 0) begin
                        // start of this sample's 50-cycle slot
                        fir_data_in  <= rom_data;   // combinational ROM output for rd_idx
                        fir_in_valid <= 1'b1;
                    end

                    if (cyc_cnt == SAMPLE_CYCLES-1) begin
                        cyc_cnt <= '0;
                        if (rd_idx == NUM_SAMPLES-1)
                            dstate <= DONE;
                        else
                            rd_idx <= rd_idx + 7'd1;
                    end else begin
                        cyc_cnt <= cyc_cnt + 7'd1;
                    end
                end

                DONE: begin
                    if (btn_pulse) begin       // press again to re-run
                        dstate  <= RUN;
                        rd_idx    <= '0;
                        cyc_cnt <= '0;
                    end
                end

                default: dstate <= IDLE;
            endcase
        end
    end

    assign led_busy = (dstate == RUN);

    // FIR filter
    logic         fir_out_valid;
    logic signed [15:0]  fir_data_out;

    fir_filter FIR (
        .clk       (clk),
        .reset     (reset),
        .in_valid  (fir_in_valid),
        .data_in   (fir_data_in),
        .out_valid (fir_out_valid),
        .data_out  (fir_data_out),
        .ready     (fir_ready)
    );

    // Output RAM
    
    (* ram_style = "distributed" *) logic [15:0] out_mem [0:NUM_SAMPLES-1];
    
    // Initialize memory for simulation without affecting hardware utilization
        initial begin
            for (int i = 0; i < NUM_SAMPLES; i++) begin
                out_mem[i] = 16'h0000;
            end
        end
    
    logic [6:0]  wr_idx;   // next write slot

// Separate index management (with reset) from memory write (no reset)
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            wr_idx <= '0;
        end else if (dstate == IDLE && btn_pulse) begin
            wr_idx <= '0;
        end else if (fir_out_valid) begin
            wr_idx <= wr_idx + 7'd1;
        end
    end

    // Memory write block without reset enables BRAM/LUTRAM inference
    always_ff @(posedge clk) begin
        if (fir_out_valid) begin
            out_mem[wr_idx] <= fir_data_out;
        end
    end

    // synchronous read, address chosen by the board switches
    always_ff @(posedge clk or negedge reset) begin
        if (!reset)
            led_data <= '0;
        else
            led_data <= out_mem[sw_addr];
    end
endmodule

