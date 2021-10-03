`timescale 1ns / 1ps

module switch_debounce_clock
	#(parameter N=19)(
	input swclock,
	output swtickClk, // 1 cykl zegara wej�ciowego
	output swtickLED // po�owa ca�ego cyklu
    );
	 
	reg[N-1:0] q_reg;
	 
	always @(posedge swclock)
	begin
		q_reg<=q_reg+1;
	end
	
	assign swtickClk=(q_reg==0) ? 1'b1 : 1'b0;
	assign swtickLED=q_reg[N-1];

endmodule
