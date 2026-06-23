`timescale 1ns/1ps
module tb_pipelined_alu;
    logic clk, rst;
    logic [7:0] result;
    logic Z, C, S, P;
    // Instantiate CPU
    pipelined_alu uut (
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
        // ---------------- INITIALIZATION ----------------
        uut.regfile[2] = 8'd5;   // R2 = 5
        uut.regfile[3] = 8'd3;   // R3 = 3
        uut.regfile[1] = 8'd0;
        uut.regfile[4] = 8'd0;
        uut.regfile[6] = 8'd0;
        uut.regfile[7] = 8'd0;
        uut.acc = 0;
        uut.data_mem[20] = 8'd99;  // Memory location for load
        // Run for some cycles
        #300;
        // ---------------- RESULTS ----------------
        $display("\n--- Final Register File ---");
        for (i=0; i<8; i++) begin
            $display("R%0d = %0d", i, uut.regfile[i]);
        end
        $display("ACC = %0d",uut.acc[7:0], uut.acc);
        $display("Flags -> Z=%b C=%b S=%b P=%b", Z, C, S, P);
        $display("Result Output = %0d", result);
        $display("MEM[25] = %0d", uut.data_mem[25]);
        $finish;
    end
endmodule