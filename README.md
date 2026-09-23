# 73-Tap-FIR-Filter

> Design, implementation, and verification of a 73-tap symmetric low-pass FIR filter on a Xilinx Artix-7 (`xc7a100tcsg324-1`) using a pipelined, symmetry-folded, dual-port circular-buffer MAC — **1 DSP48E1, 389 LUTs, 108 LUTRAM, 178 FFs**, fully verified bit-for-bit against a C golden model.

---

## 📋 Project Overview

This repository contains the complete deliverable set for the **Complex Engineering Problem (Group A)** assignment: a hardware-efficient 73-tap symmetric FIR filter that accepts **Q2.10** fixed-point input samples at **1 MSps**, convolves them with **73 Q1.15** coefficients, and produces a saturated, rounded **Q3.13** output.

The design meets a strict *minimum FPGA resource* mandate while comfortably satisfying the **1 µs / 1 MSps** timing budget.

| Parameter | Value |
|---|---|
| **Target device** | Xilinx Artix-7 `xc7a100tcsg324-1` |
| **Toolchain** | Xilinx Vivado 2018.2 |
| **System clock** | 100 MHz (10 ns period) |
| **Sample rate** | 1 MSps (one output per µs) |
| **Input format** | Q2.10 (12 bits, signed) |
| **Coefficient format** | Q1.15 (16 bits, signed) |
| **Output format** | Q3.13 (16 bits, signed, saturated) |
| **Taps** | 73 (symmetric → 37 unique MAC steps) |

---

## 👥 Contributors

- **Muniba Abrar**
- **Fahad Ahmad**

---

## 📁 Repository Structure

```
73-Tap-FIR-Filter/
├── src/
│   ├── fir_top.sv                 # Top-level wrapper module
│   ├── fir_filter.sv              # Main FIR filtering logic & DSP pipeline
│   ├── coeff_conversion.sv        # Coefficient ROM mapping module
│   └── sample_rom.sv              # Test sample storage in LUTRAM
├── sim/
│   └── tb_fir_top.sv              # SystemVerilog testbench
├── constraints/
│   └── fir_xdc.xdc                # Timing and pin location constraints
├── model/
│   ├── model_reference.c          # Bit-exact C golden reference model
│   ├── input_samples.mem          # Hex input test vectors (12-bit)
│   ├── expected_output.mem        # Expected hex output results (16-bit)
│   └── golden_model_report.csv    # Floating-point vs fixed-point validation
├── Block Diagrams/
│   ├── Architecture Block.PNG     # Top-level datapath block diagram
│   ├── buffer_addressing.png      # Partition 2a: circular buffer + pointers
│   ├── control_sync.png           # Partition 1: debounce + pacing FSM
│   ├── memory_led_interface.png   # Partition 3: output RAM + LED readback
│   ├── micro_architecture_fir_top.png  # Full fir_top micro-architecture
│   └── pipeline_core.png          # Partition 2b: 3-stage MAC pipeline
├── FIR_FILTER_FINAL_DRAFT.xpr     # Xilinx Vivado Project File
└── README.md
```

---

## ✨ Key Design Highlights

### 1. Symmetry Folding — 73 taps → 37 MAC steps
Coefficient symmetry `h[k] = h[72-k]` halves the multiply count:

- **36 symmetric pairs**: `(x[n-k] + x[n-(72-k)]) × h[k]`
- **1 center tap**: `x[n-36] × h[36]`

### 2. Dual-Port Distributed-RAM Circular Buffer
Instead of a full 73-entry shift register (~900 FFs), sample history lives in a **73×12-bit dual-port LUTRAM** (`sample_buf[0:72]`), addressed by two read pointers (`addrA`, `addrB`) that walk toward each other each cycle. A single write pointer (`wr_ptr`) overwrites the oldest sample per input.

### 3. Three-Stage Pipelined MAC
The pre-add → multiply → accumulate chain is split across three register-bounded stages so a **single DSP48E1** accepts a new MAC every clock cycle without stalling:

| Stage | Operation | Register |
|---|---|---|
| A | Pre-add: `x[n-k] + x[n-(72-k)]` | `sum_reg` (13-bit), `coef_reg` (16-bit) |
| B | Multiply: `sum_reg × coef_reg` | `mult_reg` (29-bit) |
| C | Accumulate: `acc + mult_reg` | `acc` (35-bit) |

Total fold time = **39 cycles** (37 MAC + 2 pipeline-drain).

### 4. Bit-Exact Rounding & Saturation
Both the C golden model and the RTL apply identical convergent-style rounding:

- Add half-LSB bias (`1 << 11`)
- Arithmetic shift right by 12 (Q10.25 → Q3.13)
- Saturate to signed 16-bit (`0x7FFF` / `0x8000`)

---

## 📊 Post-Implementation Results

### Resource Utilization (Vivado post-route)

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| LUT | 389 | 63,400 | 0.61 % |
| LUTRAM | 108 | 19,000 | 0.57 % |
| FF | 178 | 126,800 | 0.14 % |
| DSP48E1 | **1** | 240 | 0.42 % |
| IO | 27 | 210 | 12.86 % |
| BUFG | 1 | 32 | 3.13 % |

### Timing (post-route, 100 MHz target)

| Metric | Value |
|---|---|
| **WNS** | **+4.231 ns** |
| **TNS** | 0 ns |
| Failing endpoints | 0 / 1,199 |
| **Implied Fmax** | **≈ 173.34 MHz** |
| Total on-chip power | 0.109 W |

### Functional Verification

```
RESULT: 100 PASS / 0 FAIL out of 100 samples
*** OVERALL: PASS -- all outputs match the C golden model ***
```

The self-checking testbench (`tb_fir_top.sv`) drives all 100 two-tone test vectors through the full demo wrapper (`fir_top`) and compares every readback against `expected_output.mem` using strict (`===`) equality — confirming **bit-exact** agreement with the C golden reference across both the linear and saturated regions.

---

## 🚀 How to Build & Run

### Prerequisites
- Xilinx **Vivado 2018.2** (or later compatible version)
- A Nexys A7-100T–class board (or any Artix-7 `xc7a100tcsg324-1` device)

### 1. Synthesize & Implement
```tcl
open_project FIR_FILTER_FINAL_DRAFT.xpr
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

### 2. Run Behavioral Simulation
```tcl
launch_simulation
run all
```

Expected console output:
```
RESULT: 100 PASS / 0 FAIL out of 100 samples
*** OVERALL: PASS -- all outputs match the C golden model ***
```

### 3. Program the Board
```tcl
open_hw_manager
connect_hw_server
open_hw_target
program_hw_devices [get_hw_devices xc7a100t_0]
```

### 4. Hardware Demonstration
1. Press the **Start button** — the pacing FSM begins streaming all 100 stimulus samples into the filter.
2. `led_busy` stays high for the duration of the run.
3. Once done, dial any sample index (0–99) on the **7 DIP switches** — the corresponding Q3.13 output appears on the **16 LEDs**.

---

## 🔬 Architecture Study Summary

Four architectures were evaluated before committing to RTL:

| # | Architecture | DSP48 | LUTs / FFs | Cycles/sample | Verdict |
|---|---|---:|---:|---:|---|
| 1 | Fully parallel (37 MACs) | 37 | ~3000 / ~1500 | 1 | ❌ violates min-resource mandate |
| 2 | Sequential MAC, shift register | 1 | ~200 / ~900 | 73 | ❌ 900 FFs on shift register |
| 3 | Distributed Arithmetic | 0 | ~5000 / ~300 | ~13 | ❌ LUT-heavy on DSP-rich device |
| **4** | **Pipelined + folded + circular buffer** | **1** | **389 / 178** | **39** | ✅ **selected & implemented** |

---

## 📐 Bit-Growth Budget

| Stage | Format | Width | Notes |
|---|---|---:|---|
| Input sample | Q2.10 | 12 | — |
| Pre-adder sum | Q3.10 | 13 | `SUM_WIDTH = 12 + 1` |
| Coefficient | Q1.15 | 16 | `COEF_WIDTH` |
| Multiplier product | Q4.25 | 29 | `PROD_WIDTH = 13 + 16` |
| Accumulator | Q10.25 | 35 | +6 guard bits (`⌈log₂ 37⌉ ≈ 5.2`) |
| Rounded → Output | Q3.13 | 16 | +half-LSB, ASR 12, saturate |

---

## 📚 Reference

- Full study report: *Design, Implementation, and Verification of a 73-Tap Symmetric FIR Filter on Minimum FPGA Resources* — available in the project submission bundle.
- Vivado synthesis logs, post-route timing summaries, and the complete XSim transcript are reproduced in the report appendices.

---

## 📄 License

This project was developed as coursework for the **Complex Engineering Problem (CEP) — Group A** assignment. All RTL and supporting files are provided for academic reference.
