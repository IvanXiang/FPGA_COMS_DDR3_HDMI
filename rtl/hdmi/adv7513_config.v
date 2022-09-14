module adv7513_config (
    input               clk         ,
    input               rst_n       ,
    input               hdmi_int    ,  
    //i2c_master
    output              req         ,
    output      [3:0]   cmd         ,
    output      [7:0]   dout        ,
    input               done        ,
    output              config_done 
);

//参数定义
    
    localparam  WAIT   = 4'b0001 ,//上电等待20ms
                IDLE   = 4'b0010 ,
                WREQ   = 4'b0100 ,//发写请求
                WRITE  = 4'b1000 ;//等待一个字节写完
    parameter   DELAY  = 1000;//上电延时20ms开始配置

//信号定义
    reg     [3:0]       state_c     ;
    reg     [3:0]       state_n     ;
    
    reg     [19:0]      cnt0        ;
    wire                add_cnt0    ;
    wire                end_cnt0    ;
    reg     [1:0]       cnt1        ;
    wire                add_cnt1    ;
    wire                end_cnt1    ;
    reg                 config_flag ;//1:表示在配置摄像头 0：表示配置完成
    reg     [15:0]      lut_data    ;

    reg                 tran_req    ; 
    reg     [3:0]       tran_cmd    ; 
    reg     [7:0]       tran_dout   ; 

    wire                wait2idle   ; 
    wire                idle2wreq   ; 
    wire                write2wreq  ; 
    wire                write2idle  ; 

//状态机

    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin        
            state_c <= WAIT;
        end
        else begin
            state_c <= state_n;
        end
    end

    always  @(*)begin
        case(state_c)
            WAIT :begin 
                if(wait2idle)
                   state_n = IDLE;
                else 
                   state_n = state_c; 
            end 
            IDLE :begin 
                if(idle2wreq)
                    state_n = WREQ; 
                else 
                    state_n = state_c; 
            end  
            WREQ  :state_n = WRITE;
            WRITE :begin 
                if(write2wreq)
                    state_n = WREQ; 
                else if(write2idle)
                    state_n = IDLE;
                else 
                    state_n = state_c; 
            end 
            default:state_n = IDLE; 
        endcase 
    end

    assign wait2idle  = state_c == WAIT  && end_cnt0; 
    assign idle2wreq  = state_c == IDLE  && config_flag; 
    assign write2wreq = state_c == WRITE && done && ~end_cnt1; 
    assign write2idle = state_c == WRITE && end_cnt1; 

//计数器
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt0 <= 0;
        end
        else if(add_cnt0)begin
            if(end_cnt0)
                cnt0 <= 0;
            else
                cnt0 <= cnt0 + 1;
        end
    end
    
    assign add_cnt0 = state_c == WAIT || state_c == WRITE && end_cnt1;
    assign end_cnt0 = add_cnt0 && cnt0 == ((state_c == WAIT)?(DELAY-1):(31-1));

    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            cnt1 <= 0;
        end
        else if(add_cnt1)begin
            if(end_cnt1)
                cnt1 <= 0;
            else
                cnt1 <= cnt1 + 1;
        end
    end
    
    assign add_cnt1 = state_c == WRITE && done;
    assign end_cnt1 = add_cnt1 && cnt1 == 3-1;

//config_flag
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            config_flag <= 1'b1;
        end
        else if(config_flag & end_cnt0 & state_c != WAIT)begin    //所有寄存器配置完，flag拉低
            config_flag <= 1'b0;
        end
        else if(~config_flag & ~hdmi_int)begin 
            config_flag <= 1'b1;
        end 
    end

//输出寄存器

    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            tran_req <= 0;
            tran_cmd <= 0;
            tran_dout <= 0;
        end
        else if(state_c == WREQ)begin
            case(cnt1)
                0:begin 
                    tran_req <= 1;
                    tran_cmd <= {`CMD_START | `CMD_WRITE};
                    tran_dout <= `ADV7513_ID;
                end 
                1:begin 
                    tran_req <= 1;
                    tran_cmd <= `CMD_WRITE;
                    tran_dout <= lut_data[15:8];
                end
                2:begin 
                    tran_req <= 1;
                    tran_cmd <= {`CMD_STOP | `CMD_WRITE};
                    tran_dout <= lut_data[7:0];
                end
                default:tran_req <= 0;
            endcase 
        end
		else begin
		    tran_req  <= 0;
            tran_cmd  <= 0;
            tran_dout <= 0;
		end 
    end

//输出

    assign config_done = ~config_flag;
    assign req = tran_req;
    assign cmd = tran_cmd;
    assign dout = tran_dout; 

//lut_data   
    always@(*)begin
	    case(cnt0)			  
    	     0	: lut_data = 16'h98_03;  //Must be set to 0x03 for proper operation
	        1	: lut_data = 16'h01_00;  //Set 'N' value at 6144
	        2	: lut_data = 16'h02_18;  //Set 'N' value at 6144
	        3	: lut_data = 16'h03_00;  //Set 'N' value at 6144
	        4	: lut_data = 16'h14_70;  // Set Ch count in the channel status to 8.
	        5	: lut_data = 16'h15_20;  //Input 444 (RGB or YCrCb) with Separate Syncs, 48kHz fs
	        6	: lut_data = 16'h16_30;  //Output format 444, 24-bit input
	        7	: lut_data = 16'h18_46;  //Disable CSC
	        8	: lut_data = 16'h40_80;  //General control packet enable
	        9	: lut_data = 16'h41_10;  //Power down control
	        10	: lut_data = 16'h49_A8;  //Set dither mode - 12-to-10 bit
	        11	: lut_data = 16'h55_10;  //Set RGB in AVI infoframe
	        12	: lut_data = 16'h56_08;  //Set active format aspect
	        13	: lut_data = 16'h96_F6;  //Set interrup
	        14	: lut_data = 16'h73_07;  //Info frame Ch count to 8
	        15	: lut_data = 16'h76_1f;  //Set speaker allocation for 8 channels
	        16	: lut_data = 16'h98_03;  //Must be set to 0x03 for proper operation
	        17	: lut_data = 16'h99_02;  //Must be set to Default Value
	        18	: lut_data = 16'h9a_e0;  //Must be set to 0b1110000
	        19	: lut_data = 16'h9c_30;  //PLL filter R1 value
	        20	: lut_data = 16'h9d_61;  //Set clock divide
	        21	: lut_data = 16'ha2_a4;  //Must be set to 0xA4 for proper operation
	        22	: lut_data = 16'ha3_a4;  //Must be set to 0xA4 for proper operation
	        23	: lut_data = 16'ha5_04;  //Must be set to Default Value
	        24	: lut_data = 16'hab_40;  //Must be set to Default Value
	        25	: lut_data = 16'haf_16;  //Select HDMI mode
	        26	: lut_data = 16'hba_60;  //No clock delay
	        27	: lut_data = 16'hd1_ff;  //Must be set to Default Value
	        28	: lut_data = 16'hde_10;  //Must be set to Default for proper operation
	        29	: lut_data = 16'he4_60;  //Must be set to Default Value
	        30	: lut_data = 16'hfa_7d;  //Nbr of times to look for good phase
            default:lut_data = 16'h98_03;
        endcase 
    end 

endmodule 

