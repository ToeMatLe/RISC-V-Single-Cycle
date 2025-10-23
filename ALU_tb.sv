`timescale 1ns / 1ps
`include "typedef.svh"

module ALU_tb; 
aluOperations operation,
logic [31:0] data1,    
logic [31:0] data2,
logic [31:0] outputData

ALU dut (
    .operation  (operation),
    .data1      (data1),
    .data2      (data2),
    .outputData (outputData)
);

initial begin
    // --- Test SUB: 10 + 5 ---
    operation = ADD; data1 = 32'd10; data2 = 32'd5; #10;
    $display("\nTest ADD: %d + %d", data1, data2);
    if (outputData !== 32'd15) $error("  FAILED! Expected: 15, Actual: %d", outputData); else $display("  PASSED. Result: %d", outputData);

    // --- Test SUB: 10 - 15 ---
    operation = SUB; data1 = 32'd10; data2 = 32'd15; #10;
    $display("\nTest SUB: %d - %d", data1, data2);
    if (outputData !== -32'd5) $error("  FAILED! Expected: -5, Actual: %d", $signed(outputData)); else $display("  PASSED. Result: %d", $signed(outputData));

end
endmodule