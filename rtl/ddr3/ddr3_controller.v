`include "../param.v"

module ddr3_controller(
    input               clk         ,//50M
    input               clk_in      ,
    input               clk_out     ,
    input               rst_n       ,

    input    [127:0]    din         ,//摄像头写入mem的数据
    input               din_vld     ,
    input               din_sop     ,
    input               din_eop     ,
    input               rd_req      ,//hdmi_driver读取数据的请求
    output   [15:0]     dout        ,//发送到显示器的数据
    output              dout_vld    ,

    output              initial_done,//ddr3初始完成

    //mem
    output   [14: 0]    mem_addr    ,//地址
    output   [ 2: 0]    mem_bank    ,
    output              mem_casn    ,//命令
    output              mem_wen     ,
    output   [ 0: 0]    mem_cs_n    ,
    output              mem_rasn    ,
    output              mem_ck_n    ,//差分时钟
    output              mem_ck_p    ,
    output   [ 0: 0]    mem_cke     ,
    inout    [31: 0]    mem_dq      ,//数据
    output   [ 3: 0]    mem_dqm     ,
    inout    [ 3: 0]    mem_dqs_n   ,
    inout    [ 3: 0]    mem_dqs_p   ,
    output   [ 0: 0]    mem_odt     ,
    output              mem_rest_n  ,
    input               mem_rzq     
);

//信号定义

    wire                afi_clk             ;
    wire                avl_ready           ;
    wire                avl_burstbegin      ;
    wire    [25:0]      avl_addr            ;
    wire                avl_rdata_valid     ;
    wire    [127:0]     avl_rdata           ;
    wire    [127:0]     avl_wdata           ;
    wire                avl_read_req        ;
    wire                avl_write_req       ;
    wire    [8:0]       avl_size            ;
    wire    [15:0]      avl_byteenable      ;
    wire                local_init_done     ; 
    wire                local_cal_success   ; 
    wire                local_cal_fail      ; 
    wire                reset_n             ;
    reg     [1:0]       sys_rst_n           ;

    assign initial_done = rst_n & local_init_done & local_cal_success;

//模块例化

    ddr3_rw_ctrl  u_ctrl(
    /*input               */.clk                (afi_clk            ),//ddr3侧时钟
    /*input               */.clk_in             (clk_in             ),//摄像头数据输入侧时钟
    /*input               */.clk_out            (clk_out            ),//HDMI数据输出侧时钟
    /*input               */.rst_n              (rst_n              ),
    
    //user interface
    /*input               */.rd_req             (rd_req             ),//hdmi_driver读取数据请求
    /*input   [127:0]     */.din                (din                ),//摄像头写入mem的数据
    /*inpput              */.din_sop            (din_sop            ),
    /*input               */.din_eop            (din_eop            ),
    /*input               */.din_vld            (din_vld            ),
    /*output  [15:0]      */.dout               (dout               ),//发送到显示器的数据
    /*output              */.dout_vld           (dout_vld           ),

    //ddr3_interface interface
    /*output              */.avl_ready          (avl_ready          ),//avl.waitrequest_n
	/*input               */.avl_burstbegin     (avl_burstbegin     ),//.beginbursttransfer
	/*input   [25:0]      */.avl_addr           (avl_addr           ),//.address
	/*output              */.avl_rdata_valid    (avl_rdata_valid    ),//.readdatavalid
	/*output  [127:0]     */.avl_rdata          (avl_rdata          ),//.readdata
	/*input   [127:0]     */.avl_wdata          (avl_wdata          ),//.writedata
	/*input   [15:0]      */.avl_be             (avl_byteenable     ),//.byteenable
	/*input               */.avl_read_req       (avl_read_req       ),//.read
	/*input               */.avl_write_req      (avl_write_req      ),//.write
	/*input   [8:0]       */.avl_size           (avl_size           ) //.burstcount
    );

    ddr3_interface u_dddr3_intf(
	/*input  wire         */.pll_ref_clk         (clk               ),//给ip内部PLL的参考时钟
	/*input  wire         */.global_reset_n      (rst_n             ),//global_reset.reset_n
	/*input  wire         */.soft_reset_n        (1'b1              ),//soft_reset.reset_n
	/*output wire         */.afi_clk             (afi_clk           ),//afi_clk.clk
	/*output wire         */.afi_half_clk        (                  ),//afi_half_clk.clk
	/*output wire         */.afi_reset_n         (                  ),//afi_reset.reset_n
	/*output wire         */.afi_reset_export_n  (                  ),//afi_reset_export.
	/*output wire [14:0]  */.mem_a               (mem_addr          ),//memory.mem_a
	/*output wire [2:0]   */.mem_ba              (mem_bank          ),//.mem_ba
	/*output wire [0:0]   */.mem_ck              (mem_ck_p          ),//.mem_ck
	/*output wire [0:0]   */.mem_ck_n            (mem_ck_n          ),//.mem_ck_n
	/*output wire [0:0]   */.mem_cke             (mem_cke           ),//.mem_cke
	/*output wire [0:0]   */.mem_cs_n            (mem_cs_n          ),//.mem_cs_n
	/*output wire [3:0]   */.mem_dm              (mem_dqm           ),//.mem_dm
	/*output wire [0:0]   */.mem_ras_n           (mem_rasn          ),//.mem_ras_n
	/*output wire [0:0]   */.mem_cas_n           (mem_casn          ),//.mem_cas_n
	/*output wire [0:0]   */.mem_we_n            (mem_wen           ),//.mem_we_n
	/*output wire         */.mem_reset_n         (mem_rest_n        ),//.mem_reset_n
	/*inout  wire [31:0]  */.mem_dq              (mem_dq            ),//.mem_dq
	/*inout  wire [3:0]   */.mem_dqs             (mem_dqs_p         ),//.mem_dqs
	/*inout  wire [3:0]   */.mem_dqs_n           (mem_dqs_n         ),//.mem_dqs_n
	/*output wire [0:0]   */.mem_odt             (mem_odt           ),//.mem_odt
	/*output wire         */.avl_ready           (avl_ready         ),//avl.waitrequest_n
	/*input  wire         */.avl_burstbegin      (avl_burstbegin    ),//.beginbursttransfer
	/*input  wire [25:0]  */.avl_addr            (avl_addr          ),//.address
	/*output wire         */.avl_rdata_valid     (avl_rdata_valid   ),//.readdatavalid
	/*output wire [127:0] */.avl_rdata           (avl_rdata         ),//.readdata
	/*input  wire [127:0] */.avl_wdata           (avl_wdata         ),//.writedata
	/*input  wire [15:0]  */.avl_be              (avl_byteenable    ),//.byteenable
	/*input  wire         */.avl_read_req        (avl_read_req      ),//.read
	/*input  wire         */.avl_write_req       (avl_write_req     ),//.write
	/*input  wire [8:0]   */.avl_size            (avl_size          ),//.burstcount
	/*output wire         */.local_init_done     (local_init_done   ),//local_init_done
	/*output wire         */.local_cal_success   (local_cal_success ),//local_cal_success
	/*output wire         */.local_cal_fail      (local_cal_fail    ),//.local_cal_fail
	/*input  wire         */.oct_rzqin           (mem_rzq           ) //oct.rzqin
        
    //PLL未设置sharing模式，所以这些信号未使能
	//output wire         pll_mem_clk,               //pll_sharing.pll_mem_clk
	//output wire         pll_write_clk,             //.pll_write_clk
	//output wire         pll_locked,                //.pll_locked
	//output wire         pll_write_clk_pre_phy_clk, //.pll_write_clk_pre_phy_clk
	//output wire         pll_addr_cmd_clk,          //.pll_addr_cmd_clk
	//output wire         pll_avl_clk,               //.pll_avl_clk
	//output wire         pll_config_clk,            //.pll_config_clk
	//output wire         pll_mem_phy_clk,           //.pll_mem_phy_clk
	//output wire         afi_phy_clk,               //.afi_phy_clk
	//output wire         pll_avl_phy_clk            //.pll_avl_phy_clk
	);

endmodule 
    

