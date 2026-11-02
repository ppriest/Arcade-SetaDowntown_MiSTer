module downtown_aim_tb;
 reg clk=0; always #5 clk=~clk;
 reg reset=1,paused=0,enabled=1,autofire=0;
 reg [15:0] right0=0,right1=0;
 reg [2:0] offset=0,actual0=0,actual1=0;
 reg [1:0] speed=0,deadzone=0,manual_left=0,manual_right=0,strobe=0;
 wire [3:0] code0,code1; wire fire0,fire1;
 downtown_aim_controls #(.CLOCK_HZ(1000)) dut(
 .clk(clk),.reset(reset),.paused(paused),.enabled(enabled),.screen_to_game(offset),
 .right0(right0),.right1(right1),.speed(speed),.deadzone(deadzone),.autofire(autofire),
 .manual_left(manual_left),.manual_right(manual_right),.actual_strobe(strobe),
 .actual0(actual0),.actual1(actual1),.rotary0(code0),.rotary1(code1),.fire0(fire0),.fire1(fire1));
 reg [3:0] previous0=0,previous1=0;
 integer game_cycle=0;
 // Independent game model: each adjacent rotary contact changes the aim by
 // one octant; acknowledge it on the following clock like a completed write.
 always @(negedge clk) begin
  game_cycle=game_cycle+1;
  strobe=game_cycle%8==0 ? 2'b11 : 2'b00;
  if(reset)begin actual0=0;actual1=0;previous0=0;previous1=0;strobe=3;end
  else begin
   if(code0!=previous0)begin
    if(code0==(previous0==11?0:previous0+1))actual0=actual0+3'd1;
    else if(code0==(previous0==0?11:previous0-1))actual0=actual0-3'd1;
    else $fatal(1,"nonadjacent P1 contact");
    previous0=code0;strobe[0]=1;
   end
   if(code1!=previous1)begin
    if(code1==(previous1==11?0:previous1+1))actual1=actual1+3'd1;
    else if(code1==(previous1==0?11:previous1-1))actual1=actual1-3'd1;
    else $fatal(1,"nonadjacent P2 contact");
    previous1=code1;strobe[1]=1;
   end
  end
 end
 task clocks(input integer n);repeat(n)@(posedge clk);endtask
 reg [15:0] sample[0:7];integer rot,d,expected,n,k;integer elapsed[0:2];reg [3:0] held;
 initial begin
 sample[0]=16'h9c00;sample[1]=16'h9c64;sample[2]=16'h0064;sample[3]=16'h6464;
 sample[4]=16'h6400;sample[5]=16'h649c;sample[6]=16'h009c;sample[7]=16'h9c9c;
 clocks(20);#1;reset=0;
 for(rot=0;rot<4;rot=rot+1)begin
  offset=(16-rot*2-2)%8;
  for(d=0;d<8;d=d+1)begin
   right0=sample[d];right1=sample[d];expected=(d+16-rot*2-2)%8;
   clocks(30);n=0;
   while((actual0!=expected || actual1!=expected) && n<1500)begin clocks(1);n=n+1;end
   if(n==1500)$fatal(1,"direction convergence rot=%0d d=%0d",rot,d);
   if(fire0 || fire1)$fatal(1,"autofire default must be off");
  end
 end
 right0=0;right1=0;clocks(30);autofire=1;clocks(5);
 if(fire0 || fire1)$fatal(1,"neutral autofire");
 for(k=0;k<4;k=k+1)begin
  right0=0;right1=0;deadzone=k;clocks(30);
  right0=16'h0019;right1=16'h0019;clocks(30);
  if(fire0!==(k==1) || fire1!==(k==1))$fatal(1,"deadzone selection %0d",k);
 end
 deadzone=0;right0=sample[2];right1=sample[2];clocks(100);
 if(!fire0 || !fire1)$fatal(1,"active autofire");
 paused=1;clocks(3);held=code0;clocks(80);
 if(fire0 || fire1 || held!=code0)$fatal(1,"pause safety");
 paused=0;enabled=0;clocks(10);held=code0;clocks(100);
 if(fire0 || fire1 || held!=code0)$fatal(1,"non-DownTown gating");
 enabled=1;autofire=0;
 for(k=0;k<3;k=k+1)begin
  reset=1;right0=0;right1=0;speed=k;offset=0;clocks(20);#1;reset=0;clocks(15);
  right0=sample[4];right1=sample[4];n=0;
  while((actual0!=4 || actual1!=4) && n<1500)begin clocks(1);n=n+1;end
  if(n==1500)$fatal(1,"speed convergence");elapsed[k]=n;
 end
 if(!(elapsed[1]>elapsed[0] && elapsed[0]>elapsed[2]))$fatal(1,"speed pacing");
 right0=0;right1=0;clocks(30);held=code0;manual_right=1;clocks(1);#1;manual_right=0;clocks(8);
 if(code0!=(held==11?0:held+1))$fatal(1,"manual rotary preservation");
 $display("PASS 4 rotations x 8 directions x both players, adjacent rotary feedback, deadzones, autofire off/on, pause, game gating, speeds %0d/%0d/%0d, manual rotary",elapsed[0],elapsed[1],elapsed[2]);$finish;
 end
endmodule
