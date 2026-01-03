`timescale 1ns / 1ps
`include "typedef.svh"

module ControlUnit (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,

    // Enablers for register file and data memory
    output logic regWrite,
    output logic memWrite,
    // Register or immediate to ALU
    output logic aluSrc,
    // Branch Enable for Program Counter
    output logic branEnable,
    // Jump Enable for Program Counter
    output logic jumpEnable,
    // 4 bit ALU operations
    output aluOperations aluOp
);
// R-type, I-type, S-type, B-type, U-type, J-type

always_comb begin 
    // default values
    regWrite = 1'b0;
    memWrite = 1'b0;
    aluSrc = 1'b0;
    branEnable = 1'b0;
    jumpEnable = 1'b0;
    aluOp = 4'b0000;  // Default now is to ADD

    case (opcode)
        R: begin 
            regWrite = 1'b1; //enable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b0; // second ALU operand from register (not immediate)
            branEnable = 1'b0; // disable branch
            aluOp = (funct3 == 3'b000 && funct7 == 7'b0000000) ? ADD :
                    (funct3 == 3'b000 && funct7 == 7'b0100000) ? SUB :
                    (funct3 == 3'b100 && funct7 == 7'b0000000) ? XOR :
                    (funct3 == 3'b110 && funct7 == 7'b0000000) ? OR :
                    (funct3 == 3'b111 && funct7 == 7'b0000000) ? AND :
                    (funct3 == 3'b001 && funct7 == 7'b0000000) ? SLL :
                    (funct3 == 3'b101 && funct7 == 7'b0000000) ? SRL :
                    (funct3 == 3'b101 && funct7 == 7'b0100000) ? SRA :
                    (funct3 == 3'b010 && funct7 == 7'b0000000) ? SLT :
                    (funct3 == 3'b011 && funct7 == 7'b0000000) ? SLTU :
                    ADD; // default to ADD
        end
        I: begin 
            regWrite = 1'b1; //enable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b1; // second ALU operand from immediate
            branEnable = 1'b0; // disable branch
            aluOp = (funct3 == 3'b000) ? ADD :
            (funct3 == 3'b100) ? XOR :
            (funct3 == 3'b110) ? OR  :
            (funct3 == 3'b111) ? AND :
            (funct3 == 3'b001 && funct7==7'b0000000) ? SLL :
            (funct3 == 3'b101 && funct7==7'b0000000) ? SRL :
            (funct3 == 3'b101 && funct7==7'b0100000) ? SRA :
            (funct3 == 3'b010) ? SLT :
            (funct3 == 3'b011) ? SLTU : ADD;
        end
        STORE: begin 
            regWrite = 1'b0; //disable register write
            memWrite = 1'b1; //enable memory write
            aluSrc = 1'b1; // second ALU operand from immediate
            branEnable = 1'b0; // disable branch
            aluOp = ADD; // address calculation
        end
        LOAD: begin
            regWrite = 1'b1; //enable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b1; // second ALU operand from immediate
            branEnable = 1'b0; // disable branch
            aluOp = ADD; // address calculation
        end
        BRANCH: begin 
            regWrite = 1'b0; //disable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b0; // second ALU operand from register (not immediate)
            branEnable = 1'b1; // enable branch
            aluOp = SUB; // for comparison
        end
        LUI: begin 
            regWrite = 1'b1; //enable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b1; // second ALU operand from immediate
            branEnable = 1'b0; // disable branch
            aluOp = ADD; // for loading upper immediate
        end
        AUIPC: begin 
            regWrite = 1'b1; //enable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b1; // second ALU operand from immediate
            branEnable = 1'b0; // disable branch
            aluOp = ADD; // for PC + immediate
        end
        JAL: begin 
            regWrite = 1'b1; //enable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b1; // second ALU operand from immediate
            branEnable = 1'b1; // enable branch
            jumpEnable = 1'b1; // enable jump
            aluOp = ADD; // for PC + immediate
        end
        JALR: begin 
            regWrite = 1'b1; //enable register write
            memWrite = 1'b0; //disable memory write
            aluSrc = 1'b1; // second ALU operand from immediate
            branEnable = 1'b1; // enable branch
            jumpEnable = 1'b1; // enable jump
            aluOp = ADD; // for PC + immediate
        end
    endcase
end
endmodule