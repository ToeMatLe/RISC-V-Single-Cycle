module DataMem (
    input logic clk,
    input logic memWrite,

    input logic [31:0] = address,
    input logic [31:0] = wdata,
    output logic [31:0] = rdata
);
// 124 x 32 memory storage
logic [31:0] memory [1023:0];

// Read Data is Combinational
assign rdata = memory[address];

// Write Data is Sequential 
always_ff @(posedge clk) begin
    if (memWrite) begin 
        memory[address] <= wdata;
    end
end

endmodule