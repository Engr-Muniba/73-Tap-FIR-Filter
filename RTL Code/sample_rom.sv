`timescale 1ns / 1ps

module sample_rom (
    input  logic [6:0]         addr,
    output logic signed [11:0] data
);

    localparam int NUM_SAMPLES = 100;

  (* rom_style = "distributed" *) logic [11:0] mem [0:NUM_SAMPLES-1];

    initial begin
        $readmemh("input_samples.mem", mem);
    end

    assign data = $signed(mem[addr]);

endmodule
