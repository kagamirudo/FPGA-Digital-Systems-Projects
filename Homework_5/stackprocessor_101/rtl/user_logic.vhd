--------------------------------------------------------------------------------
-- user_logic.vhd
--
-- ECEC 661 - Homework 5 - Stack Processor 101 + new `scpb` block-copy
--
-- This file extends the assignment PDF's stack processor (which already
-- includes `sc`, `sl`, `ss`, `sadd`, `scp`) with the new block-copy
-- instruction `scpb`.
--
-- Programming model
-- =================
-- The instruction is invoked with a 3-argument calling convention on the
-- stack (top of stack last):
--
--     sc dest_addr   sc source_addr   sc number_of_data   scpb
--
-- At entry to `scpb` the stack top holds `number_of_data`, then
-- `source_addr`, then `dest_addr`.  `scpb` pops those three values and
-- copies `number_of_data` consecutive 32-bit words starting at
-- `source_addr` into the contiguous block starting at `dest_addr`.
--
-- The opcode value chosen (`0x00000201`) is one nibble above the assignment
-- PDF's `scp` (`0x00000101`), so the existing decoders are untouched.
--
-- BRAM timing model
-- =================
-- The same simulation-style latency cushion as the rest of the PDF
-- instructions is used: every BRAM read inserts the extra
-- (`fetch3`/`sc3`/`sl3`/`sl7`/`ss3`/`sadd3`/`scp3`/`scp7`) state so the
-- xsim simulation model of `blk_mem_gen_0` lines up with the registered
-- `mem_data_out`.  When mapped to silicon the user can comment-out the
-- `*3` micro-steps just like the PDF instructs for the legacy opcodes.
--
-- Micro-step plan for `scpb`
-- ==========================
--   scpb         init pop  number_of_data        (mem_addr <= sp-1, sp--)
--   scpb2        init pop  source_addr           (mem_addr <= sp-1, sp--)
--   scpb3        init pop  dest_addr             (mem_addr <= sp-1, sp--)
--   scpb4        BRAM read latency (douta not yet valid)
--   scpb5        mem_data_out valid : count   -> copy_cnt
--   scpb6        mem_data_out valid : source  -> copy_src
--   scpb7        mem_data_out valid : dest    -> copy_dst, enter loop
--   scpb_loop    if copy_cnt = 0 -> fetch; else init read at copy_src
--   scpb_r1..r3  BRAM read latency for the source word
--   scpb_r4      mem_data_out valid : source word -> schedule write
--   scpb_w       write fires this cycle; bump copy_src/dst; copy_cnt--
--
-- The body uses `unsigned` arithmetic from `numeric_std` so synthesis is
-- standard library (the PDF used the deprecated `std_logic_unsigned`).
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

    -- block-copy working registers (new for `scpb`)
    signal copy_src              : std_logic_vector(A-1 downto 0);
    signal copy_dst              : std_logic_vector(A-1 downto 0);
    signal copy_cnt              : std_logic_vector(31 downto 0);

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

    -- scpb family (NEW: block copy of N words)
    constant SCPB     : std_logic_vector(31 downto 0) := x"00000201";  -- init pop count
    constant SCPB2    : std_logic_vector(31 downto 0) := x"00000202";  -- init pop source
    constant SCPB3    : std_logic_vector(31 downto 0) := x"00000203";  -- init pop dest
    constant SCPB4    : std_logic_vector(31 downto 0) := x"00000204";  -- read latency
    constant SCPB5    : std_logic_vector(31 downto 0) := x"00000205";  -- count valid
    constant SCPB6    : std_logic_vector(31 downto 0) := x"00000206";  -- source valid
    constant SCPB7    : std_logic_vector(31 downto 0) := x"00000207";  -- dest valid
    constant SCPB_L   : std_logic_vector(31 downto 0) := x"00000208";  -- loop check
    constant SCPB_R1  : std_logic_vector(31 downto 0) := x"00000209";  -- source read latency
    constant SCPB_R2  : std_logic_vector(31 downto 0) := x"0000020A";
    constant SCPB_R3  : std_logic_vector(31 downto 0) := x"0000020B";
    constant SCPB_R4  : std_logic_vector(31 downto 0) := x"0000020C";  -- source word valid
    constant SCPB_W   : std_logic_vector(31 downto 0) := x"0000020D";  -- write + bookkeeping

    ----------------------------------------------------------------------------
    -- Components
    ----------------------------------------------------------------------------
    -- Note: the Vivado blk_mem_gen_0 generated by scripts/setup.tcl exposes
    -- a port-A enable (`ena`).  We tie it permanently high so the BRAM is
    -- always active; the bridge mux already decides whose addr/wea actually
    -- drives the port each cycle.
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
    -- The PDF's `*3` / `*4` / `*5` micro-step pattern is timed assuming
    -- *two* cycles of latency between scheduling `mem_addr <= A` and
    -- `mem_data_out = mem[A]` (one for the BRAM read, one for the
    -- mem_data_out register).  If `blk_mem_gen_0` is configured without
    -- the output-register option, the BRAM read is only one cycle, so we
    -- chain a second register here (`mem_data_out_pre`) to restore the
    -- assumed total of three cycles.
    --
    -- Latency budget:
    --   edge T   : state body schedules mem_addr <= A
    --   edge T+1 : BRAM samples addra = A;  douta <= mem[A]
    --   edge T+2 : mem_data_out_pre  <= douta = mem[A]
    --   edge T+3 : mem_data_out      <= mem_data_out_pre = mem[A]
    --   edge T+4 : state body (= state X+4) reads mem_data_out = mem[A]
    --
    -- That `+4` matches the PDF's micro-step count exactly
    -- (e.g. SC -> SC2 -> SC3 -> SC4 -> SC5, `sl5` = `sl + 4`,
    --  `SCPB5` = `SCPB + 4`).
    --
    -- NOTE: this chain intentionally does NOT clear on `reset='1'`.  The
    -- AXI driver may hold reset high while it pre-loads or reads BRAM
    -- through the bus mux (the bridge already isolates the processor's
    -- mem_addr/we from the BRAM port whenever bus2mem_en='1'); clamping
    -- mem_data_out to 0 during that window would silently turn every
    -- software read into 0x00000000.
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
                        copy_src    <= (others => '0');
                        copy_dst    <= (others => '0');
                        copy_cnt    <= (others => '0');
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

                            ----------------------------------------------------
                            -- NEW: scpb - block copy of N words
                            -- top of stack: count, source, dest
                            ----------------------------------------------------
                            when SCPB =>
                                -- init pop number_of_data
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SCPB2;

                            when SCPB2 =>
                                -- init pop source_addr
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SCPB3;

                            when SCPB3 =>
                                -- init pop dest_addr
                                mem_addr <= std_logic_vector(unsigned(sp) - 1);
                                sp       <= std_logic_vector(unsigned(sp) - 1);
                                we       <= "0";
                                ir       <= SCPB4;

                            when SCPB4 =>
                                -- BRAM read latency (douta not yet valid for count)
                                we <= "0";
                                ir <= SCPB5;

                            when SCPB5 =>
                                -- mem_data_out valid : count
                                copy_cnt <= mem_data_out;
                                we       <= "0";
                                ir       <= SCPB6;

                            when SCPB6 =>
                                -- mem_data_out valid : source_addr
                                copy_src <= mem_data_out(A-1 downto 0);
                                we       <= "0";
                                ir       <= SCPB7;

                            when SCPB7 =>
                                -- mem_data_out valid : dest_addr
                                copy_dst <= mem_data_out(A-1 downto 0);
                                we       <= "0";
                                ir       <= SCPB_L;

                            when SCPB_L =>
                                -- Loop entry : finished if count = 0
                                if unsigned(copy_cnt) = 0 then
                                    n_s <= fetch;
                                else
                                    mem_addr <= copy_src;     -- init read source word
                                    we       <= "0";
                                    ir       <= SCPB_R1;
                                end if;

                            when SCPB_R1 =>
                                we <= "0";
                                ir <= SCPB_R2;

                            when SCPB_R2 =>
                                we <= "0";
                                ir <= SCPB_R3;

                            when SCPB_R3 =>
                                we <= "0";
                                ir <= SCPB_R4;

                            when SCPB_R4 =>
                                -- mem_data_out valid : source word
                                mem_addr    <= copy_dst;
                                mem_data_in <= mem_data_out;
                                we          <= "1";   -- BRAM samples we='1' next edge
                                ir          <= SCPB_W;

                            when SCPB_W =>
                                -- The write happened on the edge entering this
                                -- state.  Bump pointers, decrement count, loop.
                                copy_src <= std_logic_vector(unsigned(copy_src) + 1);
                                copy_dst <= std_logic_vector(unsigned(copy_dst) + 1);
                                copy_cnt <= std_logic_vector(unsigned(copy_cnt) - 1);
                                we       <= "0";
                                ir       <= SCPB_L;

                            when others =>
                                null;

                        end case;  -- ir

                end case;  -- n_s
            end if;
        end if;
    end process p_cpu;

end architecture rtl;
