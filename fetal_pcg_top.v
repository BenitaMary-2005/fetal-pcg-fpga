// fetal_pcg_top.v
// Top-level: connects ROMs, peak detector, HR manager, and outputs status
module fetal_pcg_top #(
    parameter ROMA_FILE = "fetal_PCG_p01_GW_36_bin.txt",
    parameter ROMB_FILE = "fetal_PCG_p07_GW_38_bin.txt",
    parameter ROM_DEPTH = 16384,
    parameter ADDR_WIDTH = 14,
    parameter SYS_CLK_FREQ = 50000000,
    parameter SAMPLE_RATE = 333
)(
    input  wire clk,
    input  wire rst,
    input  wire sel,             // 0 = normal, 1 = abnormal
    input  wire [7:0] threshold,
    output wire [7:0] pcg_data,
    output wire beat_pulse,
    output wire [15:0] hr_bpm,
    output wire [1:0] status     // 00 NO_DATA, 01 NORMAL, 10 ABNORMAL
);

    // ---------------- sample tick generator ----------------
    localparam integer TICK_DIV = SYS_CLK_FREQ / SAMPLE_RATE;
    reg [31:0] tick_cntr;
    reg sample_tick;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tick_cntr <= 0;
            sample_tick <= 1'b0;
        end else begin
            if (tick_cntr >= TICK_DIV-1) begin
                sample_tick <= 1'b1;
                tick_cntr <= 0;
            end else begin
                sample_tick <= 1'b0;
                tick_cntr <= tick_cntr + 1;
            end
        end
    end

    // ---------------- address counter ----------------
    reg [ADDR_WIDTH-1:0] addr;
    always @(posedge clk or posedge rst) begin
        if (rst) addr <= 0;
        else if (sample_tick) addr <= (addr == ROM_DEPTH-1) ? 0 : addr + 1;
    end

    // ---------------- instantiate ROMs ----------------
    wire [7:0] romA_data, romB_data;
    pcg_rom #(.DEPTH(ROM_DEPTH), .ADDR_WIDTH(ADDR_WIDTH), .MEMFILE(ROMA_FILE)) romA (.addr(addr), .clk(clk), .data_out(romA_data));
    pcg_rom #(.DEPTH(ROM_DEPTH), .ADDR_WIDTH(ADDR_WIDTH), .MEMFILE(ROMB_FILE)) romB (.addr(addr), .clk(clk), .data_out(romB_data));

    // Select current sample
    reg [7:0] current_sample;
    always @(posedge clk) current_sample <= (sel == 1'b0) ? romA_data : romB_data;
    assign pcg_data = current_sample;

    // ---------------- peak detector ----------------
    peak_detector #(.SAMPLE_RATE(SAMPLE_RATE), .MIN_DIST_MS(300)) pdet (
        .clk(clk),
        .rst(rst),
        .sample_tick(sample_tick),
        .sample(current_sample),
        .threshold(threshold),
        .beat_pulse(beat_pulse)
    );

    // ---------------- HR manager ----------------
    hr_manager #(.SAMPLE_RATE(SAMPLE_RATE), .WINDOW_SEC(10), .MAX_BEATS(64)) hrm (
        .clk(clk),
        .rst(rst),
        .sample_tick(sample_tick),
        .beat_pulse(beat_pulse),
        .hr_bpm(hr_bpm),
        .hr_valid() // unused here
    );

    // ---------------- Status logic ----------------
    wire hr_has_data = (hr_bpm != 16'd0);
    reg [1:0] cond;
    always @(posedge clk or posedge rst) begin
        if (rst) cond <= 2'b00;
        else begin
            if (!hr_has_data) cond <= 2'b00;
            else if ((hr_bpm >= 110) && (hr_bpm <= 160)) cond <= 2'b01;
            else cond <= 2'b10;
        end
    end
    assign status = cond;

endmodule
