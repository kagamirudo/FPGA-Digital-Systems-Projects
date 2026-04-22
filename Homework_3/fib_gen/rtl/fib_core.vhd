--------------------------------------------------------------------------------
-- fib_core.vhd
--
-- ECEC 661 - Homework 3 - Problem 8.7.1 Fibonacci Number Generator
--
-- Sequential Fibonacci core. Given an input N, computes F(N) where
--     F(0) = 0, F(1) = 1, F(n) = F(n-1) + F(n-2).
-- 32-bit unsigned result. A 33-bit adder is used to detect unsigned
-- overflow; the 'overflow' flag sticks until the next start pulse.
--
-- Handshake:
--   * Host drives N, asserts start for one cycle.
--   * Core deasserts done, asserts busy, runs its FSM.
--   * When finished, busy returns low and done stays high (latched)
--     until the next start pulse.
--
-- F(47) = 2_971_215_073 is the largest value that fits in 32 bits
-- unsigned; F(48) triggers overflow.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fib_core is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;                      -- synchronous, active high
        start    : in  std_logic;                      -- 1-cycle pulse from AXI
        n        : in  std_logic_vector(31 downto 0);  -- requested index
        result   : out std_logic_vector(31 downto 0);  -- F(N) (or truncated on ovf)
        done     : out std_logic;                      -- latched, cleared on next start
        overflow : out std_logic;                      -- latched, cleared on next start
        busy     : out std_logic;                      -- high while iterating
        cycles   : out std_logic_vector(31 downto 0)   -- iteration count (debug)
    );
end entity fib_core;

architecture rtl of fib_core is

    -- S_IDLE : waiting for start
    -- S_INIT : 1-cycle delay so done can de-assert reliably after start,
    --          even for the trivial n=0 / n=1 cases
    -- S_ADD  : iterate the add-and-shift datapath
    type state_t is (S_IDLE, S_INIT, S_ADD);
    signal state : state_t;

    signal a     : unsigned(31 downto 0);  -- F(k-1)
    signal b     : unsigned(31 downto 0);  -- F(k)
    signal k     : unsigned(31 downto 0);  -- current index we already have in b
    signal n_reg : unsigned(31 downto 0);  -- latched target

    signal result_r : std_logic_vector(31 downto 0);
    signal done_r   : std_logic;
    signal ovf_r    : std_logic;
    signal busy_r   : std_logic;
    signal cyc_r    : unsigned(31 downto 0);

    -- 33-bit extended adder so we can catch the carry-out
    signal sum_ext  : unsigned(32 downto 0);

begin

    sum_ext <= ('0' & a) + ('0' & b);

    result   <= result_r;
    done     <= done_r;
    overflow <= ovf_r;
    busy     <= busy_r;
    cycles   <= std_logic_vector(cyc_r);

    fsm : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= S_IDLE;
                a        <= (others => '0');
                b        <= (others => '0');
                k        <= (others => '0');
                n_reg    <= (others => '0');
                result_r <= (others => '0');
                done_r   <= '0';
                ovf_r    <= '0';
                busy_r   <= '0';
                cyc_r    <= (others => '0');
            else
                case state is

                    when S_IDLE =>
                        busy_r <= '0';
                        if start = '1' then
                            n_reg  <= unsigned(n);
                            a      <= (others => '0');
                            b      <= (0 => '1', others => '0');
                            k      <= to_unsigned(1, 32);
                            ovf_r  <= '0';
                            done_r <= '0';   -- always drop done for >= 1 cycle
                            busy_r <= '1';
                            cyc_r  <= (others => '0');
                            state  <= S_INIT;
                        end if;

                    when S_INIT =>
                        -- handle the trivial cases here so that done went
                        -- through one full low cycle (seen by the whole system)
                        if n_reg = 0 then
                            result_r <= (others => '0');
                            done_r   <= '1';
                            busy_r   <= '0';
                            state    <= S_IDLE;
                        elsif n_reg = 1 then
                            result_r <= std_logic_vector(to_unsigned(1, 32));
                            done_r   <= '1';
                            busy_r   <= '0';
                            state    <= S_IDLE;
                        else
                            state <= S_ADD;
                        end if;

                    when S_ADD =>
                        cyc_r <= cyc_r + 1;

                        if sum_ext(32) = '1' then
                            -- overflow: latch truncated result and stop
                            ovf_r    <= '1';
                            result_r <= std_logic_vector(sum_ext(31 downto 0));
                            done_r   <= '1';
                            busy_r   <= '0';
                            state    <= S_IDLE;
                        elsif (k + 1) = n_reg then
                            -- this addition produces F(n_reg)
                            result_r <= std_logic_vector(sum_ext(31 downto 0));
                            done_r   <= '1';
                            busy_r   <= '0';
                            state    <= S_IDLE;
                        else
                            a <= b;
                            b <= sum_ext(31 downto 0);
                            k <= k + 1;
                        end if;

                end case;
            end if;
        end if;
    end process fsm;

end architecture rtl;
