`timescale 1ns/1ps

// Compile this same testbench once with the single-cycle RTL and once with the
// pipelined RTL. Both processors expose DataPath(clk, reset_n) and use the same
// instruction-memory/register-file instance names, so the benchmark itself does
// not change between runs.
module cpu_speed_benchmark_tb;

  localparam time CLK_PERIOD = 10ns;
  localparam int  LOOP_COUNT = 50;
  localparam int  DYNAMIC_INSTRUCTIONS = 3 + (4 * LOOP_COUNT) + 4;
  localparam int  TIMEOUT_CYCLES = 2000;

  logic clk = 1'b0;
  logic reset_n = 1'b0;

  int unsigned cycle_count = 0;

  always #(CLK_PERIOD / 2) clk = ~clk;

  DataPath dut (
    .clk     (clk),
    .reset_n (reset_n)
  );

  // RV32I instruction encoders used by this benchmark.
  function automatic logic [31:0] R(
      input logic [6:0] funct7,
      input logic [4:0] rs2,
      input logic [4:0] rs1,
      input logic [2:0] funct3,
      input logic [4:0] rd,
      input logic [6:0] opcode
  );
    return {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] I(
      input logic [11:0] imm12,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [4:0]  rd,
      input logic [6:0]  opcode
  );
    return {imm12, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] S(
      input logic [11:0] imm12,
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [6:0]  opcode
  );
    return {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
  endfunction

  function automatic logic [31:0] B(
      input logic [12:0] imm13,
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [6:0]  opcode
  );
    return {imm13[12], imm13[10:5], rs2, rs1, funct3,
            imm13[4:1], imm13[11], opcode};
  endfunction

  localparam logic [6:0] OP     = 7'b0110011;
  localparam logic [6:0] OP_IMM = 7'b0010011;
  localparam logic [6:0] LOAD   = 7'b0000011;
  localparam logic [6:0] STORE  = 7'b0100011;
  localparam logic [6:0] BRANCH = 7'b1100011;

  localparam logic [2:0] F_ADD  = 3'b000;
  localparam logic [2:0] F_ADDI = 3'b000;
  localparam logic [2:0] F_LW   = 3'b010;
  localparam logic [2:0] F_SW   = 3'b010;
  localparam logic [2:0] F_BNE  = 3'b001;

  localparam logic [31:0] NOP = 32'h0000_0013; // addi x0, x0, 0

  task automatic write_instruction(
      input int unsigned word_address,
      input logic [31:0] instruction
  );
    dut.instructionMem.rom_memory[word_address] = instruction;
  endtask

  function automatic logic [31:0] read_register(input int unsigned index);
    return dut.registerFile.registers[index];
  endfunction

  function automatic logic [31:0] read_memory(input int unsigned word_address);
    return dut.dataMem.memory[word_address];
  endfunction

  // Count CPU clocks, not simulator wall-clock runtime. The count starts at the
  // first active clock edge after reset is released.
  always @(posedge clk) begin
    if (!reset_n)
      cycle_count <= 0;
    else
      cycle_count <= cycle_count + 1;
  end

  initial begin : load_program
    integer address;

    $timeformat(-9, 2, " ns", 10);

    // Fill unused ROM locations with NOPs so an accidental fetch is visible and
    // deterministic instead of propagating X values through the processor.
    for (address = 0; address < 64; address++)
      write_instruction(address, NOP);

    // Benchmark program:
    //   x1 = loop counter
    //   x2 = running sum
    //   x3 = current integer
    //
    // Sum 1 through LOOP_COUNT. The loop has dependent ALU operations and a
    // taken branch on every iteration except the last.
    write_instruction(0, I(12'(LOOP_COUNT), 5'd0, F_ADDI, 5'd1, OP_IMM)); // addi x1,x0,50
    write_instruction(1, I(12'd0,           5'd0, F_ADDI, 5'd2, OP_IMM)); // addi x2,x0,0
    write_instruction(2, I(12'd1,           5'd0, F_ADDI, 5'd3, OP_IMM)); // addi x3,x0,1
    write_instruction(3, R(7'b0, 5'd3, 5'd2, F_ADD, 5'd2, OP));           // add  x2,x2,x3
    write_instruction(4, I(12'd1, 5'd3, F_ADDI, 5'd3, OP_IMM));          // addi x3,x3,1
    write_instruction(5, I(-12'sd1, 5'd1, F_ADDI, 5'd1, OP_IMM));        // addi x1,x1,-1
    write_instruction(6, B(-13'sd12, 5'd0, 5'd1, F_BNE, BRANCH));        // bne  x1,x0,-12

    // Exercise memory and a load-use dependency after the arithmetic loop.
    write_instruction(7,  S(12'd0, 5'd2, 5'd0, F_SW, STORE));            // sw   x2,0(x0)
    write_instruction(8,  I(12'd0, 5'd0, F_LW, 5'd4, LOAD));             // lw   x4,0(x0)
    write_instruction(9,  I(12'd1, 5'd4, F_ADDI, 5'd5, OP_IMM));         // addi x5,x4,1

    // x31 is the completion signature watched by the testbench. It must be the
    // final useful instruction so all earlier results have committed first.
    write_instruction(10, I(12'd1, 5'd0, F_ADDI, 5'd31, OP_IMM));        // addi x31,x0,1
    write_instruction(11, B(13'd0, 5'd0, 5'd0, 3'b000, BRANCH));         // beq  x0,x0,0

    // Hold active-low reset across several clock edges, then release it away
    // from an active edge to avoid a reset/clock race.
    repeat (4) @(posedge clk);
    @(negedge clk);
    reset_n = 1'b1;
  end

  // Sample on falling edges so register-file nonblocking writes from the prior
  // rising edge have settled before checking the completion signature.
  initial begin : monitor_completion
    wait (reset_n === 1'b1);

    forever begin
      @(negedge clk);

      if (read_register(31) === 32'd1) begin
        if (read_register(2) !== 32'd1275)
          $fatal(1, "FAIL: sum x2 = %0d, expected 1275", read_register(2));
        if (read_memory(0) !== 32'd1275)
          $fatal(1, "FAIL: memory[0] = %0d, expected 1275", read_memory(0));
        if (read_register(4) !== 32'd1275)
          $fatal(1, "FAIL: loaded x4 = %0d, expected 1275", read_register(4));
        if (read_register(5) !== 32'd1276)
          $fatal(1, "FAIL: dependent x5 = %0d, expected 1276", read_register(5));

        $display("--------------------------------------------------");
        $display("CPU BENCHMARK PASSED");
        $display("Dynamic instructions : %0d", DYNAMIC_INSTRUCTIONS);
        $display("Measured cycles       : %0d", cycle_count);
        $display("CPI                   : %0.3f",
                 real'(cycle_count) / real'(DYNAMIC_INSTRUCTIONS));
        $display("RTL clock period      : %0t", CLK_PERIOD);
        $display("RTL program time      : %0t", cycle_count * CLK_PERIOD);
        $display("Result                : sum(1..%0d) = %0d",
                 LOOP_COUNT, read_register(2));
        $display("--------------------------------------------------");
        $finish;
      end

      if (cycle_count >= TIMEOUT_CYCLES)
        $fatal(1, "TIMEOUT after %0d cycles; x31 never received completion signature",
               cycle_count);
    end
  end

endmodule
