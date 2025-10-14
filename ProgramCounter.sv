`timescale 1ns / 1ps
// need clk becasue we need previous values
module ProgramCounter (
    input logic clk,
    input logic reset_n,
    
    input logic branEnable,
    input logic [31:0] branAddress, //address should be smaller
    output logic [31:0] outputPCAddress
)
logic [31:0] currentPCAddress;

// If BranchEnable, go to the branch address, if not skip 4 to go to the next instruction
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin // if reset goes to low, go back to 0 in the instruction memory
        currentPCAddress <= 32'b0; // goes back to 0 in the instruction 
    end else begin // reset is not happening
        if (branEnable) begin
            currentPCAddress <= branAddress;
        end else begin
            currentPCAddress <= currentPCAddress + 4;
        end 
    end
end
// output the current PC address
assign outputPCAddress = currentPCAddress;

endmodule
