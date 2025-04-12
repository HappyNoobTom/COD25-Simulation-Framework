`include "include/config.v"

module BRANCH(
    input                   [ 3 : 0]            br_type,

    input                   [31 : 0]            br_src0,
    input                   [31 : 0]            br_src1,

    output      reg         [ 1 : 0]            npc_sel
);

always @(*) begin
    case (br_type)
        `BEQ: npc_sel = (br_src0 == br_src1) ? 1 : 0;
        `BNE: npc_sel = (br_src0 != br_src1) ? 1 : 0;
        `BLT: npc_sel = ($signed(br_src0) < $signed(br_src1)) ? 1 : 0;
        `BGE: npc_sel = ($signed(br_src0) >= $signed(br_src1)) ? 1 : 0;
        `BLTU: npc_sel = (br_src0 < br_src1) ? 1 : 0;
        `BGEU: npc_sel = (br_src0 >= br_src1) ? 1 : 0;
        `BR_JAL: npc_sel = 1;
        `BR_JALR: npc_sel = 2;
        default: npc_sel = 0;
    endcase
end

endmodule