`timescale 1ns / 1ps
`include "typedef.svh"

module DataPath (
    input logic clk,
    input logic reset_n,
);
ControlUnit controlUnit (
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),

    .regWrite(regWrite),
    .memWrite(memWrite),
    .aluSrc(aluSrc),
    .branEnable(branEnable),
    .jumpEnable(jumpEnable),
    .aluOp(aluOp)
);
logic [31:0] alu_in2; // second ALU operand after mux
logic [31:0] immediate; // sign/zero-extended immediate (32-bit)
// Immediate generator: extract proper immediate based on instruction format
ImmGen immgen (
    .instruction(instruction),
    .imm(immediate)
);
assign alu_in2 = aluSrc ? immediate : readData2; // Mux for ALU second operand
ALU alu (
    .operation(aluOp),
    .data1(readData1),
    .data2(alu_in2), // Mux output
    .outputData(outputData)
);
ProgramCounter programCounter (
    .clk(clk),
    .reset_n(reset_n),
    .jump_enable(jumpEnable),
    .branEnable(branEnable),
    .branAddress(branch_target_address),
    .jump_target_address(jump_target_address),
    .outputPCAddress(pcAddress)
);
InstructionMem instructionMem (
    .address(pcAddress),
    .instruction(instruction)
);
DataMem dataMem (
    .clk(clk),
    .memWrite(memWrite),
    .address(aluResult),
    .writeData(readData2),
    .readData(memReadData)
);

endmodule
