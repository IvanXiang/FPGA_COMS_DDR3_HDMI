`include"../param.v"
module ddr3_rw_ctrl (
    input               clk                ,//ddr3侧时钟
    input               clk_in             ,//数据输入侧时钟
    input               clk_out            ,//数据输出侧时钟
    input               rst_n              ,
    
    //user interface
    input               rd_req             ,//HDMI接口输入的读数据请求
    input   [127:0]     din                ,//摄像头数据
    input               din_vld            ,
    input               din_sop            ,
    input               din_eop            ,
    output  [15:0]      dout               ,//输出给HDMI接口的图像数据
    output              dout_vld           ,

    //ddr3_interface interface
    input               avl_ready          ,//avl.waitrequest_n
	output              avl_burstbegin     ,//.beginbursttransfer
	output  [25:0]      avl_addr           ,//.address
	input               avl_rdata_valid    ,//.readdatavalid
	input   [127:0]     avl_rdata          ,//.readdata
	output  [127:0]     avl_wdata          ,//.writedata
	output  [15:0]      avl_be             ,//.byteenable
	output              avl_read_req       ,//.read
	output              avl_write_req      ,//.write
	output  [8:0]       avl_size            //.burstcount
);

//参数定义
    localparam  IDLE  = 4'b0001,
                WRITE = 4'b0010,
                READ  = 4'b0100,
                DONE  = 4'b1000;
    
//信号定义
    reg     [3:0]       state_c     ;
    reg     [3:0]       state_n     ;

    reg     [8:0]       cnt         ;
    wire                add_cnt     ;
    wire                end_cnt     ;
    
    reg     [2:0]       wr_bank     ;//写bank
    reg     [2:0]       rd_bank     ;//读bank

    reg     [22:0]      wr_addr     ;//写地址   15行 + （10-2）列
    wire                add_wr_addr ;
    wire                end_wr_addr ;
    reg     [22:0]      rd_addr     ;//读地址
    wire                add_rd_addr ;
    wire                end_rd_addr ;

    reg                 wr_flag     ;
    reg                 rd_flag     ;
    reg                 flag_sel    ;
    reg                 prior_flag  ;

    reg                 change_bank ;//切换bank 
    reg                 wr_finish   ;//一帧数据写完
    reg     [1:0]       wr_finish_r ;//同步到写侧
    reg                 wr_data_flag;//wrfifo写数据的标志

    reg     [15:0]      rd_data     ;
    reg                 rd_data_vld ;
    
    reg                 avl_write   ;//写请求
    reg                 avl_read    ;//读请求
    reg                 burst_write ;//突发写
    reg                 burst_read  ;//突发读

    wire                idle2write  ;  
    wire                idle2read   ;
    wire                write2done  ;
    wire                read2done   ;
    
    wire                wfifo_rdreq ;//写缓存区
	wire                wfifo_wrreq ;
    wire    [129:0]     wfifo_wrdata;
	wire    [129:0]     wfifo_q     ;
	wire                wfifo_empty ;
	wire    [8:0]       wfifo_usedw ;
	wire                wfifo_full  ;

	wire                rfifo_rdreq ;//读缓存区
    wire                rfifo_wrreq ;
    wire    [127:0]     rfifo_wrdata;
	wire    [15:0]      rfifo_q     ;
	wire                rfifo_empty ;
	wire    [8:0]       rfifo_usedw ;
	wire                rfifo_full  ;

//状态机
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin 
            state_c <= IDLE;
        end
        else begin
            state_c <= state_n;
        end
    end

    always  @(*)begin
        case(state_c)
            IDLE  :begin 
                if(idle2write)
                    state_n = WRITE;
                else if(idle2read)
                    state_n = READ;
                else 
                    state_n = state_c;
            end 
            WRITE :begin 
                if(write2done)
                    state_n = DONE;
                else 
                    state_n = state_c;
            end     
            READ  :begin 
                if(read2done)
                    state_n = DONE;
                else 
                    state_n = state_c;
            end 
            DONE  :state_n = IDLE;
            default:state_n = IDLE;
        endcase  
    end

    assign idle2write = state_c == IDLE  && (~prior_flag && wfifo_usedw >= `USER_BL);
    assign idle2read  = state_c == IDLE  && (prior_flag && rd_flag);
    assign write2done = state_c == WRITE && (end_cnt);
    assign read2done  = state_c == READ  && (end_cnt);

//计数器
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt <= 0;
        end
        else if(add_cnt)begin
            if(end_cnt)
                cnt <= 0;
            else
                cnt <= cnt + 1;
        end
    end
    assign add_cnt = (state_c == WRITE | state_c == READ) && avl_ready; 
    assign end_cnt = add_cnt && cnt == `USER_BL-1;   

/************************读写优先级仲裁*****************************/
//rd_flag     ;//读请求标志
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            rd_flag <= 0;
        end 
        else if(rfifo_usedw <= `RD_LT)begin   
            rd_flag <= 1'b1;
        end 
        else if(rfifo_usedw > `RD_UT)begin 
            rd_flag <= 1'b0;
        end 
    end

//wr_flag     ;//写请求标志
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            wr_flag <= 0;
        end 
        else if(wfifo_usedw >= `USER_BL)begin 
            wr_flag <= 1'b1;
        end 
        else begin 
            wr_flag <= 1'b0;
        end 
    end

//flag_sel    ;//标记上一次操作
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            flag_sel <= 0;
        end 
        else if(read2done)begin 
            flag_sel <= 1;
        end 
        else if(write2done)begin 
            flag_sel <= 0;
        end 
    end

//prior_flag  ;//优先级标志 0：写优先级高   1：读优先级高     仲裁读、写的优先级
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            prior_flag <= 0;
        end 
        else if(wr_flag && (flag_sel || (~flag_sel && ~rd_flag)))begin   //突发写优先级高
            prior_flag <= 1'b0;
        end 
        else if(rd_flag && (~flag_sel || (flag_sel && ~wr_flag)))begin   //突发读优先级高
            prior_flag <= 1'b1;
        end 
    end

/******************************************************************/    

/********************      地址设计    ****************************/    

//wr_bank  rd_bank
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            wr_bank <= 3'b000;
            rd_bank <= 3'b111;
        end
        else if(change_bank)begin
            wr_bank <= ~wr_bank;
            rd_bank <= ~rd_bank;
        end
    end

// wr_addr   rd_addr
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            wr_addr <= 0; 
        end
        else if(add_wr_addr) begin
            if(end_wr_addr)
                wr_addr <= 0; 
            else
			    wr_addr <= wr_addr + (`USER_BL << 4);
        end
    end
    assign add_wr_addr = write2done;
    assign end_wr_addr = add_wr_addr && wr_addr == (`BURST_MAX << 1)- (`USER_BL << 4);
    
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            rd_addr <= 0; 
        end
        else if(add_rd_addr) begin
            if(end_rd_addr)
                rd_addr <= 0; 
            else
				rd_addr <= rd_addr + (`USER_BL << 4);
       end
    end
    assign add_rd_addr = read2done;
    assign end_rd_addr = add_rd_addr && rd_addr == (`BURST_MAX << 1)- (`USER_BL << 4);

//wr_finish     一帧数据全部写到SDRAM
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            wr_finish <= 1'b0;
        end
        else if(~wr_finish & wfifo_q[129])begin  //写完  从wrfifo读出eop
            wr_finish <= 1'b1;
        end
        else if(wr_finish && end_rd_addr)begin  //读完
            wr_finish <= 1'b0;
        end
    end

//change_bank ;//切换bank 
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            change_bank <= 1'b0;
        end
        else begin
            change_bank <= wr_finish && end_rd_addr;
        end
    end
/****************************************************************/

/*********************** wrfifo 写数据   ************************/
//控制像素数据帧 写入 或 丢帧

    always  @(posedge clk_in or negedge rst_n)begin
        if(~rst_n)begin
            wr_data_flag <= 1'b0;
        end 
        else if(~wr_data_flag & ~wr_finish_r[1] & din_sop)begin//可以向wrfifo写数据
            wr_data_flag <= 1'b1;
        end
        else if(wr_data_flag & din_eop)begin//不可以向wrfifo写入数据
            wr_data_flag <= 1'b0;
        end
    end

    always  @(posedge clk_in or negedge rst_n)begin //把wr_finish从wrfifo的读侧同步到写侧
        if(~rst_n)begin
            wr_finish_r <= 0;
        end
        else begin
            wr_finish_r <= {wr_finish_r[0],wr_finish};
        end
    end

/****************************************************************/
    
    //burst_write
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            burst_write <= 1'b0;
        end
        else begin
            burst_write <= idle2write;
        end
    end

    //burst_read
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            burst_read <= 1'b0;
        end
        else begin
            burst_read <= idle2read;
        end
    end

    //avl_read
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            avl_read <= 1'b0;
        end
        else if(idle2read)begin
            avl_read <= 1'b1;
        end
        else if(avl_read & avl_ready)begin 
            avl_read <= 1'b0;
        end 
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            avl_write <= 1'b0;
        end
        else if(idle2write)begin
            avl_write <= 1'b1;
        end
        else if(write2done)begin
            avl_write <= 1'b0;
        end
    end

    
    //rd_data rd_data_vld 输出给hdmi接口
    always  @(posedge clk_out or negedge rst_n)begin
        if(~rst_n)begin
            rd_data <= 0;
            rd_data_vld <= 1'b0;
        end
        else begin
            rd_data <= rfifo_q;
            rd_data_vld <= rfifo_rdreq;
        end
    end
    
//FIFO例化

    wrfifo u_wr_fifo(
	/*input                 */.aclr     (~rst_n         ),
	/*input   [129:0]       */.data     (wfifo_wrdata   ),
	/*input                 */.rdclk    (clk            ),
    /*input           	    */.rdreq    (wfifo_rdreq    ),
    /*input           	    */.wrclk    (clk_in         ),
    /*input           	    */.wrreq    (wfifo_wrreq    ),
    /*output  [129:0] 	    */.q        (wfifo_q        ),
	/*output                */.rdempty  (wfifo_empty    ),
    /*output  [8:0]   	    */.rdusedw  (wfifo_usedw    ),
	/*output                */.wrfull   (wfifo_full     )
    );

    assign wfifo_wrdata = {din_eop,din_sop,din};
    assign wfifo_wrreq  = ~wfifo_full & din_vld & ((~wr_finish_r[1] & din_sop) | wr_data_flag);
    assign wfifo_rdreq  = state_c == WRITE && avl_ready;

    rdfifo u_rd_fifo(
	/*input               */.aclr   (~rst_n         ),
	/*input   [127:0]     */.data   (rfifo_wrdata   ),
	/*input               */.rdclk  (clk_out        ),
	/*input               */.rdreq  (rfifo_rdreq    ),
	/*input               */.wrclk  (clk            ),
	/*input               */.wrreq  (rfifo_wrreq    ),
	/*output  [15:0]      */.q      (rfifo_q        ),
	/*output              */.rdempty(rfifo_empty    ),
	/*output              */.wrfull (rfifo_full     ),
	/*output  [8:0]       */.wrusedw(rfifo_usedw    )    
    );

    assign rfifo_wrdata = avl_rdata;
    assign rfifo_rdreq = ~rfifo_empty & rd_req;
    assign rfifo_wrreq = avl_rdata_valid & ~rfifo_full;
    
//输出
    assign dout = rd_data;
    assign dout_vld = rd_data_vld;
    assign avl_burstbegin = burst_write | burst_read;

    assign avl_addr = {26{state_c == WRITE}} & {wr_addr[22:8],wr_bank[2:0],wr_addr[7:0]}    //给写地址
                     |{26{state_c == READ}} & {rd_addr[22:8],rd_bank[2:0],rd_addr[7:0]};   //给读地址

    assign avl_wdata = wfifo_q[127:0];
    assign avl_be = 16'hffff;
    assign avl_read_req = avl_read;
    assign avl_write_req = avl_write;
    assign avl_size = `USER_BL;

endmodule 

