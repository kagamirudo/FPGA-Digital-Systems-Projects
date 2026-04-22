--------------------------------------------------------------------------------
-- fix_acc_core.vhd
--
-- ECEC 661 - Homework 3 - Problem 8.7.2 Fixed-Point Accumulator IP
--
-- Thin user-logic wrapper around the Vivado IP-Catalog Accumulator
--     xilinx.com:ip:c_accum:12.0
--
-- Operation:
--     On the rising edge of CLK, Q <= Q + B
--     When SCLR = '1', Q is synchronously zeroed (SCLR takes priority over add).
--     Output latency = 1 clock (Q is registered inside c_accum_0).
--
-- This entity is instantiated by the AXI4-Lite slave (fix_acc_axi_v1_0_S00_AXI),
-- where the slave write-enable strobe (slv_reg_wren) is wired to CLK so that
-- every AXI write to the IP advances the accumulator by exactly one step.
--
-- Ports kept at the book's signature (B/CLK/SCLR/Q) so the port map between the
-- slave and the IP-Catalog block is a direct 1:1 pass-through.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity fix_acc_core is
    port (
        B    : in  std_logic_vector(31 downto 0);  -- accumulator input
        CLK  : in  std_logic;                      -- driven by slv_reg_wren
        SCLR : in  std_logic;                      -- synchronous clear
        Q    : out std_logic_vector(31 downto 0)   -- accumulator output
    );
end entity fix_acc_core;

architecture rtl of fix_acc_core is

    -- Vivado IP-Catalog Accumulator v12.0 (black box; elaborated from XCI)
    component c_accum_0
        port (
            B    : in  std_logic_vector(31 downto 0);
            CLK  : in  std_logic;
            SCLR : in  std_logic;
            Q    : out std_logic_vector(31 downto 0)
        );
    end component;

begin

    U_ACC : c_accum_0
        port map (
            B    => B,
            CLK  => CLK,
            SCLR => SCLR,
            Q    => Q
        );

end architecture rtl;
