'indef TYPEDEF_SVH
'define TYPEDEF_SVH

typedef enum logic [3:0] {
    ADD = 4'h0, // 4'b0000
    SUB = 4'h1, // 4'b0001
    XOR = 4'h2, // 4'b0010
    OR = 4'h3, // 4'b0011
    AND = 4'h4, // 4'b0100
    SLL = 4'h5,
    SRL = 4'h6,
    SRA = 4'h7,
    SLT = 4'h8,
    SLTU = 4'h9
} aluOperations;

typedef enum logic [6:0] {
    R = 7'b0110011, // Register
    I = 7'b0010011, // Immediate
    STORE = 7'b0100011, // Store
    LOAD = 7'b0000011, // Load
    BRANCH = 7'b1100011, // Branch
    LUI = 7'b0110111, // Load Upper Immediate
    AUIPC = 7'b0010111, // Add Upper Immediate to PC 
    JAL = 7'b1101111, // Jump and Link
    JALR = 7'b1100111 // Jump and Link Register
} opcodes;

// Branch types
typedef enum logic [2:0] {
    BEQ = 3'b000, // ==
    BNE = 3'b001, // != 
    BLT = 3'b100, // < signed
    BGE = 3'b101, // >= signed
    BLTU = 3'b110, // < unsigned
    BGEU = 3'b111 // >= unsigned
} branchTypes;
'endif