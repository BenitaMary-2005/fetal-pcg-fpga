// pcg_rom.v
// Parameterized ROM to load 8-bit PCG samples from a binary text file
module pcg_rom #(
    parameter DEPTH = 16384,           // number of words (adjust to your file length)
    parameter ADDR_WIDTH = 14,         // log2(DEPTH)
    parameter MEMFILE = "C:\Fetal_PCG_FPGA_Project\fetal_PCG_p01_GW_36_bin - Copy.txt"
)(
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire clk,                   // synchronous read
    output reg  [7:0] data_out
);

    // Memory array
    reg [7:0] rom_mem [0:DEPTH-1];

    initial begin
        $readmemb(MEMFILE, rom_mem); // Load binary text file into ROM
    end

    // Synchronous read
    reg [ADDR_WIDTH-1:0] addr_reg;
    always @(posedge clk) begin
        addr_reg <= addr;
        data_out <= rom_mem[addr_reg];
    end

endmodule
