--------------------------------------------------------------------------------
-- tb_user_logic.vhd
--
-- ECEC 661 - Homework 4 - CORDIC Square Root IP
--
-- Self-checking testbench for user_logic, which wraps the Vivado IP-Catalog
-- CORDIC Square Root core (cordic_0).  Reproduces the assignment waveform
-- (Fig. 3): a single din_tvalid pulse covering four input samples
--     x = 0x080 (1.0  in 2Q7)  -> z = 0x100 (1.000   in 1Q8)
--     x = 0x040 (0.5  in 2Q7)  -> z = 0x0B5 (0.7070  in 1Q8)
--     x = 0x008 (1/16 in 2Q7)  -> z = 0x040 (0.250   in 1Q8)
--     x = 0x000 (0)            -> z = 0x000
-- followed by deasserting din_tvalid and waiting for the four registered
-- z values to appear on consecutive dout_tvalid cycles.
--
-- The CORDIC IP runs in Parallel / Maximum-Pipelining mode, so dout_tvalid
-- tracks din_tvalid one pipeline-depth later (~13-15 cycles).  The TB does
-- not assume a fixed latency: it waits for the rising edge of dout_tvalid
-- and then samples z for as many cycles as it stays high.
--
-- VHDL-2008 is used only for textio.LF in the banner.  The DUT instantiates
-- cordic_0 as a black box, so this testbench MUST be run inside Vivado xsim
-- after the cordic_0 output products have been generated.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;
use std.textio.all;

entity tb_user_logic is
end entity tb_user_logic;

architecture sim of tb_user_logic is

    constant CLK_PERIOD : time := 10 ns;     -- 100 MHz
    constant N_VEC      : integer := 4;

    type slv16_array is array (natural range <>) of std_logic_vector(15 downto 0);

    constant test_x   : slv16_array(0 to N_VEC-1) := (
        x"0080",   -- 1.0     (2Q7)
        x"0040",   -- 0.5     (2Q7)
        x"0008",   -- 1/16    (2Q7)
        x"0000"    -- 0
    );
    constant expect_z : slv16_array(0 to N_VEC-1) := (
        x"0100",   -- sqrt(1.0)   = 1.000   (1Q8)
        x"00B5",   -- sqrt(0.5)   = 0.707   (1Q8)
        x"0040",   -- sqrt(1/16)  = 0.25    (1Q8)
        x"0000"    -- sqrt(0)     = 0
    );

    signal ck          : std_logic := '0';
    signal aresetn     : std_logic := '0';
    signal din_tvalid  : std_logic := '0';
    signal x           : std_logic_vector(15 downto 0) := (others => '0');
    signal z           : std_logic_vector(15 downto 0);
    signal dout_tvalid : std_logic;

    signal errors : integer := 0;
    signal checks : integer := 0;

begin

    ----------------------------------------------------------------------------
    -- 100 MHz clock
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
            ck          => ck,
            aresetn     => aresetn,
            din_tvalid  => din_tvalid,
            x           => x,
            dout_tvalid => dout_tvalid,
            z           => z
        );

    ----------------------------------------------------------------------------
    -- Stimulus / self-check
    --
    -- Assignment waveform reproduction (Fig. 3):
    --   Reset low, din_tvalid low.
    --   Release reset, raise din_tvalid for the four samples, then drop it.
    --   Wait for dout_tvalid; sample z on each consecutive valid cycle.
    ----------------------------------------------------------------------------
    p_stim : process
        variable got      : std_logic_vector(15 downto 0);
        variable expected : std_logic_vector(15 downto 0);
        variable v_idx    : integer;
    begin
        -- Phase 1: hold reset for a few cycles (Fig. 3: aresetn low at 100 ps)
        aresetn    <= '0';
        din_tvalid <= '0';
        x          <= (others => '0');
        for i in 0 to 4 loop
            wait until rising_edge(ck);
        end loop;

        -- Phase 2: release reset, present samples on consecutive clocks while
        -- din_tvalid is high.
        aresetn    <= '1';
        wait until rising_edge(ck);

        din_tvalid <= '1';
        for i in 0 to N_VEC-1 loop
            x <= test_x(i);
            wait until rising_edge(ck);
        end loop;

        -- Phase 3: deassert din_tvalid; the IP keeps streaming the registered
        -- results out as dout_tvalid pulses.
        din_tvalid <= '0';
        x          <= (others => '0');

        -- Phase 4: wait for the first dout_tvalid then sample N_VEC values on
        -- as many consecutive valid cycles.  The "Maximum" pipelined CORDIC
        -- holds dout_tvalid high for one cycle per accepted sample, so four
        -- samples in -> four valid cycles out.
        wait until rising_edge(ck) and dout_tvalid = '1';

        for i in 0 to N_VEC-1 loop
            -- Sample z at the same edge that dout_tvalid is observed high.
            got      := z;
            expected := expect_z(i);
            v_idx    := i;
            checks   <= checks + 1;
            if got(9 downto 0) = expected(9 downto 0) then
                report "[PASS] sqrt(0x" &
                       to_hstring(test_x(v_idx)(9 downto 0)) &
                       ") = 0x" & to_hstring(got(9 downto 0))
                    severity note;
            else
                report "[FAIL] sqrt(0x" &
                       to_hstring(test_x(v_idx)(9 downto 0)) &
                       ") got 0x" & to_hstring(got(9 downto 0)) &
                       " expected 0x" & to_hstring(expected(9 downto 0))
                    severity error;
                errors <= errors + 1;
            end if;

            -- Walk to next valid cycle (or break if pipeline drained early).
            if i < N_VEC-1 then
                wait until rising_edge(ck);
                -- Skip any non-valid bubble cycles defensively, though the
                -- "Maximum" build does not insert any for this configuration.
                while dout_tvalid = '0' loop
                    wait until rising_edge(ck);
                end loop;
            end if;
        end loop;

        ------------------------------------------------------------------------
        -- Final report banner.  We end with `wait;` (not std.env.stop) so
        -- Vivado does not jump the source-window cursor on completion.
        ------------------------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        report LF &
               "+--------------------------------------------------+" & LF &
               "|         user_logic - cordic sqrt summary         |" & LF &
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
