/*
 -- ============================================================================
 -- FILE NAME	: ID.v
 -- DESCRIPTION : Instruction Decoder stage
 -- ----------------------------------------------------------------------------
 -- Revision  Date		  Coding_by		Comment
 -- 1.0.0	  2019/06/01  Yau			Yau
 -- ============================================================================
*/
/********** general header **********/
`include "nettype.h"
`include "global_config.h"
`include "stddef.h"

/********** module header **********/
`include "isa.h"
`include "cpu.h"
`include "each_module.h"

/********** internal define ***********/
/* `define Isa2regAddrBus 9:0
`define	Imme2wayBus 63:0
`define Type2wayBus 3:0
`define Insn2wayBus 11:0
`define Insn2wayOpnEnBus 7:0
`define TwoWordAddrBus 63:0 */
`define IDinfo_W 55
`define IDValid_W 6

module ID_stage(
	/******* Global Signal ********/
	input	wire	clk,
	input	wire	rst_,
	input	wire	flush,
	/******* Insn Buffer to ID **********/
	input	wire	[`WordAddrBus]	ib_id_pc_0,
	input	wire	[`WordAddrBus]	ib_id_pc_1,
	input	wire	[`WordDataBus]	ib_id_insn_0,
	input	wire	[`WordDataBus]	ib_id_insn_1,
	input	wire	[`PtabAddrBus]	ib_id_ptab_addr_0,
	input	wire	[`PtabAddrBus]	ib_id_ptab_addr_1,
	input	wire	ib_id_valid_0,
	input	wire	ib_id_valid_1,
	/******* Branch Prediction ********/
	output	reg		[`WordAddrBus]	id_branch_pc,
	output	reg		[`BtbTypeBus]	id_branch_type,
	output	reg		[`WordAddrBus]	id_branch_target_addr,
	output	reg						id_branch_en,
	/************ ID to IS ***************/
	output	reg		[`TwoWordAddrBus]	id_is_pc,
	output	reg		[`Ptab2addrBus]		id_is_ptab_addr,
	output  reg     [`IDinfo_W-1 : 0]	id_is_decode_info_0,
	output  reg     [`IDinfo_W-1 : 0]	id_is_decode_info_1,
	output  reg     [`IDValid_W-1 : 0]	id_is_decode_valid_0,
	output  reg     [`IDValid_W-1 : 0]	id_is_decode_valid_1,
	output	reg		[`ISA_EXC_W*2-1 : 0] id_is_exc_code,
	/************* Handshake **************/
	input  wire     is_allin,
	input  wire     ib_valid_ns,
	output wire     id_allin,
	output wire     id_valid_ns
	);
/******** Internal Signal ********/
wire    stall;
reg     id_valid;
wire    id_ready_go;
wire    [`IDinfo_W-1 : 0]	decode_info_0;
wire    [`IDinfo_W-1 : 0]	decode_info_1;
wire    [`IDValid_W-1 : 0]	decode_valid_0;
wire    [`IDValid_W-1 : 0]	decode_valid_1;
wire	[`ISA_EXC_W-1 : 0]	exc_code_0;
wire	[`ISA_EXC_W-1 : 0]	exc_code_1;
wire	[`BtbTypeBus]		branch_type_0;
wire	[`BtbTypeBus]		branch_type_1;
wire	[`WordAddrBus]		branch_target_addr_0;
wire	[`WordAddrBus]		branch_target_addr_1;
wire						branch_en_0;
wire						branch_en_1;

/********* Combinational Logic *********/
assign stall = !(ib_valid_ns && id_allin);
assign id_ready_go = `ENABLE;
assign id_allin = (!id_valid) || (id_ready_go && is_allin);
assign id_valid_ns = id_valid && id_ready_go;

/********** Sequential Logic *************/
always @ (posedge clk)begin
    if(!rst_)begin
        id_valid <= `DISABLE;
    end
    else if(id_allin)begin
        id_valid <= ib_valid_ns;
    end
end

always @ (posedge clk) begin
	if(!rst_) begin
		id_is_pc <= 64'b0;
		id_is_ptab_addr <= 10'b0;
		id_is_decode_info_0 <= `IDinfo_W'b0;
		id_is_decode_info_1 <= `IDinfo_W'b0;
		id_is_decode_valid_0 <= `IDValid_W'b0;
		id_is_decode_valid_1 <= `IDValid_W'b0;
		id_is_exc_code <= {`ISA_EXC_NO_EXC, `ISA_EXC_NO_EXC};
		id_branch_pc <= 32'b0;
		id_branch_type <= `TYPE_NOP;
		id_branch_target_addr <= 32'b0;
		id_branch_en <= `DISABLE;
	end
	else if (flush) begin
		id_is_pc <= 64'b0;
		id_is_ptab_addr <= 10'b0;
		id_is_decode_info_0 <= `IDinfo_W'b0;
		id_is_decode_info_1 <= `IDinfo_W'b0;
		id_is_decode_valid_0 <= `IDValid_W'b0;
		id_is_decode_valid_1 <= `IDValid_W'b0;
		id_is_exc_code <= {`ISA_EXC_NO_EXC, `ISA_EXC_NO_EXC};
		id_branch_pc <= 32'b0;
		id_branch_type <= `TYPE_NOP;
		id_branch_target_addr <= 32'b0;
		id_branch_en <= `DISABLE;
	end
	else if(stall == `DISABLE) begin
		id_is_pc <= {ib_id_pc_1,ib_id_pc_0};
		id_is_ptab_addr <= {ib_id_ptab_addr_1,ib_id_ptab_addr_0};
		id_is_decode_info_0 <= decode_info_0;
		id_is_decode_info_1 <= decode_info_1;
		id_is_decode_valid_0 <= decode_valid_0;
		id_is_decode_valid_1 <= decode_valid_1;
		id_is_exc_code <= {exc_code_1, exc_code_0};
		id_branch_pc <= (branch_en_0)?ib_id_pc_0:ib_id_pc_1;
		id_branch_type <= (branch_en_0) ? branch_type_0 : branch_type_1;
		id_branch_target_addr <= (branch_en_0) ? branch_target_addr_0 : branch_target_addr_1;
		id_branch_en <= branch_en_0 | branch_en_1;
	end
end

decoder decoder_0 (
	.pc(ib_id_pc_0),
	.insn(ib_id_insn_0),
	.valid(ib_id_valid_0),
	.branch_en(branch_en_0),
	.branch_type(branch_type_0),
	.branch_target_addr(branch_target_addr_0),
	.decode_info(decode_info_0),
	.decode_valid(decode_valid_0),
	.exc_code(exc_code_0)
	);
	
decoder decoder_1 (
	.pc(ib_id_pc_1),
	.insn(ib_id_insn_1),
	.valid(ib_id_valid_1),
	.branch_en(branch_en_1),
	.branch_type(branch_type_1),
	.branch_target_addr(branch_target_addr_1),
	.decode_info(decode_info_1),
	.decode_valid(decode_valid_1),
	.exc_code(exc_code_1)
	);
	
endmodule
