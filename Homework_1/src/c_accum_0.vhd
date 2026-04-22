library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Behavioral stand-in for Vivado C_ACCUM IP (4-bit signed in, 8-bit signed out).
entity c_accum_0 is
  port(
    B    : in  std_logic_vector(3 downto 0);
    CLK  : in  std_logic;
    SCLR : in  std_logic;
    Q    : out std_logic_vector(7 downto 0)
  );
end entity c_accum_0;

architecture rtl of c_accum_0 is
  signal acc : signed(7 downto 0) := (others => '0');
begin
  process(CLK)
  begin
    if rising_edge(CLK) then
      if SCLR = '1' then
        acc <= (others => '0');
      else
        acc <= acc + resize(signed(B), 8);
      end if;
    end if;
  end process;

  Q <= std_logic_vector(acc);
end architecture rtl;
