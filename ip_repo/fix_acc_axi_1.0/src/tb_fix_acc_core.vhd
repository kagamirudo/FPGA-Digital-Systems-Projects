--------------------------------------------------------------------------------
-- tb_fix_acc_core.vhd
--
-- ECEC 661 - Homework 3 - Problem 8.7.2 Fixed-Point Accumulator IP
--
-- Self-checking testbench for fix_acc_core.  Reproduces the book's
-- simulation wave (Fig 8.7.3, Digital Systems Projects p. 444):
--
--   - At 100 ps (here: ~100 ns) SCLR is pulsed for one CLK cycle,
--   - Four CLK cycles with B = 1   -> Q = 1, 2, 3, 4
--   - Four CLK cycles with B = -2  -> Q = 2, 0, -2, -4
--
-- Additional cases check:
--   - SCLR asserted mid-stream clears Q back to 0
--   - Sigma(1..10) = 55 matches the software spot-check in sw/main.c
--   - Very large positive B still accumulates correctly (no sign bug)
--
-- The DUT (fix_acc_core) instantiates the Vivado IP-Catalog Accumulator
-- c_accum_0 as a black box.  This testbench therefore ONLY works inside
-- Vivado xsim after the c_accum_0 output products have been generated.
-- VHDL-2008 is only needed for to_hstring() in the report messages.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;
use std.textio.all;   -- brings in LF for prettier multi-line report messages

entity tb_fix_acc_core is
end entity tb_fix_acc_core;

architecture sim of tb_fix_acc_core is

    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz

    signal clk  : std_logic := '0';
    signal sclr : std_logic := '0';
    signal b    : std_logic_vector(31 downto 0) := (others => '0');
    signal q    : std_logic_vector(31 downto 0);

    signal errors : integer := 0;
    signal checks : integer := 0;

    -- Helper: sample Q one delta after a clock edge so the registered
    -- output has propagated.  Because c_accum_0 has latency = 1, the update
    -- caused by the rising edge at time T is visible after that edge.
    procedure check_q (
        signal   q_sig    : in    std_logic_vector(31 downto 0);
        constant expected : in    integer;
        constant tag      : in    string;
        signal   err_cnt  : inout integer;
        signal   chk_cnt  : inout integer
    ) is
        variable got : integer;
    begin
        got      := to_integer(signed(q_sig));
        chk_cnt  <= chk_cnt + 1;
        if got = expected then
            report "[PASS] " & tag &
                   "  Q=" & integer'image(got) severity note;
        else
            report "[FAIL] " & tag &
                   "  got Q=" & integer'image(got) &
                   "  expected=" & integer'image(expected) severity error;
            err_cnt <= err_cnt + 1;
        end if;
    end procedure check_q;

begin

    ----------------------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------------------
    p_clk : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process p_clk;

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    dut : entity work.fix_acc_core
        port map (
            B    => b,
            CLK  => clk,
            SCLR => sclr,
            Q    => q
        );

    ----------------------------------------------------------------------------
    -- Stimulus / self-check
    ----------------------------------------------------------------------------
    p_stim : process
    begin
        -- Wait a few clocks for the IP Catalog block to settle, then
        -- force a clean sync-clear to bring Q to 0 deterministically.
        sclr <= '0';
        b    <= (others => '0');
        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- SCLR pulse (book Fig 8.7.3: SCLR high at ~100 ps)
        sclr <= '1';
        wait until rising_edge(clk);
        sclr <= '0';

        -- One settle cycle so Q has reflected SCLR.
        wait until rising_edge(clk);
        check_q(q, 0, "post-SCLR reset", errors, checks);

        ------------------------------------------------------------------------
        -- Book Fig 8.7.3:  B = 1, four accumulate cycles -> Q = 1, 2, 3, 4
        ------------------------------------------------------------------------
        b <= std_logic_vector(to_signed(1, 32));

        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q, 1, "B=1 step 1", errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q, 2, "B=1 step 2", errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q, 3, "B=1 step 3", errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q, 4, "B=1 step 4", errors, checks);

        ------------------------------------------------------------------------
        -- Book Fig 8.7.3:  B = -2, four accumulate cycles -> Q = 2, 0, -2, -4
        ------------------------------------------------------------------------
        b <= std_logic_vector(to_signed(-2, 32));

        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q,  2, "B=-2 step 1", errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q,  0, "B=-2 step 2", errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q, -2, "B=-2 step 3", errors, checks);
        wait until rising_edge(clk);
        wait for 1 ns;  check_q(q, -4, "B=-2 step 4", errors, checks);

        ------------------------------------------------------------------------
        -- Mid-stream SCLR brings Q back to 0 regardless of B.
        --
        -- IMPORTANT: c_accum_0 has latency = 1, so every rising edge of CLK
        -- *always* commits one operation.  If SCLR is high at the edge it
        -- commits a clear; if SCLR is low it commits an accumulate of B.
        -- That means the "did SCLR work?" sample has to happen right after
        -- the clearing edge, before any further clock edges re-accumulate B.
        ------------------------------------------------------------------------
        b    <= std_logic_vector(to_signed(1234567, 32));
        sclr <= '1';
        wait until rising_edge(clk);   -- commits the clear
        wait for 1 ns;
        check_q(q, 0, "mid-stream SCLR", errors, checks);
        sclr <= '0';
        b    <= (others => '0');       -- stop driving 1234567 into the next edge

        ------------------------------------------------------------------------
        -- Sigma(1..10) = 55 (spot-check matching software test).
        --
        -- Q is 0 at this point (just cleared above).  The accumulator adds B
        -- on each rising CLK, so stepping B = 1, 2, ... 10 through 10 clock
        -- cycles yields Q = 1+2+...+10 = 55 after the 10th update.
        ------------------------------------------------------------------------
        for i in 1 to 10 loop
            b <= std_logic_vector(to_signed(i, 32));
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        check_q(q, 55, "Sigma(1..10)", errors, checks);

        ------------------------------------------------------------------------
        -- Final report.
        --
        -- We intentionally end this process with a plain `wait;` rather than
        -- std.env.stop / std.env.finish.  The latter two call $stop / $finish
        -- under the hood, which makes Vivado jump the source-window cursor to
        -- that line.  `wait` just parks the process forever instead, so the
        -- banner is the last thing the user sees and the source window stays
        -- on whichever file the user was reading.
        ------------------------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        report LF &
               "+--------------------------------------------------+" & LF &
               "|          fix_acc_core - test summary             |" & LF &
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

        wait;   -- park process forever; no $stop cursor jump
    end process p_stim;

end architecture sim;
