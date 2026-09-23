`timescale 1ns / 1ps

module coeff_conversion(
    //input  logic        clk,
    input  logic [5:0]  addr,
    output logic signed [15:0] coeff
);

    (* rom_style = "distributed" *) logic signed [15:0] coeff_rom [0:36];

    initial begin
        coeff_rom[0]  = 16'sh034E; coeff_rom[1]  = 16'sh02A1; coeff_rom[2]  = 16'sh03A3;
        coeff_rom[3]  = 16'sh04DB; coeff_rom[4]  = 16'sh064F; coeff_rom[5]  = 16'sh0806;
        coeff_rom[6]  = 16'sh0A02; coeff_rom[7]  = 16'sh0C49; coeff_rom[8]  = 16'sh0EDD;
        coeff_rom[9]  = 16'sh11C0; coeff_rom[10] = 16'sh14F5; coeff_rom[11] = 16'sh187B;
        coeff_rom[12] = 16'sh1C51; coeff_rom[13] = 16'sh2075; coeff_rom[14] = 16'sh24E3;
        coeff_rom[15] = 16'sh2996; coeff_rom[16] = 16'sh2E88; coeff_rom[17] = 16'sh33B1;
        coeff_rom[18] = 16'sh3909; coeff_rom[19] = 16'sh3E84; coeff_rom[20] = 16'sh4417;
        coeff_rom[21] = 16'sh49B6; coeff_rom[22] = 16'sh4F54; coeff_rom[23] = 16'sh54E3;
        coeff_rom[24] = 16'sh5A55; coeff_rom[25] = 16'sh5F9B; coeff_rom[26] = 16'sh64A7;
        coeff_rom[27] = 16'sh696B; coeff_rom[28] = 16'sh6DD8; coeff_rom[29] = 16'sh71E2;
        coeff_rom[30] = 16'sh757D; coeff_rom[31] = 16'sh789E; coeff_rom[32] = 16'sh7B3B;
        coeff_rom[33] = 16'sh7D4C; coeff_rom[34] = 16'sh7ECB; coeff_rom[35] = 16'sh7FB3;
        coeff_rom[36] = 16'sh7FFF;
    end

          assign coeff = (addr <= 6'd36) ? coeff_rom[addr] : 16'sh0000;
endmodule
