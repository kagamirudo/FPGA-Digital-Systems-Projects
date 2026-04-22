library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use std.env.all;

entity tb_palindrome_synch_ckt is
end entity tb_palindrome_synch_ckt;

architecture sim of tb_palindrome_synch_ckt is
  constant n_c : natural := 5;
  signal x     : std_logic := '0';
  signal y     : std_logic := '0';
  signal ck    : std_logic := '0';
  signal reset : std_logic := '1';
  signal z     : std_logic;

  constant Tck : time := 10 ns;
begin
  dut : entity work.palindrome_synch_ckt
    generic map(n => n_c)
    port map(
      x => x,
      y => y,
      ck => ck,
      reset => reset,
      z => z
    );

  ck <= not ck after Tck / 2;

  stim : process
    -- Test 1: x sequence 1,0,1,0,1 and y sequence 1,0,1,0,1
    -- reverse(y) = 1,0,1,0,1 -> palindrome match -> z = 1
    type bit_array_t is array (0 to n_c - 1) of std_logic;
    constant x_seq_match : bit_array_t := ('1', '0', '1', '0', '1');
    constant y_seq_match : bit_array_t := ('1', '0', '1', '0', '1');

    -- Test 2: x sequence 1,1,0,0,1 and y sequence 1,0,1,0,0
    -- reverse(y) = 0,0,1,0,1 /= x -> no match -> z = 0
    constant x_seq_miss : bit_array_t := ('1', '1', '0', '0', '1');
    constant y_seq_miss : bit_array_t := ('1', '0', '1', '0', '0');
  begin
    reset <= '1';
    wait for 2 * Tck;
    reset <= '0';

    for i in 0 to n_c - 1 loop
      x <= x_seq_match(i);
      y <= y_seq_match(i);
      wait until rising_edge(ck);
    end loop;

    wait until rising_edge(ck);
    assert z = '1'
      report "Palindrome test 1 failed (expected z=1)"
      severity error;

    reset <= '1';
    wait until rising_edge(ck);
    reset <= '0';

    for i in 0 to n_c - 1 loop
      x <= x_seq_miss(i);
      y <= y_seq_miss(i);
      wait until rising_edge(ck);
    end loop;

    wait until rising_edge(ck);
    assert z = '0'
      report "Palindrome test 2 failed (expected z=0)"
      severity error;

    report "tb_palindrome_synch_ckt PASSED" severity note;
    stop;
    wait;
  end process;
end architecture sim;
