--------------------------------------------------------------------------------
-- cordic_sqrt_axi_v1_0_S00_AXI.vhd
--
-- ECEC 661 - Homework 4 - CORDIC Square Root IP
--
-- AXI4-Lite slave that exposes the user_logic CORDIC square-root core to a
-- Zynq processing system.  Four word-aligned registers (16 bytes total):
--
--   Word offset (byte)  Name           Access  Description
--   ------------------  -------------  ------  -----------------------------
--     0  (0x00)         slv_reg0       R/W     x input, lower 10 bits = 2Q7
--     1  (0x04)         slv_reg1       R/W     din_tvalid, bit 0 only
--     2  (0x08)         slv_reg2       R       z output, lower 10 bits = 1Q8
--     3  (0x0C)         slv_reg3       R       dout_tvalid, bit 0 only
--
-- This mapping matches the assignment's reference C snippet 1:1:
--
--     CORDIC_SQRT_mWriteReg(BASE,  0, x);          // slv_reg0 = x
--     CORDIC_SQRT_mWriteReg(BASE,  4, 1);          // din_tvalid = slv_reg1(0)
--     while(!CORDIC_SQRT_mReadReg(BASE, 12));      // dout_tvalid = slv_reg3(0)
--     CORDIC_SQRT_mWriteReg(BASE,  4, 0);          // lower din_tvalid
--     z = CORDIC_SQRT_mReadReg(BASE, 8);           // slv_reg2 holds z
--
-- Unlike the Homework 3 fix_acc design, slv_reg_wren is NOT wired to a core
-- clock here.  The CORDIC IP runs on S_AXI_ACLK and uses S_AXI_ARESETN; the
-- AXI handshake (din_tvalid / dout_tvalid) is purely software controlled.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_sqrt_axi_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4      -- 4 words = 16 bytes
    );
    port (
        -- AXI4-Lite slave
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
end entity cordic_sqrt_axi_v1_0_S00_AXI;

architecture rtl of cordic_sqrt_axi_v1_0_S00_AXI is

    constant ADDR_LSB          : integer := 2;  -- word-aligned
    constant OPT_MEM_ADDR_BITS : integer := 1;  -- 4 words

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

    -- Software-visible registers
    signal slv_reg0 : std_logic_vector(31 downto 0);  -- x in
    signal slv_reg1 : std_logic_vector(31 downto 0);  -- din_tvalid (bit 0)

    -- Core wires (driven by user_logic)
    signal core_x        : std_logic_vector(15 downto 0);
    signal core_z        : std_logic_vector(15 downto 0);
    signal core_dout_tv  : std_logic;

    signal reg_data_out  : std_logic_vector(31 downto 0);

    component user_logic
        port (
            ck          : in  std_logic;
            aresetn     : in  std_logic;
            din_tvalid  : in  std_logic;
            x           : in  std_logic_vector(15 downto 0);
            dout_tvalid : out std_logic;
            z           : out std_logic_vector(15 downto 0)
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
    -- User logic instantiation
    --   x          <- slv_reg0 [15:0]
    --   din_tvalid <- slv_reg1(0)
    --   z          -> core_z       (mux'd onto slv_reg2 read path)
    --   dout_tv    -> core_dout_tv (mux'd onto slv_reg3 read path, bit 0)
    ----------------------------------------------------------------------------
    core_x <= slv_reg0(15 downto 0);

    U : user_logic
        port map (
            ck          => S_AXI_ACLK,
            aresetn     => S_AXI_ARESETN,
            din_tvalid  => slv_reg1(0),
            x           => core_x,
            dout_tvalid => core_dout_tv,
            z           => core_z
        );

    ----------------------------------------------------------------------------
    -- Write address channel
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
    -- Write data channel
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
    --   slv_reg0 (x)          : writable
    --   slv_reg1 (din_tvalid) : writable, only bit 0 used
    --   slv_reg2 (z)          : NOT writable; driven by user_logic
    --   slv_reg3 (dout_tv)    : NOT writable; driven by user_logic
    ----------------------------------------------------------------------------
    p_reg_write : process (S_AXI_ACLK)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                slv_reg0 <= (others => '0');
                slv_reg1 <= (others => '0');
            else
                if slv_reg_wren = '1' then
                    loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
                    case loc_addr is
                        when "00" =>
                            for b in 0 to (C_S_AXI_DATA_WIDTH/8) - 1 loop
                                if S_AXI_WSTRB(b) = '1' then
                                    slv_reg0(b*8 + 7 downto b*8) <=
                                        S_AXI_WDATA(b*8 + 7 downto b*8);
                                end if;
                            end loop;
                        when "01" =>
                            for b in 0 to (C_S_AXI_DATA_WIDTH/8) - 1 loop
                                if S_AXI_WSTRB(b) = '1' then
                                    slv_reg1(b*8 + 7 downto b*8) <=
                                        S_AXI_WDATA(b*8 + 7 downto b*8);
                                end if;
                            end loop;
                        when others =>
                            null;  -- 0x08 (z) and 0x0C (dout_tv) are read-only
                    end case;
                end if;
            end if;
        end if;
    end process p_reg_write;

    ----------------------------------------------------------------------------
    -- Write response channel
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
    -- Read address channel
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
    -- Read data channel
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

    p_read_mux : process (axi_araddr, slv_reg0, slv_reg1, core_z, core_dout_tv)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        reg_data_out <= (others => '0');
        case loc_addr is
            when "00" =>
                reg_data_out <= slv_reg0;                -- x readback
            when "01" =>
                reg_data_out <= slv_reg1;                -- din_tvalid readback
            when "10" =>
                reg_data_out <= (31 downto 16 => '0') & core_z;  -- z output
            when "11" =>
                reg_data_out <= (31 downto 1  => '0') & core_dout_tv;  -- dout_tv
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
