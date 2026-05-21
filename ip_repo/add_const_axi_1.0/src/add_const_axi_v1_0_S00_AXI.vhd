--------------------------------------------------------------------------------
-- add_const_axi_v1_0_S00_AXI.vhd
--
-- ECEC 661/402 - Quiz 2 (real) - AXI4-Lite slave for the add-(-1) user logic
--
-- Word offsets (byte addresses are offset * 4):
--   0x00  X_IN   - R/W.  32-bit signed value driven into user_logic.x.
--                        Reads return the last value written.
--   0x04  Z_OUT  - R.    32-bit signed result z = x - 1 from user_logic.z.
--                        Writes are ignored (Z is driven by the IP-Catalog
--                        adder, not by software).
--   0x08  -      - R/W.  Reserved (returns 0; writes ignored).
--   0x0C  -      - R/W.  Reserved (returns 0; writes ignored).
--
-- The user_logic block is purely combinational (c_addsub latency = 0, no CE),
-- so reading Z_OUT immediately after writing X_IN already yields the new
-- result; no flush write or "go" bit is needed.
--
-- The component instantiation / port map below is the deliverable the quiz
-- hand-out asks for ("S_AXI code where component instantiation and port
-- map").
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity add_const_axi_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4   -- 4 words = 16 bytes
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
end entity add_const_axi_v1_0_S00_AXI;

architecture rtl of add_const_axi_v1_0_S00_AXI is

    constant ADDR_LSB          : integer := 2;   -- word-aligned
    constant OPT_MEM_ADDR_BITS : integer := 1;   -- 4 words

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

    -- Software-visible register: X_IN (slv_reg0).
    signal slv_reg0 : std_logic_vector(31 downto 0);

    -- Combinational result from the user logic (z = x - 1).
    signal core_z : std_logic_vector(31 downto 0);

    signal reg_data_out : std_logic_vector(31 downto 0);

    -- User-logic component declaration (deliverable: this is the
    -- "component instantiation and port map" the quiz asks for).
    component user_logic
        port (
            x : in  std_logic_vector(31 downto 0);
            z : out std_logic_vector(31 downto 0)
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
    -- User-logic instantiation
    --   x <- slv_reg0  (32-bit signed value written by software)
    --   z -> core_z    (= x + (-1) from c_addsub_0; routed into the read mux)
    ----------------------------------------------------------------------------
    U_LOGIC : user_logic
        port map (
            x => slv_reg0,
            z => core_z
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
    --   0x00 (slv_reg0)  : X_IN  - writable
    --   0x04 (Z_OUT)     : ignored (driven by user_logic, not software)
    --   0x08, 0x0C       : reserved
    ----------------------------------------------------------------------------
    p_reg_write : process (S_AXI_ACLK)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                slv_reg0 <= (others => '0');
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
                        when others =>
                            null;
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

    p_read_mux : process (axi_araddr, slv_reg0, core_z)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        case loc_addr is
            when "00" =>
                reg_data_out <= slv_reg0;       -- X_IN readback
            when "01" =>
                reg_data_out <= core_z;         -- Z_OUT = x - 1
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
