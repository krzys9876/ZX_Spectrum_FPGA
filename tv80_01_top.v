`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:36:16 10/26/2018 
// Design Name: 
// Module Name:    tv80_01_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module tv80_01_top(
	input clk,
	input SW1,SW2,SW3,SW4,
	input [4:0] KB, // kolumny klawiatury
	output [7:0] KBA, // wiersze klawiatury
	input IO_P1_4,
	output IO_P1_6, 
	output [7:0] LED,
	output o_vga_hs,o_vga_vs,
	output [3:0] o_r,
	 output [3:0] o_g,
	 output [3:0] o_b
    );
	 
	 // konwerter wpiêty wprost w piny - GND=2, TX=4, RX=6
	 wire rxIN,txOUT;
	 assign IO_P1_6=txOUT; // RX z interfejsu
	 assign rxIN=IO_P1_4; // TX z interfejsu

	 reg [31:0] counter;
	 wire [15:0] ADDR;
	 wire [7:0] DATAin;
	 wire [7:0] DATAout;
	 wire [7:0] DATAinRAM1;	 
	 wire [7:0] DATAinRAM2;	 
	 wire [7:0] DATAinRAM3;	 
	 wire [7:0] DATAinROM;	 
	 wire clk_cpu,clk_vga,clk_master,clk_baud,wr,mreq,busak,halt,rfsh,iorq,m1;
	 
	 wire rst_pos,rst;
	 	 
	 clk_divider clk_div
   (// Clock in ports
    .CLK_IN(clk),      // IN
    // Clock out ports
    .CLK_MASTER(clk_master),     // 100M
    .CLK_VGA(clk_vga),     // 25M
    .CLK_CPU(clk_cpu),		// ~3.577M
	 .CLK_BAUD(clk_baud));    // ~7.3128M
	 
	 wire vga_hs, vga_vs;
	 wire [9:0] vga_x,vga_sx;
	 wire [9:0] vga_y,vga_sy,vga_next_y,vga_next_sy,vga_sy_sh,vga_next_sy_sh;
	 wire vga_blank;
	 wire vga_blank_next;
	 wire [4:0] sx_cnt,sy_cnt;
	 wire [4:0] sx_counter,sy_counter;
	 wire [2:0] bit_num, bit_num_n;
	 wire [7:0] byte_num, byte_num_n, next_byte_num, next_byte_num_n, byte_num_sh, next_byte_num_sh;
	 
	 wire [7:0] x_shift;
	 wire [9:0] y_shift;
	 
	 wire [12:0] addr_wire;
	 reg [12:0] addr_reg;
	 reg [9:0] addr_attr_reg;
	 reg [5:0] vs_counter;
	 
	 wire [7:0] vga_mem_rec,vga_attr_rec;
	 wire char_mode;
	 wire [6:0] char_index;
	 wire [7:0] data;
	 reg [7:0] data_reg, data_reg_tmp,data_attr_reg;
	 wire [7:0] data_attr;
	 wire [11:0] color_ink,color_paper;
	 
	 wire visible_area;
	 
	 // wyœrodkowanie obrazu na ekranie
	 assign x_shift=4; // 3 bajty=32 pixele
	 assign byte_num_sh=byte_num-x_shift;
	 assign next_byte_num_sh=next_byte_num-x_shift;
	 
	 assign y_shift=24; // 24 pixele
	 assign vga_sy_sh=vga_sy-y_shift;
	 assign vga_next_sy_sh=vga_next_sy-y_shift;
	 	 
	 //assign visible_area=vga_sx<=255 && vga_sy<=191;
	 assign visible_area=byte_num_sh>=0 && byte_num_sh<=31 && vga_sy_sh>=0 && vga_sy_sh<=191; //256x192
	 assign o_bit=visible_area & data_reg[{3'b111-bit_num}];
	 assign data_attr=visible_area ? data_attr_reg : 8'b01111000; //szare t³o
	 
	 //  7:0 FLASH | BRIGHT | PEN_G | PEN_R | PEN_B | INK_G | INK_R | INK_B
   // po 4 bity w kolejnoœci: 12:0 rrrrggggbbbb
	 assign color_ink=
		  (data_attr[2:0]==0) ? (data_attr[6] ? 12'h000 : 12'h000)
		: (data_attr[2:0]==1) ? (data_attr[6] ? 12'h00C : 12'h00F)
		: (data_attr[2:0]==2) ? (data_attr[6] ? 12'hC00 : 12'hF00)
		: (data_attr[2:0]==3) ? (data_attr[6] ? 12'hC0C : 12'hF0F)
		: (data_attr[2:0]==4) ? (data_attr[6] ? 12'h0C0 : 12'h0F0)
		: (data_attr[2:0]==5) ? (data_attr[6] ? 12'h0CC : 12'h0FF)
		: (data_attr[2:0]==6) ? (data_attr[6] ? 12'hCC0 : 12'hFF0)
		: (data_attr[2:0]==7) ? (data_attr[6] ? 12'hCCC : 12'hFFF)
		: {8'b0};
	 
	 	 assign color_paper=
		  (data_attr[5:3]==0) ? (data_attr[6] ? 12'h000 : 12'h000)
		: (data_attr[5:3]==1) ? (data_attr[6] ? 12'h00C : 12'h00F)
		: (data_attr[5:3]==2) ? (data_attr[6] ? 12'hC00 : 12'hF00)
		: (data_attr[5:3]==3) ? (data_attr[6] ? 12'hC0C : 12'hF0F)
		: (data_attr[5:3]==4) ? (data_attr[6] ? 12'h0C0 : 12'h0F0)
		: (data_attr[5:3]==5) ? (data_attr[6] ? 12'h0CC : 12'h0FF)
		: (data_attr[5:3]==6) ? (data_attr[6] ? 12'hCC0 : 12'hFF0)
		: (data_attr[5:3]==7) ? (data_attr[6] ? 12'hCCC : 12'hFFF)
		: {8'b0};

	 assign o_r=(vga_blank==1) ? {4'b0} : ((data_attr[7] ? (o_bit ^ vs_counter[5]) : o_bit) ? color_ink[11:8] : color_paper[11:8]);
	 assign o_g=(vga_blank==1) ? {4'b0} : ((data_attr[7] ? (o_bit ^ vs_counter[5]) : o_bit) ? color_ink[7:4] : color_paper[7:4]);
	 assign o_b=(vga_blank==1) ? {4'b0} : ((data_attr[7] ? (o_bit ^ vs_counter[5]) : o_bit) ? color_ink[3:0] : color_paper[3:0]);

	 wire bit4_tick,bit0_tick,bit26_tick;
	 
	 assign bit_tick=bit_num[0];

	 assign bit26_tick=(bit_num==2 || bit_num==6);
	 assign bit4_tick=(bit_num==4);
	 assign bit0_tick=(bit_num==0);
	 
	 //sekwencja do sprawdzenia: 
	 //bit2 - adres do obszaru pixeli (addr_reg). 
	 //bit4 - odczyt z pamiêci do tymczasowego rejestru pixeli (data_reg_tmp)
	 //bit6 - adres do obszaru atrybutów (addr_attr_reg)
	 //bit0 - odczyt z pamiêci do rejestru atrybutów (data_attr_reg), przepianie rejestru tymczasowego pixeli (data_reg_tmp) do rejestru pixeli (data_reg)
	 	 		
	// Atrybuty zaczynaj¹ siê od 5800, a 1800 to offset od 4000 (pocz¹tek 16k bloku pamiêci). 
	assign addr_wire=(bit_num>=1 && bit_num<=4) ? 
		{vga_next_sy_sh[7:6],vga_next_sy_sh[2:0],vga_next_sy_sh[5:3],next_byte_num_sh[4:0]} : (13'h1800+{3'b0,vga_next_sy_sh[7:3],next_byte_num_sh[4:0]});
				
	// zatrzask dla adresu odczytu z pamiêci (pixele 2, atrybuty 6)
	always @(posedge bit26_tick)
	begin
		addr_reg<=addr_wire;
	end

   // zatrzask dla danch z pamiêci do rejestru tymczasowego (pixele)
	always @(posedge bit4_tick)
	begin
		data_reg_tmp<=vga_mem_rec;
	end

	 // odczyt z pamiêci (od 2 do 0 bitu do wystarczaj¹co du¿o czasu, 1 bit to by³o za ma³o)
	 // pixele (z rejestru tymczasowego) i atrybuty z pamiêci
	always @(posedge bit0_tick)
	begin
		data_reg<=data_reg_tmp;
		data_attr_reg<=vga_mem_rec;
	end
	
	always @(posedge vga_vs or posedge rst_pos)
	 begin
		if(rst_pos )
			vs_counter<=0;
		else
			if(vs_counter<60) 
				vs_counter<=vs_counter+1;
			else
				vs_counter<=0; // co ok. 1 sekundê
	 end
	
	 
	 assign o_vga_hs=vga_hs;
	 assign o_vga_vs=vga_vs;
	 
	 vga_control vga_inst (
	 .clk25(clk_vga),
	 .rst(rst_pos),
	 .vsync(vga_vs),
	 .hsync(vga_hs),
	 .x(vga_x),
	 .y(vga_y),
	 .sx(vga_sx),
	 .sy(vga_sy),
	 .sx_counter_n(sx_cnt),
	 .sy_counter_n(sy_cnt),
	 .blank(vga_blank),
	 .blank_n(vga_blank_next),
	 .sx_counter(sx_counter),
	 .sy_counter(sy_counter),
	 .bit_num(bit_num),
	 .bit_num_n(bit_num_n),
	 .byte_num(byte_num),
	 .byte_num_n(byte_num_n),
	 .next_byte_num(next_byte_num),
	 .next_byte_num_n(next_byte_num_n),
	 .next_y(vga_next_y),
	 .next_sy(vga_next_sy)
	 );
	 
	wire swtick,rst_deb,sw_up,sw_down;
	wire dummy_led01;


	//ZX80 mem+ctlr
	 assign memWE=~(wr | mreq); // 1 - enable
	 
	 wire RAMena1,RAMena2,RAMena3,ROMena;
	 
	 assign ROMena=~ADDR[15] & ~ADDR[14] & ~mreq; // 00
	 assign RAMena1=~ADDR[15] & ADDR[14] & ~mreq; // 01 
	 assign RAMena2=ADDR[15] & ~ADDR[14] & ~mreq; // 10 
	 assign RAMena3=ADDR[15] & ADDR[14] & ~mreq; // 11 
	 
	 wire UARTtxd_ena,UARTtxc_ena,UARTrxd_ena,UARTrxc_ena;
	 
	 assign UARTtxd_ena=~iorq & (ADDR[7:0]==8'hF1) & ~wr;
	 assign UARTtxc_ena=~iorq & (ADDR[7:0]==8'hF3) & ~rd;
	 assign UARTrxd_ena=~iorq & (ADDR[7:0]==8'hF5) & ~rd;
	 assign UARTrxc_ena=~iorq & (ADDR[7:0]==8'hF7) & ~rd;

	 wire keyb_en,key_down;
	 wire [7:0] DATAinkeyb;
	 
	 assign keyb_en=(ADDR[7:0]==8'hFE) & (~iorq) & (~rd);
	 wire [6:0] btn_counter;
	 assign LED[6:0]=btn_counter;
		 	 
	 zx_keyb zx_keyb_inst(.addr(ADDR[15:8]),.code(btn_counter),.en(keyb_en),.key_flag(key_down),.dout(DATAinkeyb));
	 
	 
	 // rzeczywista klawiatura
	 wire [7:0] DATAinkeybR;
	 
	 assign DATAinkeybR[7:5]=3'b1;
	 assign DATAinkeybR[4:0]=KB[4:0] & DATAinkeyb[4:0];
	 
	 assign KBA[7:0]=keyb_en ? ADDR[15:8] : 8'b1;
	 
	 //rom16k - testowy kod
	 //rom16kz82_o - oryginalny ROM ZX82
	 
	 rom16zx82_fpga_01 z80rom (
	  .clka(clk_master), // input clka
	  .ena(ROMena), // input ena
	  .addra(ADDR[13:0]), // input [13 : 0] addra
	  .douta(DATAinROM) // output [7 : 0] douta
	);
	
	ram16k z80ram1 (
	  .clka(clk_master), // input clka
	  .ena(RAMena1), // input ena
	  .wea(memWE), // input [0 : 0] wea
	  .addra(ADDR[13:0]), // input [13 : 0] addra
	  .dina(DATAout), // input [7 : 0] dina
	  .douta(DATAinRAM1), // output [7 : 0] douta
	  .clkb(clk_master),
	  .web(1'b0),
	  .addrb(addr_reg),
	  .doutb(vga_mem_rec)
	);
	
	ram16s z80ram2 (
	  .clka(clk_master), // input clka
	  .ena(RAMena2), // input ena
	  .wea(memWE), // input [0 : 0] wea
	  .addra(ADDR[13:0]), // input [13 : 0] addra
	  .dina(DATAout), // input [7 : 0] dina
	  .douta(DATAinRAM2) // output [7 : 0] douta
	);

	ram16s z80ram3 (
	  .clka(clk_master), // input clka
	  .ena(RAMena3), // input ena
	  .wea(memWE), // input [0 : 0] wea
	  .addra(ADDR[13:0]), // input [13 : 0] addra
	  .dina(DATAout), // input [7 : 0] dina
	  .douta(DATAinRAM3) // output [7 : 0] douta
	);	
	
	wire [7:0] UARTin;
	wire [7:0] UARTout,uart_audit;
	wire tx_ready,data_avail;

	uart uart_inst(
		.clk(clk_baud),
		.reset(~rst),
		.rxIN(rxIN),
		.read(UARTrxd_ena),
		.write(UARTtxd_ena),
		.datain(UARTin),
		.uart_avail(data_avail),
		.dataout(UARTout),
		.txOUT(txOUT),
		.tx_ready(tx_ready),
		.audit(uart_audit)
	);
	
	assign UARTin=DATAout;
	
	assign DATAin=UARTtxc_ena ? {7'b0,tx_ready} :
						UARTrxc_ena ? {7'b0,data_avail} :
						UARTrxd_ena ?  UARTout :
						ROMena ? DATAinROM : 
						RAMena1 ? DATAinRAM1 :
						RAMena2 ? DATAinRAM2 :
						RAMena3 ? DATAinRAM3 : 
						keyb_en ? DATAinkeybR : 8'bz;
						
	wire [15:0] ADDRv;
	wire [7:0] DATAv;
	wire memWEv,ADDRv_flag;
	
	assign ADDRv_flag=(ADDR>=16'h4000 & ADDR<=16'h57FF);
	
	assign memWEv=memWE & ADDRv_flag;
	
	assign ADDRv=ADDRv_flag ? ADDR-16'h4000 : 16'bz;

	wire [15:0] ADDRvA;
	wire [7:0] DATAvA;
	wire memWEvA,ADDRvA_flag;
	
	// testowo
	//assign LED[7:4]=DATAv[7:4];	
	//assign LED[3:0]=DATAvA[3:0];
	assign LED[7]=vs_counter[5];
	//assign LED[6:0]=7'b0;
	
	assign ADDRvA_flag=(ADDR>=16'h5800 & ADDR<=16'h5AFF);
	
	assign memWEvA=memWE & ADDRvA_flag;
	
	assign ADDRvA=ADDRvA_flag ? ADDR-16'h5800 : 16'bz;
	
	wire int_tick,int_tick_n;
	
	assign int_tick_n=~int_tick;
	
	ticker int_ticker(.clk(clk_cpu),.reset(rst_pos),.signal(vga_vs),.delay(0),.length(32),.tick(int_tick));
	
		tv80n tv80_cpu(
  // Outputs
  //m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n, A, dout,
  .m1_n(m1),
  .mreq_n(mreq),
  .iorq_n(iorq),
  .rd_n(rd),
  .wr_n(wr),
  .rfsh_n(rfsh),
  .halt_n(halt),
  .busak_n(busak),
  .A(ADDR),
  .dout(DATAout),
  // Inputs
  //reset_n, clk, wait_n, int_n, nmi_n, busrq_n, di
  .reset_n(rst),
  .clk(clk_cpu),
  .wait_n(1'b1),
  .int_n(int_tick_n),
  .busrq_n(1'b1),
  .di(DATAin)
  );
	
	always @ (posedge clk_master or negedge rst)
	begin
		if(~rst)
		begin
			counter<=0;
		end	
		else
		begin
			counter<=counter+1;
		end
	end	
	
	//assign LED[6]=rst;
	//assign LED[5]=sw_up;
	//assign LED[4]=sw_down;

	// przyciski i zegary dla stabilizacji przycisków
	button_counter #(.N(7)) but_counter(.clk(clk_master),.rst_neg(rst),.but_up(sw_up),.but_down(sw_down),.b_counter(btn_counter));		
	
	switch_debounce_clock #(.N(20)) sw_debounce_clk (.swclock(clk_master),.swtickClk(swtick),.swtickLED(dummy_led01));
	
	switch_debounce sw_deb_rst (.swclock(clk_master),.swtick(swtick),.sw(SW1),.dbsw(rst),.dbsw_neg(rst_pos));
	switch_debounce sw_deb_up (.swclock(clk_master),.swtick(swtick),.sw(SW2),.dbsw_neg(sw_up));
	switch_debounce sw_deb_down (.swclock(clk_master),.swtick(swtick),.sw(SW3),.dbsw_neg(sw_down));
	switch_debounce sw_deb_key (.swclock(clk_master),.swtick(swtick),.sw(SW4),.dbsw_neg(key_down));

	
endmodule
