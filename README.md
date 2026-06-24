# Pipelined_ALU
5-stage pipelined ALU (Arithmetic Logic Unit) with hazard control and MAC in Verilog
The project implements a classic 5-stage pipeline ((IF/ID/EX/MEM/WB) with a custom 16-bit ISA supporting ADD, SUB, AND, OR, XOR, MOV, LD, ST, MAC, BEQ, full data forwarding, hazard detection and a branch unit that actually redirects the PC; all running on an 8-bit datapath with 8 general-purpose registers.
