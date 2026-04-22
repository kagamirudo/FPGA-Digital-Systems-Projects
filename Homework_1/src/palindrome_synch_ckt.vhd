library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity palindrome_synch_ckt is
  generic(n : natural := 5);
  port(
    x, y, ck, reset : in  std_logic;
    z               : out std_logic
  );
end entity palindrome_synch_ckt;

architecture rtl of palindrome_synch_ckt is
  signal x_shift : std_logic_vector(n - 1 downto 0) := (others => '0');
  signal y_shift : std_logic_vector(n - 1 downto 0) := (others => '0');
  signal count   : natural range 0 to n := 0;
  signal z_reg   : std_logic := '0';

  function reverse_bits(v : std_logic_vector) return std_logic_vector is
    variable r : std_logic_vector(v'range);
  begin
    for i in 0 to v'length - 1 loop
      r(i) := v(v'length - 1 - i);
    end loop;
    return r;
  end function;
begin
  z <= z_reg;

  process(ck)
    variable x_next : std_logic_vector(n - 1 downto 0);
    variable y_next : std_logic_vector(n - 1 downto 0);
  begin
    if rising_edge(ck) then
      if reset = '1' then
        x_shift <= (others => '0');
        y_shift <= (others => '0');
        count   <= 0;
        z_reg   <= '0';
      else
        if count < n then
          x_next := x_shift(n - 2 downto 0) & x;
          y_next := y_shift(n - 2 downto 0) & y;

          x_shift <= x_next;
          y_shift <= y_next;
          count   <= count + 1;

          -- Evaluate exactly after the n-th sample is captured.
          if count = n - 1 then
            if x_next = reverse_bits(y_next) then
              z_reg <= '1';
            else
              z_reg <= '0';
            end if;
          end if;
        else
          if x_shift = reverse_bits(y_shift) then
            z_reg <= '1';
          else
            z_reg <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
