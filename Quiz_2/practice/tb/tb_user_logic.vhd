--------------------------------------------------------------------------------
-- tb_user_logic.vhd
--
-- ECEC 661 - Quiz 2 practice - custom stack user logic
--
-- Self-checking simulation for the user-logic portion before it is packaged as
-- an AXI4-Lite custom IP.  This is the fast sanity check to run before opening
-- the Vivado IP Packager.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity tb_user_logic is
end entity tb_user_logic;

architecture sim of tb_user_logic is

    constant CLK_PERIOD : time := 10 ns;

    signal ck        : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal cmd_valid : std_logic := '0';
    signal cmd       : std_logic_vector(1 downto 0) := "00";
    signal data_in   : std_logic_vector(31 downto 0) := (others => '0');
    signal data_out  : std_logic_vector(31 downto 0);
    signal count     : std_logic_vector(3 downto 0);
    signal empty     : std_logic;
    signal full      : std_logic;
    signal error     : std_logic;

    signal errors : integer := 0;
    signal checks : integer := 0;

    procedure tick is
    begin
        wait until rising_edge(ck);
        wait for 1 ns;
    end procedure tick;

    procedure issue_cmd (
        signal   valid : out std_logic;
        signal   op    : out std_logic_vector(1 downto 0);
        signal   din   : out std_logic_vector(31 downto 0);
        constant code  : in  std_logic_vector(1 downto 0);
        constant value : in  integer
    ) is
    begin
        din   <= std_logic_vector(to_unsigned(value, 32));
        op    <= code;
        valid <= '1';
        wait until rising_edge(ck);
        wait for 1 ns;
        valid <= '0';
        op    <= "00";
    end procedure issue_cmd;

    procedure check_int (
        constant got      : in    integer;
        constant expected : in    integer;
        constant tag      : in    string;
        signal   err_cnt  : inout integer;
        signal   chk_cnt  : inout integer
    ) is
    begin
        chk_cnt <= chk_cnt + 1;
        if got = expected then
            report "[PASS] " & tag & " = " & integer'image(got) severity note;
        else
            report "[FAIL] " & tag &
                   " got=" & integer'image(got) &
                   " expected=" & integer'image(expected) severity error;
            err_cnt <= err_cnt + 1;
        end if;
    end procedure check_int;

    procedure check_bit (
        constant got      : in    std_logic;
        constant expected : in    std_logic;
        constant tag      : in    string;
        signal   err_cnt  : inout integer;
        signal   chk_cnt  : inout integer
    ) is
    begin
        chk_cnt <= chk_cnt + 1;
        if got = expected then
            report "[PASS] " & tag & " = " & std_logic'image(got) severity note;
        else
            report "[FAIL] " & tag &
                   " got=" & std_logic'image(got) &
                   " expected=" & std_logic'image(expected) severity error;
            err_cnt <= err_cnt + 1;
        end if;
    end procedure check_bit;

begin

    p_clk : process
    begin
        ck <= '0'; wait for CLK_PERIOD / 2;
        ck <= '1'; wait for CLK_PERIOD / 2;
    end process p_clk;

    dut : entity work.user_logic
        port map (
            ck        => ck,
            resetn    => resetn,
            cmd_valid => cmd_valid,
            cmd       => cmd,
            data_in   => data_in,
            data_out  => data_out,
            count     => count,
            empty     => empty,
            full      => full,
            error     => error
        );

    p_stim : process
    begin
        -- Reset and initial status.
        resetn <= '0';
        for i in 0 to 3 loop
            tick;
        end loop;
        resetn <= '1';
        tick;

        check_int(to_integer(unsigned(count)), 0, "reset count", errors, checks);
        check_bit(empty, '1', "reset empty", errors, checks);
        check_bit(full,  '0', "reset full",  errors, checks);
        check_bit(error, '0', "reset error", errors, checks);

        -- Push three words, then pop them back in LIFO order.
        issue_cmd(cmd_valid, cmd, data_in, "01", 16#11#);
        issue_cmd(cmd_valid, cmd, data_in, "01", 16#22#);
        issue_cmd(cmd_valid, cmd, data_in, "01", 16#33#);
        check_int(to_integer(unsigned(count)), 3, "count after three pushes", errors, checks);
        check_bit(empty, '0', "not empty after pushes", errors, checks);

        issue_cmd(cmd_valid, cmd, data_in, "10", 0);
        check_int(to_integer(unsigned(data_out)), 16#33#, "pop returns newest word", errors, checks);
        check_int(to_integer(unsigned(count)), 2, "count after first pop", errors, checks);

        issue_cmd(cmd_valid, cmd, data_in, "10", 0);
        check_int(to_integer(unsigned(data_out)), 16#22#, "second pop returns next word", errors, checks);
        check_int(to_integer(unsigned(count)), 1, "count after second pop", errors, checks);

        -- Clear resets the software-visible status.
        issue_cmd(cmd_valid, cmd, data_in, "11", 0);
        check_int(to_integer(unsigned(count)), 0, "count after clear", errors, checks);
        check_bit(empty, '1', "empty after clear", errors, checks);
        check_bit(error, '0', "clear removes error", errors, checks);

        -- Underflow sets sticky error.
        issue_cmd(cmd_valid, cmd, data_in, "10", 0);
        check_bit(error, '1', "pop from empty sets error", errors, checks);

        wait for 5 * CLK_PERIOD;
        report LF &
               "+--------------------------------------------------+" & LF &
               "|       user_logic stack practice - summary        |" & LF &
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
