`timescale 1ns/1ps
module pipelined_alu(
    input  wire clk,
    input  wire rst,
    output reg  [7:0] result,
    output reg Z, C, S, P
);
    // Memories and Register File
    reg [15:0] instr_mem [0:255];
    reg [7:0]  data_mem  [0:255];
    reg [7:0]  regfile   [0:7];     
    reg [15:0] acc;   
    // Pipeline Registers
    reg [15:0] IF_ID_instr;
    reg [7:0]  IF_ID_pc;
 
    reg [7:0]  ID_EX_A, ID_EX_B,ID_EX_branch_target;
    reg [2:0]  ID_EX_rd, ID_EX_rs1, ID_EX_rs2;
    reg [3:0]  ID_EX_opcode;
    reg        ID_EX_regWrite, ID_EX_memRead, ID_EX_memWrite, ID_EX_isBranch;
    reg [8:0]  ID_EX_imm9;
 
    reg [7:0]  EX_MEM_alu_out, EX_MEM_B, EX_MEM_branch_target;
    reg [2:0]  EX_MEM_rd;
    reg        EX_MEM_regWrite, EX_MEM_memRead, EX_MEM_memWrite, EX_MEM_isBranch;
    reg        EX_MEM_Z;
    reg [7:0]  EX_MEM_addr;
 
    reg [7:0]  MEM_WB_data;
    reg [2:0]  MEM_WB_rd;
    reg        MEM_WB_regWrite;
    
    // PC and Hazard Control
    reg [7:0] pc;
    wire stall, flush;
    reg [7:0] alu_out_comb;
    reg alu_Z_comb, alu_C_comb, alu_S_comb, alu_P_comb;
 
    // IF Stage
    wire [15:0] instr = instr_mem[pc];
 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc          <= 0;
            IF_ID_instr <= 16'hFFFF;
            IF_ID_pc    <= 0;
        end
        else if (flush) begin
            pc          <= EX_MEM_branch_target;  
            IF_ID_instr <= 16'hFFFF;             
            IF_ID_pc    <= 0;
        end
        else if (!stall) begin
            IF_ID_instr <= instr;
            IF_ID_pc    <= pc;
            pc          <= pc + 1;
        end
    end
 
    // ID Stage (Decode)
    wire [3:0] opcode = IF_ID_instr[15:12];
    wire [2:0] rd     = IF_ID_instr[11:9];
    wire [2:0] rs1    = IF_ID_instr[8:6];
    wire [2:0] rs2    = IF_ID_instr[5:3];
    wire [8:0] imm9   = IF_ID_instr[8:0];
 
    always @(posedge clk) begin
        if (flush) begin
            ID_EX_opcode   <= 4'b1111;
            ID_EX_regWrite <= 0;
            ID_EX_memRead  <= 0;
            ID_EX_memWrite <= 0;
            ID_EX_isBranch <= 0;
            ID_EX_A        <= 0;
            ID_EX_B        <= 0;
            ID_EX_rd       <= 0;
            ID_EX_rs1      <= 0;
            ID_EX_rs2      <= 0;
            ID_EX_imm9     <= 9'b0;
            ID_EX_branch_target <= 8'b0;
        end
        else begin
            ID_EX_A        <= regfile[rs1];
            ID_EX_B        <= regfile[rs2];
            ID_EX_rd       <= rd;
            ID_EX_rs1      <= rs1;
            ID_EX_rs2      <= rs2;
            ID_EX_opcode   <= opcode;
            ID_EX_regWrite <= (opcode < 4'b1000) || (opcode == 4'b1000) || (opcode == 4'b1010);
            ID_EX_memRead  <= (opcode == 4'b1000); // LD
            ID_EX_memWrite <= (opcode == 4'b1001); // ST
            ID_EX_isBranch <= (opcode == 4'b1100); // BEQ
            ID_EX_imm9     <= imm9;
            ID_EX_branch_target <= imm9[7:0];
        end
    end
 
    // EX Stage (ALU + Forwarding)
    wire [7:0] fwd_A = (EX_MEM_regWrite && EX_MEM_rd == ID_EX_rs1) ? EX_MEM_alu_out :
                       (MEM_WB_regWrite  && MEM_WB_rd  == ID_EX_rs1) ? MEM_WB_data    : ID_EX_A;
    wire [7:0] fwd_B = (EX_MEM_regWrite && EX_MEM_rd == ID_EX_rs2) ? EX_MEM_alu_out :
                       (MEM_WB_regWrite  && MEM_WB_rd  == ID_EX_rs2) ? MEM_WB_data    : ID_EX_B;
    wire [7:0] fwd_store = (EX_MEM_regWrite && EX_MEM_rd == ID_EX_rd) ? EX_MEM_alu_out :
                           (MEM_WB_regWrite  && MEM_WB_rd  == ID_EX_rd) ? MEM_WB_data    : regfile[ID_EX_rd];
    always @(*) begin
        alu_out_comb = 8'd0;
        alu_Z_comb   = 0;
        alu_C_comb   = 0;
        alu_S_comb   = 0;
        alu_P_comb   = 0;
        case (ID_EX_opcode)
            4'b0000: {alu_C_comb, alu_out_comb} = fwd_A + fwd_B;           // ADD
            4'b0001: {alu_C_comb, alu_out_comb} = fwd_A - fwd_B;           // SUB
            4'b0010: alu_out_comb = fwd_A & fwd_B;                         // AND
            4'b0011: alu_out_comb = fwd_A | fwd_B;                         // OR
            4'b0100: alu_out_comb = fwd_A ^ fwd_B;                         // XOR
            4'b0101: alu_out_comb = fwd_A;                                  // MOV
            4'b1010: alu_out_comb = (acc + ({8'b0, fwd_A} * {8'b0, fwd_B}));
            default: alu_out_comb = 8'b0;                                   // NOP and others: no output
        endcase
 
        alu_Z_comb = (alu_out_comb == 8'd0);
        alu_S_comb = alu_out_comb[7];
        alu_P_comb = ~(^alu_out_comb);    
    end
 
    always @(posedge clk) begin
    if (flush) begin
        EX_MEM_regWrite      <= 0;
        EX_MEM_memWrite      <= 0;
        EX_MEM_memRead       <= 0;
        EX_MEM_isBranch      <= 0;   
        EX_MEM_alu_out       <= 0;
        EX_MEM_B             <= 0;
        EX_MEM_rd            <= 0;
        EX_MEM_Z             <= 0;
        EX_MEM_addr          <= 0;
        EX_MEM_branch_target <= 0;
    end
    else begin
        EX_MEM_alu_out  <= alu_out_comb;
        EX_MEM_rd       <= ID_EX_rd;
        EX_MEM_regWrite <= ID_EX_regWrite;
        EX_MEM_memRead  <= ID_EX_memRead;
        EX_MEM_memWrite <= ID_EX_memWrite;
        EX_MEM_isBranch <= ID_EX_isBranch;
        EX_MEM_Z        <= alu_Z_comb;
        EX_MEM_addr     <= ID_EX_imm9[7:0];
        EX_MEM_branch_target <= ID_EX_branch_target;
        EX_MEM_Z <= (ID_EX_isBranch) ? Z : alu_Z_comb;
 
        if (ID_EX_opcode == 4'b1001)
            EX_MEM_B <= fwd_store;
        else
            EX_MEM_B <= fwd_B;
        if (ID_EX_opcode == 4'b1010)
            acc <= acc + ({8'b0, fwd_A} * {8'b0, fwd_B});
        if ((ID_EX_opcode < 4'b1000) || (ID_EX_opcode == 4'b1010)) begin
            Z <= alu_Z_comb;
            C <= alu_C_comb;
            S <= alu_S_comb;
            P <= alu_P_comb;
        end
    end
    end

    // MEM Stage
    reg [7:0] mem_data;
    always @(*) begin
        mem_data = EX_MEM_alu_out;
        if (EX_MEM_memRead)
            mem_data = data_mem[EX_MEM_addr];
    end
    always @(posedge clk) begin
        if (EX_MEM_memWrite)
            data_mem[EX_MEM_addr] <= EX_MEM_B;
        MEM_WB_data     <= mem_data;
        MEM_WB_rd       <= EX_MEM_rd;
        MEM_WB_regWrite <= EX_MEM_regWrite;
    end
    
    // WB Stage
    always @(posedge clk) begin
        if (MEM_WB_regWrite) begin
            regfile[MEM_WB_rd] <= MEM_WB_data;
            result             <= MEM_WB_data;   
        end
    end
    
    // Hazard Detection
    assign stall = (ID_EX_memRead && (
        (ID_EX_rd == rs1) || 
        (ID_EX_rd == rs2) ||
        (opcode == 4'b1001 && ID_EX_rd == IF_ID_instr[11:9])
    ));
    
    // Flush on taken branch
    assign flush = (EX_MEM_isBranch && EX_MEM_Z);
endmodule
