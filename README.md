# Brainfuck Processor (VHDL)

An 8-bit **CPU written in VHDL** that interprets the **Brainfuck** language directly in hardware (INP course project, FIT VUT Brno). The CPU executes Brainfuck programs from RAM using a finite-state machine — no software interpreter involved.

## What it does

- Implements the full Brainfuck instruction set (`+ - < > . ,` and both bracket forms `[ ]` and the extended `[!]` variant from the assignment).
- Runs against the course-provided synchronous RAM and I/O model: a 13-bit address space, memory-mapped **keyboard input** (`IN_DATA`/`IN_REQ`) and **LCD output** (`OUT_DATA`/`OUT_WE`).

## Design

- **Single FSM** drives every instruction as a multi-cycle micro-sequence (`fsm_init`, `fsm_load_ins`, dedicated states for pointer/counter updates, I/O waits, and bracket matching).
- Dedicated registers: **PC** (program counter), **PTR** (data pointer), **CNT** (bracket-matching counter), with increment/decrement/clear control signals.
- Multiplexers (`mx1`, `mx2`) route addresses between PC, PTR, and CNT and select ALU operands.

## Repository contents

- `cpu.vhd` — the CPU entity + behavioral architecture.
- `login.b`, `login-simple.b` — Brainfuck test programs.
- `project1.pdf` — the assignment.

## Testing

Built and verified with the course testbench: `send` scp's `cpu.vhd` to the `inp` lab server and runs the provided `make` test suite there.
