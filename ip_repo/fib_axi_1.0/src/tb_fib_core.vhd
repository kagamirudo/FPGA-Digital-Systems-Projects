--------------------------------------------------------------------------------
-- tb_fib_core.vhd
--
-- Self-checking testbench for fib_core.  Exercises representative
-- Fibonacci indices, including the corner cases n = 0, n = 1, the
-- largest non-overflowing index (47) and the first overflowing index
-- (48, for a 32-bit unsigned result).
--
-- Requires VHDL-2008 for to_hstring() when reporting results.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_fib_core is
end entity tb_fib_core;

architecture sim of tb_fib_core is

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal start    : std_logic := '0';
    signal n        : std_logic_vector(31 downto 0) := (others => '0');
    signal result   : std_logic_vector(31 downto 0);
    signal cycles   : std_logic_vector(31 downto 0);
    signal done     : std_logic;
    signal overflow : std_logic;
    signal busy     : std_logic;

    signal errors : integer := 0;

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
    dut : entity work.fib_core
        port map (
            clk      => clk,
            rst      => rst,
            start    => start,
            n        => n,
            result   => result,
            done     => done,
            overflow => overflow,
            busy     => busy,
            cycles   => cycles
        );

    ----------------------------------------------------------------------------
    -- Stimulus / checking
    ----------------------------------------------------------------------------
    p_stim : process

        procedure run_case (
            constant n_val   : in natural;
            constant exp_val : in unsigned(31 downto 0);
            constant exp_ovf : in std_logic
        ) is
        begin
            -- drive new N and a 1-cycle start pulse
            wait until rising_edge(clk);
            n     <= std_logic_vector(to_unsigned(n_val, 32));
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';

            -- fib_core drops 'done' for at least one cycle after start (the
            -- S_INIT state), so we can safely wait for the next 0->1 edge
            -- of 'done'.  Detect the rise by sampling on clock edges.
            wait until rising_edge(clk) and done = '0';
            wait until rising_edge(clk) and done = '1';

            if exp_ovf = '1' then
                if overflow /= '1' then
                    report "FAIL n=" & integer'image(n_val) &
                           " expected overflow"
                        severity error;
                    errors <= errors + 1;
                else
                    report "PASS n=" & integer'image(n_val) &
                           " overflow correctly detected"
                        severity note;
                end if;
            else
                if overflow /= '0' then
                    report "FAIL n=" & integer'image(n_val) &
                           " unexpected overflow"
                        severity error;
                    errors <= errors + 1;
                elsif unsigned(result) /= exp_val then
                    report "FAIL n=" & integer'image(n_val) &
                           " got=0x" & to_hstring(result) &
                           " expected=0x" & to_hstring(std_logic_vector(exp_val))
                        severity error;
                    errors <= errors + 1;
                else
                    report "PASS n=" & integer'image(n_val) &
                           " fib=0x" & to_hstring(result) &
                           " cycles=" & integer'image(to_integer(unsigned(cycles)))
                        severity note;
                end if;
            end if;

            -- small gap between cases
            for i in 0 to 3 loop
                wait until rising_edge(clk);
            end loop;
        end procedure run_case;

    begin
        rst <= '1';
        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;
        rst <= '0';
        wait until rising_edge(clk);

        run_case(0,  x"00000000", '0');
        run_case(1,  x"00000001", '0');
        run_case(2,  x"00000001", '0');
        run_case(5,  x"00000005", '0');
        run_case(10, x"00000037", '0');   -- 55
        run_case(20, x"00001A6D", '0');   -- 6765
        run_case(46, x"6D73E55F", '0');   -- 1_836_311_903
        run_case(47, x"B11924E1", '0');   -- 2_971_215_073
        run_case(48, x"00000000", '1');   -- overflow; value unchecked

        wait for 5 * CLK_PERIOD;

        if errors = 0 then
            report "=====================================" severity note;
            report "TESTBENCH PASSED - all cases match"   severity note;
            report "=====================================" severity note;
        else
            report "TESTBENCH FAILED with " & integer'image(errors) & " error(s)"
                severity failure;
        end if;

        std.env.stop;
        wait;
    end process p_stim;

end architecture sim;
