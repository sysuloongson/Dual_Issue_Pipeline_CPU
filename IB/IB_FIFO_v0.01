/*
 -- ============================================================================
 -- FILE NAME	: IB_FIFO.v
 -- DESCRIPTION : FIFO for IB
 -- ----------------------------------------------------------------------------
 -- Revision  Date		  Coding_by		Comment
 -- 1.0.0	  2019/06/23  Yau			Yau
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

/********** internal define *******/
/* `define FifoAddrBus 3:0
`define	FifoDataBus 64:0
`define	FifoDepthBus 15:0
`define	FIFO_DATA_W 65 */

module IB_FIFO(
	/****** Global Signal ******/
	input  wire clk,
	input  wire rst_,
	input  wire stall,
	input  wire flush,
	/****** FIFO signal ******/
	input  wire [`FifoDataBus] fifo_in,
	input  wire fifo_w_en,
	input  wire fifo_r_en,
	output wire fifo_full,
	output wire fifo_empty,
	output reg  [`FifoDataBus] fifo_out
	);
	
	/****** internal signal ******/
	reg [`FifoAddrBus] counter;
	reg [`FifoAddrBus] read_pointer;
	reg [`FifoAddrBus] write_pointer;
	reg [`FifoDataBus] fifo [`FifoDepthBus];
	integer reset_counter;

	/****** Combinational Logic ******/
	assign fifo_full  = (counter == 4'b1111);
	assign fifo_empty = (counter == 4'b0000);

	/****** Sequential Logic *******/
	always @(posedge clk) begin
		if (!rst_) begin
			read_pointer  <= 4'b0;
			write_pointer <= 4'b0;
			counter       <= 4'b0;
			fifo_out      <= `FIFO_DATA_W'b0;
			for(reset_counter = 0; reset_counter < 16; reset_counter = reset_counter + 1)begin
				fifo[reset_counter] <= `FIFO_DATA_W'b0;
			end
		end
		else if (flush) begin
			read_pointer  <= 4'b0;
			write_pointer <= 4'b0;
			counter       <= 4'b0;
			fifo_out      <= `FIFO_DATA_W'b0;
		end
		else if(stall == `DISABLE)begin
			case({fifo_w_en, fifo_r_en})
				2'b00:begin
				end
				2'b01:begin
						fifo_out <= (~fifo_empty) ? fifo[read_pointer] : `FIFO_DATA_W'b0;
						counter  <= (~fifo_empty) ? (counter - 4'b0001) : counter;
						read_pointer <= (~fifo_empty && read_pointer == 4'hf) ? 4'b0 :
										(~fifo_empty) ? (read_pointer + 4'b0001) : read_pointer;	//if 4'hf, read_pointer needs to be back to the front.
				end
				2'b10:begin
						fifo[write_pointer] <= (~fifo_full)?fifo_in : fifo[write_pointer];
						counter <= (~fifo_full) ? (counter + 4'b0001) : counter;
						write_pointer <= (~fifo_full && write_pointer == 4'hf) ? 4'b0:
										 (~fifo_full) ? (write_pointer + 4'b0001) : write_pointer;
				end
				2'b11:begin
						fifo_out <= (fifo_empty) ? fifo_in : fifo[read_pointer];
						fifo[write_pointer] <= (~fifo_empty) ? fifo_in : fifo[write_pointer];
						read_pointer  <= (fifo_empty)? read_pointer:
											(read_pointer == 4'hf) ? 4'b0: (read_pointer + 4'b0001);
						write_pointer <= (fifo_empty)? write_pointer:
											(write_pointer == 4'hf)? 4'b0: (write_pointer + 4'b0001);
				end
			endcase
		end
	end
endmodule
