library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.output_limiter.all;

entity tb_output_limiter is
end entity tb_output_limiter;

architecture sim of tb_output_limiter is
  signal x : std_logic_vector(n - 1 downto 0) := (others => '0');
  signal z : std_logic_vector(n - 1 downto 0);
begin
  dut : entity work.user_logic
    generic map(
      u => "1010", -- 10
      l => "0101"  -- 5
    )
    port map(
      x => x,
      z => z
    );

  stim : process
    variable expected : unsigned(n - 1 downto 0);
  begin
    for i in 0 to (2 ** n) - 1 loop
      x <= std_logic_vector(to_unsigned(i, n));
      wait for 10 ns;

      if i < 5 then
        expected := to_unsigned(5, n);
      elsif i > 10 then
        expected := to_unsigned(10, n);
      else
        expected := to_unsigned(i, n);
      end if;

      assert unsigned(z) = expected
        report "Limiter mismatch at x=" & integer'image(i)
        severity error;
    end loop;

    report "tb_output_limiter PASSED" severity note;
    stop;
    wait;
  end process;
end architecture sim;
