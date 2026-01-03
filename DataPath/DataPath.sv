`timescale 1ns / 1ps
`include "typedef.svh"

module DataPath (
    input logic clk,
    input logic reset_n
);
// Control Signals (from a RISC-V ControlUnit)
logic regWrite, memWrite, aluSrc, branEnable, jumpEnable;
aluOperations aluOp;

// Wires for interconnecting modules
logic [31:0] pcAddress; // Current PC Address
logic [31:0] instruction; // Current Instruction
logic [6:0] opcode; // opcode field from instruction
logic [2:0] funct3; // funct3 field from instruction
logic [6:0] funct7; // funct7 field from instruction
logic [31:0] readData1, readData2; // Data read from registers

logic [31:0] sign_extended_immediate; // sign extended immediate
logic [31:0] outputData; // ALU output data
logic [31:0] memReadData; // Data read from Data Memory

logic [31:0] branch_target_address; // Branch target address
logic [31:0] jump_target_address; // Jump target address 
logic [31:0] outputPCAddress; // Output PC Address
logic [31:0] pcPlus4;
assign pcPlus4 = pcAddress + 4;

// Wires for Register File
logic [4:0] rs1, rs2, rd; // register specifiers from instruction

// Decoding instruction fields
assign opcode = instruction[6:0];
assign rd = instruction[11:7];
assign funct3 = instruction[14:12];
assign rs1 = instruction[19:15];
assign rs2 = instruction[24:20];
assign funct7 = instruction[31:25];

// Immediate Generator for RISC-V formats
// This logic reassembles the scattered immediate bits
always_comb begin
    // Based on the RISC-V reference card formats
    case (opcode)
        I:      sign_extended_immediate = {{20{instruction[31]}}, instruction[31:20]};
        LOAD:   sign_extended_immediate = {{20{instruction[31]}}, instruction[31:20]};
        JALR:   sign_extended_immediate = {{20{instruction[31]}}, instruction[31:20]};
        STORE:  sign_extended_immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        BRANCH: sign_extended_immediate = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        LUI:    sign_extended_immediate = {instruction[31:12], 12'b0};
        AUIPC:  sign_extended_immediate = {instruction[31:12], 12'b0};
        JAL:    sign_extended_immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
        default: sign_extended_immediate = 32'b0;
    endcase
end

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
// Check if immediate is needed for ALU second operand
logic [31:0] alu_in2; // second ALU operand after mux
assign alu_in2 = aluSrc ? sign_extended_immediate : readData2; // Mux for ALU second operand

ALU alu (
    .operation(aluOp),
    .data1(readData1),
    .data2(alu_in2), // Mux output
    .outputData(outputData)
);

// Check branch condition met
logic branch_condition_met = 1'b0;   
logic alu_zero_flag = 1'b0;   
assign alu_zero_flag = (readData1 == readData2);
assign branch_target_address = pcAddress + sign_extended_immediate;
assign branch_condition_met  = BRANCH & alu_zero_flag; 

// Define JALR or JAL
assign jump_target_address = (opcode == JALR) ? (readData1 + sign_extended_immediate) : (pcAddress + sign_extended_immediate);

ProgramCounter programCounter (
    .clk(clk),
    .reset_n(reset_n),
    .jump_enable(jumpEnable),
    .branEnable(branch_condition_met),
    .branAddress(branch_target_address),
    .jump_target_address(jump_target_address),
    .outputPCAddress(pcAddress)
);
InstructionMem instructionMem (
    .address(pcAddress),
    .instruction(instruction)
);
// 3 way Mux for Data Memory read data or ALU output to write back to Register File
logic [31:0] regWriteData; // This is the new wire
always_comb begin 
    if (opcode == LOAD)begin 
        regWriteData = memReadData;
    end
    else if (opcode == JAL) begin 
        regWriteData = pcPlus4;
    end
    else begin 
        regWriteData = outputData;
    end
end

DataMem dataMem (
    .clk(clk),
    .memWrite(memWrite),
    .address(outputData), // Use ALU result as address
    .wdata(readData2), // Data from readData2 is written to memory
    .rdata(memReadData)
);
RegisterFile registerFile (
    .clk(clk),
    .regWrite(regWrite),
    .raddress1(rs1),
    .raddress2(rs2),
    .waddress(rd),
    .wdata(regWriteData), // Write back data from data memory (3 way mux output)
    .rdata1(readData1),
    .rdata2(readData2)
);
endmodule
