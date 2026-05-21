--------------------------------------------------------------------------------
-- tb_user_logic.vhd
--
-- ECEC 661/402 - Quiz 2 (real) - Add-(-1) custom IP testbench
--
-- Self-checking testbench for the user_logic block, which wraps the Vivado
-- IP-Catalog Adder/Subtractor (xilinx.com:ip:c_addsub:12.0) configured as
--     S = A + B   with B = -1 (signed 32-bit constant)
--
-- Coverage matches the printed reference run from the quiz hand-out:
--     x = -5  ->  z = -6
--     x = -4  ->  z = -5
--     x = -3  ->  z = -4
--     x = -2  ->  z = -3
--     x = -1  ->  z = -2
--     x =  0  ->  z = -1
--     x =  1  ->  z =  0
--     x =  2  ->  z =  1
--     x =  3  ->  z =  2
--
-- Plus a few signed boundary checks (max negative, max positive, INT32_MIN
-- and INT32_MAX) to catch wrap-around bugs.
--
-- This testbench requires VHDL-2008 only for std.textio.LF in multi-line
-- report messages.  Because user_logic instantiates c_addsub_0 as a black
-- box, the simulation must be run inside Vivado xsim AFTER the IP output
-- products have been generated (scripts/setup.tcl handles that).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity tb_user_logic is
end entity tb_user_logic;

architecture sim of tb_user_logic is

    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz visualization clock

    signal ck : std_logic := '0';                           -- only for the wave
    signal x  : std_logic_vector(31 downto 0) := (others => '0');
    signal z  : std_logic_vector(31 downto 0);

    type int_vec is array (natural range <>) of integer;

    -- Quiz reference run, in order.
    constant X_REF : int_vec := (-5, -4, -3, -2, -1,  0,  1,  2,  3);
    constant Z_REF : int_vec := (-6, -5, -4, -3, -2, -1,  0,  1,  2);

    signal errors : integer := 0;
    signal checks : integer := 0;

    -- Sample z and compare against the expected signed sum.
    procedure check_z (
        signal   z_sig    : in    std_logic_vector(31 downto 0);
        constant expected : in    integer;
        constant xv       : in    integer;
        signal   err_cnt  : inout integer;
        signal   chk_cnt  : inout integer
    ) is
        variable got : integer;
    begin
        got     := to_integer(signed(z_sig));
        chk_cnt <= chk_cnt + 1;
        if got = expected then
            report "[PASS] x=" & integer'image(xv) &
                   "  z=" & integer'image(got)
                severity note;
        else
            report "[FAIL] x=" & integer'image(xv) &
                   "  got z=" & integer'image(got) &
                   "  expected=" & integer'image(expected)
                severity error;
            err_cnt <= err_cnt + 1;
        end if;
    end procedure check_z;

begin

    ----------------------------------------------------------------------------
    -- Visualization clock (the DUT itself is combinational, latency = 0).
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
            x => x,
            z => z
        );

    ----------------------------------------------------------------------------
    -- Stimulus: walk the reference run, then sanity-check signed boundaries.
    --
    -- Because c_addsub_0 has latency 0 the result is combinational; we drive
    -- a vector, wait one full period for the wave to be readable, then sample.
    ----------------------------------------------------------------------------
    p_stim : process
    begin
        -- Idle a couple of cycles so the wave has a clean head.
        x <= (others => '0');
        for i in 0 to 2 loop
            wait until rising_edge(ck);
        end loop;

        -- Reference run from the quiz hand-out (same vectors as the PuTTY
        -- screenshot), checked one-by-one.
        for i in X_REF'range loop
            x <= std_logic_vector(to_signed(X_REF(i), 32));
            wait until rising_edge(ck);
            wait for 1 ns;
            check_z(z, Z_REF(i), X_REF(i), errors, checks);
        end loop;

        -- Signed boundary cases:
        -- x = INT32_MAX (=  2147483647)  ->  z = 2147483646
        x <= std_logic_vector(to_signed(2147483647, 32));
        wait until rising_edge(ck);
        wait for 1 ns;
        check_z(z, 2147483646, 2147483647, errors, checks);

        -- x = INT32_MIN (= -2147483648)  ->  z = INT32_MAX (wrap around -1)
        --   -2147483648 + (-1) = -2147483649, which in two's-complement 32-bit
        --   wraps to  2147483647.  The IP is signed but the sum is computed
        --   modulo 2^32.
        x <= std_logic_vector(to_signed(-2147483648, 32));
        wait until rising_edge(ck);
        wait for 1 ns;
        check_z(z, 2147483647, -2147483648, errors, checks);

        wait for 5 * CLK_PERIOD;

        report LF &
               "+--------------------------------------------------+" & LF &
               "|        tb_user_logic  -  add-(-1) summary        |" & LF &
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

        wait;
    end process p_stim;

end architecture sim;
