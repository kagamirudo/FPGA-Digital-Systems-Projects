--------------------------------------------------------------------------------
-- bus_ip_mem_bridge.vhd
--
-- ECEC 661 - Homework 5 - Stack Processor 101 with `scpb`
--
-- Bridge between the AXI bus (via slv_reg* / `bus2mem_*`) and the user IP
-- (the stack processor's `ip2mem_*` signals) into the single port of
-- blk_mem_gen_0.
--
--   * When bus2mem_en = '1', the bus owns the BRAM port - software preloads
--     the program and data memory and reads back results.
--   * When bus2mem_en = '0', the stack processor owns the BRAM port and
--     executes the loaded program.
--
-- A `busy` flag back to the processor lets `idle`->`fetch` poll for bus
-- ownership being released (the assignment processor does `if run='1' and
-- busy='0' then n_s <= fetch;`).
--
-- This file is the exact bridge from the assignment PDF, lifted with only
-- formatting changes so the `setup.tcl` script can compile it directly.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity bus_ip_mem_bridge is
    generic (
        A : natural := 10
    );
    port (
        ip2mem_data_in  : in  std_logic_vector(31 downto 0);
        bus2mem_data_in : in  std_logic_vector(31 downto 0);
        ip2mem_addr     : in  std_logic_vector(A-1 downto 0);
        bus2mem_addr    : in  std_logic_vector(A-1 downto 0);
        bus2mem_we      : in  std_logic_vector(0 downto 0);
        ip2mem_we       : in  std_logic_vector(0 downto 0);
        bus2mem_en      : in  std_logic;
        addra           : out std_logic_vector(A-1 downto 0);
        dina            : out std_logic_vector(31 downto 0);
        wea             : out std_logic_vector(0 downto 0);
        busy            : out std_logic
    );
end entity bus_ip_mem_bridge;

architecture rtl of bus_ip_mem_bridge is
begin

    p_mux : process (bus2mem_addr, bus2mem_data_in,
                     ip2mem_addr,  ip2mem_data_in,
                     bus2mem_we,   ip2mem_we,
                     bus2mem_en)
    begin
        if bus2mem_en = '1' then
            wea   <= bus2mem_we;
            addra <= bus2mem_addr;
            dina  <= bus2mem_data_in;
            busy  <= '1';
        else
            wea   <= ip2mem_we;
            addra <= ip2mem_addr;
            dina  <= ip2mem_data_in;
            busy  <= '0';
        end if;
    end process p_mux;

end architecture rtl;
