--------------------------------------------------------------------------------
-- user_logic.vhd
--
-- ECEC 661 - Final (real) - Stack Processor 101 + new `ssq` (stack-the-square)
--
-- This file extends the assignment PDF's stack processor (`sc`, `sl`, `ss`,
-- `sadd`, `scp`) with the new unary arithmetic instruction `ssq`
-- ("stack the square").
--
-- Programming model
-- =================
-- The instruction takes the value currently on top of the stack, squares it,
-- and writes the result back on top of the stack.  Stack effect:
--
--     ... x   --ssq-->  ... (x*x)
--
-- After execution the stack pointer still points to the next available
-- address (no net change), exactly as the prompt requires:
--
--     sc 7  ssq  halt
--
-- leaves mem[128] = 49 (since sp is initialised to 128 in `idle`, `sc 7`
-- writes 7 to mem[128] and sets sp = 129, then `ssq` overwrites mem[128]
-- with 7*7 = 49 and leaves sp = 129 = next free slot).
--
-- Opcode choice
-- =============
-- `ssq = 0x00000041`.  This places the new opcode in the unused `0x4x`
-- slot, immediately above the assignment PDF's `sadd = 0x31` family, so
-- none of the existing decoders or constants need to move.
--
-- BRAM timing model
-- =================
-- Identical to the legacy opcodes: every BRAM read inserts the extra
-- `*3` / `*4` micro-step states so the xsim simulation model of
-- `blk_mem_gen_0` lines up with the registered `mem_data_out` chain.
-- The latency budget from "schedule mem_addr <= A" to "state body reads
-- mem_data_out = mem[A]" is +4 cycles, matching the PDF.
--
-- Micro-step plan for `ssq`
-- =========================
--   SSQ      mem_addr <= sp-1    (start read of top-of-stack value)
--   SSQ2     latency
--   SSQ3     latency
--   SSQ4     latency
--   SSQ5     temp1 <= mem_data_out (= x)
--   SSQ6     mem_addr <= sp-1, mem_data_in <= x*x, we = '1',
--            then return to fetch.
--
-- Note that `sp` itself is left unchanged: top-of-stack is at sp-1 both
-- before and after the instruction, so the "next available address"
-- remains sp.  Multiplication uses `numeric_std` and truncates to 32
-- bits via `resize`.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity user_logic is
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
end entity user_logic;

architecture rtl of user_logic is

    ----------------------------------------------------------------------------
    -- BRAM signals
    ----------------------------------------------------------------------------
    signal wea, we   : std_logic_vector(0 downto 0);
    signal addra     : std_logic_vector(A-1 downto 0);
    signal dina      : std_logic_vector(31 downto 0);
    signal douta     : std_logic_vector(31 downto 0);
    signal temp_we   : std_logic_vector(0 downto 0);

    ----------------------------------------------------------------------------
    -- Processor registers
    ----------------------------------------------------------------------------
    signal sp, pc, mem_addr      : std_logic_vector(A-1 downto 0);
    signal mem_data_in           : std_logic_vector(31 downto 0);
    signal mem_data_out          : std_logic_vector(31 downto 0);
    signal mem_data_out_pre      : std_logic_vector(31 downto 0);
    signal ir                    : std_logic_vector(31 downto 0);
    signal temp1, temp2          : std_logic_vector(31 downto 0);

    signal busy, done_FF         : std_logic;

    ----------------------------------------------------------------------------
    -- Machine state
    ----------------------------------------------------------------------------
    type state_t is (idle, fetch, fetch2, fetch3, fetch4, fetch5, exe, chill);
    signal n_s : state_t;

    ----------------------------------------------------------------------------
    -- Instruction Definitions (lowest hex = micro-step within an opcode)
    ----------------------------------------------------------------------------
    constant HALT : std_logic_vector(31 downto 0) := x"000000FF";

    -- sc family (stack-constant push)
    constant SC   : std_logic_vector(31 downto 0) := x"00000001";
    constant SC2  : std_logic_vector(31 downto 0) := x"00000002";
    constant SC3  : std_logic_vector(31 downto 0) := x"00000003";
    constant SC4  : std_logic_vector(31 downto 0) := x"00000004";
    constant SC5  : std_logic_vector(31 downto 0) := x"00000005";

    -- sl family (load from memory)
    constant SL   : std_logic_vector(31 downto 0) := x"00000011";
    constant SL2  : std_logic_vector(31 downto 0) := x"00000012";
    constant SL3  : std_logic_vector(31 downto 0) := x"00000013";
    constant SL4  : std_logic_vector(31 downto 0) := x"00000014";
    constant SL5  : std_logic_vector(31 downto 0) := x"00000015";
    constant SL6  : std_logic_vector(31 downto 0) := x"00000016";
    constant SL7  : std_logic_vector(31 downto 0) := x"00000017";
    constant SL8  : std_logic_vector(31 downto 0) := x"00000018";
    constant SL9  : std_logic_vector(31 downto 0) := x"00000019";

    -- ss family (store to memory)
    constant SS   : std_logic_vector(31 downto 0) := x"00000021";
    constant SS2  : std_logic_vector(31 downto 0) := x"00000022";
    constant SS3  : std_logic_vector(31 downto 0) := x"00000023";
    constant SS4  : std_logic_vector(31 downto 0) := x"00000024";
    constant SS5  : std_logic_vector(31 downto 0) := x"00000025";
    constant SS6  : std_logic_vector(31 downto 0) := x"00000026";

    -- sadd family (pop two, add, push)
    constant SADD  : std_logic_vector(31 downto 0) := x"00000031";
    constant SADD2 : std_logic_vector(31 downto 0) := x"00000032";
    constant SADD3 : std_logic_vector(31 downto 0) := x"00000033";
    constant SADD4 : std_logic_vector(31 downto 0) := x"00000034";
    constant SADD5 : std_logic_vector(31 downto 0) := x"00000035";
    constant SADD6 : std_logic_vector(31 downto 0) := x"00000036";

    -- ssq family (NEW: square the top of stack in place)
    constant SSQ  : std_logic_vector(31 downto 0) := x"00000041";
    constant SSQ2 : std_logic_vector(31 downto 0) := x"00000042";
    constant SSQ3 : std_logic_vector(31 downto 0) := x"00000043";
    constant SSQ4 : std_logic_vector(31 downto 0) := x"00000044";
    constant SSQ5 : std_logic_vector(31 downto 0) := x"00000045";
    constant SSQ6 : std_logic_vector(31 downto 0) := x"00000046";

    -- scp family (single-word copy: pop source, pop dest, copy *source -> dest)
    constant SCP   : std_logic_vector(31 downto 0) := x"00000101";
    constant SCP2  : std_logic_vector(31 downto 0) := x"00000102";
    constant SCP3  : std_logic_vector(31 downto 0) := x"00000103";
    constant SCP4  : std_logic_vector(31 downto 0) := x"00000104";
    constant SCP5  : std_logic_vector(31 downto 0) := x"00000105";
    constant SCP6  : std_logic_vector(31 downto 0) := x"00000106";
    constant SCP7  : std_logic_vector(31 downto 0) := x"00000107";
    constant SCP8  : std_logic_vector(31 downto 0) := x"00000108";
    constant SCP9  : std_logic_vector(31 downto 0) := x"00000109";

    ----------------------------------------------------------------------------
    -- Components
    ----------------------------------------------------------------------------
    component blk_mem_gen_0
        port (
            clka  : in  std_logic;
            ena   : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(9 downto 0);
            dina  : in  std_logic_vector(31 downto 0);
            douta : out std_logic_vector(31 downto 0)
        );
    end component;

    component bus_ip_mem_bridge
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
    end component;

begin

    ----------------------------------------------------------------------------
    -- Bus/IP mux + main memory
    ----------------------------------------------------------------------------
    temp_we(0) <= bus2mem_we;

    bridge : bus_ip_mem_bridge
        generic map (A => A)
        port map (
            bus2mem_addr    => bus2mem_addr,
            bus2mem_data_in => bus2mem_data_in,
            ip2mem_addr     => mem_addr,
            ip2mem_data_in  => mem_data_in,
            bus2mem_we      => temp_we,
            ip2mem_we       => we,
            bus2mem_en      => bus2mem_en,
            addra           => addra,
            dina            => dina,
            wea             => wea,
            busy            => busy
        );

    mm : blk_mem_gen_0
        port map (
            clka  => ck,
            ena   => '1',
            wea   => wea,
            addra => addra,
            dina  => dina,
            douta => douta
        );

    ----------------------------------------------------------------------------
    -- mem_data_out register chain.
    --
    -- Latency budget:
    --   edge T   : state body schedules mem_addr <= A
    --   edge T+1 : BRAM samples addra = A;  douta <= mem[A]
    --   edge T+2 : mem_data_out_pre  <= douta = mem[A]
    --   edge T+3 : mem_data_out      <= mem_data_out_pre = mem[A]
    --   edge T+4 : state body (= state X+4) reads mem_data_out = mem[A]
    --
    -- This chain intentionally does NOT clear on `reset='1'` so the AXI
    -- driver can hold reset while it dumps memory through the bridge.
    ----------------------------------------------------------------------------
    p_mdo : process (ck)
    begin
        if rising_edge(ck) then
            mem_data_out_pre <= douta;
            mem_data_out     <= mem_data_out_pre;
        end if;
    end process p_mdo;

    sp2bus_data_out <= mem_data_out;
    done            <= done_FF;

    ----------------------------------------------------------------------------
    -- Stack Processor : fetch / execute / chill
    ----------------------------------------------------------------------------
    p_cpu : process (ck)
    begin
        if rising_edge(ck) then
            if reset = '1' then
                n_s <= idle;
            else
                case n_s is

                    when chill =>
                        null;

                    when idle =>
                        pc          <= (others => '0');
                        sp          <= (7 => '1', others => '0');  -- base = 128
                        ir          <= (others => '0');
                        temp1       <= (others => '0');
                        temp2       <= (others => '0');
                        mem_addr    <= (others => '0');
                        mem_data_in <= (others => '0');
                        we          <= "0";
                        done_FF     <= '0';
                        if run = '1' and busy = '0' then
                            n_s <= fetch;
                        end if;

                    ------------------------------------------------------------
                    -- fetch / fetch2 .. fetch5 : pc -> ir
                    ------------------------------------------------------------
                    when fetch =>
                        mem_addr <= pc;
                        pc       <= std_logic_vector(unsigned(pc) + 1);
                        we       <= "0";
                        n_s      <= fetch2;

                    when fetch2 =>
                        we  <= "0";
                        n_s <= fetch3;

                    when fetch3 =>
                        we  <= "0";
                        n_s <= fetch4;

                    when fetch4 =>
                        we  <= "0";
                        n_s <= fetch5;

                    when fetch5 =>
                        we  <= "0";
                        ir  <= mem_data_out;
                        n_s <= exe;

                    ------------------------------------------------------------
                    -- exe : decode ir; each opcode walks ir through its
                    -- micro-steps in place and finally sets n_s <= fetch.
                    ------------------------------------------------------------
                    when exe =>
                        case ir is

                            when HALT =>
                                done_FF <= '1';
                                n_s     <= chill;

                            ----------------------------------------------------
                            -- sc : push constant pointed to by pc
                            ----------------------------------------------------
                            when SC =>
                                mem_addr <= pc;
                                pc       <= std_logic_vector(unsigned(pc) + 1);
                                we       <= "0";
                                ir       <= SC2;
                            when SC2 =>
                                we <= "0";
                                ir <= SC3;
                            when SC3 =>
                                we <= "0";
                                ir <= SC4;
                            when SC4 =>
                                we <= "0";
                                ir <= SC5;
                            when SC5 =>
                                mem_addr    <= sp;
                                sp          <= std_logic_vector(unsigned(sp) + 1);
                                mem_data_in <= mem_data_out;
                                we          <= "1";
                                n_s         <= fetch;

                            ----------------------------------------------------
                            -- sl : pop address, load *address onto stack
                            ----------------------------------------------------
                            when SL =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SL2;
                            when SL2 =>
                                we <= "0";
                                ir <= SL3;
                            when SL3 =>
                                we <= "0";
                                ir <= SL4;
                            when SL4 =>
                                we <= "0";
                                ir <= SL5;
                            when SL5 =>
                                mem_addr <= mem_data_out(A-1 downto 0);
                                we       <= "0";
                                ir       <= SL6;
                            when SL6 =>
                                we <= "0";
                                ir <= SL7;
                            when SL7 =>
                                we <= "0";
                                ir <= SL8;
                            when SL8 =>
                                we <= "0";
                                ir <= SL9;
                            when SL9 =>
                                mem_addr    <= sp;
                                sp          <= std_logic_vector(unsigned(sp) + 1);
                                mem_data_in <= mem_data_out;
                                we          <= "1";
                                n_s         <= fetch;

                            ----------------------------------------------------
                            -- ss : pop data, pop address, mem[address] <= data
                            ----------------------------------------------------
                            when SS =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SS2;
                            when SS2 =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SS3;
                            when SS3 =>
                                we <= "0";
                                ir <= SS4;
                            when SS4 =>
                                we <= "0";
                                ir <= SS5;
                            when SS5 =>
                                we    <= "0";
                                temp1 <= mem_data_out;
                                ir    <= SS6;
                            when SS6 =>
                                mem_addr    <= mem_data_out(A-1 downto 0);
                                mem_data_in <= temp1;
                                we          <= "1";
                                n_s         <= fetch;

                            ----------------------------------------------------
                            -- sadd : pop two, push (a+b)
                            ----------------------------------------------------
                            when SADD =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SADD2;
                            when SADD2 =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SADD3;
                            when SADD3 =>
                                we <= "0";
                                ir <= SADD4;
                            when SADD4 =>
                                we <= "0";
                                ir <= SADD5;
                            when SADD5 =>
                                we    <= "0";
                                temp1 <= mem_data_out;
                                ir    <= SADD6;
                            when SADD6 =>
                                mem_addr    <= sp;
                                sp          <= std_logic_vector(unsigned(sp) + 1);
                                mem_data_in <= std_logic_vector(
                                                   unsigned(temp1) +
                                                   unsigned(mem_data_out));
                                we          <= "1";
                                n_s         <= fetch;

                            ----------------------------------------------------
                            -- NEW: ssq - "stack the square"
                            --
                            -- Read mem[sp-1] (top of stack), square it, and
                            -- write the result back to mem[sp-1].  sp stays
                            -- pointing at the next available slot.
                            --
                            -- For `sc 7 ssq halt`:
                            --   * sc 7 -> mem[128] = 7, sp = 129
                            --   * ssq  -> mem[128] = 49, sp = 129
                            ----------------------------------------------------
                            when SSQ =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SSQ2;
                            when SSQ2 =>
                                we <= "0";
                                ir <= SSQ3;
                            when SSQ3 =>
                                we <= "0";
                                ir <= SSQ4;
                            when SSQ4 =>
                                we <= "0";
                                ir <= SSQ5;
                            when SSQ5 =>
                                -- mem_data_out is now mem[sp-1] = x
                                temp1 <= mem_data_out;
                                we    <= "0";
                                ir    <= SSQ6;
                            when SSQ6 =>
                                -- write x*x back to the same stack slot
                                mem_addr    <= std_logic_vector(unsigned(sp) - 1);
                                mem_data_in <= std_logic_vector(
                                                   resize(unsigned(temp1) *
                                                          unsigned(temp1), 32));
                                we          <= "1";
                                n_s         <= fetch;

                            ----------------------------------------------------
                            -- scp : single-word copy from PDF (kept verbatim)
                            -- top of stack: source, then dest
                            ----------------------------------------------------
                            when SCP =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SCP2;
                            when SCP2 =>
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SCP3;
                            when SCP3 =>
                                we <= "0";
                                ir <= SCP4;
                            when SCP4 =>
                                we <= "0";
                                ir <= SCP5;
                            when SCP5 =>
                                mem_addr <= mem_data_out(A-1 downto 0);
                                we       <= "0";
                                ir       <= SCP6;
                            when SCP6 =>
                                we    <= "0";
                                temp1 <= std_logic_vector(
                                            resize(unsigned(mem_data_out(A-1 downto 0)), 32));
                                ir    <= SCP7;
                            when SCP7 =>
                                we <= "0";
                                ir <= SCP8;
                            when SCP8 =>
                                we <= "0";
                                ir <= SCP9;
                            when SCP9 =>
                                mem_addr    <= temp1(A-1 downto 0);
                                mem_data_in <= mem_data_out;
                                we          <= "1";
                                n_s         <= fetch;

                            when others =>
                                null;

                        end case;  -- ir

                end case;  -- n_s
            end if;
        end if;
    end process p_cpu;

end architecture rtl;
