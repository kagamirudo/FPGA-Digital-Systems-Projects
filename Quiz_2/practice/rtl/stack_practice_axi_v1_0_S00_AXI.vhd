--------------------------------------------------------------------------------
-- stack_practice_axi_v1_0_S00_AXI.vhd
--
-- ECEC 661 - Quiz 2 practice - AXI4-Lite register map for user_logic
--
-- Word offsets (byte addresses are offset * 4):
--   0x00 DATA_IN  - R/W. Value pushed by a PUSH command.
--   0x04 COMMAND  - W.   bit 0 = PUSH, bit 1 = POP, bit 2 = CLEAR.
--                   If multiple bits are set, CLEAR wins, then POP, then PUSH.
--   0x08 DATA_OUT - R.   Last value popped from the stack.
--   0x0C STATUS   - R.   bits [3:0] = count, bit 8 = empty,
--                         bit 9 = full, bit 10 = sticky error.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stack_practice_axi_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4
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
end entity stack_practice_axi_v1_0_S00_AXI;

architecture rtl of stack_practice_axi_v1_0_S00_AXI is

    constant ADDR_LSB          : integer := 2;
    constant OPT_MEM_ADDR_BITS : integer := 1;

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

    signal slv_reg0 : std_logic_vector(31 downto 0);  -- DATA_IN
    signal slv_reg1 : std_logic_vector(31 downto 0);  -- last COMMAND write

    signal cmd_valid : std_logic;
    signal cmd       : std_logic_vector(1 downto 0);
    signal data_out  : std_logic_vector(31 downto 0);
    signal count     : std_logic_vector(3 downto 0);
    signal empty     : std_logic;
    signal full      : std_logic;
    signal error     : std_logic;

    signal reg_data_out : std_logic_vector(31 downto 0);

begin

    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= axi_bresp;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= axi_rresp;
    S_AXI_RVALID  <= axi_rvalid;

    u_logic : entity work.user_logic
        generic map (
            DATA_WIDTH => 32,
            DEPTH      => 8
        )
        port map (
            ck        => S_AXI_ACLK,
            resetn    => S_AXI_ARESETN,
            cmd_valid => cmd_valid,
            cmd       => cmd,
            data_in   => slv_reg0,
            data_out  => data_out,
            count     => count,
            empty     => empty,
            full      => full,
            error     => error
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

    p_reg_write : process (S_AXI_ACLK)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                slv_reg0  <= (others => '0');
                slv_reg1  <= (others => '0');
                cmd_valid <= '0';
                cmd       <= "00";
            else
                cmd_valid <= '0';
                cmd       <= "00";

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
                            slv_reg1  <= S_AXI_WDATA;
                            cmd_valid <= '1';
                            if S_AXI_WDATA(2) = '1' then
                                cmd <= "11";  -- clear
                            elsif S_AXI_WDATA(1) = '1' then
                                cmd <= "10";  -- pop
                            elsif S_AXI_WDATA(0) = '1' then
                                cmd <= "01";  -- push
                            else
                                cmd <= "00";
                            end if;

                        when others =>
                            null;  -- DATA_OUT and STATUS are read-only
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

    p_read_mux : process (axi_araddr, slv_reg0, slv_reg1, data_out, count, empty, full, error)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
        variable status   : std_logic_vector(31 downto 0);
    begin
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        status := (others => '0');
        status(3 downto 0) := count;
        status(8)  := empty;
        status(9)  := full;
        status(10) := error;

        case loc_addr is
            when "00" =>
                reg_data_out <= slv_reg0;
            when "01" =>
                reg_data_out <= slv_reg1;
            when "10" =>
                reg_data_out <= data_out;
            when others =>
                reg_data_out <= status;
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
