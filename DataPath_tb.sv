`timescale 1ns/1ps
`include "typedef.svh"

module DataPath_tb;
logic clk;
logic reset_n;

// DUT
DataPath dut (
    .clk     (clk),
    .reset_n (reset_n)
);

// 1. Clock Generation
parameter CLK_PERIOD = 10; // 10ns period = 100MHz
initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
end

// 2. Program Loading
// This initial block loads a test program directly into the
// instruction memory using its hierarchical path.
initial begin
    $display("Loading program into Instruction Memory...");
    
    // addi x1, x0, 5
    dut.instructionMem.rom_memory[0] = 32'h00500093;
    // addi x2, x0, 10
    dut.instructionMem.rom_memory[1] = 32'h00A00113;
    // add x3, x1, x2  (x3 should be 15)
    dut.instructionMem.rom_memory[2] = 32'h002081B3;
    // sw x3, 12(x0)   (Store 15 at address 12)
    dut.instructionMem.rom_memory[3] = 32'h00302623;
    // lw x4, 12(x0)   (Load 15 from address 12 into x4)
    dut.instructionMem.rom_memory[4] = 32'h00C02203;
    // beq x0, x0, 0   (Infinite loop to end)
    dut.instructionMem.rom_memory[5] = 32'h00000063;
end

// 3. Reset and Simulation Control
initial begin
    $display("Starting Testbench...");
    $dumpfile("datapath.vcd"); // Save waveform
    $dumpvars(0, dut);         // Dump all signals in the DUT

    reset_n = 1'b0; // Assert reset (active-low)
    @(posedge clk);
    @(posedge clk);
    reset_n = 1'b1; // De-assert reset
    $display("Reset released. Running program.");

    // Let the program run.
    // We have 6 instructions, let's run for 8 cycles.
    repeat (8) @(posedge clk);

    $display("Simulation complete. Checking results...");
    
    // 4. Check Results
    // We check the internal registers of the RegisterFile module
    // Note: Your RegisterFile.sv uses 'registers' for internal storage
    logic [31:0] x1, x2, x3, x4;
    x1 = dut.registerFile.registers[1];
    x2 = dut.registerFile.registers[2];
    x3 = dut.registerFile.registers[3];
    x4 = dut.registerFile.registers[4];

    // Check registers
    if (x1 == 32'd5) $display("PASS: x1 = 5");
    else $display("FAIL: x1 = %d, expected 5", x1);

    if (x2 == 32'd10) $display("PASS: x2 = 10");
    else $display("FAIL: x2 = %d, expected 10", x2);

    if (x3 == 32'd15) $display("PASS: x3 = 15");
    else $display("FAIL: x3 = %d, expected 15", x3);

    if (x4 == 32'd15) $display("PASS: x4 = 15");
    else $display("FAIL: x4 = %d, expected 15", x4);

    // Check data memory
    // Address 12 is Word 3 (12 / 4 = 3)
    // Your DataMem.sv uses [11:2] indexing, so 12 becomes 3.
    logic [31:0] mem_val;
    mem_val = dut.dataMem.memory[3];
    
    if (mem_val == 32'd15) $display("PASS: Memory[12] = 15");
    else $display("FAIL: Memory[12] = %d, expected 15", mem_val);

    $finish; // End the simulation
end

endmodule