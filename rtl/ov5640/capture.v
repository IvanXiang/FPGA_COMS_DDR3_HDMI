`include "../param.v"
module capture(
    input           clk     ,//像素时钟 摄像头输出的pclk
    input           rst_n   ,

    input           enable  ,//采集使能 配置完成
    input           vsync   ,//摄像头场同步信号
    input           href    ,//摄像头行参考信号
    input   [7:0]   din     ,//摄像头像素字节

    output  [127:0] dout    ,//像素数据
    output          dout_sop,//包文头 一帧图像第一个像素点
    output          dout_eop,//包文尾 一帧图像最后一个像素点
    output          dout_vld //像素数据有效
);

//信号定义

    reg     [11:0]      cnt_h       ;//计一行1280个像素
    wire                add_cnt_h   ;
    wire                end_cnt_h   ;

    reg     [9:0]       cnt_v       ;//计一帧720行
    wire                add_cnt_v   ;
    wire                end_cnt_v   ;
    
    reg     [1:0]       vsync_r     ;//同步打拍
    wire                vsync_nedge ;//下降沿
    reg                 flag        ;//串并转换标志
 
    reg     [127:0]     data        ;
    reg                 data_vld    ;
    reg                 data_sop    ;
    reg                 data_eop    ;

//计数器
    
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt_h <= 0; 
        end
        else if(add_cnt_h) begin
            if(end_cnt_h)
                cnt_h <= 0; 
            else
                cnt_h <= cnt_h+1 ;
       end
    end
    assign add_cnt_h = (flag & href);
    assign end_cnt_h = add_cnt_h  && cnt_h == (`H_AP << 1)-1;
    
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt_v <= 0; 
        end
        else if(add_cnt_v) begin
            if(end_cnt_v)
                cnt_v <= 0; 
            else
                cnt_v <= cnt_v+1 ;
       end
    end
    assign add_cnt_v = end_cnt_h;
    assign end_cnt_v = add_cnt_v  && cnt_v == `V_AP-1 ;

//vsync同步打拍
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            vsync_r <= 2'b00;
        end
        else begin
            vsync_r <= {vsync_r[0],vsync};
        end
    end
    assign vsync_nedge = vsync_r[1] & ~vsync_r[0];

    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            flag <= 1'b0;
        end
        else if(enable & vsync_nedge)begin  //摄像头配置完成且场同步信号拉低之后开始采集有效数据
            flag <= 1'b1;
        end
        else if(end_cnt_v)begin     //一帧数据采集完拉低
            flag <= 1'b0;   
        end
    end

//data

    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            data <= 0;
        end
        
        else if(add_cnt_h)begin
            //data <= {data[119:0],din};
            data <= {din,data[127:8]};//右移 RGB--先输出 g[2:0],b[4:0]，再输出 r[4:0],g[5:3]
        end
        
       /*
        else if(cnt_v < 180)begin 
            data <= {8{16'b11111_000000_00000}};
        end
        else if(cnt_v < 360)begin 
            data <= {8{16'b00000_111111_00000}};
        end
        else if(cnt_v < 540)begin 
            data <= {8{16'b00000_000000_11111}};
        end 
        else begin 
            data <= {8{16'b11111_000000_11111}};
        end 
		  */
    end

//data_sop
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            data_sop <= 1'b0;
            data_eop <= 1'b0;
            data_vld <= 1'b0;
        end
        else begin
            data_sop <= add_cnt_h && cnt_h == 15 && cnt_v == 0;
            data_eop <= end_cnt_v;
            data_vld <= add_cnt_h && cnt_h[3:0] == 4'hf;
        end
    end

    assign dout = data;
    assign dout_sop = data_sop;
    assign dout_eop = data_eop;
    assign dout_vld = data_vld;


endmodule 
