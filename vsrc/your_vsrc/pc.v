module PC (
    input                   [ 0 : 0]            clk,
    input                   [ 0 : 0]            rst,
    input                   [ 0 : 0]            en,
    input                   [31 : 0]            npc,

    output      reg         [31 : 0]            pc
);

// 添加初始化代码以确保PC的初始值是0
initial begin
    pc = 32'h0; // 首次上电后初始值为0
    $display("PC MODULE: Initial value set to 0x%08x", pc);
    $display("PC MODULE: Will be set to `PC_INIT (0x00400000) on first reset");
end

always @(posedge clk) begin
    if (rst) begin
        pc <= `PC_INIT;
        $display("PC MODULE: Reset activated, setting PC to 0x%08x", `PC_INIT);
    end else if (en) begin
        pc <= npc;
        $display("PC MODULE: Updating PC from 0x%08x to 0x%08x", pc, npc);
    end
end

endmodule