/*
 -- ============================================================================
 -- FILE NAME	: IF.v
 -- DESCRIPTION : Instruction Fetch stage
 -- ----------------------------------------------------------------------------
 -- Revision  Date		  Coding_by		Comment
 -- 1.0.0	  2019/05/25  Yau			Yau
 -- ============================================================================
*/
/********** Common header file **********/
`include "nettype.h"
`include "global_config.h"
`include "stddef.h"

/********** Individual header file **********/
`include "cpu.h"
`include "each_module.h"

`define ADDR_WORDSIZE 31:0
`define INSN_WORDSIZE 31:0
`define ENABLE 1'b1
`define DISABLE 1'b0
`define RESET_ENABLE 1'b0
`define RESET_VECTOR 32'b0

module IF(
	/****global signal****/
	input  wire clk,
	input  wire rst_,
	/****Branch Prediction Unit****/
	input  wire bp_if_en,	//prediction completed
	input  wire [`ADDR_WORDSIZE] bp_if_target,
	input  wire bp_if_delot_en,
	input  wire [`ADDR_WORDSIZE] bp_if_delot_pc,
	output wire [`ADDR_WORDSIZE] if_bp_pc,		//same as if_rd_addr
	/**** Icache Signal ****/
	output wire if_rw,
	output wire [3:0] if_rwen,
	output wire [`ADDR_WORDSIZE] if_icache_pc,
	output reg  if_icache_delot_en,
	/**** Hand Shake ****/
	input  wire icache_allin,
	input  wire bp_allin,
	output wire if_valid_ns, 
	/******** EX ********/
	input wire ex_bp_error,
	input wire [`ADDR_WORDSIZE] ex_new_target,
	/******** CP0 ********/
	input wire exc_flush_all,
	input wire [`ADDR_WORDSIZE] cp0_if_excaddr	//if the exception arbiter is in WB
	);
	
	/***** Internal Signal *****/
	wire stall;
	wire [`ADDR_WORDSIZE] next_pc;
	wire [`ADDR_WORDSIZE] new_pc;
	wire if_ready_go;
	reg  if_valid;
	reg  [`ADDR_WORDSIZE] target_after_delot;
	reg  [`ADDR_WORDSIZE] if_pc;

/***** Combinational Logic *****/
	//to BP
	assign if_bp_pc = if_pc;
	assign if_icache_pc = if_pc;
	//to icache
	assign if_rw = `DISABLE;
	assign if_rwen = 4'b1111;
	//Next PC
	assign next_pc = (bp_if_delot_en)? bp_if_delot_pc:
						(target_after_delot != 0) ? target_after_delot:
						(bp_if_en) ? bp_if_target:(if_pc[`PcByteOffsetLoc] == 2'b00) ? (if_pc + `WORD_ADDR_W'd16):
												  (if_pc[`PcByteOffsetLoc] == 2'b01) ? (if_pc + `WORD_ADDR_W'd12):
												  (if_pc[`PcByteOffsetLoc] == 2'b10) ? (if_pc + `WORD_ADDR_W'd8) : (if_pc + `WORD_ADDR_W'd4);
	assign new_pc  = (ex_bp_error)?ex_new_target:cp0_if_excaddr;
	//Hand shake
	assign if_ready_go = `ENABLE;
	assign if_valid_ns = if_valid && if_ready_go;
	assign stall = !(icache_allin && bp_allin);

/**** sequential logic ****/
always @(posedge clk) begin
	if (!rst_) begin
		if_pc <= `RESET_VECTOR;
		if_valid <= `DISABLE;
		if_icache_delot_en <= 1'b0;
	end
	else if (ex_bp_error == `ENABLE || exc_flush_all == `ENABLE) begin
		if_pc <= new_pc;
		if_valid <= `ENABLE;
		if_icache_delot_en <= 1'b0;
	end
	else if(stall == `DISABLE)begin
		if_pc <= next_pc;
		if_valid <= `ENABLE;
		if_icache_delot_en <= bp_if_delot_en;
	end
end

always @(posedge clk) begin
	if (!rst_) begin
		target_after_delot <= 32'b0;
	end
	else if (bp_if_delot_en) begin
		target_after_delot <= bp_if_target;
	end
	else if (stall == `DISABLE) begin
		target_after_delot <= 32'b0;
	end
end
endmodule
