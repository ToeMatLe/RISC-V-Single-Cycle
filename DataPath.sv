`timescale 1ns / 1ps
`include "typedef.svh"

module DataPath (
    input logic clk,
    input logic reset_n,

    input logic regWrite, aluSrc, memWrite, branEnable, jumpEnable, 
    input aluOperations aluOp, 
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
ALU alu (
    .operation(aluOp),
    .data1(readData1),
    .data2(aluSecondOperand),
    .outputData(aluResult)
);
DataMem dataMem (
    .clk(clk),
    .memWrite(memWrite),
    .address(aluResult),
    .writeData(readData2),
    .readData(memReadData)
);

endmodule
