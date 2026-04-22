library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package output_limiter is
  constant n : natural := 4;
end package output_limiter;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.output_limiter.all;

entity user_logic is
  generic(
    u : std_logic_vector(n - 1 downto 0) := (others => '1');
    l : std_logic_vector(n - 1 downto 0) := (others => '0')
  );
  port(
    x : in  std_logic_vector(n - 1 downto 0);
    z : out std_logic_vector(n - 1 downto 0)
  );
end entity user_logic;

architecture rtl of user_logic is
begin
  process(x)
  begin
    if unsigned(x) < unsigned(l) then
      z <= l;
    elsif unsigned(x) > unsigned(u) then
      z <= u;
    else
      z <= x;
    end if;
  end process;
end architecture rtl;
