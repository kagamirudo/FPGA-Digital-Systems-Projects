--------------------------------------------------------------------------------
-- user_logic.vhd
--
-- ECEC 661 - Homework 4 - CORDIC Square Root IP
--
-- Thin wrapper around the Vivado IP-Catalog CORDIC block configured for the
-- Square Root function:
--     xilinx.com:ip:cordic:6.0
--
-- IP configuration (see Fig. 1 in the assignment):
--     Functional Selection      : Square Root
--     Architectural Configuration: Parallel
--     Pipelining Mode           : Maximum
--     Data Format               : UnsignedFraction
--     Phase Format              : Radians
--     Input Width               : 10
--     Output Width              : 10
--     Round Mode                : Truncate
--
-- Q-format at the boundary:
--     x : 2Q7  (10-bit unsigned)  - bits  9 .. 0  of the 16-bit input
--     z : 1Q8  (10-bit unsigned)  - bits  9 .. 0  of the 16-bit output
--
-- The upper six bits of x are unused on input and the upper six bits of z are
-- forced to zero on output, matching the assignment waveform (Fig. 3) where
-- only the low byte/byte-and-a-bit are populated.
--
-- AXI-stream handshake:
--     din_tvalid  -> S_AXIS_CARTESIAN_tvalid
--     dout_tvalid <- M_AXIS_DOUT_tvalid
-- The IP back-pressures via S_AXIS_CARTESIAN_tready; for the deeply pipelined
-- "Maximum" build it is held continuously high under steady traffic, so a
-- well-behaved producer can simply pulse din_tvalid for one cycle per sample
-- (this is what the test bench and the Vitis app do).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity user_logic is
    port (
        ck          : in  std_logic;
        aresetn     : in  std_logic;
        din_tvalid  : in  std_logic;
        x           : in  std_logic_vector(15 downto 0);
        dout_tvalid : out std_logic;
        z           : out std_logic_vector(15 downto 0)
    );
end entity user_logic;

architecture rtl of user_logic is

    ----------------------------------------------------------------------------
    -- CORDIC Square Root IP component declaration
    --
    -- The Vivado CORDIC v6.0 IP byte-pads its TDATA buses, so a 10-bit input /
    -- 10-bit output configuration produces 16-bit wide TDATA channels (the
    -- upper 6 bits being unused per byte alignment of AXI-Stream).
    ----------------------------------------------------------------------------
    component cordic_0
        port (
            aclk                     : in  std_logic;
            s_axis_cartesian_tvalid  : in  std_logic;
            s_axis_cartesian_tdata   : in  std_logic_vector(15 downto 0);
            m_axis_dout_tvalid       : out std_logic;
            m_axis_dout_tdata        : out std_logic_vector(15 downto 0)
        );
    end component;

    signal s_tdata : std_logic_vector(15 downto 0);
    signal m_tdata : std_logic_vector(15 downto 0);

begin

    -- Pack input: 10 valid bits (2Q7) in [9:0]; upper byte-padding bits zero.
    s_tdata(9 downto 0)   <= x(9 downto 0);
    s_tdata(15 downto 10) <= (others => '0');

    U_CORDIC : cordic_0
        port map (
            aclk                    => ck,
            s_axis_cartesian_tvalid => din_tvalid,
            s_axis_cartesian_tdata  => s_tdata,
            m_axis_dout_tvalid      => dout_tvalid,
            m_axis_dout_tdata       => m_tdata
        );

    -- Unpack output: 10 valid bits (1Q8) in [9:0]; mirror to top of 16-bit z.
    z(9 downto 0)   <= m_tdata(9 downto 0);
    z(15 downto 10) <= (others => '0');

end architecture rtl;
