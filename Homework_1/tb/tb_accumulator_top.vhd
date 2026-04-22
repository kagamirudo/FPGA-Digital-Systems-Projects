library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

entity tb_accumulator_top is
end entity tb_accumulator_top;

architecture sim of tb_accumulator_top is
  signal ck   : std_logic := '0';
  signal sclr : std_logic := '0';
  signal x    : std_logic_vector(3 downto 0) := (others => '0');
  signal q    : std_logic_vector(7 downto 0);

  constant Tck : time := 10 ns;

  type int_array_t is array (natural range <>) of integer;
  -- 20 signed 4-bit values in allowed range [-8..7]
  constant seq20 : int_array_t := (
    -8, -7, -6, -5, -4, -3, -2, -1, 0, 1,
     2,  3,  4,  5,  6,  7, -8,  7, -1, 6
  );
begin
  dut : entity work.accumulator_top
    port map(
      ck => ck,
      sclr => sclr,
      x => x,
      q => q
    );

  ck <= not ck after Tck / 2;

  stim : process
    variable expected_sum : integer := 0;
  begin
    sclr <= '1';
    wait until rising_edge(ck);
    wait for 1 ns;
    sclr <= '0';
    wait until rising_edge(ck);
    wait for 1 ns;
    assert signed(q) = to_signed(0, 8)
      report "Accumulator clear failed"
      severity error;

    for i in seq20'range loop
      x <= std_logic_vector(to_signed(seq20(i), 4));
      wait until rising_edge(ck);
      wait for 1 ns;

      expected_sum := expected_sum + seq20(i);
      assert signed(q) = to_signed(expected_sum, 8)
        report "Accumulator mismatch at sample " & integer'image(i)
        severity error;
    end loop;

    report "tb_accumulator_top PASSED" severity note;
    stop;
    wait;
  end process;
end architecture sim;
