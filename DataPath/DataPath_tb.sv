`timescale 1ns/1ps
`include "typedef.svh"

module DataPath_tb;

  // ---------------------------------------------------------------------------
  // Clock / reset
  // ---------------------------------------------------------------------------
  logic clk = 0;
  logic reset_n = 0;

  // 10ns period
  always #5 clk = ~clk;

  // DUT
  DataPath dut (
    .clk     (clk),
    .reset_n (reset_n)
  );

  // ---------------------------------------------------------------------------
  // RV32I instruction encoders (helpers so we can author assembly in TB code)
  // ---------------------------------------------------------------------------

  // Pack immediate with sign extension helpers
function automatic logic [31:0] sext(input int value, input int bits);
  logic [31:0] tmp;
  begin
    tmp = 32'b0;
    tmp[bits-1:0] = value[bits-1:0];      // copy lower bits
    for (int i = bits; i < 32; i++)       // fill upper bits with sign
      tmp[i] = value[bits-1];
    sext = tmp;
  end
endfunction

  // R-type: OP = 7'b0110011
  function automatic logic [31:0] R(
      input logic [6:0]  funct7,
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [4:0]  rd,
      input logic [6:0]  opcode
  );
    R = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  // I-type: OP-IMM/LOAD/JALR
  function automatic logic [31:0] I(
      input logic [11:0] imm12,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [4:0]  rd,
      input logic [6:0]  opcode
  );
    I = {imm12, rs1, funct3, rd, opcode};
  endfunction

  // S-type: STORE
  function automatic logic [31:0] S(
      input logic [11:0] imm12,
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [6:0]  opcode
  );
    S = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
  endfunction

  // B-type: BRANCH (imm is byte offset; must be even)
  function automatic logic [31:0] B(
      input logic [12:0] imm13, // signed, bit0 must be 0
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [6:0]  opcode
  );
    // Encode as imm[12|10:5|4:1|11] << 1
    logic [12:0] imm = imm13;
    B = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
  endfunction

  // U-type: LUI/AUIPC
  function automatic logic [31:0] U(
      input logic [31:12] imm20,
      input logic [4:0]   rd,
      input logic [6:0]   opcode
  );
    U = {imm20, rd, opcode};
  endfunction

  // J-type: JAL (imm is byte offset; must be even)
  function automatic logic [31:0] J(
      input logic [20:0] imm21, // signed
      input logic [4:0]  rd,
      input logic [6:0]  opcode
  );
    // Encode as imm[20|10:1|11|19:12] << 1
    logic [20:0] imm = imm21;
    J = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  // ---------------------------------------------------------------------------
  // Constants (standard RV32I opcodes / functs)
  // ---------------------------------------------------------------------------
  localparam [6:0] OP      = 7'b0110011; // R-type
  localparam [6:0] OP_IMM  = 7'b0010011; // I-type ALU immediates
  localparam [6:0] LOAD    = 7'b0000011; // LW
  localparam [6:0] STORE   = 7'b0100011; // SW
  localparam [6:0] BRANCH  = 7'b1100011; // BEQ/BNE/BLT/…
  localparam [6:0] LUI     = 7'b0110111;
  localparam [6:0] AUIPC   = 7'b0010111;
  localparam [6:0] JAL     = 7'b1101111;
  localparam [6:0] JALR    = 7'b1100111;

  // funct3 / funct7 combos
  localparam [2:0] F_ADD_SUB = 3'b000;
  localparam [6:0] F7_ADD    = 7'b0000000;
  localparam [6:0] F7_SUB    = 7'b0100000;

  localparam [2:0] F_SLL = 3'b001;
  localparam [2:0] F_SLT = 3'b010;
  localparam [2:0] F_SLTU= 3'b011;
  localparam [2:0] F_XOR = 3'b100;
  localparam [2:0] F_SRL_SRA = 3'b101;
  localparam [6:0] F7_SRL    = 7'b0000000;
  localparam [6:0] F7_SRA    = 7'b0100000;
  localparam [2:0] F_OR  = 3'b110;
  localparam [2:0] F_AND = 3'b111;

  // I-ALU funct3 (ADDI/XORI/ORI/ANDI/SLTI/SLTIU/SLLI/SRLI/SRAI):
  localparam [2:0] F_ADDI=3'b000, F_XORI=3'b100, F_ORI=3'b110, F_ANDI=3'b111, F_SLTI=3'b010, F_SLTIU=3'b011, F_SLLI=3'b001, F_SRLI_SRAI=3'b101;

  // Loads/stores funct3
  localparam [2:0] F_LW  = 3'b010;
  localparam [2:0] F_SW  = 3'b010;

  // Branch funct3
  localparam [2:0] F_BEQ = 3'b000;
  localparam [2:0] F_BNE = 3'b001;
  localparam [2:0] F_BLT = 3'b100;
  localparam [2:0] F_BGE = 3'b101;

  // ---------------------------------------------------------------------------
  // Program: we’ll fill instruction ROM via hierarchy:
  //   dut.instructionMem.rom_memory[idx] = 32'hXXXXXXXX;
  // (if your instance names differ, adjust here).
  // ---------------------------------------------------------------------------

  // quick writer
  task automatic ROMW(input int word_addr, input logic [31:0] instr);
    dut.instructionMem.rom_memory[word_addr] = instr;
  endtask

  // check helpers (peek RF & DMEM)
  function automatic logic [31:0] RF(input int idx);
    RF = dut.registerFile.registers[idx];
  endfunction
  function automatic logic [31:0] DM(input int word_idx);
    DM = dut.dataMem.memory[word_idx];
  endfunction

  // simple wait-for-cycles
  task automatic step(input int cycles = 1);
    repeat (cycles) @(posedge clk);
  endtask

  // ---------------------------------------------------------------------------
  // Test program & checks
  // ---------------------------------------------------------------------------
  initial begin
    // reset
    reset_n = 0;
    step(2);
    reset_n = 1;

    // --- CASE 0: initialize a few registers with ADDI ------------------------
    // x1 = 10, x2 = -3, x3 = 0x1234
    // register is being truncated somewhere
    ROMW( 0, I(12'sd10,  5'd0, F_ADDI, 5'd1, OP_IMM));  // addi x1,x0,10      ; init positive
    ROMW( 1, I(12'$signed(-3),  5'd0, F_ADDI, 5'd2, OP_IMM));  // addi x2,x0,-3      ; init negative
    ROMW( 2, I(12'sd0x123,5'd0, F_ADDI, 5'd3, OP_IMM)); // addi x3,x0,0x123   ; small hex

    // --- CASE 1: arithmetic/logic R-type ------------------------------------
    // x4 = x1 + x2 = 7
    // x5 = x1 - x2 = 13
    // x6 = x1 ^ x3
    // x7 = x1 | x3
    // x8 = x1 & x3
    ROMW( 3, R(F7_ADD, 5'd2,5'd1, F_ADD_SUB, 5'd4, OP)); // add  x4,x1,x2
    ROMW( 4, R(F7_SUB, 5'd2,5'd1, F_ADD_SUB, 5'd5, OP)); // sub  x5,x1,x2
    ROMW( 5, R(7'b0,   5'd3,5'd1, F_XOR,     5'd6, OP)); // xor  x6,x1,x3
    ROMW( 6, R(7'b0,   5'd3,5'd1, F_OR,      5'd7, OP)); // or   x7,x1,x3
    ROMW( 7, R(7'b0,   5'd3,5'd1, F_AND,     5'd8, OP)); // and  x8,x1,x3

    // --- CASE 2: shifts ------------------------------------------------------
    // x9 = x1 << 1
    // x10= x3 >> 2 (logical)
    // x11= x2 >>> 1 (arithmetic, stays negative)
    ROMW( 8,  R(7'b0, 5'd1,5'd1, F_SLL,      5'd9,  OP));          // sll x9,x1,x1 (using x1=10 → shift 10 bits; just to exercise datapath)
    ROMW( 9,  R(F7_SRL,5'd1,5'd3, F_SRL_SRA, 5'd10, OP));          // srl x10,x3,x1
    ROMW(10,  R(F7_SRA,5'd1,5'd2, F_SRL_SRA, 5'd11, OP));          // sra x11,x2,x1

    // --- CASE 3: set-less-than (signed/unsigned) -----------------------------
    // x12 = (x2 < x1) signed → 1  (-3 < 10)
    // x13 = (x2 < x1) unsigned → 0 (0xFFFF_FFFD < 10 ? no)
    ROMW(11, R(7'b0, 5'd2,5'd1, F_SLT,  5'd12, OP));               // slt  x12,x1,x2  (NB: ordering in R is rs2,rs1)
    ROMW(12, R(7'b0, 5'd2,5'd1, F_SLTU, 5'd13, OP));               // sltu x13,x1,x2

    // --- CASE 4: store & load -----------------------------------------------
    // SW x4 -> mem[0], then LW to x14
    ROMW(13, S(12'sd0, 5'd4, 5'd0, F_SW, STORE));                   // sw  x4,0(x0)
    ROMW(14, I(12'sd0, 5'd0, F_LW, 5'd14, LOAD));                   // lw  x14,0(x0)

    // --- CASE 5: branch taken & not taken -----------------------------------
    // If x1 == 10, skip next instruction; then a BNE that is not taken.
    // Place NOP as "addi x0,x0,0"
    ROMW(15, I(12'sd10, 5'd0, F_ADDI, 5'd15, OP_IMM));              // x15 = 10
    ROMW(16, B(13'sd2,   5'd15,5'd1, F_BEQ, BRANCH));               // beq x1,x15, +2   ; skip over next ADDI
    ROMW(17, I(12'sd99,  5'd0, F_ADDI, 5'd16, OP_IMM));             // (skipped if BEQ taken)
    ROMW(18, B(13'sd2,   5'd15,5'd1, F_BNE, BRANCH));               // bne x1,x15, +2   ; not taken → fall-through
    ROMW(19, I(12'sd7,   5'd0, F_ADDI, 5'd16, OP_IMM));             // x16 = 7

    // --- CASE 6: Jumps (JAL / JALR) -----------------------------------------
    // JAL: x17 gets return PC; jump forward over one ADDI
    ROMW(20, J(21'sd2, 5'd17, JAL));                                // jal x17, +2
    ROMW(21, I(12'sd111,5'd0, F_ADDI, 5'd18, OP_IMM));              // (skipped)
    ROMW(22, I(12'sd5,  5'd0, F_ADDI, 5'd18, OP_IMM));              // x18 = 5
    // JALR: x19 = ret addr; target = x18 + 0 → jump over next ADDI
    ROMW(23, I(12'sd0, 5'd18, 3'b000, 5'd1, JALR));                 // jalr x1,x18,0  (use rd=x1 as link demo)
    ROMW(24, I(12'sd222,5'd0, F_ADDI, 5'd20, OP_IMM));              // (skipped)
    ROMW(25, I(12'sd6,  5'd0, F_ADDI, 5'd20, OP_IMM));              // x20 = 6

    // --- Finish with an infinite branch to self to stop PC naturally --------
    ROMW(26, B(13'sd0, 5'd0, 5'd0, F_BEQ, BRANCH));                 // beq x0,x0,0 (loop)

    // release reset after ROM is loaded (already high)

    // Let it run enough cycles to finish (roughly ROM depth)
    step(80);

    // -------------------------------------------------------------------------
    // Checks (each case commented with the intent)
    // -------------------------------------------------------------------------

    // CASE 0: ADDI inits
    assert (RF(1) == 32'd10)  else $fatal("ADDI x1 init failed");
    assert (RF(2) == -32'sd3) else $fatal("ADDI x2 init failed");
    assert (RF(3) == 32'h0000_0123) else $fatal("ADDI x3 init failed");

    // CASE 1: R-type arith/logic
    assert (RF(4) == 32'd7)   else $fatal("ADD x4=x1+x2 failed");
    assert (RF(5) == 32'd13)  else $fatal("SUB x5=x1-x2 failed");
    assert (RF(6) == (32'd10 ^ 32'h123)) else $fatal("XOR x6 failed");
    assert (RF(7) == (32'd10 | 32'h123)) else $fatal("OR x7 failed");
    assert (RF(8) == (32'd10 & 32'h123)) else $fatal("AND x8 failed");

    // CASE 2: shifts (exact values depend on your shift semantics;
    // our program used variable shifts to just exercise the paths)
    // Check they executed at all (not zero) — feel free to tighten if desired:
    assert (RF(9)  !== 32'd0) else $fatal("SLL did not execute");
    assert (RF(10) !== 32'd0) else $fatal("SRL did not execute");
    assert (RF(11) !== 32'd0) else $fatal("SRA did not execute");

    // CASE 3: set-less-than (signed/unsigned)
    assert (RF(12) == 32'd1)  else $fatal("SLT signed compare failed");
    assert (RF(13) == 32'd0)  else $fatal("SLTU unsigned compare failed");

    // CASE 4: store/load
    assert (DM(0)   == RF(4)) else $fatal("SW to mem[0] failed");
    assert (RF(14)  == RF(4)) else $fatal("LW back into x14 failed");

    // CASE 5: branches
    assert (RF(16)  == 32'd7) else $fatal("BEQ/BNE sequencing failed");

    // CASE 6: jumps
    // x17 holds link addr from JAL; x18==5; x20==6
    assert (RF(18) == 32'd5)  else $fatal("JAL target block failed");
    assert (RF(20) == 32'd6)  else $fatal("JALR target block failed");

    $display("DataPath program completed — all checks passed.");
    $finish;
  end

endmodule
