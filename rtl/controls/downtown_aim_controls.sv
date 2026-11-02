// SPDX-License-Identifier: GPL-3.0-or-later
// DownTown interprets its 12-position switch as relative steps. Use completed
// game angle writes as feedback rather than treating the switch as absolute.
module downtown_aim_controls #(parameter integer CLOCK_HZ=96000000)(
    input wire clk, reset, paused, enabled,
    input wire [2:0] screen_to_game,
    input wire [15:0] right0, right1,
    input wire [1:0] speed, deadzone,
    input wire autofire,
    input wire [1:0] manual_left, manual_right, actual_strobe,
    input wire [2:0] actual0, actual1,
    output wire [3:0] rotary0, rotary1,
    output wire fire0, fire1
);
    localparam integer MS_DIV=CLOCK_HZ/1000;
    localparam integer MS_W=MS_DIV<2 ? 1 : $clog2(MS_DIV);
    reg [MS_W-1:0] ms_count=0;
    wire tick_ms=ms_count==MS_DIV-1;
    always @(posedge clk) begin
        if(reset || tick_ms) ms_count<=0;
        else ms_count<=ms_count+1'b1;
    end
    wire [5:0] threshold=deadzone==0 ? 6'd32 : deadzone==1 ? 6'd13 : deadzone==2 ? 6'd38 : 6'd51;
    wire [3:0] active, update;
    wire [11:0] direction;
    snk_aim_quant4 quant (
        .clk(clk), .reset(reset), .ana({16'd0,right1,16'd0,right0}),
        .thr({6'd32,threshold,6'd32,threshold}), .inv_y(4'd0),
        .defl(active), .dir(direction), .upd(update)
    );
    wire [2:0] target0=direction[2:0]+screen_to_game;
    wire [2:0] target1=direction[8:6]+screen_to_game;
    wire [7:0] code0, code1;
    assign rotary0=code0[3:0];
    assign rotary1=code1[3:0];
    rotary_target_servo #(.ANGLE_STATES(8),.CODE_STATES(12),.CODE_POSITIVE_IS_CW(1)) p1 (
        .clk(clk),.reset(reset),.paused(paused),.enable(enabled),.tick_ms(tick_ms),
        .stick_active(active[0]),.target_update(update[0]),.target_angle({5'd0,target0}),
        .speed(speed),.actual_strobe(actual_strobe[0]),.actual_angle({5'd0,actual0}),
        .manual_cw(manual_right[0]),.manual_ccw(manual_left[0]),.code(code0),
        .target(),.observed(),.aiming(),.pending()
    );
    rotary_target_servo #(.ANGLE_STATES(8),.CODE_STATES(12),.CODE_POSITIVE_IS_CW(1)) p2 (
        .clk(clk),.reset(reset),.paused(paused),.enable(enabled),.tick_ms(tick_ms),
        .stick_active(active[2]),.target_update(update[2]),.target_angle({5'd0,target1}),
        .speed(speed),.actual_strobe(actual_strobe[1]),.actual_angle({5'd0,actual1}),
        .manual_cw(manual_right[1]),.manual_ccw(manual_left[1]),.code(code1),
        .target(),.observed(),.aiming(),.pending()
    );
    aim_autofire af0(.clk(clk),.reset(reset),.paused(paused),.tick_ms(tick_ms),
        .enable(enabled && autofire),.stick_active(active[0]),.fire(fire0));
    aim_autofire af1(.clk(clk),.reset(reset),.paused(paused),.tick_ms(tick_ms),
        .enable(enabled && autofire),.stick_active(active[2]),.fire(fire1));
endmodule
