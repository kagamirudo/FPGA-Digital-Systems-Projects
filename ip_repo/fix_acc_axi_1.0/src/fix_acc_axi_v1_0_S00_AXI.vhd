--------------------------------------------------------------------------------
-- fix_acc_axi_v1_0_S00_AXI.vhd
--
-- ECEC 661 - Homework 3 - Problem 8.7.2 Fixed-Point Accumulator IP
--
-- AXI4-Lite slave interface for the fix_acc_core user logic.
--
-- Word offsets (byte addresses are offset * 4):
--   0x00 B_IN    - R/W.  Writing advances the accumulator by the written value
--                        (because the write strobe slv_reg_wren is wired to the
--                        accumulator's CLK port).  Reads return the last
--                        written value for debug.
--   0x04 Q_OUT   - R.    32-bit signed accumulator output.  AXI writes to this
--                        address are ignored by design (Q is driven by the
--                        core, not by software).
--   0x08 CTRL    - R/W.  Bit 0 = SCLR (synchronous clear of the accumulator).
--                        Software pulses this high, then low, to zero Q.
--
-- The "slv_reg_wren drives CLK" trick comes straight from the textbook
-- (Digital Systems Projects, section 8.7.2, p. 445): every AXI write causes
-- exactly one rising edge of slv_reg_wren, which is one accumulator step.
-- SCLR has priority, so writes to the CTRL register that assert SCLR zero
-- the accumulator instead of accumulating the current B_IN.
--
-- Latency is 1 clock from B_IN to Q_OUT.  Software that wants to read the
-- final sum after a sequence of writes must issue one extra "flush" write to
-- clock the last value through the output register; see docs/register_map.md.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fix_acc_axi_v1_0_S00_AXI is
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
end entity fix_acc_axi_v1_0_S00_AXI;

architecture rtl of fix_acc_axi_v1_0_S00_AXI is

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

    -- Addressable software-visible registers
    signal slv_reg0 : std_logic_vector(31 downto 0);  -- B_IN
    signal slv_reg2 : std_logic_vector(31 downto 0);  -- CTRL (bit 0 = SCLR)

    -- Core wires
    signal core_q : std_logic_vector(31 downto 0);

    signal reg_data_out : std_logic_vector(31 downto 0);

    -- fix_acc_core: wraps the IP-Catalog c_accum_0 block.
    component fix_acc_core
        port (
            B    : in  std_logic_vector(31 downto 0);
            CLK  : in  std_logic;
            SCLR : in  std_logic;
            Q    : out std_logic_vector(31 downto 0)
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
    -- User logic instantiation (book p. 445)
    -- CLK  <- slv_reg_wren   : every AXI write advances the accumulator
    -- SCLR <- slv_reg2(0)    : synchronous clear from software
    -- B    <- slv_reg0       : accumulator input value
    -- Q    -> core_q         : accumulator output (routed to the read mux)
    ----------------------------------------------------------------------------
    U : fix_acc_core
        port map (
            B    => slv_reg0,
            CLK  => slv_reg_wren,
            SCLR => slv_reg2(0),
            Q    => core_q
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
    -- slv_reg0 (B_IN)  : writable
    -- slv_reg1 (Q_OUT) : NOT writable from AXI; driven by the accumulator core
    -- slv_reg2 (CTRL)  : writable, bit 0 = SCLR
    -- slv_reg3         : reserved, ignored
    ----------------------------------------------------------------------------
    p_reg_write : process (S_AXI_ACLK)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                slv_reg0 <= (others => '0');
                slv_reg2 <= (others => '0');
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
                        when "10" =>
                            for b in 0 to (C_S_AXI_DATA_WIDTH/8) - 1 loop
                                if S_AXI_WSTRB(b) = '1' then
                                    slv_reg2(b*8 + 7 downto b*8) <=
                                        S_AXI_WDATA(b*8 + 7 downto b*8);
                                end if;
                            end loop;
                        when others =>
                            null;  -- 0x04 (Q_OUT) is read-only; 0x0C reserved
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

    p_read_mux : process (axi_araddr, slv_reg0, core_q, slv_reg2)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        reg_data_out <= (others => '0');
        case loc_addr is
            when "00" =>
                reg_data_out <= slv_reg0;     -- B_IN readback
            when "01" =>
                reg_data_out <= core_q;       -- Q_OUT from accumulator
            when "10" =>
                reg_data_out <= slv_reg2;     -- CTRL (SCLR)
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
