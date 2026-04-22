--------------------------------------------------------------------------------
-- user_logic.vhd
--
-- ECEC 402/661 - Example Quiz (practice) - IP Catalog Multiplier
--
-- Wraps the Vivado IP-Catalog Multiplier block mult_gen_0:
--     xilinx.com:ip:mult_gen:12.0
--
-- Configuration (must match scripts/setup.tcl):
--   * Parallel Multiplier
--   * Signed/Signed, both inputs 4 bits (-8 .. 7)
--   * Full-width output 8 bits (MSB=7, LSB=0)   -> signed -128 .. 127
--   * Multiplier Construction: Use LUTs, Speed Optimized
--   * Pipeline stages = 2    -> output latency is 2 CLK cycles
--   * Clock Enable / Synchronous Clear disabled
--
-- Behaviour:
--   z(t+2) = x(t) * y(t)    (interpreting all three as signed)
--
-- The entity signature is kept verbatim from the quiz hand-out, including the
-- UNISIM library clause, so that the file drops straight into the quiz project
-- without modification.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.Vcomponents.all;

entity user_logic is
  Port (ck : IN STD_LOGIC;
    x, y : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    z : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)  );
end user_logic;

architecture rtl of user_logic is

  -- Vivado IP-Catalog Multiplier v12.0 (elaborated from the generated XCI).
  component mult_gen_0
    port (
      CLK : in  std_logic;
      A   : in  std_logic_vector(3 downto 0);
      B   : in  std_logic_vector(3 downto 0);
      P   : out std_logic_vector(7 downto 0)
    );
  end component;

begin

  U_MULT : mult_gen_0
    port map (
      CLK => ck,
      A   => x,
      B   => y,
      P   => z
    );

end architecture rtl;
