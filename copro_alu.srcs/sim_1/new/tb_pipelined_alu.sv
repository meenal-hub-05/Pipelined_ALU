`timescale 1ns/1ps
module tb_pipelined_alu;
    logic clk, rst;
    logic [7:0] result;
    logic Z, C, S, P;
    // Instantiate CPU
    pipelined_alu #(8,256) uut (
        .clk(clk),
        .rst(rst),
        .result(result),
        .Z(Z), .C(C), .S(S), .P(P)
    );
    // Clock Generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;
    // Reset
    initial begin
        rst = 1;
        #20 rst = 0;
    end
    // Program Load
    initial begin
        integer i;
        // Clear memories
        for (i=0; i<256; i++) begin
            uut.instr_mem[i] = 16'hFFFF;
            uut.data_mem[i]  = 8'h00;
        end
        // ---------------- PROGRAM ----------------
        // (1) ADD R1 = R2 + R3   (Forwarding check)
        uut.instr_mem[0] = 16'b0000_001_010_011_000;  
        // (2) SUB R4 = R1 - R2   (depends on fresh R1 → forwarding)
        uut.instr_mem[1] = 16'b0001_100_001_010_000;  
        // (3) LD R6 <- MEM[20]   (Load)
        uut.instr_mem[2] = 16'b1000_110_000010100;  
        // (4) ADD R7 = R6 + R2   (immediate use of R6 → load-use hazard → stall)
        uut.instr_mem[3] = 16'b0000_111_110_010_000;  
        // (5) MAC ACC = ACC + (R2*R3)
        uut.instr_mem[4] = 16'b1010_000_010_011_000;  
        // (6) ST MEM[25] <- R7
        uut.instr_mem[5] = 16'b1001_111_000011001; 
        // ---------------- ST-AFTER-LD HAZARD TEST ----------------
        // LD R5 <- MEM[30]   (load a known value into R5)
        uut.instr_mem[6] = 16'b1000_101_000011110;   // opcode=LD, rd=R5, imm9=30
        // ST MEM[31] <- R5   (immediately store R5 - triggers the hazard)
        uut.instr_mem[7] = 16'b1001_101_000011111;   // opcode=ST, rd=R5, imm9=31
        // instr[8]: SUB R1, R1, R1  → R1=0, Z flag goes 1
        uut.instr_mem[8]  = 16'b0001_001_001_001_000;
        // instr[9]: BEQ target=12  → imm9 = 000001100 = 12
        uut.instr_mem[9]  = 16'b1100_000_000001100;
        // instr[10]: ADD R2,R2,R2  → TRAP: R2=10 if not skipped
        uut.instr_mem[10] = 16'b0000_010_010_010_000;
        // instr[11]: ADD R3,R3,R3  → TRAP: R3=6 if not skipped
        uut.instr_mem[11] = 16'b0000_011_011_011_000;
        // instr[12]: ADD R4,R2,R3  → verdict instruction at branch target
        uut.instr_mem[12] = 16'b0000_100_010_011_000;
        // instr[13]: MAC R0, R6, R7  → acc = 15 + 10296 = 10311; R0 = 71
        uut.instr_mem[13] = 16'b1010_000_110_111_000;
        // instr[14]: MAC R0, R2, R3  → acc = 10311 + 15 = 10326; R0 = 86
        uut.instr_mem[14] = 16'b1010_000_010_011_000;
 
        // ---------------- INITIALIZATION ----------------
        uut.regfile[2] = 8'd5;   // R2 = 5
        uut.regfile[3] = 8'd3;   // R3 = 3
        uut.regfile[1] = 8'd0;
        uut.regfile[4] = 8'd0;
        uut.regfile[6] = 8'd0;
        uut.regfile[7] = 8'd0;
        uut.acc = 0;
        uut.data_mem[20] = 8'd99;  // Memory location for load
        uut.data_mem[30] = 8'd77;
        // Run for some cycles
        #250;
        // ---------------- RESULTS ----------------
        $display("\n--- Final Register File ---");
        for (i=0; i<8; i++) begin
            $display("R%0d = %0d", i, uut.regfile[i]);
        end
        $display("ACC = %0d", uut.acc);
        $display("Flags -> Z=%b C=%b S=%b P=%b", Z, C, S, P);
        $display("Result Output = %0d", result);
        $display("MEM[25] = %0d", uut.data_mem[25]);
        $display("MEM[31] = %0d (expect 77)", uut.data_mem[31]);
        $display("\n========== BRANCH FIX VERIFICATION ==========");
        $display("R1 = %0d  (expect  0 : SUB R1,R1,R1 zeroed it)", uut.regfile[1]);
        $display("R2 = %0d  (expect  5 : instr[10] must have been squashed)", uut.regfile[2]);
        $display("R3 = %0d  (expect  3 : instr[11] must have been squashed)", uut.regfile[3]);
        $display("R4 = %0d  (expect  8 : R2+R3 with original values -> branch taken correctly)", uut.regfile[4]);

        $display("\n========== MAC FIX VERIFICATION ==========");
        $display("R0  = %0d  (expect 86  : lower 8 bits of final acc)", uut.regfile[0]);
        $display("ACC = %0d  (expect 10326 : 15 + 10296 + 15, proves 16-bit accumulation)", uut.acc);
        $finish;
    end
endmodule
