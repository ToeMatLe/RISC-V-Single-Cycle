# RISC-V Single-Cycle Processor (RV32I)

## Project Overview
This project implements a **single-cycle RV32I RISC-V processor** in **SystemVerilog**, along with a comprehensive **testbench** that verifies instruction execution, control flow, memory access, and jump/branch behavior.

The design follows the classic **single-cycle datapath model** taught in computer architecture courses and is simulated using **Xilinx Vivado**.

---

## Software Used

### Xilinx Vivado (Version 2025.2)
Xilinx Vivado is an **industry-level hardware design tool** used for:
- RTL design and behavioral simulation  
- Gate-level and schematic generation  
- FPGA implementation via **bitstream generation**

Vivado enables this processor to be synthesized, analyzed, and deployed onto supported FPGA development boards.

---

## Instruction Set Reference

This processor follows the **RV32I Base Integer Instruction Set**, using the official **RISC-V Reference Card** as guidance.

The reference was used to ensure correctness of:
- Instruction formats (R, I, S, B, U, J)
- Opcode and funct field encoding
- Immediate reconstruction and sign extension
- Branch and jump semantics (`BEQ`, `BNE`, `JAL`, `JALR`)
- Datapath and control signal behavior

---

## Datapath Reference Diagram

The overall processor architecture is based on the standard **single-cycle RISC-V datapath**, shown below. This diagram served as the reference for structuring the datapath, control signals, and data flow between modules.

<img width="1010" height="554" alt="Screenshot 2026-01-03 at 2 38 19 PM" src="https://github.com/user-attachments/assets/6c066a20-a5d6-4f5b-a277-b64faf9d476a" />


### Diagram Highlights
- **Program Counter (PC)** with `PC + 4` and branch/jump target selection
- **Instruction Memory** for instruction fetch
- **Register File** with two read ports and one write port
- **Immediate Generator** supporting all RV32I formats
- **ALU** with arithmetic, logic, shift, and comparison operations
- **Data Memory** for load and store instructions
- **Write-back Mux** selecting ALU result, memory data, or `PC + 4`
- **Control Unit** generating control signals from opcode and funct fields

---

## Implemented Instructions

### Arithmetic & Logic
- `ADD`, `SUB`
- `XOR`, `OR`, `AND`
- `SLL`, `SRL`, `SRA`
- `SLT`, `SLTU`
- `ADDI`

### Memory
- `LW`
- `SW`

### Control Flow
- `BEQ`
- `BNE`
- `JAL`
- `JALR`

---

## Testbench Verification

The testbench (`DataPath_tb.sv`) verifies:
- Correct instruction decoding and execution
- Register file read/write behavior
- ALU operations and shift behavior
- Load/store memory access
- Branch taken vs. not taken behavior
- Jump and link functionality (`PC + 4`)
- JALR target alignment

The simulation halts with `$fatal` if any instruction behaves incorrectly.

Successful execution prints:
