`include "../param.v"
module  adv7513_hdmi (
    input                   clk         ,
    input                   rst_n       ,
    input                   rdy         ,
    input     [15:0]        rgb_din     ,
    input                   rgb_din_vld ,
    output                  hdmi_req    ,
    //adv7513图像数据接口
    output                  hdmi_hsync  ,//行同步
    output                  hdmi_vsync  ,//场同步
    output                  hdmi_de     ,//数据有效
    output                  hdmi_clk    ,//像素时钟
    output      [15:0]      hdmi_rgb     //图像数据
);

//信号定义
    
    reg     [10:0]      cnt_h       ;
    wire                add_cnt_h   ;
    wire                end_cnt_h   ;
    reg     [9:0]       cnt_v       ;
    wire                add_cnt_v   ;
    wire                end_cnt_v   ;
    reg                 add_flag    ;

    reg                 h_vld       ;
    reg                 v_vld       ;
    reg                 hsync       ;
    reg                 vsync       ;
    reg                 rd_req      ;//读图像数据的请求

    wire    [15:0]      fifo_wrdata ; 
    wire                fifo_rdreq  ; 
    wire                fifo_wrreq  ; 
    wire                fifo_empty  ; 
    wire                fifo_full   ; 
    wire    [15:0]      fifo_qout   ; 
    wire    [4:0]       fifo_usedw  ; 

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
    assign add_cnt_h = (add_flag);
    assign end_cnt_h = add_cnt_h && cnt_h == `H_TP-1 ;
    
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
    assign add_cnt_v = (end_cnt_h);
    assign end_cnt_v = add_cnt_v  && cnt_v == `V_TP-1 ;
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            add_flag <= 1'b0;
        end
        else if(rdy)begin
            add_flag <= 1'b1;
        end
    end

//h_vld 
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            h_vld <= 1'b0;
        end
        else if(cnt_h == `H_START-1)begin
            h_vld <= 1'b1;
        end
        else if(cnt_h == `H_END-1)begin 
            h_vld <= 1'b0;
        end 
    end

//v_vld
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            v_vld <= 1'b0;
        end
        else if(end_cnt_h && cnt_v == `V_START - 1)begin
            v_vld <= 1'b1;
        end
        else if(end_cnt_h && cnt_v == `V_END - 1)begin
            v_vld <= 1'b0;
        end
    end

//hsync
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            hsync <= 0;
        end
        else if(add_cnt_h && cnt_h == `H_SW-1)begin
            hsync <= 1'b1;
        end
        else if(add_cnt_h && cnt_h == `H_TP-1)begin 
            hsync <= 1'b0;
        end     
    end

//vsync
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            vsync <= 1'b0;
        end
        else if(add_cnt_v && cnt_v == `V_SW-1)begin
            vsync <= 1'b1;
        end
        else if(add_cnt_v && cnt_v == `V_TP-1)begin
            vsync <= 1'b0;
        end
    end

//rd_req    读图像数据请求
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            rd_req <= 1'b0;
        end
        else if(fifo_usedw <= 8)begin
            rd_req <= 1'b1;
        end
        else if(fifo_usedw >= 28)begin
            rd_req <= 1'b0;
        end
    end

//FIFO例化
    hdmi_buffer u_buffer(
	/*input	            */.aclr    (~rst_n      ),
	/*input	            */.clock   (clk         ),
	/*input     [15:0]  */.data    (fifo_wrdata ),
	/*input	            */.rdreq   (fifo_rdreq  ),
	/*input	            */.wrreq   (fifo_wrreq  ),
	/*output        	*/.empty   (fifo_empty  ),
	/*output        	*/.full    (fifo_full   ),
	/*output    [15:0]	*/.q       (fifo_qout   ),
	/*output    [4:0] 	*/.usedw   (fifo_usedw  )
    );
    
    assign fifo_wrdata = rgb_din;
    assign fifo_wrreq  = rgb_din_vld & ~fifo_full;
    assign fifo_rdreq  = v_vld & h_vld & ~fifo_empty;

//输出  
    assign hdmi_req   = rd_req;
    assign hdmi_hsync = hsync;
    assign hdmi_vsync = vsync;
    assign hdmi_de    = h_vld & v_vld;
    assign hdmi_clk   = ~clk;
    assign hdmi_rgb   = (h_vld & v_vld) ? fifo_qout : 0;


endmodule 

