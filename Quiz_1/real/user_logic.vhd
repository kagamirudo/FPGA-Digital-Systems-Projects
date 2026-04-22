library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

-- 4-bit wide, 6-deep RAM-based shift register.
-- Output z is x delayed by six rising edges of ck, gated by CE, and cleared
-- synchronously by SCLR.  The delay line is the Vivado IP-Catalog
-- "RAM-based Shift Register" (c_shift_ram v12.0) instantiated as a black box.
entity user_logic is
    port (
        x            : in  std_logic_vector(3 downto 0);
        ck, ce, sclr : in  std_logic;
        z            : out std_logic_vector(3 downto 0)
    );
end user_logic;

architecture rtl of user_logic is

    component c_shift_ram_0
        port (
            D    : in  std_logic_vector(3 downto 0);
            CLK  : in  std_logic;
            CE   : in  std_logic;
            SCLR : in  std_logic;
            Q    : out std_logic_vector(3 downto 0)
        );
    end component;

begin

    U_SR : c_shift_ram_0
        port map (
            D    => x,
            CLK  => ck,
            CE   => ce,
            SCLR => sclr,
            Q    => z
        );

end architecture rtl;
