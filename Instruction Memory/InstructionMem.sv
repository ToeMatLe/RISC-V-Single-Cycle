module InstructionMem (
    input logic [31:0] address,
    output logic [31:0] instruction
);
// 64 x 32 memory storage, and array of instructions
logic [31:0] rom_memory [63:0];

// Read Data is Combinational
// ignore the last 2 bits to divide by 4
assign instruction = rom_memory[address [31:2]]; 
endmodule