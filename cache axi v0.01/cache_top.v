`include "nettype.h"
`include "global_config.h"
`include "stddef.h"

`include "cpu.h"
`include "each_module.h"

`define     StateBus	2:0
`define	 IDLE 	    3'b000
`define     R_DATA		3'b001
`define     INS_READ 	3'b010
`define	 UNCACHE 	3'b011
`define     W_DATA 	3'b100

`define	CounterBus 	4:0

module cache_top 	
	(
	/********** global **********/
	input	wire     clk,
	input	wire     reset,
	input	wire     flus,
	output	wire						icache_busy,
	
	/********** cpu **********/
	//icache
	input	wire	[`WordAddrBus]		if_icache_rd_addr,
	input   wire   						if_icache_rw,	
	input   wire   	[`WriteEnBus]		if_icache_rwen,
//	output  reg   	[`FourWordDataBus]	if_icache_rd_data,
    output  wire  	[`FourWordDataBus]	if_icache_rd_data,
	output	wire						if_icache_addr_ok,
	output	wire						if_icache_data_ok,
	input	wire   	[`PtabAddrBus]		if_icache_ptab,
	output  wire    [`PtabAddrBus]		icache_ib_ptab,
	output	wire	[`WordAddrBus]		cpu_rd_pc,
	input  wire                        if_icache_delot_en,
	//output reg                         icache_ib_delot_en,
	output wire                        icache_ib_delot_en,
	//uncacheable
	input	wire						cpu_uncache_en,
	input	wire						cpu_uncache_rw,
	input	wire	[`WordAddrBus]		cpu_uncache_rd_addr,
	input	wire	[`WordDataBus]		cpu_uncache_wr_data,
	output	wire	[`WordDataBus]		cpu_uncache_rd_data,
	output	wire						cpu_uncache_data_ok,
	//cacheable
	input	wire	[`WordAddrBus]		cpu_mem_rd_addr,
	input	wire						cpu_mem_rw,
	input	wire	[`WriteEnBus]		cpu_mem_rwen,
	input	wire	[`WordDataBus]		cpu_mem_wr_data,
	output	wire	[`WordDataBus]		cpu_mem_rd_data,
	output	wire						cpu_mem_addr_ok,
	output	wire						cpu_mem_data_ok,
	/********** axi **********/
	//aw
	output	wire		[3:0]  			awid,
	output	wire		[31:0]  		awaddr,
	output	wire		[7:0]  			awlen,
	output	wire		[2:0]  			awsize,
	output	wire		[1:0]  			awburst,
	output	wire		[2:0]  			awlock,
	output	wire		[3:0]  			awcache,
	output	wire		[2:0]  			awprot,
	output	wire	                	awvalid,
	//output 	wire 		[3 : 0] 	awqos,
	input	wire	                	awready,
	//w
	output	wire		[3:0]  			wid,
	output	wire		[31:0]  		wdata,
	output	wire		[3:0]  			wstrb,
	output	wire	              	 	wlast,
	output	wire	               		wvalid,
	input	wire	               		wready,
	//b
	input	wire		[3:0] 			bid,
	input  	wire		[1:0] 	    	bresp,
	input	wire	                	bvalid,
	output	wire	                	bready,
	//ar
	output 	wire		[3:0]  			arid,
	output 	wire		[31:0]   		araddr,
	output 	wire		[7:0] 			arlen,
	output 	wire		[2:0]  			arsize,
	output 	wire		[1:0]  			arburst,
	output 	wire		[2:0]  			arlock,
	output 	wire		[3:0]  			arcache,
	output 	wire		[2:0]   		arprot,
	output	wire	               	 	arvalid,
	input	wire	              	  	arready,
	//r
    input  	wire		[3:0]  			rid,
	input  	wire		[31:0]			rdata,
	input	wire		[1 :0]  		rresp,
	input	wire	                	rlast,
	input	wire	                	rvalid,
	output	wire	                	rready
);

	/********** internal signal **********/
	//axi
	wire					axi_ar_en;
	wire					axi_aw_en;
	wire	[`WordAddrBus]	cache_rd_addr;
	wire	[`WordDataBus]	cache_rd_data;
	wire	[`WordAddrBus]	cache_wr_addr;
	wire	[`WordDataBus]	cache_wr_data;
	wire					bus_wr_data_ready;
	reg						bus_wr_data_ready_reg;
	wire					bus_rd_data_ready;
	wire					bus_uncache_ready;
	wire					bus_wr_data_finish;
	wire	[7:0]			aw_burst_len;
	wire	[7:0]			ar_burst_len;
	wire	[1:0]			aw_burst_step;
	wire	[1:0]			ar_burst_step;
	//i_cache
	wire	[`WordAddrBus]	icache_bus_rd_addr;
	wire	[`WordDataBus]	icache_bus_rd_data;
	wire					icache_bus_data_ready;
	wire					icache_bus_rw;
	wire					icache_bus_as;
	
	wire	[`WordAddrBus]	if_icache_rd_addr_ture;
	//d_cache
	wire	[`WordAddrBus]	dcache_bus_rd_addr;
	wire	[`WordAddrBus]	dcache_bus_wr_addr;
	wire	[`WordDataBus]	dcache_bus_rd_data;
	wire	[`WordDataBus]	dcache_bus_wr_data;
	wire					dcache_bus_data_ready;
	wire					dcache_bus_rw;
	wire					dcache_bus_as;
	wire                   cpu_dcache_req_op_valid;
	
	wire	[`WordAddrBus]	dcache_rd_addr;
	wire	[`WordDataBus]	dcache_rd_data;
	wire	[`WordDataBus]	dcache_wr_data;
	wire	[`WriteEnBus]	dcache_rwen;
	wire					dcache_rw;
	wire					dcache_addr_ok;
	wire					dcache_data_ok;
	//state machine
	reg		[`StateBus]		state;
	reg		[`StateBus]		nxstate;
	wire					state_change;
	reg		[`CounterBus]	cnt;
	reg						cnt_end;
	wire					state_idel;
	wire					state_rd_data;
	wire					state_wr_data;
	wire					state_ins_read;
	wire					state_uncache;
	wire					nxstate_idel;
	wire					nxstate_rd_data;
	wire					nxstate_wr_data;
	wire					nxstate_ins_read;
	wire					nxstate_uncache;
	//uncache
	wire					uncache_stall;
	wire					uncache_addr_ok;
	wire					uncache_data_ok;
	wire	[`WordAddrBus]	uncache_rd_addr;
	wire	[`WordDataBus]	uncache_wr_data;
	wire	[`WordDataBus]	uncache_rd_data;
	wire	[`WriteEnBus]	uncache_rwen;
	wire					uncache_rw;
	
	//reg						flag;
	
	
	/********** state machine **********/
	assign	state_idel		    =	(state   == `IDLE);
	assign	state_rd_data	    =	(state   == `R_DATA);
	assign	state_wr_data	    =	(state   == `W_DATA);
	assign	state_ins_read		=	(state   == `INS_READ);
	assign	state_uncache	    =	(state   == `UNCACHE);
	assign	nxstate_idel	    =	(nxstate == `IDLE);
	assign	nxstate_rd_data	    =	(nxstate == `R_DATA);
	assign	nxstate_wr_data  	=	(nxstate == `W_DATA);
	assign	nxstate_ins_read	=	(nxstate == `INS_READ);
	assign	nxstate_uncache	    =	(nxstate == `UNCACHE);
	assign	state_change	    =	(state 	 != nxstate);
	
	always @ (posedge clk)begin
		if(reset == `RESET_ENABLE)begin
			state		<=	`IDLE;
		end
		else if (state_change) begin
			state		<=	nxstate;
		end
	end
	
	always @ (*) begin
		case(state)
			`IDLE	:	nxstate	=	((cpu_uncache_en) ? `UNCACHE :
									(dcache_bus_as && (dcache_bus_rw == `READ)) ? `R_DATA  :
									(dcache_bus_as && (dcache_bus_rw == `WRITE)) ? `W_DATA :
									(icache_bus_as) ? `INS_READ : `IDLE);
			`W_DATA	:	nxstate	=	((bus_wr_data_finish) ? ((cpu_uncache_en) ? `UNCACHE : `IDLE) : `W_DATA);
			`R_DATA :   nxstate	=	((~cnt_end) ? `R_DATA : `IDLE);
			`INS_READ:	nxstate	=	((~cnt_end) ? `INS_READ : `IDLE);
			`UNCACHE :	nxstate	=	((bus_uncache_ready) ? `IDLE : `UNCACHE);
			default	:	nxstate	=	`IDLE;
		endcase
	end
	
	/********** cnt **********/
	always @ (posedge clk) begin
		if (reset == `RESET_ENABLE)begin
			cnt		<=	5'b0;
		end
		else if(cnt == 5'd16)begin
			cnt		<= 5'd17;
		end
		else if (cnt == 5'd17) begin
			cnt		<=	'b0;
		end
		else begin
			cnt		<=(((nxstate_ins_read) | (nxstate_rd_data)) && (bus_rd_data_ready)) ? (cnt + 5'b1) : cnt;
		end
	end
	
	always @ (posedge clk) begin
		if (reset == `RESET_ENABLE)begin
			cnt_end	<= `DISABLE;
		end
		else begin
			cnt_end	<= (cnt == 5'd17);
		end
	end
	
	
	//output 
	assign	icache_busy			=	~if_icache_addr_ok;
	assign	cpu_mem_addr_ok		=	dcache_addr_ok;
	assign	cpu_mem_data_ok		=	dcache_data_ok;
	assign	cpu_mem_rd_data		=	dcache_rd_data;
	assign	cpu_uncache_data_ok = 	uncache_data_ok;
	assign	cpu_uncache_rd_data	=	uncache_rd_data;
	
	//uncache
	assign	bus_uncache_ready	=	bus_wr_data_finish | bus_rd_data_ready;
	assign	uncache_addr_ok		=	(nxstate_uncache);
	assign	uncache_data_ok		=	(state_uncache) ? (bus_rd_data_ready | bus_wr_data_finish) : `DISABLE;
	assign	uncache_wr_data		=	cpu_uncache_wr_data;
	assign	uncache_rw			=	cpu_uncache_rw;
	assign	uncache_rd_data		=	(bus_rd_data_ready) ? cache_rd_data : 'b0;
	assign	uncache_rd_addr		=	((cpu_uncache_rd_addr [31:28] == 4'b1000) | (cpu_uncache_rd_addr [31:28] == 4'b1001)) ? (cpu_uncache_rd_addr - 32'h8000_0000):
									((cpu_uncache_rd_addr [31:28] == 4'b1010) | (cpu_uncache_rd_addr [31:28] == 4'b1011)) ? (cpu_uncache_rd_addr - 32'ha000_0000):
									cpu_uncache_rd_addr; //virtual and true addr transform(no tlb,just kseg0,kseg1,kseg2,kseg3)
	
	//i_cache
	assign	icache_bus_rd_data		=	cache_rd_data;
	assign	icache_bus_data_ready	=	(bus_rd_data_ready) &&((nxstate == `INS_READ));
	assign	if_icache_rd_addr_ture	=	((if_icache_rd_addr [31:28] == 4'b1000) | (if_icache_rd_addr [31:28] == 4'b1001)) ? (if_icache_rd_addr - 32'h8000_0000):
										((if_icache_rd_addr [31:28] == 4'b1010) | (if_icache_rd_addr [31:28] == 4'b1011)) ? (if_icache_rd_addr - 32'ha000_0000):
										if_icache_rd_addr;
	
	
	
	//d_cache
	assign	dcache_wr_data			=	cpu_mem_wr_data;
	assign	dcache_rwen				=	cpu_mem_rwen;
	assign	dcache_rw				=	cpu_mem_rw;
	assign	dcache_rd_data			=	cache_rd_data;
	assign	dcache_bus_data_ready	=	(bus_rd_data_ready | bus_wr_data_ready) && (nxstate_rd_data | nxstate_wr_data);
	assign	dcache_rd_addr			=	((cpu_mem_rd_addr [31:28] == 4'b1000) | (cpu_mem_rd_addr [31:28] == 4'b1001)) ? (cpu_mem_rd_addr - 32'h8000_0000):
										((cpu_mem_rd_addr [31:28] == 4'b1010) | (cpu_mem_rd_addr [31:28] == 4'b1011)) ? (cpu_mem_rd_addr - 32'ha000_0000):
										cpu_mem_rd_addr;
	assign cpu_dcache_req_op_valid  =  (reset==`RESET_ENABLE)?(nxstate_rd_data |  nxstate_wr_data):'b0;
	
	//axi
	assign	aw_burst_len	=	(nxstate_uncache) ? 8'd0 : 8'd15;
	assign	ar_burst_len	=	(nxstate_uncache) ? 8'd0 : 8'd15;
	assign	aw_burst_step	=	2'b1;
	assign	ar_burst_step	=	2'b1;
	assign	axi_ar_en		=	((nxstate_uncache) & (uncache_rw == `READ) | (nxstate_ins_read) | (nxstate_rd_data));
	assign	axi_aw_en		=	(((nxstate_uncache) & (uncache_rw == `WRITE)) | (nxstate_wr_data));
	assign	cache_rd_addr	=	(nxstate_uncache)  ? uncache_rd_addr:
								(nxstate_rd_data)  ? dcache_bus_rd_addr:
								(nxstate_ins_read) ? icache_bus_rd_addr:
								'b0;
	assign	cache_wr_addr	=	(nxstate_uncache)? uncache_rd_addr :
								(nxstate_wr_data)? dcache_bus_wr_addr :
								'b0;
	assign 	cache_wr_data	=	(nxstate_uncache)? uncache_wr_data :
								(nxstate_wr_data)? dcache_bus_wr_data :
								'b0;

	
	axi_interface	axi_interface(
		.axi_ar_en(axi_ar_en),
		.axi_aw_en(axi_aw_en),
		.cpu_rd_addr(cache_rd_addr),
		.cpu_rd_data(cache_rd_data),
		.cpu_wr_addr(cache_wr_addr),
		.cpu_wr_data(cache_wr_data),
		.bus_rd_data_ready(bus_rd_data_ready),
		.bus_wr_data_ready(bus_wr_data_ready),
		.bus_wr_data_finish(bus_wr_data_finish),
		.aw_burst_len(aw_burst_len),
		.ar_burst_len(ar_burst_len),
		.aw_burst_step(aw_burst_step),
		.ar_burst_step(ar_burst_step),
		//
		.clk(clk),
		.reset(reset),
		//
		.awid(awid),
		.awaddr(awaddr),
		.awlen(awlen),
		.awsize(awsize),
		.awburst(awburst),
		.awlock(awlock),
		.awcache(awcache),
		.awprot(awprot),
		.awvalid(awvalid),
		.awready(awready),
		//
		.wid(wid),
		.wdata(wdata),
		.wstrb(wstrb),
		.wlast(wlast),
		.wvalid(wvalid),
		.wready(wready),
		//
		.bid(bid),
		.bresp(bresp),
		.bvalid(bvalid),
		.bready(bready),
		//
		.arid(arid),
		.araddr(araddr),
		.arlen(arlen),
		.arsize(arsize),
		.arburst(arburst),
		.arlock(arlock),
		.arcache(arcache),
		.arprot(arprot),
		.arvalid(arvalid),
		.arready(arready),
		//
		.rid(rid),
		.rresp(rresp),
		.rlast(rlast),
		.rvalid(rvalid),
		.rready(rready),
		.rdata(rdata)
	);	
	
	i_cache_4_way_no_reg i_cache (
		.clk(clk),
		.reset(reset),
		.cpu_rd_addr(if_icache_rd_addr_ture),
		.cpu_rd_addr_virtual(if_icache_rd_addr),
		.cpu_icache_ptab(if_icache_ptab),
		.icache_ib_ptab(icache_ib_ptab),
		.cpu_rd_pc(cpu_rd_pc),
		.cpu_rw(if_icache_rw),
		.cpu_rwen(if_icache_rwen),
		.cpu_rd_data(if_icache_rd_data),
		.cpu_if_addr_ok(if_icache_addr_ok),
		.cpu_if_data_ok(if_icache_data_ok),
		.if_icache_delot_en(if_icache_delot_en),
		.icache_ib_delot_en(icache_ib_delot_en),
		//
		.bus_rw(icache_bus_rw),
		.bus_rd_addr(icache_bus_rd_addr),
		.bus_as(icache_bus_as),
		.bus_data_ready(bus_rd_data_ready),
		.bus_rd_data(icache_bus_rd_data)
	);

	d_cache_directed d_cache(
		.clk(clk),
		.reset(reset),
		.cpu_dcache_req_op_valid(cpu_dcache_req_op_valid),
		.cpu_dcache_addr(dcache_rd_addr),
		.cpu_dcache_rw(dcache_rw),
		.cpu_dcache_rwen(dcache_rwen),
		.cpu_dcache_wr_data(dcache_wr_data),
		.cpu_dcache_rd_data(dcache_rd_data),
		.cpu_mem_data_ok(dcache_data_ok),
		.cpu_mem_addr_ok(dcache_addr_ok),
		//
		.bus_rw(dcache_bus_rw),
		.bus_as(dcache_bus_as),
		.bus_rd_addr(dcache_bus_rd_addr),
		.bus_wr_addr(dcache_bus_wr_addr),
		.bus_ready(dcache_bus_data_ready),
		.bus_rd_data(dcache_bus_rd_data),
		.bus_wr_data(dcache_bus_wr_data)
	);
	
endmodule

`undef StateBus	
`undef	IDLE		
`undef	R_DATA		
`undef INS_READ 	
`undef	UNCACHE 	
`undef W_DATA 		

`undef	CounterBus 	














