// Adapted from MiSTer-devel/Arcade-TaitoF2_MiSTer.

interface raizing_ssbus_if();
    logic [63:0] data;
    logic [31:0] addr;
    logic [7:0] select;
    logic write;
    logic read;
    logic query;
    logic [63:0] data_out;
    logic ack;

    function automatic logic access(input integer index);
        return select == index[7:0] && !query && (read || write);
    endfunction

    task automatic setup(
        input integer index,
        input [31:0] count,
        input integer width
    );
        ack <= 1'b0;
        if(select == index[7:0] && query) begin
            data_out <= {index[7:0], 22'd0, width[1:0], count};
            ack <= 1'b1;
        end
    endtask

    task automatic read_response(input integer index, input [63:0] value);
        if(select == index[7:0]) begin
            data_out <= value;
            ack <= 1'b1;
        end
    endtask

    task automatic write_ack(input integer index);
        if(select == index[7:0])
            ack <= 1'b1;
    endtask
endinterface

module raizing_ssbus_mux #(
    parameter COUNT = 4
)(
    input clk,
    input reset,
    raizing_ssbus_if devices[COUNT],
    raizing_ssbus_if stream
);

    integer i;
    wire [COUNT-1:0] device_ack;
    wire [COUNT*64-1:0] device_data;
    reg [63:0] selected_data;
    reg selected_ack;

    genvar gi;
    generate
        for(gi = 0; gi < COUNT; gi = gi + 1) begin : gen_devices
            always @* begin
                devices[gi].data = stream.data;
                devices[gi].addr = stream.addr;
                devices[gi].select = stream.select;
                devices[gi].write = stream.write;
                devices[gi].read = stream.read;
                devices[gi].query = stream.query;
            end

            assign device_ack[gi] = devices[gi].ack;
            assign device_data[gi*64 +: 64] = devices[gi].data_out;
        end
    endgenerate

    always @* begin
        selected_ack = 1'b0;
        selected_data = 64'd0;

        for(i = 0; i < COUNT; i = i + 1) begin
            selected_ack = selected_ack | device_ack[i];
            selected_data = selected_data |
                (device_data[i*64 +: 64] & {64{device_ack[i]}});
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            stream.ack <= 1'b0;
            stream.data_out <= 64'd0;
        end else begin
            stream.ack <= selected_ack;
            stream.data_out <= selected_data;
        end
    end

endmodule

module raizing_ssbus_flat_bridge(
    input clk,
    input reset,
    raizing_ssbus_if ssbus,
    output [63:0] data,
    output [31:0] addr,
    output [7:0] select,
    output write,
    output read,
    output query,
    input [63:0] data_out,
    input ack
);

    assign data = ssbus.data;
    assign addr = ssbus.addr;
    assign select = ssbus.select;
    assign write = ssbus.write;
    assign read = ssbus.read;
    assign query = ssbus.query;

    always @(posedge clk) begin
        if(reset) begin
            ssbus.data_out <= 64'd0;
            ssbus.ack <= 1'b0;
        end else begin
            ssbus.data_out <= data_out & {64{ack}};
            ssbus.ack <= ack;
        end
    end

endmodule
