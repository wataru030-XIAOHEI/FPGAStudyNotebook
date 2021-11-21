`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/11/21 20:14:08
// Design Name: 
// Module Name: uartTop
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: uart数据发生器，每隔10ms发送一个数据，每次数据为前一个数据值+1；
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uartTop(//only for test 
    clk,
    rstn,
    uart_tx
    );
    input clk;
    input rstn;
    output uart_tx;

    wire [2:0] Baudrate_Set ;  
    reg send_go;
    wire[7:0] data ; 
    reg [7:0] data_reg;
    wire Tx_Done ;
    assign Baudrate_Set = 3'd4;


    uart_top u_uart_top(
        .clk          ( clk          ),
        .rstn         ( rstn         ),
        .Baudrate_Set ( Baudrate_Set ),
        .send_go      ( send_go      ),
        .data         ( data         ),
        .data_tx      ( uart_tx      ),
        .Tx_Done      ( Tx_Done      )
    );

    reg [25:0] cnt ;
    always @(posedge clk or negedge rstn) begin
        if(!rstn)begin
            cnt <= 26'd0;
        end
        else begin
            if (cnt == 26'd49_999_999) begin //每隔1s发一次
                cnt <= 26'd0;
            end
            else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
//send_en  信号变动
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            send_go <= 1'b0;
        end
        else begin
            if (cnt == 19'd1) begin //为1 是为了节约时间
                send_go <= 1'b1;
            end
            else begin
                send_go <= 1'b0;
            end
        end
    end


    //数据发生
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data_reg <= 8'd0;
        end
        else begin
            if (Tx_Done) begin
                data_reg <= data_reg + 1'b1;
            end           
        end
    end
    assign data = data_reg ;
endmodule
