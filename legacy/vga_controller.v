module vga_controller(
    input  wire       clk_25mhz,
    input  wire       reset,
    output reg        hsync,
    output reg        vsync,
    output reg [9:0]  x_pos,
    output reg [9:0]  y_pos,
    output wire       video_on
);

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk_25mhz or posedge reset) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end
        else begin
            if (h_count == 10'd799) begin
                h_count <= 10'd0;
                if (v_count == 10'd524)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end
            else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    always @(*) begin
        hsync = ~((h_count >= 10'd656) && (h_count < 10'd752));
        vsync = ~((v_count >= 10'd490) && (v_count < 10'd492));
    end

    assign video_on = (h_count < 10'd640) && (v_count < 10'd480);

    always @(*) begin
        x_pos = h_count;
        y_pos = v_count;
    end

endmodule
