--------------------------------------------------------------------------------
-- sp101_axi_v1_0_S00_AXI.vhd
--
-- ECEC 661 - Homework 5 - Stack Processor 101 IP (AXI4-Lite slave)
--
-- Five word-aligned registers (32-byte aperture).  Mapping matches the
-- assignment PDF's `// Registers/Ports Mapping` comment block:
--
--     Word offset (byte)  Name      Access  Description
--     ------------------  --------  ------  -------------------------------
--       0  (0x00)         slv_reg0  R/W     control bits:
--                                              bit 0 = run
--                                              bit 1 = reset
--                                              bit 2 = bus2mem_en
--                                              bit 3 = bus2mem_we
--       1  (0x04)         slv_reg1  R/W     bus2mem_addr (lower 10 bits)
--       2  (0x08)         slv_reg2  R/W     bus2mem_data_in (32-bit)
--       3  (0x0C)         slv_reg3  R       sp2bus_data_out (32-bit)
--       4  (0x10)         slv_reg4  R       done flag (bit 0)
--
-- The bare-metal test app's offsets land directly on these slots, so the
-- assignment's reference C snippet (write 0,4,8; read 12,16) works
-- unchanged:
--
--     SP101_mWriteReg(BASE,  0, 0xE);            -- reset+bus2mem_en+bus2mem_we
--     SP101_mWriteReg(BASE,  4, addr);           -- bus2mem_addr
--     SP101_mWriteReg(BASE,  8, data);           -- bus2mem_data_in
--     val = SP101_mReadReg(BASE, 12);            -- sp2bus_data_out
--     while ((SP101_mReadReg(BASE, 16) & 1) == 0); -- spin on done
--
-- The slave stores the writable registers, drives the read-only ones from
-- the user_logic core, and instantiates a single `user_logic` (the stack
-- processor) clocked by S_AXI_ACLK.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sp101_axi_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 5      -- 8 words = 32 bytes
    );
    port (
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;
        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic
    );
end entity sp101_axi_v1_0_S00_AXI;

architecture rtl of sp101_axi_v1_0_S00_AXI is

    constant ADDR_LSB          : integer := 2;  -- word-aligned
    constant OPT_MEM_ADDR_BITS : integer := 2;  -- 8 words = 5 visible + spare

    signal axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_bvalid  : std_logic;
    signal axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_arready : std_logic;
    signal axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_rresp   : std_logic_vector(1 downto 0);
    signal axi_rvalid  : std_logic;
    signal aw_en       : std_logic;

    signal slv_reg_wren : std_logic;
    signal slv_reg_rden : std_logic;

    -- Software-writable registers
    signal slv_reg0 : std_logic_vector(31 downto 0);  -- control
    signal slv_reg1 : std_logic_vector(31 downto 0);  -- bus2mem_addr
    signal slv_reg2 : std_logic_vector(31 downto 0);  -- bus2mem_data_in

    -- Core wires (driven by user_logic)
    signal core_sp2bus_data_out : std_logic_vector(31 downto 0);
    signal core_done            : std_logic;

    signal reg_data_out : std_logic_vector(31 downto 0);

    component user_logic
        generic (
            A : natural := 10
        );
        port (
            run             : in  std_logic;
            reset           : in  std_logic;
            bus2mem_en      : in  std_logic;
            bus2mem_we      : in  std_logic;
            ck              : in  std_logic;
            bus2mem_addr    : in  std_logic_vector(A-1 downto 0);
            bus2mem_data_in : in  std_logic_vector(31 downto 0);
            sp2bus_data_out : out std_logic_vector(31 downto 0);
            done            : out std_logic
        );
    end component;

begin

    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= axi_bresp;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= axi_rresp;
    S_AXI_RVALID  <= axi_rvalid;

    ----------------------------------------------------------------------------
    -- Stack processor (user_logic) instantiation
    -- Control bits are sliced straight from slv_reg0 :
    --   bit 0 = run, bit 1 = reset, bit 2 = bus2mem_en, bit 3 = bus2mem_we
    -- bus2mem_addr is the lower 10 bits of slv_reg1.
    -- bus2mem_data_in is the full 32 bits of slv_reg2.
    -- sp2bus_data_out and done feed back to the read mux.
    ----------------------------------------------------------------------------
    U : user_logic
        generic map (
            A => 10
        )
        port map (
            run             => slv_reg0(0),
            reset           => slv_reg0(1),
            bus2mem_en      => slv_reg0(2),
            bus2mem_we      => slv_reg0(3),
            ck              => S_AXI_ACLK,
            bus2mem_addr    => slv_reg1(9 downto 0),
            bus2mem_data_in => slv_reg2,
            sp2bus_data_out => core_sp2bus_data_out,
            done            => core_done
        );

    ----------------------------------------------------------------------------
    -- AXI4-Lite write address channel
    ----------------------------------------------------------------------------
    p_awready : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                aw_en       <= '1';
            else
                if axi_awready = '0' and S_AXI_AWVALID = '1'
                   and S_AXI_WVALID = '1' and aw_en = '1' then
                    axi_awready <= '1';
                    aw_en       <= '0';
                elsif S_AXI_BREADY = '1' and axi_bvalid = '1' then
                    aw_en       <= '1';
                    axi_awready <= '0';
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process p_awready;

    p_awaddr : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awaddr <= (others => '0');
            else
                if axi_awready = '0' and S_AXI_AWVALID = '1'
                   and S_AXI_WVALID = '1' and aw_en = '1' then
                    axi_awaddr <= S_AXI_AWADDR;
                end if;
            end if;
        end if;
    end process p_awaddr;

    ----------------------------------------------------------------------------
    -- AXI4-Lite write data channel
    ----------------------------------------------------------------------------
    p_wready : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_wready <= '0';
            else
                if axi_wready = '0' and S_AXI_AWVALID = '1'
                   and S_AXI_WVALID = '1' and aw_en = '1' then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process p_wready;

    slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;

    ----------------------------------------------------------------------------
    -- Register writes
    --   slv_reg0 (control)         : writable
    --   slv_reg1 (bus2mem_addr)    : writable, lower 10 bits used
    --   slv_reg2 (bus2mem_data_in) : writable
    --   slv_reg3 (sp2bus_data_out) : NOT writable (driven by core)
    --   slv_reg4 (done)            : NOT writable (driven by core)
    ----------------------------------------------------------------------------
    p_reg_write : process (S_AXI_ACLK)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                slv_reg0 <= (others => '0');
                slv_reg1 <= (others => '0');
                slv_reg2 <= (others => '0');
            else
                if slv_reg_wren = '1' then
                    loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
                    case loc_addr is
                        when "000" =>
                            for b in 0 to (C_S_AXI_DATA_WIDTH/8) - 1 loop
                                if S_AXI_WSTRB(b) = '1' then
                                    slv_reg0(b*8 + 7 downto b*8) <=
                                        S_AXI_WDATA(b*8 + 7 downto b*8);
                                end if;
                            end loop;
                        when "001" =>
                            for b in 0 to (C_S_AXI_DATA_WIDTH/8) - 1 loop
                                if S_AXI_WSTRB(b) = '1' then
                                    slv_reg1(b*8 + 7 downto b*8) <=
                                        S_AXI_WDATA(b*8 + 7 downto b*8);
                                end if;
                            end loop;
                        when "010" =>
                            for b in 0 to (C_S_AXI_DATA_WIDTH/8) - 1 loop
                                if S_AXI_WSTRB(b) = '1' then
                                    slv_reg2(b*8 + 7 downto b*8) <=
                                        S_AXI_WDATA(b*8 + 7 downto b*8);
                                end if;
                            end loop;
                        when others =>
                            null;  -- 0x0C, 0x10 are read-only (core driven)
                    end case;
                end if;
            end if;
        end if;
    end process p_reg_write;

    ----------------------------------------------------------------------------
    -- AXI4-Lite write response channel
    ----------------------------------------------------------------------------
    p_bvalid : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_bvalid <= '0';
                axi_bresp  <= "00";
            else
                if axi_awready = '1' and S_AXI_AWVALID = '1'
                   and axi_wready = '1' and S_AXI_WVALID = '1'
                   and axi_bvalid = '0' then
                    axi_bvalid <= '1';
                    axi_bresp  <= "00";
                elsif S_AXI_BREADY = '1' and axi_bvalid = '1' then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process p_bvalid;

    ----------------------------------------------------------------------------
    -- AXI4-Lite read address channel
    ----------------------------------------------------------------------------
    p_arready : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_arready <= '0';
                axi_araddr  <= (others => '0');
            else
                if axi_arready = '0' and S_AXI_ARVALID = '1' then
                    axi_arready <= '1';
                    axi_araddr  <= S_AXI_ARADDR;
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process p_arready;

    ----------------------------------------------------------------------------
    -- AXI4-Lite read data channel
    ----------------------------------------------------------------------------
    p_rvalid : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rvalid <= '0';
                axi_rresp  <= "00";
            else
                if axi_arready = '1' and S_AXI_ARVALID = '1'
                   and axi_rvalid = '0' then
                    axi_rvalid <= '1';
                    axi_rresp  <= "00";
                elsif axi_rvalid = '1' and S_AXI_RREADY = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process p_rvalid;

    slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);

    p_read_mux : process (axi_araddr, slv_reg0, slv_reg1, slv_reg2,
                          core_sp2bus_data_out, core_done)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        reg_data_out <= (others => '0');
        case loc_addr is
            when "000" =>
                reg_data_out <= slv_reg0;
            when "001" =>
                reg_data_out <= slv_reg1;
            when "010" =>
                reg_data_out <= slv_reg2;
            when "011" =>
                reg_data_out <= core_sp2bus_data_out;
            when "100" =>
                reg_data_out <= (31 downto 1 => '0') & core_done;
            when others =>
                reg_data_out <= (others => '0');
        end case;
    end process p_read_mux;

    p_rdata : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rdata <= (others => '0');
            else
                if slv_reg_rden = '1' then
                    axi_rdata <= reg_data_out;
                end if;
            end if;
        end if;
    end process p_rdata;

end architecture rtl;
