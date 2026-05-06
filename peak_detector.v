// peak_detector.v
// Detect rising edge crossings above threshold with refractory period
module peak_detector #(
    parameter SAMPLE_RATE = 333,    // samples per second
    parameter MIN_DIST_MS = 300     // minimum distance between peaks in ms
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_tick, // 1-cycle pulse at sample rate
    input  wire [7:0]  sample,      // current 8-bit sample
    input  wire [7:0]  threshold,   // threshold (0..255)
    output reg         beat_pulse   // one-cycle pulse when beat detected
);

    reg [7:0] prev_sample;
    localparam integer MIN_DIST_SAMPLES = (MIN_DIST_MS * SAMPLE_RATE) / 1000;
    integer refrac_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prev_sample <= 8'd0;
            beat_pulse <= 1'b0;
            refrac_cnt <= 0;
        end else begin
            beat_pulse <= 1'b0;
            if (sample_tick) begin
                if (refrac_cnt > 0)
                    refrac_cnt <= refrac_cnt - 1;

                if ((prev_sample <= threshold) && (sample > threshold) && (refrac_cnt == 0)) begin
                    beat_pulse <= 1'b1;
                    refrac_cnt <= MIN_DIST_SAMPLES;
                end
                prev_sample <= sample;
            end
        end
    end

endmodule
