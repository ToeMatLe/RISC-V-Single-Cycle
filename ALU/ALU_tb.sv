`timescale 1ns / 1ps
`include "typedef.svh"

module ALU_tb; 
    aluOperations operation;
    logic [31:0] data1;
    logic [31:0] data2;
    logic [31:0] outputData;

  ALU dut (
    .operation (operation),
    .data1 (data1),
    .data2 (data2),
    .outputData (outputData)
);

initial begin
    // --- Test ADD: 10 + 5 ---
    operation = ADD; data1 = 32'd10; data2 = 32'd5; 
    #10;
    $display("\nTest ADD: %0d + %0d", data1, data2);
    if (outputData !== 32'd15) $error("  FAILED! Expected: 15, Actual: %0d", outputData);
    else $display("  PASSED. Result: %0d", outputData);

    // --- Test SUB: 10 - 15 ---
    operation = SUB; data1 = 32'd10; data2 = 32'd15; 
    #10;
    $display("\nTest SUB: %0d - %0d", data1, data2);
    if ($signed(outputData) !== -32'sd5) $error("  FAILED! Expected: -5, Actual: %0d", $signed(outputData));
    else $display("  PASSED. Result: %0d", $signed(outputData));

    // ALU applies the operation bit by bit across all 32 bits.
    // --- Test XOR ---
    operation = XOR; data1 = 32'hAAAA_5555; data2 = 32'h0F0F_F0F0;
    #10;
    $display("\nTest XOR: 0x%08h ^ 0x%08h", data1, data2);
    if (outputData !== 32'hA5A5_A5A5) $error("  FAILED! Expected: 0xA5A5A5A5, Actual: 0x%08h", outputData);
    else $display("  PASSED. Result: 0x%08h", outputData);

    // --- Test OR ---
    operation = OR; data1 = 32'hF0F0_F0F0; data2 = 32'h0FF0_00FF;
    #10;
    $display("\nTest OR: 0x%08h | 0x%08h", data1, data2);
    if (outputData !== 32'hFFF0_F0FF) $error("  FAILED! Expected: 0xFFF0F0FF, Actual: 0x%08h", outputData);
    else $display("  PASSED. Result: 0x%08h", outputData);

    // --- Test AND ---
    operation = AND; data1 = 32'hF0F0_F0F0; data2 = 32'h0FF0_00FF;
    #10;
    $display("\nTest AND: 0x%08h & 0x%08h", data1, data2);
    if (outputData !== 32'h00F0_00F0) $error("  FAILED! Expected: 0x00F000F0, Actual: 0x%08h", outputData);
    else $display("  PASSED. Result: 0x%08h", outputData);

    // -----------------------
    // Shifts (RISC-V style: shamt = data2[4:0])
    // -----------------------

    // --- Test SLL: 1 << 3 ---
    operation = SLL; data1 = 32'h0000_0001; data2 = 32'd3;
    #10;
    $display("\nTest SLL: 0x%08h << %0d", data1, data2[4:0]);
    if (outputData !== (data1 << data2[4:0])) $error("  FAILED! Expected: 0x%08h, Actual: 0x%08h", (data1 << data2[4:0]), outputData);
    else $display("  PASSED. Result: 0x%08h", outputData);

    // --- Test SRL: 0x80000000 >> 1 ---
    operation = SRL; data1 = 32'h8000_0000; data2 = 32'd1;
    #10;
    $display("\nTest SRL: 0x%08h >> %0d (logical)", data1, data2[4:0]);
    if (outputData !== (data1 >> data2[4:0])) $error("  FAILED! Expected: 0x%08h, Actual: 0x%08h", (data1 >> data2[4:0]), outputData);
    else $display("  PASSED. Result: 0x%08h", outputData);

    // --- Test SRA: 0x80000000 >>> 1 ---
    operation = SRA; data1 = 32'h8000_0000; data2 = 32'd1;
    #10;
    $display("\nTest SRA: 0x%08h >>> %0d (arithmetic)", data1, data2[4:0]);
    if ($signed(outputData) !== ($signed(data1) >>> data2[4:0]))
        $error("  FAILED! Expected: 0x%08h, Actual: 0x%08h", ($signed(data1) >>> data2[4:0]), outputData);
    else $display("  PASSED. Result: 0x%08h", outputData);

    // --- Test SRA: -1 >>> 4 stays -1 ---
    operation = SRA; data1 = 32'hFFFF_FFFF; data2 = 32'd4;
    #10;
    $display("\nTest SRA: -1 >>> %0d (should stay -1)", data2[4:0]);
    if ($signed(outputData) !== -32'sd1) $error("  FAILED! Expected: -1, Actual: %0d", $signed(outputData));
    else $display("  PASSED. Result: %0d", $signed(outputData));

    // -----------------------
    // Comparisons: SLT / SLTU (should output 0 or 1)
    // -----------------------

    // --- Test SLT: -1 < 1 (signed) => 1 ---
    operation = SLT; data1 = 32'hFFFF_FFFF; data2 = 32'd1;
    #10;
    $display("\nTest SLT: %0d < %0d (signed)", $signed(data1), $signed(data2));
    if (outputData !== 32'd1) $error("  FAILED! Expected: 1, Actual: %0d", outputData);
    else $display("  PASSED. Result: %0d", outputData);

    // --- Test SLT: 1 < -1 (signed) => 0 ---
    operation = SLT; data1 = 32'd1; data2 = 32'hFFFF_FFFF;
    #10;
    $display("\nTest SLT: %0d < %0d (signed)", $signed(data1), $signed(data2));
    if (outputData !== 32'd0) $error("  FAILED! Expected: 0, Actual: %0d", outputData);
    else $display("  PASSED. Result: %0d", outputData);

    // --- Test SLTU: 0xFFFFFFFF < 1 (unsigned) => 0 ---
    operation = SLTU; data1 = 32'hFFFF_FFFF; data2 = 32'd1;
    #10;
    $display("\nTest SLTU: %0u < %0u (unsigned)", data1, data2);
    if (outputData !== 32'd0) $error("  FAILED! Expected: 0, Actual: %0d", outputData);
    else $display("  PASSED. Result: %0d", outputData);

    // --- Test SLTU: 1 < 0xFFFFFFFF (unsigned) => 1 ---
    operation = SLTU; data1 = 32'd1; data2 = 32'hFFFF_FFFF;
    #10;
    $display("\nTest SLTU: %0u < %0u (unsigned)", data1, data2);
    if (outputData !== 32'd1) $error("  FAILED! Expected: 1, Actual: %0d", outputData);
    else $display("  PASSED. Result: %0d", outputData);
end
endmodule
