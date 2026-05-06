// hr_manager.v
// Maintains beat timestamps in FIFO, computes HR over 10s
module hr_manager #(
    parameter SAMPLE_RATE = 333,
    parameter WINDOW_SEC = 10,
    parameter MAX_BEATS = 64     // capacity of beat FIFO
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_tick,
    input  wire        beat_pulse,
    output reg  [15:0] hr_bpm,
    output reg         hr_valid
);

    reg [31:0] sample_idx;
    reg [31:0] beat_fifo [0:MAX_BEATS-1];
    integer head, tail, count;
    integer j;

    localparam integer WINDOW_SAMPLES = WINDOW_SEC * SAMPLE_RATE;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_idx <= 0;
            head <= 0; tail <= 0; count <= 0;
            hr_bpm <= 0; hr_valid <= 1'b0;
            for (j = 0; j < MAX_BEATS; j = j + 1)
                beat_fifo[j] <= 0;
        end else begin
            // increment sample index
            if (sample_tick)
                sample_idx <= sample_idx + 1;

            // push beat timestamp into FIFO
            if (beat_pulse) begin
                if (count < MAX_BEATS) begin
                    beat_fifo[tail] <= sample_idx;
                    tail <= (tail + 1) % MAX_BEATS;
                    count <= count + 1;
                end else begin
                    head <= (head + 1) % MAX_BEATS;
                    beat_fifo[tail] <= sample_idx;
                    tail <= (tail + 1) % MAX_BEATS;
                end
            end

            // remove old beats (fixed loop)
            for (j = 0; j < MAX_BEATS; j = j + 1) begin
                if (count > 0 && (sample_idx - beat_fifo[head] >= WINDOW_SAMPLES)) begin
                    head <= (head + 1) % MAX_BEATS;
                    count <= count - 1;
                end
            end

            // compute HR
            hr_bpm  <= count * (60 / WINDOW_SEC);
            hr_valid <= (count > 0);
        end
    end

endmodule
