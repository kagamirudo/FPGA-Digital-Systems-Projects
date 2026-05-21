--------------------------------------------------------------------------------
-- user_logic.vhd
--
-- ECEC 661 - Quiz 2 practice - custom stack user logic
--
-- Small synchronous stack used as the "user logic" inside a custom AXI4-Lite
-- IP.  The quiz announcement says Quiz 2 focuses on user logic, IP packaging,
-- block design integration, and XSA export, so this file stays independent of
-- Vitis and board hardware.
--
-- Command encoding, sampled when cmd_valid = '1':
--   "01" push  data_in
--   "10" pop   top value to data_out
--   "11" clear stack, status, and data_out
--   "00" idle
--
-- Status is intentionally simple so it is easy to map into AXI registers:
--   count : number of valid stack entries (0..8)
--   empty : count = 0
--   full  : count = 8
--   error : sticky overflow/underflow flag, cleared by reset or clear command
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity user_logic is
    generic (
        DATA_WIDTH : integer := 32;
        DEPTH      : integer := 8
    );
    port (
        ck        : in  std_logic;
        resetn    : in  std_logic;
        cmd_valid : in  std_logic;
        cmd       : in  std_logic_vector(1 downto 0);
        data_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_out  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        count     : out std_logic_vector(3 downto 0);
        empty     : out std_logic;
        full      : out std_logic;
        error     : out std_logic
    );
end entity user_logic;

architecture rtl of user_logic is

    type stack_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal stack_mem : stack_t := (others => (others => '0'));
    signal sp        : integer range 0 to DEPTH := 0;
    signal dout_reg  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal err_reg   : std_logic := '0';

begin

    data_out <= dout_reg;
    count    <= std_logic_vector(to_unsigned(sp, 4));
    empty    <= '1' when sp = 0 else '0';
    full     <= '1' when sp = DEPTH else '0';
    error    <= err_reg;

    p_stack : process (ck)
    begin
        if rising_edge(ck) then
            if resetn = '0' then
                stack_mem <= (others => (others => '0'));
                sp        <= 0;
                dout_reg  <= (others => '0');
                err_reg   <= '0';
            elsif cmd_valid = '1' then
                case cmd is
                    when "01" =>   -- push
                        if sp = DEPTH then
                            err_reg <= '1';
                        else
                            stack_mem(sp) <= data_in;
                            sp            <= sp + 1;
                        end if;

                    when "10" =>   -- pop
                        if sp = 0 then
                            err_reg <= '1';
                        else
                            dout_reg <= stack_mem(sp - 1);
                            sp       <= sp - 1;
                        end if;

                    when "11" =>   -- clear
                        stack_mem <= (others => (others => '0'));
                        sp        <= 0;
                        dout_reg  <= (others => '0');
                        err_reg   <= '0';

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process p_stack;

end architecture rtl;
