PicoRV32 - A Size-Optimized RISC-V CPU
======================================

PicoRV32 is a CPU core that implements the [RISC-V RV32IMC Instruction Set](http://riscv.org/).
It can be configured as RV32E, RV32I, RV32IC, RV32IM, or RV32IMC core, and optionally
contains a built-in interrupt controller.

PicoRV32 is free and open hardware licensed under the [ISC license](http://en.wikipedia.org/wiki/ISC_license)
(a license similar in terms to the MIT license or the 2-clause BSD license).

Table of Contents
-----------------

- [Features and Typical Applications](#features-and-typical-applications)
- [Core Variations](#core-variations)
- [Verilog Module Parameters](#verilog-module-parameters)
- [Interface Specifications](#interface-specifications)
    - [Native Memory Interface](#native-memory-interface)
    - [Look-Ahead Interface](#look-ahead-interface)
    - [Pico Co-Processor Interface (PCPI)](#pico-co-processor-interface-pcpi)
    - [RISC-V Formal Interface (RVFI)](#risc-v-formal-interface-rvfi)
- [Custom Instructions for IRQ Handling](#custom-instructions-for-irq-handling)
- [Performance and Utilization](#performance-and-utilization)
- [Development Environment](#development-environment)
- [Verification and Testing](#verification-and-testing)
- [Example: PicoSoC](#example-picosoc)
- [Files in this Repository](#files-in-this-repository)


Features and Typical Applications
---------------------------------

- **Small Footprint**: 750-2000 LUTs in Xilinx 7-Series architecture.
- **High Frequency**: 250-450 MHz on Xilinx 7-Series FPGAs.
- **Flexible Interfaces**: Native memory interface, AXI4-Lite master, or Wishbone master.
- **Optional Extensions**: support for M (Multiply/Divide) and C (Compressed) extensions.
- **Custom IRQ Support**: Simple custom instructions for efficient interrupt handling.
- **Formal Verification**: Built-in support for the RVFI formal interface.

This CPU is meant to be used as an auxiliary processor in FPGA designs and ASICs. Due
to its high fmax, it can be integrated into most existing designs without crossing
clock domains.


Core Variations
---------------

The core exists in three main variations:

- **`picorv32`**: The base core with a simple native memory interface.
- **`picorv32_axi`**: The core with an integrated AXI4-Lite master interface.
- **`picorv32_wb`**: The core with an integrated Wishbone B4/pipelined master interface.

A separate `picorv32_axi_adapter` module is also provided to bridge between the native memory interface and AXI4.


Verilog Module Parameters
-------------------------

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `ENABLE_COUNTERS` | 1 | Enable `RDCYCLE[H]`, `RDTIME[H]`, and `RDINSTRET[H]` |
| `ENABLE_COUNTERS64` | 1 | Enable 64-bit versions of the counters |
| `ENABLE_REGS_16_31` | 1 | Enable registers x16..x31 (set to 0 for RV32E) |
| `ENABLE_REGS_DUALPORT` | 1 | Use dual-port register file (faster but larger) |
| `LATCHED_MEM_RDATA` | 0 | Set to 1 if `mem_rdata` is stable after transaction |
| `TWO_STAGE_SHIFT` | 1 | Shift in stages of 4 and 1 bit (smaller/slower) |
| `BARREL_SHIFTER` | 0 | Use a barrel shifter (larger/faster) |
| `TWO_CYCLE_COMPARE` | 0 | Add FF stage to comparator longest path |
| `TWO_CYCLE_ALU` | 0 | Add FF stage to ALU data path |
| `COMPRESSED_ISA` | 0 | Enable support for RISC-V Compressed (C) extension |
| `CATCH_MISALIGN` | 1 | Enable circuitry for catching misaligned memory access |
| `CATCH_ILLINSN` | 1 | Enable circuitry for catching illegal instructions |
| `ENABLE_PCPI` | 0 | Enable external Pico Co-Processor Interface |
| `ENABLE_MUL` | 0 | Internal PCPI Multiply support (requires `picorv32_pcpi_mul`) |
| `ENABLE_FAST_MUL` | 0 | Internal PCPI Single-cycle Multiply support |
| `ENABLE_DIV` | 0 | Internal PCPI Division support (requires `picorv32_pcpi_div`) |
| `ENABLE_IRQ` | 0 | Enable custom Interrupt Controller and instructions |
| `ENABLE_IRQ_QREGS` | 1 | Enable `getq` and `setq` instructions for IRQ handlers |
| `ENABLE_IRQ_TIMER` | 1 | Enable the `timer` instruction |
| `ENABLE_TRACE` | 0 | Enable the `trace_valid` and `trace_data` output ports |
| `REGS_INIT_ZERO` | 0 | Initialize register file to zero (for simulation/formal) |
| `PROGADDR_RESET` | `32'h0` | The start address of the program |
| `PROGADDR_IRQ` | `32'h10` | The start address of the interrupt handler |
| `STACKADDR` | `32'hffffffff` | Initial stack pointer value (if not `0xffffffff`) |


Interface Specifications
------------------------

### Native Memory Interface

The native interface is a simple valid-ready interface:

- `mem_valid` (output): Core initiates a transfer.
- `mem_instr` (output): High if the transfer is an instruction fetch.
- `mem_ready` (input): Peer acknowledges the transfer.
- `mem_addr` [31:0] (output): The address for the transfer.
- `mem_wdata` [31:0] (output): Data to be written.
- `mem_wstrb` [3:0] (output): Write enable byte mask.
- `mem_rdata` [31:0] (input): Data read from memory.

### Look-Ahead Interface

The Look-Ahead interface provides info about the next transfer one clock cycle earlier:

- `mem_la_read`, `mem_la_write`, `mem_la_addr`, `mem_la_wdata`, `mem_la_wstrb`.

### Pico Co-Processor Interface (PCPI)

PCPI allows implementing custom instructions in external cores. If an illegal instruction is encountered and PCPI is enabled, the core asserts `pcpi_valid` and passes the instruction and operand values.

### RISC-V Formal Interface (RVFI)

When `RISCV_FORMAL` is defined, the core provides RVFI ports for formal verification or instruction tracing. See [riscv-formal](https://github.com/YosysHQ/riscv-formal/blob/master/docs/rvfi.md) for details.


Custom Instructions for IRQ Handling
------------------------------------

The following custom instructions are supported when `ENABLE_IRQ` is set. They are encoded under the `custom0` opcode.

- **`getq rd, qs`**: Move from q-register to general-purpose register.
- **`setq qd, rs`**: Move from general-purpose register to q-register.
- **`retirq`**: Return from interrupt and re-enable interrupts.
- **`maskirq rd, rs`**: Write new IRQ mask and read old one.
- **`waitirq rd`**: Wait until an interrupt is pending.
- **`timer rd, rs`**: Configure the down-counter timer.

IRQ 0 is the Timer, IRQ 1 is EBREAK/Illegal Instruction, and IRQ 2 is Bus Error.


Performance and Utilization
---------------------------

The average CPI is approximately 4. Dhrystone results: 0.516 DMIPS/MHz.

### Xilinx 7-Series LUTs:
- **Small**: ~760 LUTs (min features)
- **Regular**: ~920 LUTs (default)
- **Large**: ~2000 LUTs (all features, PCPI, IRQ, MUL/DIV)


Development Environment
-----------------------

### Software Toolchain

Build the RISC-V GNU toolchain for a pure RV32I target:

    make download-tools
    make build-tools

### Nix Support

A `shell.nix` file is provided. Just run `nix-shell` to enter an environment with all dependencies.

### FuseSoC Support

Use `picorv32.core` with [FuseSoC](https://github.com/olofk/fusesoc) for management and build automation.


Verification and Testing
------------------------

- **Icarus Verilog**: Run `make test`.
- **Verilator**: Run `make test_verilator`.
- **Wishbone**: Run `make test_wb`.
- **Formal**: Run `make check` (requires Yosys and SMT solvers).


Example: PicoSoC
----------------

The `picosoc/` directory contains a simple SoC implementation that executes code directly from SPI flash. It supports the iCE40-HX8K Breakout Board and iCEBreaker Board.


Files in this Repository
------------------------

- `picorv32.v`: The core implementation (contains CPU and PCPI modules).
- `Makefile`: Build and test automation.
- `picorv32.core`: FuseSoC core description.
- `shell.nix`: Nix environment configuration.
- `testbench.v`: Standard testbench.
- `testbench_wb.v`: Wishbone testbench.
- `testbench.cc`: Verilator testbench.
- `firmware/`: Basic test firmware.
- `tests/`: ISA-level tests from riscv-tests.
- `dhrystone/`: Dhrystone benchmark implementation.
- `picosoc/`: PicoSoC example.
- `scripts/`: various synthesis and helper scripts.
