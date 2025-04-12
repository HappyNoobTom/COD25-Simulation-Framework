`include "include/config.v"

module CPU (
    input                   [ 0 : 0]            clk,
    input                   [ 0 : 0]            rst,

    input                   [ 0 : 0]            global_en,

/* ------------------------------ Memory (inst) ----------------------------- */
    output                  [31 : 0]            imem_raddr,
    input                   [31 : 0]            imem_rdata,

/* ------------------------------ Memory (data) ----------------------------- */
    input                   [31 : 0]            dmem_rdata,
    output                  [ 0 : 0]            dmem_we,
    output                  [31 : 0]            dmem_addr,
    output                  [31 : 0]            dmem_wdata,

/* ---------------------------------- Debug --------------------------------- */
    output                  [ 0 : 0]            commit,
    output                  [31 : 0]            commit_pc,
    output                  [31 : 0]            commit_inst,
    output                  [ 0 : 0]            commit_halt,
    output                  [ 0 : 0]            commit_reg_we,
    output                  [ 4 : 0]            commit_reg_wa,
    output                  [31 : 0]            commit_reg_wd,
    output                  [ 0 : 0]            commit_dmem_we,
    output                  [31 : 0]            commit_dmem_wa,
    output                  [31 : 0]            commit_dmem_wd,

    input                   [ 4 : 0]            debug_reg_ra,
    output                  [31 : 0]            debug_reg_rd
);

wire [31 : 0] pc_add4, pc_j, pc, npc, inst, imm, alu_src0, alu_src1, alu_res, rf_rd0, rf_rd1, rf_wd, dmem_rd_out;
wire [1 : 0] npc_sel, rf_wd_sel;
wire [3 : 0] br_type, dmem_access;
wire [4 : 0] alu_op, rf_ra0, rf_ra1, rf_wa;
wire rf_we, alu_src0_sel, alu_src1_sel;

assign imem_raddr = pc;  // read instruction
assign dmem_addr = alu_res;  // read data

PC_ADD4 pcadd4 (
    .pc(pc),
    .pc_add4(pc_add4)
);

PC_AND pcand (
    .pc(alu_res),
    .pc_and(pc_j)
);

MUX41 npc_mux (
    .src0(pc_add4),
    .src1(alu_res),  // pc_offset
    .src2(pc_j),
    .src3(0),
    .sel(npc_sel),
    .res(npc)
);

PC my_pc (
    .clk(clk),
    .rst(rst),
    .en(global_en),
    .npc(npc),
    .pc(pc)
);

// 添加一段初始PC的调试代码
initial begin
    $display("CPU: PC module initialized");
    $display("CPU: Ensure PC is initialized to 0x00400000");
end

DECODER decoder (
    .inst(imem_rdata),
    .alu_op(alu_op),
    .imm(imm),
    .rf_ra0(rf_ra0),
    .rf_ra1(rf_ra1),
    .rf_wa(rf_wa),
    .rf_we(rf_we),
    .rf_wd_sel(rf_wd_sel),
    .alu_src0_sel(alu_src0_sel),
    .alu_src1_sel(alu_src1_sel),
    .br_type(br_type),
    .dmem_access(dmem_access),
    .dmem_we(dmem_we)
);

REG_FILE reg_file (
    .clk(clk),
    .rf_ra0(rf_ra0),
    .rf_ra1(rf_ra1),
    .rf_wa(rf_wa),
    .rf_we(rf_we),
    .rf_wd(rf_wd),
    .rf_rd0(rf_rd0),
    .rf_rd1(rf_rd1),
    .dbg_reg_ra(debug_reg_ra),
    .dbg_reg_rd(debug_reg_rd)
);

BRANCH branch (
    .br_type(br_type),
    .br_src0(rf_rd0),
    .br_src1(rf_rd1),
    .npc_sel(npc_sel)
);

MUX21 alu_src0_mux (
    .src0(rf_rd0),
    .src1(pc),
    .sel(alu_src0_sel),
    .res(alu_src0)
);

MUX21 alu_src1_mux (
    .src0(rf_rd1),
    .src1(imm),
    .sel(alu_src1_sel),
    .res(alu_src1)
);

ALU alu (
    .alu_src0(alu_src0),
    .alu_src1(alu_src1),
    .alu_op(alu_op),
    .alu_res(alu_res)
);

MUX41 rf_wd_mux (
    .src0(pc_add4),
    .src1(alu_res),
    .src2(dmem_rd_out),
    .src3(0),
    .sel(rf_wd_sel),
    .res(rf_wd)
);

SL_UNIT sl_unit (
    .addr(alu_res),
    .dmem_access(dmem_access),
    .rd_in(dmem_rdata),
    .wd_in(rf_rd1),
    .rd_out(dmem_rd_out),
    .wd_out(dmem_wdata)
);


// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> DEBUG <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
reg  [ 0 : 0]   commit_reg          ;
reg  [31 : 0]   commit_pc_reg       ;
reg  [31 : 0]   commit_inst_reg     ;
reg  [ 0 : 0]   commit_halt_reg     ;
reg  [ 0 : 0]   commit_reg_we_reg   ;
reg  [ 4 : 0]   commit_reg_wa_reg   ;
reg  [31 : 0]   commit_reg_wd_reg   ;
reg  [ 0 : 0]   commit_dmem_we_reg  ;
reg  [31 : 0]   commit_dmem_wa_reg  ;
reg  [31 : 0]   commit_dmem_wd_reg  ;

// 添加调试计数器
reg [31:0] debug_cycle_counter;
// 添加第一个周期标志
reg first_cycle_flag;

// 添加初始值设置
initial begin
    first_cycle_flag = 1;
    commit_pc_reg = 0;
    commit_inst_reg = 0;
    commit_reg_we_reg = 0;
    commit_reg_wa_reg = 0;
    commit_reg_wd_reg = 0;
    commit_dmem_we_reg = 0;
    commit_dmem_wa_reg = 0;
    commit_dmem_wd_reg = 0;
    $display("CPU INITIAL: First cycle flag set, commit signals initialized");
end

always @(posedge clk) begin
    if (rst) begin
        commit_reg          <= 1'H0;
        commit_pc_reg       <= 32'H0;        // 确保初始值为0
        commit_inst_reg     <= 32'H0;
        commit_halt_reg     <= 1'H0;
        commit_reg_we_reg   <= 1'H0;
        commit_reg_wa_reg   <= 5'H0;
        commit_reg_wd_reg   <= 32'H0;
        commit_dmem_we_reg  <= 1'H0;
        commit_dmem_wa_reg  <= 32'H0;
        commit_dmem_wd_reg  <= 32'H0;
        debug_cycle_counter <= 32'H0;
        first_cycle_flag    <= 1'b1;         // 重置时设置第一个周期标志
        
        // 添加调试信息
        $display("CPU RESET: commit_pc_reg initialized to 0x%08x", commit_pc_reg);
    end
    else if (global_en) begin
        // 增加调试计数器
        debug_cycle_counter <= debug_cycle_counter + 1;
        
        // 第一个周期后清除标志
        if (first_cycle_flag) begin
            first_cycle_flag <= 1'b0;
            $display("CPU DEBUG: First cycle completed, flag cleared");
        end
        
        // !!!! 请注意根据自己的具体实现替换 <= 右侧的信号 !!!!
        commit_reg          <= 1'H1;                        // 不需要改动
        commit_pc_reg       <= pc;                          // 需要为当前的 PC
        commit_inst_reg     <= imem_rdata;                  // 需要为当前的指令
        commit_halt_reg     <= imem_rdata == `HALT;         // 注意！请根据指令集设置 HALT_INST！
        commit_reg_we_reg   <= rf_we;                       // 需要为当前的寄存器堆写使能
        commit_reg_wa_reg   <= rf_wa;                       // 需要为当前的寄存器堆写地址
        commit_reg_wd_reg   <= rf_wd;                       // 需要为当前的寄存器堆写数据，修正为rf_wd
        commit_dmem_we_reg  <= dmem_we;                     // 修改为当前的数据存储器写使能
        commit_dmem_wa_reg  <= dmem_addr;                   // 修改为当前的数据存储器地址
        commit_dmem_wd_reg  <= dmem_wdata;                  // 修改为当前的数据存储器写数据
        
        // 添加更多调试信息
        $display("CPU DEBUG: Updated commit_pc_reg from 0x%08x to 0x%08x", commit_pc_reg, pc);
        
        // 调试信息打印
        $display("DEBUG [Cycle %d] PC: 0x%08x, Instr: 0x%08x", debug_cycle_counter, pc, imem_rdata);
        $display("DEBUG [Cycle %d] RF_WE: %d, RF_WA: %d, RF_WD: 0x%08x", debug_cycle_counter, rf_we, rf_wa, rf_wd);
        $display("DEBUG [Cycle %d] DMEM_WE: %d, DMEM_ADDR: 0x%08x, DMEM_WD: 0x%08x", debug_cycle_counter, dmem_we, dmem_addr, dmem_wdata);
    end
end

// 添加寄存器读写调试信息
initial begin
    $display("DEBUG: CPU initialization start");
end

// 使用寄存器值进行difftest的提交
// 这是因为写入寄存器发生在时钟上升沿，而difftest会在同一个周期内检查CPU状态
// 我们需要保持相同的时序
// 特殊处理第一个周期，使其与参考模型对齐
assign commit               = first_cycle_flag ? 1'b0 : commit_reg;
assign commit_pc            = first_cycle_flag ? 32'h0 : commit_pc_reg;
assign commit_inst          = first_cycle_flag ? 32'h0 : commit_inst_reg;
assign commit_halt          = first_cycle_flag ? 1'b0 : commit_halt_reg;
assign commit_reg_we        = first_cycle_flag ? 1'b0 : commit_reg_we_reg;
assign commit_reg_wa        = first_cycle_flag ? 5'h0 : commit_reg_wa_reg;
assign commit_reg_wd        = first_cycle_flag ? 32'h0 : commit_reg_wd_reg;
assign commit_dmem_we       = first_cycle_flag ? 1'b0 : commit_dmem_we_reg;
assign commit_dmem_wa       = first_cycle_flag ? 32'h0 : commit_dmem_wa_reg;
assign commit_dmem_wd       = first_cycle_flag ? 32'h0 : commit_dmem_wd_reg;

// 添加difftest调试信息
always @(posedge clk) begin
    if (!rst && global_en) begin
        $display("DIFFTEST [Cycle %d] commit_pc=0x%08x, commit_inst=0x%08x", 
                 debug_cycle_counter, commit_pc, commit_inst);
        $display("DIFFTEST [Cycle %d] commit_reg_we=%d, commit_reg_wa=%d, commit_reg_wd=0x%08x",
                 debug_cycle_counter, commit_reg_we, commit_reg_wa, commit_reg_wd);
        $display("DIFFTEST [Cycle %d] commit_dmem_we=%d, commit_dmem_wa=0x%08x, commit_dmem_wd=0x%08x",
                 debug_cycle_counter, commit_dmem_we, commit_dmem_wa, commit_dmem_wd);
        
        // 额外添加关于first_cycle_flag的调试信息
        $display("DIFFTEST [Cycle %d] first_cycle_flag=%d", debug_cycle_counter, first_cycle_flag);
        
        // 检查寄存器1的写入
        if (commit_reg_we && commit_reg_wa == 5'd1) begin
            $display("IMPORTANT: Writing to register 1 with value 0x%08x", commit_reg_wd);
        end
    end
end

// 添加后置调试观察
reg [31:0] dbg_last_cycle_pc;
reg [31:0] dbg_last_cycle_inst;
reg [31:0] dbg_last_cycle_regwd;
reg [4:0]  dbg_last_cycle_regwa;
reg        dbg_last_cycle_regwe;

always @(posedge clk) begin
    if (!rst) begin
        dbg_last_cycle_pc <= pc;
        dbg_last_cycle_inst <= imem_rdata;
        dbg_last_cycle_regwd <= rf_wd;
        dbg_last_cycle_regwa <= rf_wa;
        dbg_last_cycle_regwe <= rf_we;
        
        // 检查寄存器变化 - 这需要修改REG_FILE模块来输出寄存器值，或者使用其他方式检查
        if (dbg_last_cycle_regwe && dbg_last_cycle_regwa == 5'd1) begin
            $display("REGISTER CHECK [Cycle %d] Should have written 0x%08x to reg[1]", 
                     debug_cycle_counter-1, dbg_last_cycle_regwd);
        end
    end
end

// 添加寄存器写入数据的调试
always @(*) begin
    $display("RF_WD_SEL DEBUG: rf_wd_sel=%d, pc_add4=0x%08x, alu_res=0x%08x, dmem_rd_out=0x%08x, rf_wd=0x%08x",
             rf_wd_sel, pc_add4, alu_res, dmem_rd_out, rf_wd);
    
    if (rf_we && rf_wa == 5'd1) begin
        $display("RF_WRITE DEBUG: Writing to reg[1], rf_wd=0x%08x", rf_wd);
    end
end

endmodule
