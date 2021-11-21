`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/11/20 20:11:52
// Design Name: 
// Module Name: uart_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: UART,并转串(8BIT -->1BIT),以1位的低电平标志串行传输开始，传输完毕之后，以1位高电平标志传输结束,低位先传
//                      设计过程中存在各种问题
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_top(
    input clk,
    input rstn,
    input [2:0] Baudrate_Set,//波特率设置，有8种波特率
    input send_go,//发送使能信号,脉冲信号，前端模块准备送出数据，会产生一个类似Done信号的脉冲，以便下一个模块（也就是这个模块）可以知道有信号来了，准备接收
    input [7:0] data,
    output data_tx,
    output Tx_Done //发送完成信号
    );
    //---parameter
    parameter SendStartValue = 1'b0;
    parameter SendOverValue = 1'b1;
    
    //------reg/wires
    reg[17:0] div_cnt;//分频得到基本时钟 
        //Baudrate_Set = 0 ---> baudrate = 9600
        //Baudrate_Set = 1 ---> baudrate = 19200
        //Baudrate_Set = 2 ---> baudrate = 38400
        //Baudrate_Set = 3---> baudrate = 57600
        //Baudrate_Set = 4 ---> baudrate = 115200
        //.....
    reg [17:0] bps_DR;
    reg [3:0] bps_cnt;
    wire bps_clk;
    reg send_en;//发送使能，与send_go有关系，接收到send_go脉冲后，一直持续拉高到数据传输结束
        //tx_Data_Reg
    reg data_tx_reg;
    reg Tx_Done_Reg;
    reg [7:0] data_reg;//送入数据寄存器，只暂存了send_go高电平时候的数据，其他时候无论外来数据如何变化，都不理会

    //----------------------
    //--------------dataInReg-------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data_reg <= 8'd0;
        end
        else begin
            if (send_go) begin//send_go为高电平时，拿取外部数据
                data_reg <= data ;
            end
            else begin
                data_reg <= data_reg;
            end
        end
    end
    //--------------------
    //baudrate_set 
    //bps_DR ： 波特率计数器
    //bps_DR = 1_000_000_000 / baudrate / 20 
    always @(*) begin
        case(Baudrate_Set)
        3'd0:bps_DR =  1_000_000_000 / 9600 / 20 ;
        3'd1:bps_DR =  1_000_000_000 / 19200 / 20 ; 
        3'd2:bps_DR =  1_000_000_000 / 38400 / 20 ;
        3'd3:bps_DR =  1_000_000_000 / 57600 / 20 ;
        3'd4:bps_DR =  1_000_000_000 / 115200 / 20 ;
        default : bps_DR = 1_000_000_000 / 9600 / 20 ;
        endcase
    end



    //-----------------------
    always @(posedge clk or negedge rstn) begin
        if(!rstn)begin
            div_cnt <= 18'd0;
        end
        else begin
            if(send_en)begin
                if (div_cnt == bps_DR - 1'b1) begin
                        div_cnt <= 18'd0 ;
                end
                else begin
                    div_cnt <= div_cnt + 1'b 1 ; 
                end
            end
            else begin
                div_cnt <= 18'd0;
            end
        end
    end
    //-------bps_cnt--------------------
    assign bps_clk = (div_cnt == 1);
    always @(posedge clk or negedge rstn) begin
        if(!rstn)begin
            bps_cnt <= 4'd0;
        end
        else begin
            if (send_en) begin
                if (bps_clk) begin
                    if (bps_cnt == 4'd11) begin
                            bps_cnt <= 4'd0;                       
                    end
                    else begin
                        bps_cnt <= bps_cnt + 1'b1;
                        //Tx_Done_Reg <= 1'b0;
                    end
                end 
            end
            else begin
                bps_cnt <= 4'd0;
            end
        end
    end


//-----------------------Send block------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data_tx_reg <= 1'b0;
        end
        else begin
            case (bps_cnt)
                //4'd0:Tx_Done_Reg <= 1'b0;//拉低发送完成信号，合并到下一个always block里面了
                4'd1:data_tx_reg <=SendStartValue;//接收到发送使能信号“1”后，进行发送使能，发送标志位为0
                4'd2:data_tx_reg <= data_reg[0];
                4'd3:data_tx_reg <= data_reg[1];
                4'd4:data_tx_reg <= data_reg[2];
                4'd5:data_tx_reg <= data_reg[3];
                4'd6:data_tx_reg <= data_reg[4];
                4'd7:data_tx_reg <= data_reg[5];
                4'd8:data_tx_reg <= data_reg[6];
                4'd9:data_tx_reg <= data_reg[7];
                4'd10:data_tx_reg <= SendOverValue;
                4'd11:begin 
                    data_tx_reg <= SendOverValue;
                    //Tx_Done_Reg <= 1'b1; 已经移动到下一个always_block里面
                end//send over
                default :data_tx_reg <= 1'b1;
                    
            endcase
        end
    end
    //-----------------send_go to send_en--------//
   always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            send_en <= 1'b0;
        end
        else begin
            if (send_go) begin //为1 是为了节约时间
                send_en <= 1'b1;
            end
            else begin
                if (Tx_Done) begin
                    send_en <= 1'b0;
                end
            end
        end
    end

    //-----------done change 
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            Tx_Done_Reg <= 1'b0;
        end
        else begin
            if ((bps_clk == 1'b1) && (bps_cnt == 4'd10)) begin //让done可以提前拉高，之后拉低。不会影响后续数据的进入，done一旦拉高超过1个周期，后续数据可能会发生错误，因此如此修改
                Tx_Done_Reg <= 1'b1;
            end
            else begin
                Tx_Done_Reg <= 1'b0;
            end
        end
    end
    assign data_tx = data_tx_reg;
    assign Tx_Done = Tx_Done_Reg;



endmodule
