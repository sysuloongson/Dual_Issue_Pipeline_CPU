/*
 -- ============================================================================
 -- FILE NAME	: cp0.v
 -- DESCRIPTION : cp0
 -- ----------------------------------------------------------------------------
 -- Revision  Date		  Coding_by		Comment
 -- 1.0.0	  2019/07/08  Yau			Yau
 -- ============================================================================
*/
/********** Common header file **********/
`include "nettype.h"
`include "global_config.h"
`include "stddef.h"

/********** Individual header file **********/
`include "cpu.h"
`include "each_module.h"
//macro define
`define PRIVILEGE 3'b110
`define REG_ADDR_BUS 4:0
`define CP0_INT_BUS 7:0
`define CP0_BADVADDR 8
`define CP0_STATUS 12
`define CP0_CAUSE 13
`define CP0_EPC 14
`define EXC_CODE_WAY0 4:0
`define EXC_CODE_WAY1 9:5
`define EXC_CODE_W 5
`define EXC_INT 5'b00
`define EXC_SYS 5'h08
`define EXC_OV 5'h0c
`define EXC_NONE 5'h10
`define EXC_ERET 5'h11
`define EXC_ADDR 32'hbfc00380 //entrance PC of exception handling program
`define EXC_INT_ADDR 32'hbfc00380  //entrance PC of interrupt handling program
`define EXC_FLUSH_DISABLE 0
`define EXC_FLUSH_ENABLE 1

module cp0(
	/***** global *****/
	input  wire clk,
	input  wire rst_,
	/***** for MFC0 at EX *****/
	input  wire ex_cp0_re,
	input  wire [`REG_ADDR_BUS] ex_cp0_raddr_0,
	input  wire [`REG_ADDR_BUS] ex_cp0_raddr_1,
	output wire [`WordDataBus]  ex_cp0_rdata_0,	
	output wire [`WordDataBus]  ex_cp0_rdata_1,
	/***** for MTC0 from WB *****/
	input  wire wb_cp0_we,
	input  wire [`REG_ADDR_BUS] wb_cp0_waddr_0,
	input  wire [`REG_ADDR_BUS] wb_cp0_waddr_1,
	input  wire [`WordDataBus]  wb_cp0_wdata_0,
	input  wire [`WordDataBus]  wb_cp0_wdata_1,
	/***** External Interrupt input *****/
	input  wire [`CP0_INT_BUS]  int_i,
	/***** EXC input from EX *****/
	input  wire [`TwoWordAddrBus]  ex_cp0_exc_pc_i,
	input  wire [1:0] ex_cp0_in_delay_i,
	input  wire [`EXC_CODE_W*2-1 : 0] ex_cp0_exc_code_i,
	/***** EXC output *****/
	output wire exc_flush_all,
	output reg  exc_flush_icache,		//to flush the latest icache output a cycle later than other stages.
	output wire [`WordAddrBus]  cp0_if_excaddr  //to if
);
	
	/***** Internal Signal *****/
	reg  [`WordAddrBus] badvaddr;
	reg  [`WordDataBus] status;
	reg  [`WordDataBus] cause;
	reg  [`WordAddrBus] epc;
	wire [1:0] exc_en;
	wire [`EXC_CODE_W-1 : 0] exc_code_0;
	wire [`EXC_CODE_W-1 : 0] exc_code_1;
	wire [`WordAddrBus] exc_pc_i;
	wire in_delay_i;

	/***** Combinational Logic *****/
	assign exc_en = (ex_cp0_exc_code_i[`EXC_CODE_WAY0]!=`EXC_NONE)?2'b01:
					(ex_cp0_exc_code_i[`EXC_CODE_WAY1]!=`EXC_NONE)?2'b10:2'b00;
	//assign exc_code_0 = (status[15:10]&cause[15:10]!=8'h00 && status[1] == 1'b0 && status[0] == 1'b1)?`EXC_INT:ex_cp0_exc_code_i[`EXC_CODE_WAY0];
	//hard int & soft int both regarded as EXC_INT
	assign exc_code_0 = (int_i == 1'b1||(status[15:10]&cause[15:10]!=8'h00 && status[1] == 1'b0 && status[0] == 1'b1))?`EXC_INT:ex_cp0_exc_code_i[`EXC_CODE_WAY0];
	assign exc_code_1 = ex_cp0_exc_code_i[`EXC_CODE_WAY1];
	assign exc_pc_i = (exc_en == 2'b01)?ex_cp0_exc_pc_i[31:0]:
						(exc_en == 2'b10)?ex_cp0_exc_pc_i[63:32]:32'b0;
	assign in_delay_i = (exc_en == 2'b01 & ex_cp0_in_delay_i[0] == 1'b1) || (exc_en == 2'b10 & ex_cp0_in_delay_i[1] == 1'b1);
	assign exc_flush_all = (!rst_)? `EXC_FLUSH_DISABLE:
						(|exc_en) ? `EXC_FLUSH_ENABLE : `EXC_FLUSH_DISABLE;
	
	//entrance PC of exception handling program
	assign cp0_if_excaddr = (!rst_)?32'b0:
							(exc_code_0 == `EXC_INT)?`EXC_INT_ADDR:
							(exc_code_0 == `EXC_ERET && wb_cp0_waddr_0 == `CP0_EPC && wb_cp0_we)?wb_cp0_wdata_0:
							(exc_code_0 == `EXC_ERET)?epc:
							(exc_code_0 != `EXC_NONE)? `EXC_ADDR:
							(exc_code_1 == `EXC_INT)?`EXC_INT_ADDR:
							(exc_code_1 == `EXC_ERET && wb_cp0_waddr_1 == `CP0_EPC && wb_cp0_we)?wb_cp0_wdata_1:
							(exc_code_1 == `EXC_ERET)?epc:
							(exc_code_1 != `EXC_NONE)? `EXC_ADDR:32'b0;

	//CP0 read
	assign ex_cp0_rdata_0 = (!rst_) ? 32'b0: (!ex_cp0_re) ? 32'b0:
					 (ex_cp0_raddr_0 == `CP0_BADVADDR) ? badvaddr:
					 (ex_cp0_raddr_0 == `CP0_STATUS) ? status:
					 (ex_cp0_raddr_0 == `CP0_CAUSE) ? cause:
					 (ex_cp0_raddr_0 == `CP0_EPC) ? epc:32'b0;
	assign ex_cp0_rdata_1 = (!rst_) ? 32'b0: (!ex_cp0_re) ? 32'b0:
					 (ex_cp0_raddr_1 == `CP0_BADVADDR) ? badvaddr:
					 (ex_cp0_raddr_1 == `CP0_STATUS) ? status:
					 (ex_cp0_raddr_1 == `CP0_CAUSE) ? cause:
					 (ex_cp0_raddr_1 == `CP0_EPC) ? epc:32'b0;

	/***** Sequential Logic *****/
	always @(posedge clk) begin
		if (!rst_) begin
			exc_flush_icache <= 1'b0;
		end
		else begin
			exc_flush_icache <= exc_flush_all;
		end
	end

	task do_exc;begin
		if(status[1]==0)begin
			if(in_delay_i)begin
				cause[31] <= 1'b1;
				epc       <= exc_pc_i - 4;
			end
			else begin
				cause[31] <= 1'b0;
				epc       <= exc_pc_i;
			end
		end
		status[1] <= 1'b1;
		cause[6:2]<= (exc_en==2'b01)?exc_code_0:exc_code_1;
	end
	endtask

	task do_eret;begin
		status[1] <= 1'b0; //EXL <= 0, enable int detection
	end
	endtask
	
	//CP0 update
	always @(posedge clk) begin
		if (!rst_) begin
			badvaddr <= 32'b0;
			status   <= 32'h00000000; 
			cause    <= 32'b0;
			epc      <= 32'b0;
		end
		else begin
			cause[15:10] <= int_i;
			case(exc_en)
				2'b01: if (exc_code_0 == `EXC_ERET) begin
							do_eret();
	  				   end
	  				   else begin
	  				   		do_exc();
	  				   end
	  			2'b10: if (exc_code_1 == `EXC_ERET) begin
							do_eret();
	  				   end
	  				   else begin
	  				   		do_exc();
	  				   end
	  			2'b00: if(wb_cp0_we)begin
	  							badvaddr <= (wb_cp0_waddr_1 == `CP0_BADVADDR)?wb_cp0_wdata_1:
	  										(wb_cp0_waddr_0 == `CP0_BADVADDR)?wb_cp0_wdata_0:badvaddr;
	  							status   <= (wb_cp0_waddr_1 == `CP0_STATUS)?wb_cp0_wdata_1:
	  										(wb_cp0_waddr_0 == `CP0_STATUS)?wb_cp0_wdata_0:status;
	  							cause    <= (wb_cp0_waddr_1 == `CP0_CAUSE)?wb_cp0_wdata_1:
	  										(wb_cp0_waddr_0 == `CP0_CAUSE)?wb_cp0_wdata_0:cause;
								epc      <= (wb_cp0_waddr_1 == `CP0_EPC)?wb_cp0_wdata_1:
	  										(wb_cp0_waddr_0 == `CP0_EPC)?wb_cp0_wdata_0:epc;	  						
	  				   end
	  		endcase
		end
	end

endmodule

