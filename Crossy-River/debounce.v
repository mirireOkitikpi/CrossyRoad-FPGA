`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// debounce.v — Two-stage synchroniser + saturating counter (Lab 2 method)
////////////////////////////////////////////////////////////////////////////////
module debounce #(parameter COUNTER_WIDTH = 20)(
    input  clk, rst, btn_in,
    output btn_out
);
    reg btn_sync_0, btn_sync_1;
    reg [COUNTER_WIDTH-1:0] counter;
    reg btn_stable;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter    <= {COUNTER_WIDTH{1'b0}};
            btn_stable <= 1'b0;
        end else if (btn_sync_1 != btn_stable) begin
            if (counter == {COUNTER_WIDTH{1'b1}}) begin
                btn_stable <= btn_sync_1;
                counter    <= {COUNTER_WIDTH{1'b0}};
            end else
                counter <= counter + 1'b1;
        end else
            counter <= {COUNTER_WIDTH{1'b0}};
    end

    assign btn_out = btn_stable;
endmodule
