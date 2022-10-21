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
        DATA_ADDR : OUT STD_LOGIC_VECTOR(12 DOWNTO 0); -- adresa do pameti
        DATA_WDATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
        DATA_RDATA : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
        DATA_RDWR : OUT STD_LOGIC; -- cteni (0) / zapis (1)
        DATA_EN : OUT STD_LOGIC; -- povoleni cinnosti

        -- vstupni port
        IN_DATA : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
        IN_VLD : IN STD_LOGIC; -- data platna
        IN_REQ : OUT STD_LOGIC; -- pozadavek na vstup data

        -- vystupni port
        OUT_DATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- zapisovana data
        OUT_BUSY : IN STD_LOGIC; -- LCD je zaneprazdnen (1), nelze zapisovat
        OUT_WE : OUT STD_LOGIC -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
    );
END cpu;
-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
ARCHITECTURE behavioral OF cpu IS

    -- Program counter PC
    SIGNAL pc_reg : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL pc_inc : STD_LOGIC;
    SIGNAL pc_dec : STD_LOGIC;
    SIGNAL pc_clear : STD_LOGIC;

    -- Program counter CNT
    SIGNAL cnt_reg : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL cnt_inc : STD_LOGIC;
    SIGNAL cnt_dec : STD_LOGIC;
    SIGNAL cnt_clear : STD_LOGIC;

    -- Program counter PTR
    SIGNAL ptr_reg : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL ptr_inc : STD_LOGIC;
    SIGNAL ptr_dec : STD_LOGIC;
    SIGNAL ptr_clear : STD_LOGIC;

    -- mx1
    SIGNAL mx1_sel : STD_LOGIC;
    SIGNAL mx1_out : STD_LOGIC_VECTOR(15 DOWNTO 0);

    -- mx2
    SIGNAL mx2_sel : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL mx2_out : STD_LOGIC_VECTOR(15 DOWNTO 0);

    TYPE fsm_state_t IS (
        fsm_init,
        fsm_inc_ptr,
        fsm_dec_ptr,
        fsm_inc_val,
        fsm_dec_val,
        fsm_putchar,
        fsm_getchar,
        fsm_while_start,
        fsm_while_end,
        fsm_neg_while_start,
        fsm_neg_while_end,
        fsm_null
    );

    signal fsm_state : fsm_state_t := fsm_init;

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
            ptr_reg <= (OTHERS => '0');
        ELSIF (CLK'event) AND (CLK = '1') THEN
            IF (ptr_inc = '1') THEN
                ptr_reg <= ptr_reg + 1;
            END IF;
            IF (ptr_dec = '1') THEN
                ptr_reg <= ptr_reg - 1;
            END IF;
            IF (ptr_clear = '1') THEN
                ptr_reg <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;

    -- MX1
    mx1 : PROCESS (RESET, CLK)
    BEGIN
        IF (RESET = '1') THEN
            DATA_ADDR <= (OTHERS => '0');
        ELSIF (CLK'event) AND (CLK = '1') THEN
            CASE mx1_sel IS
                WHEN '0' => DATA_ADDR <= pc_reg;
                WHEN '1' => DATA_ADDR <= ptr_reg;
                WHEN OTHERS => DATA_ADDR <= (OTHERS => '0');
            END CASE;
        END IF;

    END PROCESS;

    -- MX2
    mx2 : PROCESS (RESET, CLK)
    BEGIN
        IF (RESET = '1') THEN
            DATA_WDATA <= (OTHERS => '0');
        ELSIF (CLK'event) AND (CLK = '1') THEN
            CASE mx2_sel IS
                WHEN "00" => DATA_WDATA <= IN_DATA;
                WHEN "01" => DATA_WDATA <= DATA_RDATA - 1;
                WHEN "10" => DATA_WDATA <= DATA_RDATA + 1;
                WHEN OTHERS => DATA_WDATA <= (OTHERS => '0');
            END CASE;
        END IF;

    END PROCESS;
    fsm : PROCESS (RESET, CLK)
    BEGIN
        IF (RESET = '1') THEN
            DATA_WDATA <= (OTHERS => '0');
        ELSIF (CLK'event) AND (CLK = '1') THEN

            CASE fsm_state IS
                WHEN fsm_init => DATA_WDATA <= IN_DATA;
                WHEN OTHERS => DATA_WDATA <= (OTHERS => '0');
            END CASE;

        END IF;

    END PROCESS;

END behavioral;