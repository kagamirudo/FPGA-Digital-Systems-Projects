--------------------------------------------------------------------------------
-- user_logic.vhd
--
-- ECEC 661/402 - Quiz 2 (real) - Add-(-1) custom IP
--
-- Thin wrapper around the Vivado IP-Catalog Adder/Subtractor:
--     xilinx.com:ip:c_addsub:12.0
--
-- IP configuration (see scripts/setup.tcl):
--   Implementation     : Fabric
--   Add Mode           : Add          ->  S = A + B
--   A : Signed, 32-bit
--   B : Signed, 32-bit, *Constant Input* = 32'b11111111_11111111_11111111_11111111
--                                         = -1   (two's complement, signed 32)
--   Output Width       : 32
--   Latency            : 0            ->  combinational; no CLK / CE
--   Clock Enable (CE)  : disabled
--
-- Behaviour:
--     z = x + (-1) = x - 1   (interpreting all signals as signed 32)
--
-- Because the IP block has B as an internal constant and no clock, the
-- generated component has only the A and S ports.  The user_logic entity
-- below mirrors the block-symbol shown in the quiz hand-out:
--
--       +---------------+
--   x[31:0] --> A[31:0] | c_addsub_0 | S[31:0] --> z[31:0]
--                       +---------------+
--                              B = -1 (constant)
--
-- This file is the "user_logic" deliverable: it is the *only* HDL between the
-- AXI4-Lite slave and the IP-Catalog block.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity user_logic is
    port (
        x : in  std_logic_vector(31 downto 0);
        z : out std_logic_vector(31 downto 0)
    );
end entity user_logic;

architecture rtl of user_logic is

    -- Vivado IP-Catalog Adder/Subtractor v12.0 (black box; elaborated from XCI).
    --
    -- With Latency = 0 and B configured as a constant input, the only ports
    -- the IP exposes are A (signed input) and S (signed sum).  No CLK, no CE,
    -- no SCLR, no B port.
    component c_addsub_0
        port (
            A : in  std_logic_vector(31 downto 0);
            S : out std_logic_vector(31 downto 0)
        );
    end component;

begin

    U_ADDSUB : c_addsub_0
        port map (
            A => x,
            S => z
        );

end architecture rtl;
