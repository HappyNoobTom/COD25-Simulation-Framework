module REG_FILE (
    input  [ 0 : 0] clk,
    input  [ 4 : 0] rf_ra0,
    input  [ 4 : 0] rf_ra1,
    input  [ 4 : 0] rf_wa,
    input  [ 0 : 0] rf_we,
    input  [31 : 0] rf_wd,
    output [31 : 0] rf_rd0,
    output [31 : 0] rf_rd1,

    input  [ 4 : 0] dbg_reg_ra, 
    output [31 : 0] dbg_reg_rd
);

    reg [31 : 0] reg_file[0 : 31];

    // 用于初始化寄存器
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) 
            reg_file[i] = 0;
        $display("REG_FILE: All registers initialized to 0");
    end

    // 用于调试的计数器
    reg [31:0] debug_write_count;
    initial begin
        debug_write_count = 0;
    end

    // Write
    always @(posedge clk) begin
        debug_write_count <= debug_write_count + 1;
        
        if (rf_wa != 0 && rf_we) begin  // never write reg 0
            $display("REG_FILE WRITE [%d]: Writing 0x%08x to reg[%d] (BEFORE)", debug_write_count, rf_wd, rf_wa);
            $display("REG_FILE WRITE [%d]: reg[%d] value BEFORE write: 0x%08x", debug_write_count, rf_wa, reg_file[rf_wa]);
            
            // 使用阻塞赋值进行寄存器写入，确保立即更新
            reg_file[rf_wa] = rf_wd;
            $display("REG_FILE WRITE [%d]: reg[%d] value AFTER immediate write: 0x%08x", debug_write_count, rf_wa, reg_file[rf_wa]);
            
            // 特别监控寄存器1
            if (rf_wa == 5'd1) begin
                $display("REG_FILE WRITE IMPORTANT [%d]: Writing 0x%08x to reg[1]", debug_write_count, rf_wd);
                $display("REG_FILE CHECK IMMEDIATELY: Current value of reg[1] = 0x%08x", reg_file[1]);
            end
        end
    end

    // 跟踪非阻塞赋值后的寄存器更新
    always @(negedge clk) begin
        if (rf_wa != 0 && rf_we) begin
            $display("REG_FILE WRITE [%d]: reg[%d] value AFTER write: 0x%08x", debug_write_count-1, rf_wa, reg_file[rf_wa]);
        end
    end

    // Read
    assign rf_rd0 = rf_ra0 == 0 ? 0 : reg_file[rf_ra0];  // reg[0] always reads as 0
    assign rf_rd1 = rf_ra1 == 0 ? 0 : reg_file[rf_ra1];  // reg[0] always reads as 0

    // Debug
    assign dbg_reg_rd = reg_file[dbg_reg_ra];
    
    // 监控读操作 - 特别是涉及寄存器1的读取
    always @(*) begin
        if (rf_ra0 == 5'd1 || rf_ra1 == 5'd1) begin
            $display("REG_FILE READ: Reading reg[1] = 0x%08x", reg_file[1]);
        end
        
        if (dbg_reg_ra == 5'd1) begin
            $display("REG_FILE DEBUG READ: Debug reading reg[1] = 0x%08x", reg_file[1]);
        end
    end
    
    // 在每个时钟周期结束时检查寄存器1的值
    always @(negedge clk) begin
        $display("REG_FILE CHECK: Current value of reg[1] = 0x%08x", reg_file[1]);
    end

endmodule