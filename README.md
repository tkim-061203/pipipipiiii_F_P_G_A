# PicoSoC with Lightweight Cryptographic Accelerators

This repository provides a complete System-on-Chip (SoC) based on the **PicoRV32** RISC-V CPU, featuring high-speed hardware accelerators for **TinyJAMBU**, **Xoodyak**, and **GIFT-COFB**. The design is optimized for area-constrained ASIC implementations using the **OpenLane2** flow.

---

## 1. Project Overview

The project extends the standard PicoSoC architecture by integrating a dedicated **Crypto Layer** on the system bus. This allows the PicoRV32 core to offload intensive cryptographic operations to hardware, significantly improving performance and energy efficiency compared to software-only implementations.

### Key Components

- **CPU**: PicoRV32 (RV32I) - A size-optimized RISC-V implementation.
- **Interconnect**: Unified memory-mapped interface (Valid-Ready protocol).
- **Memory**: 4 KB Boot BRAM, 64 KB Application BRAM.
- **Crypto Accelerators**:
  - **TinyJAMBU**: AEAD (Authenticated Encryption with Associated Data).
  - **Xoodyak**: Area-optimized Keyed-only AEAD (Hash mode removed for ASIC efficiency).
  - **GIFT-COFB**: NIST Lightweight Cryptography (LWC) finalist algorithm.
- **Peripherals**: 115200 Baud UART, SD Card SPI Master, GPIO.

---

## 2. Beginner's Guide & Tutorial

Welcome to PicoSoC! If you are new to SoC (System-on-Chip) design or hardware-software co-design, this guide will help you understand how this project works.

### 🧠 Core Concepts

A SoC is like a miniature computer on a single chip. It consists of:
1.  **The CPU (The Brain)**: Processes instructions. Here, we use the **PicoRV32**.
2.  **Memory (The Storage)**: Where code and data live.
    - **ROM (Read-Only Memory)**: Contains permanent instructions (like a bootloader).
    - **RAM (Random Access Memory)**: Fast, temporary storage for your program's variables and stack.
3.  **Peripherals (The Tools)**: Specialized hardware for specific tasks (e.g., UART for communication, Crypto Accelerators for encryption).
4.  **Interconnect (The Nervous System)**: The bus that allows the CPU to talk to the Memory and Peripherals.

### 🗺️ How the CPU Talks: Memory Mapping

In this SoC, everything is **Memory-Mapped**. This means the CPU doesn't have special "commands" to talk to the UART or the Crypto cores. Instead, it just writes to or reads from specific **addresses**.

- If the CPU writes to `0x0001_0000`, it is saving data in **RAM**.
- If the CPU writes to `0x3000_0000`, it is sending a command to the **TinyJAMBU accelerator**.

Think of the Memory Map as a city directory: different addresses lead to different "buildings" (devices).

### 📁 Understanding the Files

To work on this project, you need to know which files do what:

| Category | Files | Description |
| :--- | :--- | :--- |
| **Hardware (RTL)** | `picorv32.v`, `picosoc/*.v`, `tinyjambu/*.v`, etc. | The "blueprints" written in Verilog. These define the actual digital circuits. |
| **Software (Firmware)** | `firmware/*.c`, `firmware/*.S` | The "instructions" written in C or Assembly that run on the CPU. |
| **The Linker Map** | `firmware/riscv.ld` | A critical file that tells the software *where* the RAM and ROM are located in the hardware. |
| **Simulation** | `testbench.v`, `Makefile` | Tools to run a "virtual" version of your chip on your computer to see if it works. |
| **ASIC Flow** | `openlane/` | The instructions used to turn the Verilog blueprints into a real silicon chip. |

---

## 3. System Architecture

### Memory Map

The system uses a 32-bit address space. All crypto cores are memory-mapped for easy software interaction.

| Base Address | Peripheral | Description |
| :--- | :--- | :--- |
| `0x0000_0000` | **Boot ROM** | 4 KB Bootloader (Software pre-loaded) |
| `0x0001_0000` | **Main RAM** | 64 KB Application Memory |
| `0x1000_0000` | **GPIO/UART** | Control register at `0x00`, UART at `0x04-0x10` |
| `0x3000_0000` | **TinyJAMBU** | AEAD Accelerator |
| `0x4000_0000` | **Xoodyak** | AEAD Accelerator (Optimized) |
| `0x5000_0000` | **GIFT-COFB** | AEAD Accelerator |
| `0x6000_0000` | **SD Master** | SPI Interface for secondary storage |

---

## 4. Cryptographic Hardware Accelerators

### TinyJAMBU AEAD

TinyJAMBU is a lightweight permutation-based AEAD. The hardware implementation supports high-frequency operation and provides a simple interface for Key, Nonce, and Data processing.

- **Data Width**: 128-bit Key, 96-bit Nonce.
- **Control**: `JB_CTRL` defines AD and Message lengths for automatic processing.

### Xoodyak (Optimized Keyed-Only)

The Xoodyak core has been significantly modified for ASIC area reduction:

- **Optimization**: All Hash-related state and logic were removed. Only the **Keyed AEAD** mode is supported.
- **Interface**: Improved 2-bit `sel_type` control:
  - `0x01` (binary `01`): Encrypt
  - `0x02` (binary `10`): Decrypt
- **Control Register (`XD_CTRL`)**:
  - `[17:16]`: Mode Selector
  - `[12:8]`: Associated Data Length (0-16 bytes)
  - `[4:0]`: Message/Data Length (0-16 bytes)

### GIFT-COFB

A block-cipher based AEAD finalist in the NIST LWC competition.

- **Block Size**: 128-bit.
- **Interface**: Uses an ACK/REQ handshake mechanism to ensure data is processed correctly within the GIFT permutation cycles.

---

## 5. Software Development Stack

### Firmware Implementation

The system firmware (`firmware/`) provides a hardware abstraction layer (HAL) for the accelerators.

Example usage for Xoodyak:

```c
// Setup Key and Nonce
XD(0x00) = key_low; ... XD(0x0C) = key_high;
XD(0x10) = nonce_low; ... XD(0x1C) = nonce_high;

// Process 9B AD and 14B Data
XD_CTRL = (1u << 16) | (9u << 8) | 14u;
while (!(XD_STATUS & 0x02)); // Wait for Done bit
```

### Simulation Flow

The project uses **Icarus Verilog** for high-speed functional verification.

```bash
cd scripts/vivado/
make sim_system
```

This command performs the following:

1. Compiles the RISC-V firmware using `riscv64-unknown-elf-gcc`.
2. Converts the binary to a `.hex` file.
3. Runs the top-level SoC simulation.

---

## 6. ASIC Flow (OpenLane2)

The repository is structured to support a complete digital backend flow.

### Directory Structure

- `openlane/designs/picosoc/`: Design-specific files.
- `openlane/designs/picosoc/src/`: Synchronized RTL source files.
- `openlane/sw/`: ASIC-ready firmware binaries.

### Synthesis Configuration

The `config.json` file is tuned for the SkyWater 130nm process (sky130):

- **Clock**: Target 10ns (100 MHz).
- **Core Area**: Optimized for high utilization.
- **Pin Mapping**: GPIO, UART, and SPI pins are mapped to standard chip I/Os.

---

## 7. Files in the Repository

- `picorv32.v`: The base RISC-V core.
- `picosoc/`: Hardware modules (Wrappers and Crypto RTL).
- `scripts/`: Simulation and FPGA scripts.
- `openlane/`: ASIC flow and synchronized releases.
- `README.md`: This document.

---

## 8. Credits and License

- **PicoRV32**: Clifford Wolf (ISC License).
- **PicoSoC**: Clifford Wolf (ISC License).
- **Crypto Accelerators**: Integrated and optimized for this project.
