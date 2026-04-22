--------------------------------------------------------------------------------
-- fib_axi_v1_0.vhd
--
-- Top level of the Fibonacci AXI4-Lite IP.  Wires the AXI slave
-- register block to the compute core.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity fib_axi_v1_0 is
    generic (
        C_S00_AXI_DATA_WIDTH : integer := 32;
        C_S00_AXI_ADDR_WIDTH : integer := 4
    );
    port (
        s00_axi_aclk    : in  std_logic;
        s00_axi_aresetn : in  std_logic;
        s00_axi_awaddr  : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_awprot  : in  std_logic_vector(2 downto 0);
        s00_axi_awvalid : in  std_logic;
        s00_axi_awready : out std_logic;
        s00_axi_wdata   : in  std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_wstrb   : in  std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
        s00_axi_wvalid  : in  std_logic;
        s00_axi_wready  : out std_logic;
        s00_axi_bresp   : out std_logic_vector(1 downto 0);
        s00_axi_bvalid  : out std_logic;
        s00_axi_bready  : in  std_logic;
        s00_axi_araddr  : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_arprot  : in  std_logic_vector(2 downto 0);
        s00_axi_arvalid : in  std_logic;
        s00_axi_arready : out std_logic;
        s00_axi_rdata   : out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_rresp   : out std_logic_vector(1 downto 0);
        s00_axi_rvalid  : out std_logic;
        s00_axi_rready  : in  std_logic
    );
end entity fib_axi_v1_0;

architecture rtl of fib_axi_v1_0 is

    signal rst          : std_logic;
    signal fib_start    : std_logic;
    signal fib_n        : std_logic_vector(31 downto 0);
    signal fib_result   : std_logic_vector(31 downto 0);
    signal fib_cycles   : std_logic_vector(31 downto 0);
    signal fib_done     : std_logic;
    signal fib_overflow : std_logic;
    signal fib_busy     : std_logic;

begin

    rst <= not s00_axi_aresetn;

    u_slave : entity work.fib_axi_v1_0_S00_AXI
        generic map (
            C_S_AXI_DATA_WIDTH => C_S00_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
        )
        port map (
            fib_start    => fib_start,
            fib_n        => fib_n,
            fib_result   => fib_result,
            fib_cycles   => fib_cycles,
            fib_done     => fib_done,
            fib_overflow => fib_overflow,
            fib_busy     => fib_busy,

            S_AXI_ACLK    => s00_axi_aclk,
            S_AXI_ARESETN => s00_axi_aresetn,
            S_AXI_AWADDR  => s00_axi_awaddr,
            S_AXI_AWPROT  => s00_axi_awprot,
            S_AXI_AWVALID => s00_axi_awvalid,
            S_AXI_AWREADY => s00_axi_awready,
            S_AXI_WDATA   => s00_axi_wdata,
            S_AXI_WSTRB   => s00_axi_wstrb,
            S_AXI_WVALID  => s00_axi_wvalid,
            S_AXI_WREADY  => s00_axi_wready,
            S_AXI_BRESP   => s00_axi_bresp,
            S_AXI_BVALID  => s00_axi_bvalid,
            S_AXI_BREADY  => s00_axi_bready,
            S_AXI_ARADDR  => s00_axi_araddr,
            S_AXI_ARPROT  => s00_axi_arprot,
            S_AXI_ARVALID => s00_axi_arvalid,
            S_AXI_ARREADY => s00_axi_arready,
            S_AXI_RDATA   => s00_axi_rdata,
            S_AXI_RRESP   => s00_axi_rresp,
            S_AXI_RVALID  => s00_axi_rvalid,
            S_AXI_RREADY  => s00_axi_rready
        );

    u_core : entity work.fib_core
        port map (
            clk      => s00_axi_aclk,
            rst      => rst,
            start    => fib_start,
            n        => fib_n,
            result   => fib_result,
            done     => fib_done,
            overflow => fib_overflow,
            busy     => fib_busy,
            cycles   => fib_cycles
        );

end architecture rtl;
