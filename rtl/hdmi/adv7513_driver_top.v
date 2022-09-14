module adv7513_driver_top(
    input               clk             ,
    input               clk_hdmi        ,
    input               rst_n           ,

     //配置接口
    output              hdmi_i2c_scl    ,
    inout               hdmi_i2c_sda    ,
    input               hdmi_tx_int     ,//用于初始化配置
    
    //像素数据接口
    input     [15:0]    rgb_din         ,
    input               rgb_din_vld     ,
    output              hdmi_req        ,
    output              hdmi_tx_clk     ,//像素时钟
    output    [15:0]    hdmi_tx_rgb     ,//图像数据
    output              hdmi_tx_de      ,//数据有效
    output              hdmi_tx_hsync   ,//行同步信号
    output              hdmi_tx_vsync    //场同步信号

);

//信号定义
    wire                trans_req   ; 
    wire    [3:0]       trans_cmd   ; 
    wire    [7:0]       trans_data  ;
    wire                trans_done  ;
    wire                config_done ;
	wire				i2c_scl		;
    wire                sda_in      ;
    wire                sda_out     ;
    wire                sda_out_en  ;
             

//模块例化
    adv7513_config u_adv7513_cfg(
    /*input               */.clk         (clk           ),
    /*input               */.rst_n       (rst_n         ),
    /*input               */.hdmi_int    (hdmi_tx_int   ),  
    //i2c_master
    /*output              */.req         (trans_req     ),
    /*output      [3:0]   */.cmd         (trans_cmd     ),
    /*output      [7:0]   */.dout        (trans_data    ),
    /*input               */.done        (trans_done    ),
    /*output              */.config_done (config_done   )
    );

    i2c_master u_hdmi_i2c(
    /*input               */.clk         (clk       ),
    /*input               */.rst_n       (rst_n     ),
    /*input               */.req         (trans_req ),
    /*input       [3:0]   */.cmd         (trans_cmd ),
    /*input       [7:0]   */.din         (trans_data),
    /*output      [7:0]   */.dout        (          ),
    /*output              */.done        (trans_done),
    /*output              */.slave_ack   (          ),
    /*output              */.i2c_scl     (i2c_scl   ),
    /*input               */.i2c_sda_i   (sda_in    ),
    /*output              */.i2c_sda_o   (sda_out   ),
    /*output              */.i2c_sda_oe  (sda_out_en)   
    );

    adv7513_hdmi u_vga_hdmi(
    /*input               */.clk         (clk_hdmi      ),
    /*input               */.rst_n       (rst_n         ),
    /*input     [15:0]    */.rgb_din     (rgb_din       ),
    /*input               */.rgb_din_vld (rgb_din_vld   ),
    /*input               */.rdy         (config_done   ),
    /*output              */.hdmi_req    (hdmi_req      ),//请求数据
    //adv7513图像数据接口
    /*output              */.hdmi_hsync  (hdmi_tx_hsync ),//行同步
    /*output              */.hdmi_vsync  (hdmi_tx_vsync ),//场同步
    /*output              */.hdmi_de     (hdmi_tx_de    ),//数据有效
    /*output              */.hdmi_clk    (hdmi_tx_clk   ),//像素时钟
    /*output    [15:0]    */.hdmi_rgb    (hdmi_tx_rgb   ) //图像数据
);

    assign hdmi_i2c_scl = i2c_scl;
    assign hdmi_i2c_sda = sda_out_en?sda_out:1'bz;
    assign sda_in       = hdmi_i2c_sda;

endmodule 

