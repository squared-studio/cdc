module cdc_fifo_tb;

    // Marking the start and end of Simulation
    initial $display("\033[7;36m TEST STARTED \033[0m");
    final   $display("\033[7;36m TEST ENDED \033[0m");

    ////////////////////////////////////////////////////////////////////////////
    // LOCAL PARAMETERS
    ////////////////////////////////////////////////////////////////////////////

    // AS DUT
    localparam int ELEM_WIDTH = 4;
    localparam int FIFO_SIZE  = 4;

    ////////////////////////////////////////////////////////////////////////////
    // SIGNALS
    ////////////////////////////////////////////////////////////////////////////

    // AS DUT
    logic                  arst_ni;
    logic [ELEM_WIDTH-1:0] elem_in_i;
    logic                  elem_in_clk_i;
    logic                  elem_in_valid_i;
    logic                  elem_in_ready_o;
    logic [ELEM_WIDTH-1:0] elem_out_o;
    logic                  elem_out_clk_i;
    logic                  elem_out_valid_o;
    logic                  elem_out_ready_i;

    ////////////////////////////////////////////////////////////////////////////
    // DUT
    ////////////////////////////////////////////////////////////////////////////

    cdc_fifo #(
        .ELEM_WIDTH(ELEM_WIDTH),
        .FIFO_SIZE (FIFO_SIZE )
    ) u_cdc_fifo (
        .arst_ni,
        .elem_in_i,
        .elem_in_clk_i,
        .elem_in_valid_i,
        .elem_in_ready_o,
        .elem_out_o,
        .elem_out_clk_i,
        .elem_out_valid_o,
        .elem_out_ready_i
    );

    ////////////////////////////////////////////////////////////////////////////
    // VARIABLESS
    ////////////////////////////////////////////////////////////////////////////

    // pass-fail count
    int pass;
    int fail;

    // Driver mailboxs
    mailbox #(logic [ELEM_WIDTH-1:0]) elem_in_dvr_mbx  = new(1);
    mailbox #(logic [ELEM_WIDTH-1:0]) elem_out_dvr_mbx = new(1);

    // Monitor mailboxs
    mailbox #(logic [ELEM_WIDTH-1:0]) elem_in_mon_mbx  = new();
    mailbox #(logic [ELEM_WIDTH-1:0]) elem_out_mon_mbx = new();

    // time period variables
    int tp1;
    int tp2;

    ////////////////////////////////////////////////////////////////////////////
    // METHODS
    ////////////////////////////////////////////////////////////////////////////

    // initialise IOs and apply reset
    task static apply_reset();
        #10ns;
        arst_ni          <= '0;
        elem_in_i        <= '0;
        elem_in_clk_i    <= '0;
        elem_in_valid_i  <= '0;
        elem_out_clk_i   <= '0;
        elem_out_ready_i <= '0;
        #10ns;
        arst_ni          <= '1;
        #10ns;
    endtask

    // Start toggling clocks
    task static start_clock();
        fork
            forever begin
                elem_in_clk_i <= '1;  #(tp1 * 500ps);
                elem_in_clk_i <= '0;  #(tp1 * 500ps);
            end
            forever begin
                elem_out_clk_i <= '1; #(tp2 * 500ps);
                elem_out_clk_i <= '0; #(tp2 * 500ps);
            end
        join_none
    endtask

    // Initiate all the verification process
    task static start_driver_monitor_scoreboard();
        fork

            forever begin // in driver
                logic [ELEM_WIDTH-1:0] data;
                elem_in_dvr_mbx.get(data);
                elem_in_i       <= data;
                elem_in_valid_i <= '1;
                do @ (posedge elem_in_clk_i);
                while (elem_in_ready_o !== 1);
                elem_in_valid_i <= '0;
            end

            forever begin // out driver
                logic [ELEM_WIDTH-1:0] data;
                elem_out_dvr_mbx.get(data);
                elem_out_ready_i <= '1;
                do @ (posedge elem_out_clk_i);
                while (elem_out_valid_o !== 1);
                elem_out_ready_i <= '0;
            end

            forever begin // in monitor
                //logic [ELEM_WIDTH-1:0] data;
                @ (posedge elem_in_clk_i);
                if ((elem_in_valid_i === '1) && (elem_in_ready_o === '1)) begin
                    elem_in_mon_mbx.put(elem_in_i);
                end
            end

            forever begin // out monitor
                //logic [ELEM_WIDTH-1:0] data;
                @ (posedge elem_out_clk_i);
                if ((elem_out_valid_o === '1) && (elem_out_ready_i === '1)) begin
                    elem_out_mon_mbx.put(elem_out_o);
                end
            end

            forever begin // scoreboard
                logic [ELEM_WIDTH-1:0] data_in;
                logic [ELEM_WIDTH-1:0] data_out;
                elem_in_mon_mbx.get(data_in);
                elem_out_mon_mbx.get(data_out);
                $display("I:0x%0h O:0x%0h", data_in, data_out);
                if (data_in === data_out) pass++;
                else                      fail++;
            end

        join_none
    endtask

    // wait until no valid is observed for `x` clock on both domains
    task static wait_cooldown (int x = 10);
        static int cnt = 0;
        while (cnt < x) begin
            cnt++;
            fork
                begin
                    @ (posedge elem_in_clk_i);
                    if (elem_in_valid_i === '1) cnt = 0;
                end
                begin
                    @ (posedge elem_out_clk_i)
                    if (elem_out_valid_o === '1) cnt = 0;
                end
            join
        end
    endtask

    ////////////////////////////////////////////////////////////////////////////
    // PROCEDURALS
    ////////////////////////////////////////////////////////////////////////////

    initial begin

        automatic int tc;

        // Dump VCD file for manual checking
        $dumpfile("dump.vcd");
        $dumpvars;

        // Take input for Number of tests to run
        if (!$value$plusargs ("TC=%d", tc))
            $fatal(1, "\033[7;31m TC not found \033[0m");

        // Take input for timeperiod 1 duration
        if (!$value$plusargs ("T1=%d", tp1))
            $fatal(1, "\033[7;31m T1 not found \033[0m");

        // Take input for timeperiod 2 duration
        if (!$value$plusargs ("T2=%d", tp2))
            $fatal(1, "\033[7;31m T2 not found \033[0m");

        // display both variables
        $display("T1=%0dns T2=%0dns", tp1, tp2);

        // Apply asynchronous global reset
        apply_reset();

        // Start all the verification components
        start_driver_monitor_scoreboard();

        // Start clock 
        start_clock();

        // generate 100 random data inputs
        fork
            repeat (tc) elem_in_dvr_mbx.put ($urandom);
            repeat (tc) elem_out_dvr_mbx.put($urandom);
        join

        // Wait for the end of all valid data
        wait_cooldown();

        // print results
        $display("%0d/%0d PASSED", pass, pass+fail);

        // End simulation
        $finish;

    end

endmodule

