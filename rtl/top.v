module top(

    input               clk             ,
    input               rst_n           ,

    //摄像头OV5640接口
    output              cmos_scl        ,//时钟
    inout               cmos_sda        ,//数据
    output              cmos_reset      ,//复位
    output              cmos_pwdn       ,
    output              cmos_xclk       ,
    input               cmos_vsync      ,
    input               cmos_pclk       ,
    input               cmos_href       ,
    input    [7:0]      cmos_din        , 

    //DDR3接口
    output   [14: 0]    ddr3_addr       ,//地址
    output   [ 2: 0]    ddr3_bank       ,
    output              ddr3_casn       ,//命令
    output              ddr3_wen        ,
    output   [ 1: 0]    ddr3_cs_n       ,
    output              ddr3_rasn       ,
    output              ddr3_ck_n       ,//差分时钟
    output              ddr3_ck_p       ,
    output   [ 1: 0]    ddr3_cke        ,
    inout    [31: 0]    ddr3_dq         ,//数据
    output   [ 3: 0]    ddr3_dqm        ,
    inout    [ 3: 0]    ddr3_dqs_n      ,
    inout    [ 3: 0]    ddr3_dqs_p      ,
    output   [ 1: 0]    ddr3_odt        ,
    output              ddr3_rest_n     ,
    input    [1:0]      ddr3_rzq        ,

    //HDMI配置接口  ADV7513接口
    output              hdmi_i2c_scl    ,
    inout               hdmi_i2c_sda    ,
    input               hdmi_tx_int     ,//用于初始化配置
    //HDMI像素数据接口
    output              hdmi_tx_clk     ,//像素时钟
    output   [23:0]     hdmi_tx_rgb     ,//图像数据
    output              hdmi_tx_de      ,//数据有效
    output              hdmi_tx_hsync   ,//行同步信号
    output              hdmi_tx_vsync    //场同步信号
);

//信号定义
    wire            clk_50m         ; 
    wire            clk_cmos        ; 
    wire            clk_hdmi        ; 
    wire            clk_sample      ; 
    wire            locked0         ;
	 wire			locked1 		;
	 
    wire            clk_pclk        ;
    wire            cfg_done        ;
    wire    [127:0] pixel           ; 
    wire            pixel_sop       ;
    wire            pixel_eop       ;
    wire            pixel_vld       ;
    wire            hdmi_req        ;
    wire    [15:0]  rgb_data        ;
    wire            rgb_data_vld    ;
    wire    [15:0]  hdmi_rgb        ;
	 wire			     initial_done    ;
    reg             sys_rst_n       ;
    
    always  @(posedge clk)begin
        sys_rst_n <= initial_done;
    end


//模块例化
    
    pll u_pll(
	/*input  wire  */.refclk    (clk        ),   //  refclk.clk
	/*input  wire  */.rst       (~rst_n     ),      //   reset.reset
	/*output wire  */.outclk_0  (clk_50m    ), // outclk0.clk
	/*output wire  */.outclk_1  (clk_cmos   ), // outclk1.clk
	/*output wire  */.outclk_2  (clk_hdmi   ), // outclk2.clk
	/*output wire  */.locked    (locked0    )    //  locked.export
	);
    
	 sample_pll_0002 u_sample_pll (
	 /*input  wire */.refclk   (clk			),   //  refclk.clk
	 /*input  wire */.rst      (~rst_n		),      //   reset.reset
	 /*output wire */.outclk_0 (clk_sample	), // outclk0.clk
	 /*output wire */.locked   (locked1		)    //  locked.export
	);
	 
    iobuf_iobuf_in_v0i u_iobuf( 
	/*input         */.datain   (cmos_pclk  ),
	/*output        */.dataout  (clk_pclk   )
    );

    cmos_top u_cmos_top(    //摄像头配置
    /*input           */.clk     (clk_50m       ),
    /*input           */.rst_n   (sys_rst_n     ),
    /*output          */.scl     (cmos_scl      ),
    /*inout           */.sda     (cmos_sda      ),
    /*output          */.pwdn    (cmos_pwdn     ),
    /*output          */.reset   (cmos_reset    ),
    /*output          */.cfg_done(cfg_done      )
    );

    capture u_capture(
    /*input           */.clk     (clk_pclk      ),//像素时钟 摄像头输出的pclk
    /*input           */.rst_n   (sys_rst_n     ),
    /*input           */.enable  (cfg_done      ),//采集使能 配置完成
    /*input           */.vsync   (cmos_vsync    ),//摄像头场同步信号
    /*input           */.href    (cmos_href     ),//摄像头行参考信号
    /*input   [7:0]   */.din     (cmos_din      ),//摄像头像素字节
    /*output  [127:0] */.dout    (pixel         ),//像素数据
    /*output          */.dout_sop(pixel_sop     ),//包文头 一帧图像第一个像素点
    /*output          */.dout_eop(pixel_eop     ),//包文尾 一帧图像最后一个像素点
    /*output          */.dout_vld(pixel_vld     ) //像素数据有效
    );

    ddr3_controller u_mem_cntroller(
    /*input               */.clk         (clk_50m       ),//50M
    /*input               */.clk_in      (clk_pclk      ),//84M
    /*input               */.clk_out     (clk_hdmi      ),//75M
    /*input               */.rst_n       (rst_n         ),
    /*input    [127:0]    */.din         (pixel         ),//摄像头写入mem的数据
    /*input               */.din_vld     (pixel_vld     ),
    /*input               */.din_sop     (pixel_sop     ),
    /*input               */.din_eop     (pixel_eop     ),
    /*input               */.rd_req      (hdmi_req      ),//hdmi_driver读取数据的请求
    /*output   [15:0]     */.dout        (rgb_data      ),//发送到显示器的数据
    /*output              */.dout_vld    (rgb_data_vld  ),
    /*output              */.initial_done(initial_done  ),//ddr3初始化完成
    //mem
    /*output   [14: 0]    */.mem_addr    (ddr3_addr     ),//地址
    /*output   [ 2: 0]    */.mem_bank    (ddr3_bank     ),
    /*output              */.mem_casn    (ddr3_casn     ),//命令
    /*output              */.mem_wen     (ddr3_wen      ),
    /*output   [ 0: 0]    */.mem_cs_n    (ddr3_cs_n[0]  ),
    /*output              */.mem_rasn    (ddr3_rasn     ),
    /*output              */.mem_ck_n    (ddr3_ck_n     ),//差分时钟
    /*output              */.mem_ck_p    (ddr3_ck_p     ),
    /*output   [ 0: 0]    */.mem_cke     (ddr3_cke[0]   ),
    /*inout    [31: 0]    */.mem_dq      (ddr3_dq       ),//数据
    /*output   [ 3: 0]    */.mem_dqm     (ddr3_dqm      ),
    /*inout    [ 3: 0]    */.mem_dqs_n   (ddr3_dqs_n    ),
    /*inout    [ 3: 0]    */.mem_dqs_p   (ddr3_dqs_p    ),
    /*output   [ 0: 0]    */.mem_odt     (ddr3_odt[0]   ),
    /*output              */.mem_rest_n  (ddr3_rest_n   ),
    /*input               */.mem_rzq     (ddr3_rzq[0]   )
    );

    adv7513_driver_top u_hdmi(  //ADV7513驱动
    /*input               */.clk             (clk_50m       ),
    /*input               */.clk_hdmi        (clk_hdmi      ),
    /*input               */.rst_n           (sys_rst_n     ),
    //配置接口
    /*output              */.hdmi_i2c_scl    (hdmi_i2c_scl  ),
    /*inout               */.hdmi_i2c_sda    (hdmi_i2c_sda  ),
    /*input               */.hdmi_tx_int     (hdmi_tx_int   ),//用于初始化配置
    /*input     [15:0]    */.rgb_din         (rgb_data      ),
    /*input               */.rgb_din_vld     (rgb_data_vld  ),
    /*output              */.hdmi_req        (hdmi_req      ),
    //像素数据接口                                          
    /*output              */.hdmi_tx_clk     (hdmi_tx_clk   ),//像素时钟
    /*output   [15:0]     */.hdmi_tx_rgb     (hdmi_rgb      ),//图像数据
    /*output              */.hdmi_tx_de      (hdmi_tx_de    ),//数据有效
    /*output              */.hdmi_tx_hsync   (hdmi_tx_hsync ),//行同步信号
    /*output              */.hdmi_tx_vsync   (hdmi_tx_vsync ) //场同步信号
);

    assign cmos_xclk = clk_cmos;
    assign hdmi_tx_rgb = {hdmi_rgb[15:11],3'd0,
                          hdmi_rgb[10:5] ,2'd0,
                          hdmi_rgb[4:0]  ,3'd0};
endmodule 

