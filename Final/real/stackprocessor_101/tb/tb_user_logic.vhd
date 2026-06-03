--------------------------------------------------------------------------------
-- tb_user_logic.vhd
--
-- ECEC 661 - Final (real) - Stack Processor 101 with new `ssq` instruction
--
-- Self-checking VHDL-2008 testbench driving `user_logic` exactly the way the
-- assignment PDF's xsim script does (raw bus2mem_* / run / reset / done),
-- exercising the new `ssq` ("stack the square") instruction.
--
-- The prompt's canonical example is:
--
--     sc 7  ssq  halt
--
-- After execution sp101 must have written 49 onto the stack and the
-- stack pointer must point to the next available address.  Since `idle`
-- initialises sp = 128 and `sc 7` writes mem[128] = 7 then bumps sp to
-- 129, `ssq` overwrites mem[128] with 7*7 = 49 and leaves sp = 129.
--
-- Three scenarios are run:
--   * test 1 : sc 7 ssq halt  -> mem[128] = 49   (the prompt example)
--   * test 2 : sc 0 ssq halt  -> mem[128] =  0   (zero edge case)
--   * test 3 : sc 1 ssq halt  -> mem[128] =  1   (identity edge case)
--
-- For each scenario the TB:
--   1. holds `reset` high and `bus2mem_en` high so the bus owns memory,
--   2. preloads a sentinel into mem[128] so a no-op would be detected,
--   3. loads the program `sc x ssq halt` into mem[0..3],
--   4. releases reset, deasserts bus2mem_en, asserts `run`,
--   5. spins on `done`,
--   6. re-acquires the bus and reads mem[128],
--   7. checks the result against the expected square,
--   8. prints PASS / FAIL.
--
-- VHDL-2008 is used for `LF` and `to_hstring()`.
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
    -- Opcode mnemonics for readable program literals (must match user_logic).
    ----------------------------------------------------------------------------
    constant OP_SC   : integer := 16#001#;
    constant OP_SSQ  : integer := 16#041#;
    constant OP_HALT : integer := 16#0FF#;

    -- Stack base : `idle` initialises sp = 128, so the top of stack lives
    -- at mem[128] for the first sc/ssq program above.
    constant STACK_BASE : integer := 128;

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
        -- Drive a single bus read.  Latency: BRAM (1 cycle) + the two
        -- mem_data_out chain registers (2 cycles).  We wait 4 to leave
        -- a small headroom for the bus mux.
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
        -- run_ssq : exercise one `sc x  ssq  halt` scenario.
        --
        -- 1) pre-write a sentinel into mem[STACK_BASE] so a no-op is caught.
        -- 2) load `sc x ssq halt` into mem[0..3].
        -- 3) run the processor.
        -- 4) read back mem[STACK_BASE] and compare against expected (= x*x).
        ------------------------------------------------------------------------
        procedure run_ssq (
            scenario_label : string;
            x_in           : integer;
            sentinel       : std_logic_vector(31 downto 0);
            expected       : std_logic_vector(31 downto 0)) is
            variable got : std_logic_vector(31 downto 0);
        begin
            report "==== Scenario: " & scenario_label severity note;

            ----------------------------------------------------------------
            -- Phase A : own the bus, reset, then load memory + program
            ----------------------------------------------------------------
            start_bus_phase;

            -- sentinel at the top-of-stack slot (mem[128])
            bus_write_slv(STACK_BASE, sentinel);

            -- program : sc x  ssq  halt   (4 words at mem[0..3])
            bus_write_int(0, OP_SC);
            bus_write_int(1, x_in);
            bus_write_int(2, OP_SSQ);
            bus_write_int(3, OP_HALT);

            ----------------------------------------------------------------
            -- Phase B : let the processor run
            ----------------------------------------------------------------
            run_and_wait_done;

            ----------------------------------------------------------------
            -- Phase C : re-acquire the bus, read back mem[128], self-check
            ----------------------------------------------------------------
            bus2mem_en <= '1';
            bus2mem_we <= '0';
            wait until rising_edge(ck);

            bus_read(STACK_BASE, got);
            check_word(scenario_label, STACK_BASE, got, expected);
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
        -- Test 1 : the prompt example  sc 7 ssq halt -> mem[128] = 49
        ------------------------------------------------------------------------
        run_ssq(
            scenario_label => "ssq x=7 (prompt example)",
            x_in           => 7,
            sentinel       => x"DEADBEEF",
            expected       => x"00000031"   -- 49
        );

        ------------------------------------------------------------------------
        -- Test 2 : zero edge case  sc 0 ssq halt -> mem[128] = 0
        ------------------------------------------------------------------------
        run_ssq(
            scenario_label => "ssq x=0 (zero)",
            x_in           => 0,
            sentinel       => x"DEADBEEF",
            expected       => x"00000000"
        );

        ------------------------------------------------------------------------
        -- Test 3 : identity edge case  sc 1 ssq halt -> mem[128] = 1
        ------------------------------------------------------------------------
        run_ssq(
            scenario_label => "ssq x=1 (identity)",
            x_in           => 1,
            sentinel       => x"DEADBEEF",
            expected       => x"00000001"
        );

        ------------------------------------------------------------------------
        -- Final banner
        ------------------------------------------------------------------------
        wait for 5 * CLK_PERIOD;

        report LF &
               "+--------------------------------------------------+" & LF &
               "|     sp101 + ssq  stack-the-square TB summary     |" & LF &
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
