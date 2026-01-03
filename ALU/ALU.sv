`timescale 1ns / 1ps
`include "typedef.svh"

module ALU ( 
    // Inputs are wire by default, Outputs are reg
    input aluOperations operation,
    
    input logic [31:0] data1,
    input logic [31:0] data2,
    output logic [31:0] outputData
);
// combinational logic
always_comb begin
    case (operation)
        ADD: begin
            outputData = data1 + data2;
        end
        SUB: begin 
            outputData = data1 - data2;
        end
        XOR: begin 
            outputData = data1 ^ data2;
        end
        OR: begin 
            outputData = data1 | data2;
        end
        AND: begin 
            outputData = data1 & data2;
        end
        SLL: begin 
            outputData = data1 << data2;
        end
        // SRL works with unsigned
        SRL: begin 
            outputData = data1 >> data2;
        end
        // SRA works with signed
        SRA: begin 
            outputData = $signed(data1) >>> data2; 
        end
        // STL works with signed
        SLT: begin 
            outputData = $signed(data1) < $signed(data2) ? 32'b1 : 32'b0;
        end
        // SLTU works with unsigned
        SLTU: begin 
            outputData = (data1 < data2) ? 32'b1 : 32'b0;
        end
        // Prevent latches
        default: outputData = 32'b0; 
    endcase
end
endmodule



