-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
ENTITY cpu IS
    PORT (
        CLK : IN STD_LOGIC; -- hodinovy signal
        RESET : IN STD_LOGIC; -- asynchronni reset procesoru
        EN : IN STD_LOGIC; -- povoleni cinnosti procesoru

        -- synchronni pamet RAM
        DATA_ADDR : OUT STD_LOGIC_VECTOR(12 DOWNTO 0) := "0000000000000"; -- adresa do pameti
        DATA_WDATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000000"; -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
        DATA_RDATA : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
        DATA_RDWR : OUT STD_LOGIC := '0'; -- cteni (0) / zapis (1)
        DATA_EN : OUT STD_LOGIC := '0'; -- povoleni cinnosti

        -- vstupni port
        IN_DATA : IN STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000000"; -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
        IN_VLD : IN STD_LOGIC; -- data platna
        IN_REQ : OUT STD_LOGIC := '0'; -- pozadavek na vstup data

        -- vystupni port
        OUT_DATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000000"; -- zapisovana data
        OUT_BUSY : IN STD_LOGIC; -- LCD je zaneprazdnen (1), nelze zapisovat
        OUT_WE : OUT STD_LOGIC := '0'-- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
    );
END cpu;
-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
ARCHITECTURE behavioral OF cpu IS

    -- Program counter PC
    SIGNAL pc_reg : STD_LOGIC_VECTOR(12 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pc_inc : STD_LOGIC := '0';
    SIGNAL pc_dec : STD_LOGIC := '0';
    SIGNAL pc_clear : STD_LOGIC := '0';

    -- Program counter CNT
    SIGNAL cnt_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');---TODO change bits
    SIGNAL cnt_inc : STD_LOGIC := '0';
    SIGNAL cnt_dec : STD_LOGIC := '0';
    SIGNAL cnt_clear : STD_LOGIC := '0';

    -- Program counter PTR
    SIGNAL ptr_reg : STD_LOGIC_VECTOR(12 DOWNTO 0) := "1000000000000";
    SIGNAL ptr_inc : STD_LOGIC := '0';
    SIGNAL ptr_dec : STD_LOGIC := '0';
    SIGNAL ptr_clear : STD_LOGIC := '0';

    -- mx1
    SIGNAL mx1_sel : STD_LOGIC := '0';
    -- mx2
    SIGNAL mx2_sel : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    TYPE fsm_state_t IS (
        fsm_init,
        fsm_load_ins,
        fsm_for_mem,
        fsm_dec,
        fsm_inc_ptr,
        fsm_inc_ptr2,
        fsm_dec_ptr,
        fsm_dec_ptr2,
        fsm_inc_val,
        fsm_inc_val_1,
        fsm_inc_val_2,
        fsm_inc_val_3,
        fsm_inc_val_4,
        fsm_dec_val,
        fsm_dec_val_1,
        fsm_dec_val_2,
        fsm_dec_val_3,
        fsm_dec_val_4,
        fsm_putchar,
        fsm_putchar_1,
        fsm_putchar_2,
        fsm_putchar_3,
        fsm_getchar,
        fsm_while_start,
        fsm_while_end,
        fsm_neg_while_start,
        fsm_neg_while_end,
        fsm_null
    );

    SIGNAL fsm_state : fsm_state_t := fsm_init;

BEGIN
    -- Program counter PC
    pc_cntr : PROCESS (RESET, CLK)
    BEGIN
        IF (RESET = '1') THEN
            pc_reg <= (OTHERS => '0');
        ELSIF (CLK'event) AND (CLK = '1') THEN
            IF (pc_inc = '1') THEN
                pc_reg <= pc_reg + 1;
            END IF;
            IF (pc_dec = '1') THEN
                pc_reg <= pc_reg - 1;
            END IF;
            IF (pc_clear = '1') THEN
                pc_reg <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;
    -- CNT
    cnt_cntr : PROCESS (RESET, CLK)
    BEGIN
        IF (RESET = '1') THEN
            cnt_reg <= (OTHERS => '0');
        ELSIF (CLK'event) AND (CLK = '1') THEN
            IF (cnt_inc = '1') THEN
                cnt_reg <= cnt_reg + 1;
            END IF;
            IF (cnt_dec = '1') THEN
                cnt_reg <= cnt_reg - 1;
            END IF;
            IF (cnt_clear = '1') THEN
                cnt_reg <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;

    -- PTR
    ptr_cntr : PROCESS (RESET, CLK)
    BEGIN
        IF (RESET = '1') THEN
            ptr_reg <= "1000000000000";
        ELSIF (CLK'event) AND (CLK = '1') THEN
            IF (ptr_inc = '1') THEN
                ptr_reg <= ptr_reg + 1;
            END IF;
            IF (ptr_dec = '1') THEN
                ptr_reg <= ptr_reg - 1;
            END IF;
            IF (ptr_clear = '1') THEN
                ptr_reg <= "1000000000000";
            END IF;
        END IF;
        IF (ptr_reg < "1000000000000") THEN -- mozna nefunguje spravne
            ptr_reg <= "1000000000000";
        END IF;
    END PROCESS;

    -- MX1
    mx1 : PROCESS (RESET, CLK)
    BEGIN
        IF (CLK'event) AND (CLK = '1') THEN
            CASE mx1_sel IS
                WHEN '0' => DATA_ADDR <= pc_reg;
                WHEN '1' => DATA_ADDR <= ptr_reg;
                WHEN OTHERS => DATA_ADDR <= pc_reg;
            END CASE;
        END IF;

    END PROCESS;

    -- MX2
    mx2 : PROCESS (RESET, CLK)
    BEGIN
        IF (CLK'event) AND (CLK = '1') THEN
            CASE mx2_sel IS
                WHEN "00" => DATA_WDATA <= IN_DATA;
                WHEN "01" => DATA_WDATA <= DATA_RDATA - 1;
                WHEN "10" => DATA_WDATA <= DATA_RDATA + 1;
                WHEN OTHERS => DATA_WDATA <= IN_DATA;
            END CASE;
        END IF;

    END PROCESS;
    fsm : PROCESS (RESET, CLK)
    BEGIN
        IF (RESET = '1') THEN
            fsm_state <= fsm_init;
            DATA_EN <= '0';
            DATA_RDWR <= '0';
            mx1_sel <= '0';
            mx2_sel <= "00";
        ELSIF (CLK'event) AND (CLK = '1') THEN
            --- set everything to default so we dont have to specify everything in every state

            pc_dec <= '0';
            pc_clear <= '0';
            -- Program counter CNT
            cnt_dec <= '0';
            cnt_clear <= '0';
            -- Program counter PTR
            ptr_clear <= '0';
            IN_REQ <= '0';
            OUT_DATA <= "00000000";
            OUT_WE <= '0';

            CASE fsm_state IS
                WHEN fsm_init =>
                    DATA_EN <= '0';
                    pc_clear <= '1';
                    cnt_clear <= '1';
                    ptr_clear <= '1';

                    fsm_state <= fsm_load_ins;
                WHEN fsm_load_ins =>
                    mx1_sel <= '0';
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';

                    fsm_state <= fsm_for_mem;
                WHEN fsm_for_mem =>
                    DATA_EN <= '1';
                    fsm_state <= fsm_dec;

                WHEN fsm_dec =>
                    CASE DATA_RDATA IS
                        WHEN x"3E" =>
                            fsm_state <= fsm_inc_ptr;
                        WHEN x"3C" =>
                            fsm_state <= fsm_dec_ptr;
                        WHEN x"2B" =>
                            fsm_state <= fsm_inc_val;
                        WHEN x"2D" =>
                            fsm_state <= fsm_dec_val;
                        WHEN x"5B" =>
                            fsm_state <= fsm_while_start;
                        WHEN x"5D" =>
                            fsm_state <= fsm_while_end;
                        WHEN x"28" =>
                            fsm_state <= fsm_neg_while_start;
                        WHEN x"29" =>
                            fsm_state <= fsm_neg_while_end;
                        WHEN x"2E" =>
                            fsm_state <= fsm_putchar;
                        WHEN x"2C" =>
                            fsm_state <= fsm_getchar;
                        WHEN x"00" =>
                            fsm_state <= fsm_null;
                        WHEN OTHERS =>
                            fsm_state <= fsm_init;

                    END CASE;
                WHEN fsm_inc_ptr =>
                    ptr_inc <= '1';
                    pc_inc <= '1';
                    fsm_state <= fsm_inc_ptr2;
                WHEN fsm_inc_ptr2 =>
                    ptr_inc <= '0';
                    pc_inc <= '0';
                    fsm_state <= fsm_load_ins;

                WHEN fsm_dec_ptr =>
                    ptr_dec <= '1';
                    pc_inc <= '1';
                    fsm_state <= fsm_dec_ptr2;
                WHEN fsm_dec_ptr2 =>
                    ptr_dec <= '0';
                    pc_inc <= '0';
                    fsm_state <= fsm_load_ins;
                WHEN fsm_inc_val => -- sets up reading from memory
                    pc_inc <= '1';
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    mx2_sel <= "10";
                    fsm_state <= fsm_inc_val_1;
                WHEN fsm_inc_val_1 => -- waits for memory
                    pc_inc <= '0';
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    fsm_state <= fsm_inc_val_2;
                WHEN fsm_inc_val_2 => -- waits for memory
                    DATA_RDWR <= '1';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    fsm_state <= fsm_inc_val_3;
                WHEN fsm_inc_val_3 => -- writes increased value to memory
                    DATA_RDWR <= '1';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    fsm_state <= fsm_inc_val_4;
                WHEN fsm_inc_val_4 => ---set everything back
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';
                    mx1_sel <= '0';
                    mx2_sel <= "00";
                    fsm_state <= fsm_load_ins;

                WHEN fsm_dec_val => -- sets up reading from memory
                    pc_inc <= '1';
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    mx2_sel <= "01";
                    fsm_state <= fsm_dec_val_1;
                WHEN fsm_dec_val_1 => -- waits for memory
                    pc_inc <= '0';
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    fsm_state <= fsm_dec_val_2;
                WHEN fsm_dec_val_2 => -- waits for memory
                    DATA_RDWR <= '1';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    fsm_state <= fsm_dec_val_3;
                WHEN fsm_dec_val_3 => -- writes increased value to memory
                    DATA_RDWR <= '1';
                    DATA_EN <= '1';
                    mx1_sel <= '1';
                    fsm_state <= fsm_dec_val_4;
                WHEN fsm_dec_val_4 => ---set everything back
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';
                    mx1_sel <= '0';
                    mx2_sel <= "00";
                    fsm_state <= fsm_load_ins;
                WHEN fsm_putchar =>
                    pc_inc <= '1';
                    DATA_RDWR <= '0';
                    DATA_EN <= '1';
                    mx1_sel <= '1';

                    fsm_state <= fsm_putchar_1;
                WHEN fsm_putchar_1 =>
                    pc_inc <= '0';
                    fsm_state <= fsm_putchar_2;
                WHEN fsm_putchar_2 =>
                    fsm_state <= fsm_putchar_3;
                WHEN fsm_putchar_3 =>

                    IF (OUT_BUSY = '0') THEN
                        OUT_WE <= '1';
                        OUT_DATA <= DATA_RDATA;
                        mx1_sel <= '0';
                        fsm_state <= fsm_load_ins;
                    END IF;
                WHEN OTHERS => fsm_state <= fsm_init;
            END CASE;

        END IF;

    END PROCESS;

END behavioral;