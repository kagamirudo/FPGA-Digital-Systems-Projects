--------------------------------------------------------------------------------
-- tb_user_logic.vhd
--
-- ECEC 661 - Quiz 1 (real) - RAM-based Shift Register IP
--
-- Self-checking testbench for user_logic.vhd, which wraps the Vivado
-- IP-Catalog "RAM-based Shift Register" (c_shift_ram v12.0) configured as:
--
--     Width = 4, Depth = 6, CE enabled, SCLR enabled
--
-- Coverage:
--   * post-SCLR init           -> z = 0
--   * 6-cycle latency          -> driving x = 1..6 makes z stream 1,2,3,4,5,6
--                                 with exactly six rising-edge delay
--   * CE = 0 freezes z         -> no update of z while CE is low
--   * CE restored              -> x applied during CE=0 still needs 6 edges
--                                 of CE=1 to emerge on z
--   * SCLR clears pipeline     -> z = 0 on the very next rising edge
--
-- This TB only runs inside Vivado xsim after c_shift_ram_0 has been
-- generated (source scripts/setup.tcl or use the GUI walkthrough).
-- VHDL-2008 is required for std.textio.LF in the final banner.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity tb_user_logic is
end entity tb_user_logic;

architecture sim of tb_user_logic is

    constant CK_PERIOD : time := 10 ns;

    signal ck   : std_logic := '0';
    signal ce   : std_logic := '0';
    signal sclr : std_logic := '0';
    signal x    : std_logic_vector(3 downto 0) := (others => '0');
    signal z    : std_logic_vector(3 downto 0);

    signal errors : integer := 0;
    signal checks : integer := 0;

    procedure check_z (
        signal   zsig     : in    std_logic_vector(3 downto 0);
        constant expected : in    integer;
        constant tag      : in    string;
        signal   err_cnt  : inout integer;
        signal   chk_cnt  : inout integer
    ) is
        variable got : integer;
    begin
        got     := to_integer(unsigned(zsig));
        chk_cnt <= chk_cnt + 1;
        if got = expected then
            report "[PASS] " & tag &
                   "  z=" & integer'image(got) severity note;
        else
            report "[FAIL] " & tag &
                   "  got z=" & integer'image(got) &
                   "  expected=" & integer'image(expected) severity error;
            err_cnt <= err_cnt + 1;
        end if;
    end procedure check_z;

begin

    ----------------------------------------------------------------------------
    -- Clock
    ----------------------------------------------------------------------------
    p_ck : process
    begin
        ck <= '0'; wait for CK_PERIOD / 2;
        ck <= '1'; wait for CK_PERIOD / 2;
    end process p_ck;

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    dut : entity work.user_logic
        port map (
            x    => x,
            ck   => ck,
            ce   => ce,
            sclr => sclr,
            z    => z
        );

    ----------------------------------------------------------------------------
    -- Stimulus / self-check
    ----------------------------------------------------------------------------
    p_stim : process
    begin
        --------------------------------------------------------------------
        -- 1. Initial clear: hold SCLR high for a couple of edges so the
        --    whole delay line is 0, then release.
        --------------------------------------------------------------------
        ce   <= '1';
        sclr <= '1';
        x    <= (others => '0');
        wait until rising_edge(ck);
        wait until rising_edge(ck);
        sclr <= '0';
        wait for 1 ns;
        check_z(z, 0, "post-SCLR init z=0", errors, checks);

        --------------------------------------------------------------------
        -- 2. Six-cycle latency: drive x = 1,2,3,4,5,6.  After six rising
        --    edges the first value (1) reaches z, then z streams
        --    2, 3, 4, 5, 6 on the following five edges.
        --
        --    Pipeline [stage1..stage6=Q] after edge N:
        --      E0 (post-SCLR): [0,0,0,0,0,0]  z=0
        --      E1 (x=1):       [1,0,0,0,0,0]  z=0
        --      E2 (x=2):       [2,1,0,0,0,0]  z=0
        --      ...
        --      E6 (x=6):       [6,5,4,3,2,1]  z=1   <- first emerges
        --      E7 (x=7):       [7,6,5,4,3,2]  z=2
        --      E8 (x=8):       [8,7,6,5,4,3]  z=3
        --      E9 (x=0):       [0,8,7,6,5,4]  z=4
        --      E10 (x=0):      [0,0,8,7,6,5]  z=5
        --      E11 (x=0):      [0,0,0,8,7,6]  z=6
        --------------------------------------------------------------------
        for i in 1 to 6 loop
            x <= std_logic_vector(to_unsigned(i, 4));
            wait until rising_edge(ck);
        end loop;
        wait for 1 ns;
        check_z(z, 1, "latency step 1 (z=x[-6]=1)", errors, checks);

        x <= std_logic_vector(to_unsigned(7, 4));
        wait until rising_edge(ck); wait for 1 ns;
        check_z(z, 2, "latency step 2 (z=x[-6]=2)", errors, checks);

        x <= std_logic_vector(to_unsigned(8, 4));
        wait until rising_edge(ck); wait for 1 ns;
        check_z(z, 3, "latency step 3 (z=x[-6]=3)", errors, checks);

        x <= (others => '0');        -- stop driving new data; queue drains
        wait until rising_edge(ck); wait for 1 ns;
        check_z(z, 4, "latency step 4 (z=x[-6]=4)", errors, checks);
        wait until rising_edge(ck); wait for 1 ns;
        check_z(z, 5, "latency step 5 (z=x[-6]=5)", errors, checks);
        wait until rising_edge(ck); wait for 1 ns;
        check_z(z, 6, "latency step 6 (z=x[-6]=6)", errors, checks);

        --------------------------------------------------------------------
        -- 3. CE = 0 must freeze z at its current value (z = 6 here) while
        --    clocks continue to tick.
        --------------------------------------------------------------------
        ce <= '0';
        x  <= std_logic_vector(to_unsigned(9, 4));  -- ignored while CE=0
        for i in 1 to 3 loop
            wait until rising_edge(ck);
        end loop;
        wait for 1 ns;
        check_z(z, 6, "CE=0 holds z=6 for 3 edges", errors, checks);

        --------------------------------------------------------------------
        -- 4. CE restored: x = 9 was driven throughout, but no edge sampled
        --    it.  It still needs six CE=1 edges to propagate to z.
        --------------------------------------------------------------------
        ce <= '1';
        for i in 1 to 5 loop
            wait until rising_edge(ck);
        end loop;
        x <= (others => '0');
        wait until rising_edge(ck);
        wait for 1 ns;
        check_z(z, 9, "CE restored, 9 reaches z after 6 edges",
                errors, checks);

        --------------------------------------------------------------------
        -- 5. Mid-stream SCLR: fill the pipeline with 0xF, then assert SCLR
        --    for one edge.  The entire delay line must snap to 0.
        --------------------------------------------------------------------
        for i in 1 to 6 loop
            x <= std_logic_vector(to_unsigned(15, 4));   -- 0xF
            wait until rising_edge(ck);
        end loop;
        wait for 1 ns;
        check_z(z, 15, "pre-SCLR: pipeline full of 0xF", errors, checks);

        sclr <= '1';
        x    <= (others => '0');
        wait until rising_edge(ck);
        wait for 1 ns;
        check_z(z, 0, "SCLR clears z to 0 in one edge", errors, checks);
        sclr <= '0';

        --------------------------------------------------------------------
        -- Final report
        --------------------------------------------------------------------
        wait for 5 * CK_PERIOD;

        report LF &
               "+--------------------------------------------------+" & LF &
               "|          tb_user_logic - test summary            |" & LF &
               "+--------------------------------------------------+" & LF &
               "   checks executed : " & integer'image(checks)         & LF &
               "   errors          : " & integer'image(errors)         & LF &
               "+--------------------------------------------------+"
            severity note;

        if errors = 0 then
            report LF &
                   "####################################################" & LF &
                   "##                                                ##" & LF &
                   "##        TESTBENCH  PASSED  -  all cases ok      ##" & LF &
                   "##                                                ##" & LF &
                   "####################################################"
                severity note;
        else
            report LF &
                   "####################################################" & LF &
                   "##                                                ##" & LF &
                   "##   TESTBENCH  FAILED  -  " & integer'image(errors) &
                       " error(s) detected    ##" & LF &
                   "##                                                ##" & LF &
                   "####################################################"
                severity failure;
        end if;

        wait;   -- park forever; no $stop cursor jump in Vivado source view
    end process p_stim;

end architecture sim;
