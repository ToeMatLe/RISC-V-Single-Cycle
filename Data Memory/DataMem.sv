module DataMem (
    input logic clk,
    input logic memWrite,
    input logic [31:0] address,
    input logic [31:0] wdata,
    output logic [31:0] rdata
);
// 1024 x 32 memory storage
logic [31:0] memory [1023:0];

// Read Data is Combinational
// Use word address (ignore bottom 2 bits). Check bounds are natural for synthesis simulations.
assign rdata = memory[address[11:2]];

// Write Data is Sequential 
always_ff @(posedge clk) begin
    if (memWrite) begin 
        memory[address[11:2]] <= wdata;
    end
end

endmodule