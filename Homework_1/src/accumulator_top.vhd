library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity accumulator_top is
  port(
    ck    : in  std_logic;
    sclr  : in  std_logic;
    x     : in  std_logic_vector(3 downto 0);
    q     : out std_logic_vector(7 downto 0)
  );
end entity accumulator_top;

architecture rtl of accumulator_top is
begin
  u_ip : entity work.c_accum_0
    port map(
      B    => x,
      CLK  => ck,
      SCLR => sclr,
      Q    => q
    );
end architecture rtl;
