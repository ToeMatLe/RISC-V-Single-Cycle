#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

TOOL="${1:-auto}"

# UCLA school server VCS/Verdi setup.
export SYNOPSYS="${SYNOPSYS:-/usr/apps/synopsys}"
export VCS_HOME="${VCS_HOME:-/home/apps3/Synopsys/VCS/vT-2022.06-1}"
export VERDI_HOME="${VERDI_HOME:-/home/apps3/Synopsys/Verdi/vT-2022.06-SP1}"
export LM_LICENSE_FILE="${LM_LICENSE_FILE:-5281@lm-cadence.seas.ucla.edu}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-1784@lm-synopsys.seas.ucla.edu}"
export PATH="$VCS_HOME/bin:$VCS_HOME/amd64/bin:$PATH"

SV_SOURCES=(
    "Program Counter/ProgramCounter.sv"
    "Instruction Memory/InstructionMem.sv"
    "Register File/RegisterFile.sv"
    " Control Unit/ControlUnit.sv"
    "ALU/ALU.sv"
    "Data Memory/DataMem.sv"
    "Data Path/DataPath.sv"
    "Benchmarks/cpu_speed_benchmark_tb.sv"
)

VCS_INCDIRS=(
    +incdir+.
    +incdir+ALU
    "+incdir+ Control Unit"
    "+incdir+Data Memory"
    "+incdir+Instruction Memory"
    "+incdir+Data Path"
    "+incdir+Program Counter"
    "+incdir+Register File"
)

VERILATOR_INCDIRS=(
    -I.
    -IALU
    "-I Control Unit"
    "-IData Memory"
    "-IInstruction Memory"
    "-IData Path"
    "-IProgram Counter"
    "-IRegister File"
)

run_vcs() {
    if ! command -v vcs >/dev/null 2>&1; then
        echo "Could not find VCS on PATH."
        exit 1
    fi

    vcs \
        -full64 -sverilog -timescale=1ns/1ps \
        -debug_access+all -kdb \
        "${VCS_INCDIRS[@]}" \
        "${SV_SOURCES[@]}" \
        -top cpu_speed_benchmark_tb \
        -o cpu_speed_benchmark_simv \
        -R
}

run_verilator() {
    if ! command -v verilator >/dev/null 2>&1; then
        echo "Could not find Verilator on PATH."
        exit 1
    fi

    local build_dir="${TMPDIR:-/tmp}/rv_single_cycle_bench_obj"

    verilator \
        --binary --timing \
        -Wno-EOFNEWLINE \
        -Wno-VARHIDDEN \
        -Wno-WIDTHTRUNC \
        -Wno-PROCASSINIT \
        -Wno-UNUSEDSIGNAL \
        -Wno-CASEINCOMPLETE \
        -Wno-SYNCASYNCNET \
        "${VERILATOR_INCDIRS[@]}" \
        "${SV_SOURCES[@]}" \
        --top-module cpu_speed_benchmark_tb \
        -Mdir "$build_dir"

    "$build_dir/Vcpu_speed_benchmark_tb"
}

case "$TOOL" in
    auto)
        if command -v vcs >/dev/null 2>&1; then
            run_vcs
        else
            run_verilator
        fi
        ;;
    vcs)
        run_vcs
        ;;
    verilator)
        run_verilator
        ;;
    *)
        echo "Usage: $0 [auto|vcs|verilator]"
        exit 2
        ;;
esac
