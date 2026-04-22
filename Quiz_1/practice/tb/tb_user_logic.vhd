--------------------------------------------------------------------------------
-- tb_user_logic.vhd
--
-- ECEC 402/661 - Example Quiz (practice) - IP Catalog Multiplier
--
-- Self-checking testbench for user_logic (wraps mult_gen_0).  The IP is
-- configured with 2 pipeline stages, so z(t) = x(t-2) * y(t-2) interpreting
-- all signals as signed.
--
-- Test plan:
--   1. Clock at 100 MHz (10 ns period).
--   2. Driver streams back-to-back 4-bit signed (x, y) vectors on every
--      rising edge - first the five vectors required by the quiz, then the
--      six vectors from the example wave in the hand-out so the simulation
--      snip matches the reference figure.
--   3. Checker waits LATENCY rising edges for the pipeline to fill, then
--      samples z one delta after each subsequent edge and compares it to
--      the expected signed product.
--   4. A final report banner prints PASS / FAIL.
--
--   Quiz vectors (required):
--      (-8,  7) -> -56
--      ( 3,  6) ->  18
--      (-1,  3) ->  -3
--      (-4,  5) -> -20
--      (-6, -2) ->  12
--
--   Example-wave vectors (from the hand-out, for a visual match):
--      (-1, -1) ->   1
--      ( 5,  3) ->  15
--      ( 2, -4) ->  -8
--      (-8, -8) ->  64
--      ( 0,  0) ->   0
--      ( 0,  0) ->   0
--
-- This testbench requires VHDL-2008 only for std.textio.LF in multi-line
-- report messages.  The DUT treats mult_gen_0 as a black box, so this TB
-- must be run inside Vivado xsim after the IP output products have been
-- generated (scripts/setup.tcl handles that).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;   -- LF for pretty multi-line reports

entity tb_user_logic is
end entity tb_user_logic;

architecture sim of tb_user_logic is

    constant CLK_PERIOD : time    := 10 ns;   -- 100 MHz
    constant LATENCY    : integer := 2;       -- must match PipeStages in setup.tcl

    signal ck : std_logic := '0';
    signal x  : std_logic_vector(3 downto 0) := (others => '0');
    signal y  : std_logic_vector(3 downto 0) := (others => '0');
    signal z  : std_logic_vector(7 downto 0);

    type int_vec is array (natural range <>) of integer;

    -- Quiz vectors followed by the example-wave vectors.  Keep the three
    -- arrays index-aligned; the expected product is computed by hand and
    -- hard-coded so a silent numeric_std rounding change cannot hide a bug.
    constant X_ALL : int_vec := (-8,  3, -1, -4, -6, -1,  5,  2, -8,  0,  0);
    constant Y_ALL : int_vec := ( 7,  6,  3,  5, -2, -1,  3, -4, -8,  0,  0);
    constant Z_ALL : int_vec := (-56, 18, -3, -20, 12,  1, 15, -8, 64,  0,  0);

    signal errors : integer := 0;
    signal checks : integer := 0;

    -- Right-pad (or clip) `s` to exactly `w` characters using trailing spaces.
    -- Used to keep the PASSED / FAILED banner box aligned regardless of the
    -- number of digits in the error count.
    function rpad (s : string; w : natural) return string is
        variable r : string(1 to w) := (others => ' ');
    begin
        if s'length >= w then
            return s(s'left to s'left + w - 1);
        else
            r(1 to s'length) := s;
            return r;
        end if;
    end function rpad;

    -- Sample z and compare against the expected product.  Called after a
    -- 1 ns settle past each rising edge so the pipeline output register
    -- has had time to propagate.
    procedure check_z (
        signal   z_sig    : in    std_logic_vector(7 downto 0);
        constant expected : in    integer;
        constant idx      : in    integer;
        constant xv       : in    integer;
        constant yv       : in    integer;
        signal   err_cnt  : inout integer;
        signal   chk_cnt  : inout integer
    ) is
        variable got : integer;
    begin
        got     := to_integer(signed(z_sig));
        chk_cnt <= chk_cnt + 1;
        if got = expected then
            report "[PASS] #" & integer'image(idx) &
                   "  (" & integer'image(xv) & ", " & integer'image(yv) & ")" &
                   "  z=" & integer'image(got)
                severity note;
        else
            report "[FAIL] #" & integer'image(idx) &
                   "  (" & integer'image(xv) & ", " & integer'image(yv) & ")" &
                   "  got z=" & integer'image(got) &
                   "  expected=" & integer'image(expected)
                severity error;
            err_cnt <= err_cnt + 1;
        end if;
    end procedure check_z;

begin

    ----------------------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------------------
    p_clk : process
    begin
        ck <= '0'; wait for CLK_PERIOD / 2;
        ck <= '1'; wait for CLK_PERIOD / 2;
    end process p_clk;

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    dut : entity work.user_logic
        port map (
            ck => ck,
            x  => x,
            y  => y,
            z  => z
        );

    ----------------------------------------------------------------------------
    -- Driver: applies the next (x, y) before every rising edge, then holds
    -- zeros to flush the pipeline.
    ----------------------------------------------------------------------------
    p_drive : process
    begin
        for i in X_ALL'range loop
            x <= std_logic_vector(to_signed(X_ALL(i), 4));
            y <= std_logic_vector(to_signed(Y_ALL(i), 4));
            wait until rising_edge(ck);
        end loop;

        x <= (others => '0');
        y <= (others => '0');
        wait;
    end process p_drive;

    ----------------------------------------------------------------------------
    -- Checker: aligned with the driver.  Skips LATENCY-1 edges so that the
    -- first rising_edge inside the main loop is the edge where the first
    -- valid product appears at z, then samples z one delta past each edge.
    --
    -- Timing (LATENCY = 2 pipe stages):
    --   t = 0           driver presents  X(0), Y(0)
    --   edge 1 (t=5ns)  pipeline latches X(0), Y(0); z still garbage
    --   edge 2 (t=15ns) z becomes X(0)*Y(0)    <- first check fires here
    --   edge 3 (t=25ns) z becomes X(1)*Y(1)    <- second check
    --   ...
    ----------------------------------------------------------------------------
    p_check : process
    begin
        for i in 1 to LATENCY - 1 loop
            wait until rising_edge(ck);
        end loop;

        for i in X_ALL'range loop
            wait until rising_edge(ck);
            wait for 1 ns;
            check_z(z, Z_ALL(i), i, X_ALL(i), Y_ALL(i), errors, checks);
        end loop;

        wait for 5 * CLK_PERIOD;

        report LF &
               "+--------------------------------------------------+" & LF &
               "|          tb_user_logic  -  test summary          |" & LF &
               "+--------------------------------------------------+" & LF &
               "   checks executed : " & integer'image(checks)         & LF &
               "   errors          : " & integer'image(errors)         & LF &
               "+--------------------------------------------------+"
            severity note;

        -- Box is 52 chars wide overall: "##" + 48 inner + "##".
        -- The inner field uses "##  " + 46-char rpad + "##" so variable-length
        -- numbers do not break alignment.
        if errors = 0 then
            report LF &
                   "####################################################" & LF &
                   "##                                                ##" & LF &
                   "##  " & rpad("TESTBENCH  PASSED  -  all cases ok", 46) & "##" & LF &
                   "##                                                ##" & LF &
                   "####################################################"
                severity note;
        else
            report LF &
                   "####################################################" & LF &
                   "##                                                ##" & LF &
                   "##  " & rpad("TESTBENCH  FAILED  -  " &
                                 integer'image(errors) &
                                 " error(s) detected", 46) & "##" & LF &
                   "##                                                ##" & LF &
                   "####################################################"
                severity failure;
        end if;

        wait;   -- park process; no std.env.stop so the source cursor stays put
    end process p_check;

end architecture sim;
