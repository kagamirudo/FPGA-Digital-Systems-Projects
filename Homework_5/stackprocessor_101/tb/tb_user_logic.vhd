--------------------------------------------------------------------------------
-- tb_user_logic.vhd
--
-- ECEC 661 - Homework 5 - Stack Processor 101 with new `scpb` block-copy
--
-- Self-checking VHDL-2008 testbench that drives `user_logic` exactly the way
-- the PDF's xsim script does (raw bus2mem_* / run / reset / done signals),
-- exercising the new instruction with three scenarios:
--
--   * test 1 : count = 3  (multi-word block copy)
--   * test 2 : count = 1  (single-word copy, off-by-one check)
--   * test 3 : count = 0  (no-op copy must leave the destination intact)
--
-- For each scenario the TB:
--   1. holds `reset` high and `bus2mem_en` high so the bus owns memory,
--   2. preloads the destination block with a sentinel,
--   3. preloads the source block with the source words,
--   4. loads the program `sc dest sc src sc count scpb halt`,
--   5. releases reset, deasserts bus2mem_en, asserts `run`,
--   6. spins on `done`,
--   7. re-acquires the bus and reads back the destination block,
--   8. compares each word against the golden vector and accumulates a global
--      pass/fail counter,
--   9. prints PASS / FAIL banner at the end.
--
-- This is run inside Vivado xsim because `user_logic` instantiates
-- `blk_mem_gen_0` (an IP-Catalog block) - the same setup the assignment PDF
-- assumes for the simulation script.  VHDL-2008 is used for `LF` /
-- `to_hstring()`.
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

    constant CLK_PERIOD : time    := 10 ns;
    constant A          : natural := 10;

    ----------------------------------------------------------------------------
    -- Opcode mnemonics for readable program literals
    ----------------------------------------------------------------------------
    constant OP_SC   : integer := 16#001#;
    constant OP_SCPB : integer := 16#201#;
    constant OP_HALT : integer := 16#0FF#;

    ----------------------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------------------
    signal ck              : std_logic := '0';
    signal run_sig         : std_logic := '0';
    signal reset_sig       : std_logic := '1';
    signal bus2mem_en      : std_logic := '1';
    signal bus2mem_we      : std_logic := '0';
    signal bus2mem_addr    : std_logic_vector(A-1 downto 0) := (others => '0');
    signal bus2mem_data_in : std_logic_vector(31 downto 0)  := (others => '0');
    signal sp2bus_data_out : std_logic_vector(31 downto 0);
    signal done_sig        : std_logic;

    ----------------------------------------------------------------------------
    -- Self-checking bookkeeping
    ----------------------------------------------------------------------------
    signal checks : integer := 0;
    signal errors : integer := 0;

    ----------------------------------------------------------------------------
    -- Reusable bit-vector array type for the procedure signatures
    ----------------------------------------------------------------------------
    type word_arr is array (natural range <>) of std_logic_vector(31 downto 0);

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
        generic map (
            A => A
        )
        port map (
            run             => run_sig,
            reset           => reset_sig,
            bus2mem_en      => bus2mem_en,
            bus2mem_we      => bus2mem_we,
            ck              => ck,
            bus2mem_addr    => bus2mem_addr,
            bus2mem_data_in => bus2mem_data_in,
            sp2bus_data_out => sp2bus_data_out,
            done            => done_sig
        );

    ----------------------------------------------------------------------------
    -- Stimulus
    ----------------------------------------------------------------------------
    p_stim : process

        ------------------------------------------------------------------------
        -- Drive a single bus write : memory[addr] <= data
        ------------------------------------------------------------------------
        procedure bus_write_int (addr : integer; data : integer) is
        begin
            bus2mem_addr    <= std_logic_vector(to_unsigned(addr, A));
            bus2mem_data_in <= std_logic_vector(to_signed(data, 32));
            wait until rising_edge(ck);
        end procedure;

        procedure bus_write_slv (addr : integer;
                                 data : std_logic_vector(31 downto 0)) is
        begin
            bus2mem_addr    <= std_logic_vector(to_unsigned(addr, A));
            bus2mem_data_in <= data;
            wait until rising_edge(ck);
        end procedure;

        ------------------------------------------------------------------------
        -- Drive a single bus read.  Latency from setting bus2mem_addr until
        -- sp2bus_data_out is valid is BRAM (1) + mem_data_out register (1) =
        -- 2 cycles.  We wait 4 to leave headroom for the combinational bus mux.
        ------------------------------------------------------------------------
        procedure bus_read (addr : integer;
                            got  : out std_logic_vector(31 downto 0)) is
        begin
            bus2mem_we   <= '0';
            bus2mem_addr <= std_logic_vector(to_unsigned(addr, A));
            for i in 0 to 3 loop
                wait until rising_edge(ck);
            end loop;
            got := sp2bus_data_out;
        end procedure;

        ------------------------------------------------------------------------
        -- Compare got vs expected; update pass/fail counters.
        -- (`label` is a VHDL reserved word, so we use `tag` here.)
        ------------------------------------------------------------------------
        procedure check_word (tag      : string;
                              addr     : integer;
                              got      : std_logic_vector(31 downto 0);
                              expected : std_logic_vector(31 downto 0)) is
        begin
            checks <= checks + 1;
            if got = expected then
                report "[PASS] " & tag & " addr=" & integer'image(addr) &
                       " got=0x" & to_hstring(got)
                    severity note;
            else
                report "[FAIL] " & tag & " addr=" & integer'image(addr) &
                       " got=0x" & to_hstring(got) &
                       " expected=0x" & to_hstring(expected)
                    severity error;
                errors <= errors + 1;
            end if;
        end procedure;

        ------------------------------------------------------------------------
        -- start_bus_phase : take the bus, hold reset, enable writes.
        ------------------------------------------------------------------------
        procedure start_bus_phase is
        begin
            run_sig    <= '0';
            reset_sig  <= '1';
            bus2mem_en <= '1';
            bus2mem_we <= '1';
            for i in 0 to 1 loop
                wait until rising_edge(ck);
            end loop;
            reset_sig <= '0';
            wait until rising_edge(ck);
        end procedure;

        ------------------------------------------------------------------------
        -- run_and_wait_done : release the bus, raise `run`, spin on `done`.
        ------------------------------------------------------------------------
        procedure run_and_wait_done is
        begin
            bus2mem_we <= '0';
            bus2mem_en <= '0';
            wait until rising_edge(ck);
            run_sig <= '1';
            while done_sig /= '1' loop
                wait until rising_edge(ck);
            end loop;
            run_sig <= '0';
            wait until rising_edge(ck);
        end procedure;

        ------------------------------------------------------------------------
        -- run_scpb : exercise one scenario.  Pre-writes `dest_pre` into
        -- memory at dest_base, `src_data` at src_base, loads the canonical
        -- program at addrs 0..7, runs it, then reads dest_base back and
        -- compares against `expected`.  All three arrays must be the same
        -- length; pass length 1 for the count=0 test (one sentinel word).
        ------------------------------------------------------------------------
        procedure run_scpb (
            scenario_label : string;
            dest_base      : integer;
            src_base       : integer;
            count          : integer;
            dest_pre       : word_arr;
            src_data       : word_arr;
            expected       : word_arr) is
            variable got : std_logic_vector(31 downto 0);
        begin
            report "==== Scenario: " & scenario_label severity note;

            ----------------------------------------------------------------
            -- Phase A : own the bus, reset, then load memory + program
            ----------------------------------------------------------------
            start_bus_phase;

            for i in 0 to dest_pre'length - 1 loop
                bus_write_slv(dest_base + i, dest_pre(i));
            end loop;

            for i in 0 to src_data'length - 1 loop
                bus_write_slv(src_base + i, src_data(i));
            end loop;

            bus_write_int(0, OP_SC);
            bus_write_int(1, dest_base);
            bus_write_int(2, OP_SC);
            bus_write_int(3, src_base);
            bus_write_int(4, OP_SC);
            bus_write_int(5, count);
            bus_write_int(6, OP_SCPB);
            bus_write_int(7, OP_HALT);

            ----------------------------------------------------------------
            -- Phase B : let the processor run
            ----------------------------------------------------------------
            run_and_wait_done;

            ----------------------------------------------------------------
            -- Phase C : re-acquire the bus, read back, self-check
            ----------------------------------------------------------------
            bus2mem_en <= '1';
            bus2mem_we <= '0';
            wait until rising_edge(ck);

            for i in 0 to expected'length - 1 loop
                bus_read(dest_base + i, got);
                check_word(scenario_label, dest_base + i, got, expected(i));
            end loop;
        end procedure;

    begin
        ------------------------------------------------------------------------
        -- Reset for a few cycles before the first test
        ------------------------------------------------------------------------
        reset_sig       <= '1';
        run_sig         <= '0';
        bus2mem_en      <= '1';
        bus2mem_we      <= '0';
        bus2mem_addr    <= (others => '0');
        bus2mem_data_in <= (others => '0');
        for i in 0 to 4 loop
            wait until rising_edge(ck);
        end loop;

        ------------------------------------------------------------------------
        -- Test 1 : multi-word block copy
        --   source 100..102 = [0x0B, 0x16, 0x21] -> dest 200..202
        ------------------------------------------------------------------------
        run_scpb(
            scenario_label => "scpb count=3",
            dest_base      => 200,
            src_base       => 100,
            count          => 3,
            dest_pre       => (x"00000000", x"00000000", x"00000000"),
            src_data       => (x"0000000B", x"00000016", x"00000021"),
            expected       => (x"0000000B", x"00000016", x"00000021")
        );

        ------------------------------------------------------------------------
        -- Test 2 : single-word block copy (count=1) - off-by-one guard
        --   source 110 = [0x63] -> dest 210
        ------------------------------------------------------------------------
        run_scpb(
            scenario_label => "scpb count=1",
            dest_base      => 210,
            src_base       => 110,
            count          => 1,
            dest_pre       => (0 to 0 => x"00000000"),
            src_data       => (0 to 0 => x"00000063"),
            expected       => (0 to 0 => x"00000063")
        );

        ------------------------------------------------------------------------
        -- Test 3 : zero-count copy must NOT touch the destination
        --   pre-fill dest 220 = 0xDEADBEEF, then run scpb with count=0,
        --   then verify dest 220 still equals 0xDEADBEEF.
        ------------------------------------------------------------------------
        run_scpb(
            scenario_label => "scpb count=0",
            dest_base      => 220,
            src_base       => 120,
            count          => 0,
            dest_pre       => (0 to 0 => x"DEADBEEF"),
            src_data       => (0 to 0 => x"00000055"),
            expected       => (0 to 0 => x"DEADBEEF")
        );

        ------------------------------------------------------------------------
        -- Final banner
        ------------------------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        report LF &
               "+--------------------------------------------------+" & LF &
               "|    sp101 + scpb  block-copy testbench summary    |" & LF &
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
