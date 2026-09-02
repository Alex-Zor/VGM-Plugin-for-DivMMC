    DEVICE ZXSPECTRUM128                                ;
                                                        ;
                        ORG 08000h                      ;
vgm_start:                                              ;
;====================== Plugin header ==================;
                        db "PLUG", 0                    ;
                        dw entry_point                  ; entry point
                        db "VGM"                        ;
                        ds 9                            ;
                                                        ;
;====================== ESXDOS =========================;
ESXDOS_GETSETDRV:       EQU $89                         ;
ESXDOS_OPEN:            EQU $9A                         ;
ESXDOS_CLOSE:           EQU $9B                         ;
ESXDOS_READ:            EQU $9D                         ;
ESXDOS_FSEEK:           EQU $9F                         ;
ESXDOS_FSTAT:           EQU $A1                         ;
ESXDOS_OPENDIR:         EQU $A3                         ;
ESXDOS_READDIR:         EQU $A4                         ;
                                                        ;
FA_READ:                EQU 1                           ;
                                                        ;
;====================== AY =============================;
AY_ADDR:                EQU $FFFD                       ;
AY_DATA:                EQU $BFFD                       ;
                                                        ;
;====================== SAA1099 ========================;
SAA1099_ADDR:           EQU $01FF                       ;
SAA1099_DATA:           EQU $00FF                       ;
SAA1099_ADDR2:          EQU $03FF                       ;
SAA1099_DATA2:          EQU $02FF                       ;
                                                        ;
;====================== YM2413 =========================;
YM2413_ADDR:            EQU $C0                         ;
YM2413_DATA:            EQU $C1                         ;
                                                        ;
;====================== SN76489 ========================;
SN76489_ADDR:           EQU $C3                         ;
SN76489_ADDR2:          EQU $C2                         ;
                                                        ;                                                        ;                                                        ;
;====================== YMG262 =========================;
YMF262_ADDR1:           EQU $C4                         ;
YMF262_DATA1:           EQU $C5                         ;
YMF262_ADDR2:           EQU $C6                         ;
YMF262_DATA2:           EQU $C7                         ;
                                                        ;
;====================== VGM ============================;
CMD_SN76489:            EQU $50                         ;
CMD_SN76489_2:          EQU $30                         ;
CMD_YM2413:             EQU $51                         ;
CMD_YM2203:             EQU $55                         ;
CMD_YM3812:             EQU $5A                         ;
CMD_YMF262_1:           EQU $5E                         ;
CMD_YMF262_2:           EQU $5F                         ;                                                        ;
CMD_WAIT_N:             EQU $61                         ;
CMD_WAIT_60:            EQU $62                         ;
CMD_WAIT_50:            EQU $63                         ;
CMD_END:                EQU $66                         ;
CMD_AY8910:             EQU $A0                         ;
CMD_SAA1099:            equ $BD                         ;
                                                        ;
;=================== chips_mask ========================;
; Битовая маска чипов, объявленных в заголовке VGM      ;
; (собирается в rd_header, используется в sound_off).   ;
MSK_OPL:                EQU 1                           ; YM3812/YMF262
MSK_AY:                 EQU 2                           ; AY-3-8910
MSK_SN:                 EQU 4                           ; SN76489 (+2x)
MSK_YM2203:             EQU 8                           ; YM2203 (+2x)
MSK_SAA:                EQU 16                          ; SAA1099 (+2x)
MSK_YM2413:             EQU 32                          ; YM2413
                                                        ;
;====================== ENTRY ==========================;
entry_point:                                            ;
                jr      start                           ;
                db      " < ver0.63 by AlexZor > "      ;
; ======================================================;
                                                        ;
; ТОЧКА ВХОДА ПЛАГИНА esxDOS.                           ;
; Сохраняет IX/IY, запрашивает у esxDOS текущий диск (drive),
; показывает меню/оформление экрана, запускает воспроизведение
; файла и переход к следующему, восстанавливает регистры и выходит.
; ======================================================;
start:          di                                      ;
                push    ix                              ;
                push    iy                              ;
                ld      (entryFile), hl                 ;
                ld      a, 0                            ;
                ld      b, 0                            ;
                rst     8                               ;
                defb    ESXDOS_GETSETDRV                ;
                ld      (drive), a                      ;
                call    menu                            ;
                call    play_file                       ;
                call    next_file                       ;
                pop     iy                              ;
                pop     ix                              ;
                ei                                      ;
                ret                                     ;
;====================Player=============================;
; ВОСПРОИЗВЕДЕНИЕ ОДНОГО VGM-ФАЙЛА.                     ;
; Открывает файл, подгружает первый блок в буфер, разбирает
; заголовок (rd_header), затем крутит цикл: parser (одна VGM-
; команда) -> проверка EOF -> проверка нажатой клавиши (порт 7FFEh),
; пока не кончится файл (stop_eof) или не нажата клавиша (stop_key).
; По выходу пишет event (0/1/0xFFFF), закрывает файл и глушит чип.
; ======================================================;
play_file:                                              ;
                call    open_file                       ;
                call    fill_buf                        ;
                call    rd_header                       ;
                set     1, a                            ;
                ld      (eof), a                        ;
                ld      de, 0                           ;
                                                        ;
parser_loop:    call    parser                          ;
                ld      bc, (eof)                       ;
                ld      a, b                            ;
                or      c                               ;
                jr      z, stop_eof                     ;
                ld      bc, 7BFEh                       ; exit when keypress
                in      a, (c)                          ;
                bit     0, a                            ;
                jr      z, stop_key                     ;
                jr      parser_loop                     ;
                                                        ;
;------------------ Stop play --------------------------;
stop_key:
                xor     a
                ld      h, a
                ld      bc, 0FBFEh
                in      a, (c)
                bit     0, a
                or      0FEh
                cpl
                ld      l, a
                ld      (event), hl
                jr      exit_play
stop_eof:
                ld      hl, 0FFFFh
exit_play:
                ld      (event), hl
                call    close_file
                call    sound_off
                ret                                     ;
                                                        ;
; --- обработчик VGM-команды 0x66 (конец потока данных):
; обнуляет eof, тем самым завершая цикл parser_loop в play_file.
end_vgm:
                ld      hl, 0                           ;
                ld      (eof), hl                       ;
                ret                                     ;
                                                        ;
;--------------------- Parser --------------------------;
; РАЗБОРЩИК ОДНОЙ VGM-КОМАНДЫ.
; Читает байт-код команды (get_byte) и передаёт управление нужному
; обработчику: запись в AY/SAA1099/OPL2/OPL3/SN76489, паузы
; (N сэмплов / 1 кадр 50 или 60 Гц), команды 0x55/0xA5 (см. ниже)
; или конец потока (0x66 -> end_vgm). Неизвестные байты пропускаются.
; ======================================================;
parser:                                                 ;
                call    get_byte                        ;
                                                        ;
                cp      CMD_YMF262_1                    ;
                jp      z, wr_ymf262_1                  ;
                                                        ;
                cp      CMD_YMF262_2                    ;
                jp      z, wr_ymf262_2                  ;
                                                        ;
                cp      CMD_YM3812                      ;
                jp      z, wr_ymf262_1                  ;
                                                        ;
                cp      CMD_AY8910                      ;
                jr      z, wr_ay8910                    ;
                                                        ;                                                        ;
                cp      CMD_SAA1099                     ;
                jr      z, wr_saa1099                   ;
                                                        ;
                cp      CMD_YM2413                      ;
                jr      z, wr_ym2413                    ;
                                                        ;
                cp      CMD_WAIT_N                      ;
                jp      z, do_wait_n                    ;
                                                        ;
                cp      CMD_WAIT_50                     ;
                jp      z, do_wait_50                   ;
                                                        ;
                cp      CMD_WAIT_60                     ;
                jp      z, do_wait_60                   ;
                                                        ;
                cp      CMD_YM2203                      ;
                jr      z, loc_0002                     ;
                                                        ;
                cp      0A5h                            ;
                jr      z, loc_0001                     ;
                                                        ;
                cp      CMD_SN76489                     ;  PSG (SN76489/SN76496)
                jr      z,  wr_SN76489                  ;
                                                        ;
                cp      CMD_SN76489_2                   ;  PSG, 2-й чип (VGM cmd 0x30)
                jr      z,  wr_SN76489_2                ;
                                                        ;
                cp      CMD_END                         ;
                jr      z, end_vgm                      ;
                                                        ;
                jr      parser                          ;
; --- команда 0xA5: тот же формат, что и 0x55, но со значением 0xF1 (см. ниже) ---
loc_0001:                                               ;
                ld      a, 0F1h                         ;
                jr      loc_0003                        ;
; --- команда 0x55: пишет фиксированное значение в регистр AY_ADDR ---
loc_0002:                                               ;
                ld      a, 0F0h                         ;
loc_0003:                                               ;
                ld      bc, AY_ADDR                     ;
                out     (c), a                          ;
                                                        ;
;---------------------- AY write -----------------------;
; ---------------- Запись в AY-8910/8912 (команда 0xA0) ;
; Читает 2 байта потока (регистр, значение) и пишет их  ;
; по очереди в порты AY_ADDR/AY_DATA.                   ;
wr_ay8910:                                              ;
                call    get_byte                        ;
                ld      bc, AY_ADDR                     ;
                out     (c), a                          ;
                call    get_byte                        ;
                ld      bc, AY_DATA                     ;
                out     (c), a                          ;
                ret                                     ;
;-------------------- SAA write ------------------------;
; ---------------- Запись в SAA1099 (команда 0xBD) -----;
; Читает 2 байта потока (регистр, значение). Бит 7 байта;
; регистра - это флаг чипа из потока VGM (спецификация, ;
; Dual Chip Support #2): 0 - первый чип (порты #01FF/   ;
; #00FF), 1 - второй чип (порты #03FF/#02FF). Бит 7     ;
; в реальный регистр SAA не передаётся - маскируется    ;
; перед выводом.                                        ;
                                                        ;
wr_saa1099:                                             ;
                call    get_byte                        ; a = регистр (бит7 = номер чипа)
                bit     7, a                            ;
                jr      nz, wr_saa1099_2                ;
                                                        ;
                and     07Fh                            ;
                ld      bc, SAA1099_ADDR                ;
                out     (c), a                          ;
                call    get_byte                        ;
                ld      bc, SAA1099_DATA                ;
                out     (c), a                          ;
                ret                                     ;
                                                        ;
wr_saa1099_2:                                           ;
                and     07Fh                            ;
                ld      bc, SAA1099_ADDR2               ;
                out     (c), a                          ;
                call    get_byte                        ;
                ld      bc, SAA1099_DATA2               ;
                out     (c), a                          ;
                ret                                     ;
                                                        ;                                                                               ;
; -------------- Запись в YM2413/OPLL (команда 0x51) ---;
; Читает 2 байта потока (регистр, значение) и пишет их  ;
; по очереди в порты YM2413_ADDR/YM2413_DATA.           ;
wr_ym2413:                                              ;
                call    get_byte                        ;
                ld      bc, YM2413_ADDR                 ;
                out     (c), a                          ;
                call    get_byte                        ;
                ld      bc, YM2413_DATA                 ;
                out     (c), a                          ;
                ret                                     ;
                                                        ;
;--------------- YMF (YM3812) write --------------------;
; ---- Запись в OPL2/OPL3, банк 1 (команды 0x5A и 0x5E) ;
; Читает 2 байта потока (регистр, значение), пишет их   ;
; в YMF262_ADDR1/YMF262_DATA1.                          ;
wr_ymf262_1:    call    get_byte                        ;
                out     (YMF262_ADDR1), a               ;
                call    get_byte                        ;
                out     (YMF262_DATA1), a               ;
                nop                                     ;
                ret                                     ;
                                                        ;
; ---- Запись в OPL3, банк 2 (команда 0x5F) ------------;
; Читает 2 байта потока (регистр, значение), пишет их   ;
; в YMF262_ADDR2/YMF262_DATA2 (второй набор регистров OPL3).
wr_ymf262_2:    call    get_byte                        ;
                out     (YMF262_ADDR2), a               ;
                call    get_byte                        ;
                out     (YMF262_DATA2), a               ;
                ret                                     ;
                                                        ;
; ---- Запись в SN76489/SN76496 PSG (команда 0x50) -----;
; Читает 1 байт потока и пишет его напрямую в SN76489_ADDR
; (у этого чипа один порт, регистр кодируется в самом байте).
wr_SN76489:                                             ;
                call    get_byte                        ;
                out     (SN76489_ADDR), a               ;
                ret                                     ;
; ---- Запись во 2-й SN76489 (команда VGM 0x30) --------;
; По спецификации VGM второй SN76489 адресуется отдельным;
; кодом команды (0x30), а не флагом-битом в байте, как у;
; остальных чипов. Читает 1 байт потока и пишет его в   ;
; SN76489_ADDR2 ($C2).                                  ;
wr_SN76489_2:                                           ;
                call    get_byte                        ;
                out     (SN76489_ADDR2), a              ;
                ret                                     ;
; ======================================================;
; ПАУЗЫ VGM (команды 0x61/0x62/0x63).                   ;
; do_wait_n:  0x61 NN NN - ждать NN сэмплов (16-битное число).
; do_wait_50: 0x63       - ждать 1 кадр при 50 Гц (0x0376 тактов).
; do_wait_60: 0x62       - ждать 1 кадр при 60 Гц (0x02E2 тактов).
; Внутри - busy-wait цикл (wait_hl), который попутно опрашивает
; клавиатуру через IX и уменьшает счётчик DE до нуля; итоговый
; "недосчитанный" остаток инвертируется и кладётся в DE.;
; ======================================================;
do_wait_n:                                              ;
                call    get_byte                        ;
                ld      c, a
                call    get_byte
                ld      h, a
                ld      l, c
wait_hl:
                sbc     hl, de
                jr      c, loc_0007
loc_0005:
                exx
                ld      (hl), 27h
                ld      a, (ix+0)
                cp      e
                jr      nz, loc_0006
                inc     ix
                inc     l
loc_0006:
                exx
                ld      a, h
                or      l
                dec     hl
                jr      nz, loc_0005
loc_0007:
                ld      a, h
                xor     0FFh
                ld      d, a
                ld      a, l
                xor     0FFh
                ld      e, a
                ret
; --- пауза 1 кадр, 50 Гц: hl = 0x0376 тактов, общий цикл ожидания wait_hl ---
do_wait_50:
                ld      hl, 376h
                jr      wait_hl                         ;
; --- пауза 1 кадр, 60 Гц: hl = 0x02E2 тактов, общий цикл ожидания wait_hl ---
do_wait_60:
                ld      hl, 2E2h                        ;
                jr      wait_hl                         ;
                                                        ;
;-------------------------------------------------------;
; =======================================================
; ЧТЕНИЕ ОЧЕРЕДНОГО БАЙТА ИЗ ПОТОКА VGM-ДАННЫХ.
; Берёт байт по указателю bufPos; если указатель дошёл до конца
; страницы буфера (BUFF_END), сначала дозагружает диск (fill_buf).
; Продвигает bufPos и счётчик прочитанных байт DE (используется
; в read_gd3/wait-командах для отслеживания текущего смещения).
; ============================================================
get_byte:
                ld      hl, (bufPos)
                ld      a, h
                cp      BUFF_END
                call    z, fill_buf
                ld      a, (hl)
                inc     hl
                ld      (bufPos), hl
                inc     de
                ret
                                                        ;
;-------------------------------------------------------;
; ============================================================
; ДОЗАГРУЗКА БУФЕРА С ДИСКА.
; Читает очередной блок (0x200 байт) файла в BUFF_START через
; esxDOS F_READ. По фактически прочитанному числу байт (bc)
; определяет, достигнут ли конец файла (флаг в eof), и сбрасывает
; bufPos обратно на начало буфера.
; ============================================================
fill_buf:
                ld      a, (file_handle)
                ld      hl, BUFF_START
                ld      bc, 200h
                rst     8
                defb    ESXDOS_READ
                ld      (eof), bc
                ex      de, hl
                ld      de, 106h
                add     hl, de
                ex      de, hl
                exx
                ld      a, b
                cp      c
                jr      z, loc_0008
                inc     b
                exx
                ld      hl, BUFF_START
                ld      (bufPos), hl
                ret
loc_0008:
                ld      b, 0
                inc     e
                exx
                ld      hl, BUFF_START
                ld      (bufPos), hl
                ret
                                                        ;
;-------------------------------------------------------;
; ============================================================
; ОТКРЫТИЕ VGM-ФАЙЛА.
; Открывает файл (имя - entryFile) на текущем диске через esxDOS
; F_OPEN, сохраняет хендл (file_handle), затем считывает информацию
; о файле (F_FSTAT) в fstat_buff (используется для размера файла).
; ============================================================
open_file:
                xor     a
                ld      (file_handle), a
                ld      b, 1
                ld      hl, (entryFile)
                ld      a, (drive)
                rst     8
                defb    ESXDOS_OPEN
                ld      (file_handle), a

                ld      hl, fstat_buff
                rst     8
                defb    ESXDOS_FSTAT
                                                        ;
                ret
                                                        ;
;-------------------------------------------------------;
; ------------------ Закрытие VGM-файла ----------------;
; Закрывает файл по хендлу через esxDOS F_CLOSE.
close_file:
                ld      a, (file_handle)
                rst     8
                defb    ESXDOS_CLOSE
                ld      (file_handle), a
                ret
                                                        ;
;-------------------------------------------------------;
; ======================================================;
; ДЕЙСТВИЕ ПОСЛЕ ОКОНЧАНИЯ ВОСПРОИЗВЕДЕНИЯ.
; По event решает, что делать: "Q" (event=1) - завершить плагин;
; клавиша "пробел" (event=0) - перейти к следующему файлу;
; конец файла без нажатия (event=0xFFFF) - показать "PAUSE" и
; ждать нажатия любой клавиши (busy-loop loop_pause), затем перейти
; к следующему файлу.
; ============================================================
next_file:
                ld      a, (event)
                cp      1
                jr      nz, loc_0009
                ld      a, 3
                ret
loc_0009:
                ld      a, (event)
                or      a
                jr      nz, eof_event
                ld      a, 0Bh
                ld      bc, 1
                ret
eof_event:
                call    clear_text
                ld      de, 907h
                ld      bc, txt_pause
                call    print
                ld      hl, 0FFFFh
loop_pause:
                ld      bc, ($)
                ld      bc, (loop_pause)
                ld      bc, (loop_pause)
                ld      bc, (loop_pause)
                dec     hl
                ld      a, l
                or      h
                jr      nz, loop_pause
                ld      a, 0Bh
                ld      bc, 1
                ret
                                                        ;
;=============== Set progressbar =======================;
; ИНИЦИАЛИЗАЦИЯ ПРОГРЕСС-БАРА.
; По размеру файла (fstat_buff+8/+9) вычисляет шаг (сколько байт
; проигранных данных соответствует одному делению бара) и строит
; таблицу bar из 29 порогов делением полного размера на 29 частей
; (див. цикл lp_div/lp_bartbl).
; ======================================================;
bar_init:       ld      a, (fstat_buff+9)               ; calc step for bar
                ld      h, a                            ;
                ld      a, (fstat_buff+8)               ;
                ld      l, a                            ;
                                                        ;
                or      a
                rr      h
                rr      l
                ld      a, h
                exx
                ld      c, a
                ld      b, 0
                ld      hl, 5961h
                ld      e, 0
                exx
                ld      d, 0
                ld      e, h
                inc     de
                ld      c, 0
lp_div:
                or      a
                sbc     hl, de
                jr      c, done_div
                inc     c
                jr      lp_div
done_div:
                ld      ix, bar
                ld      b, 1Dh
                xor     a
                ld      hl, 0
                ld      d, 0
lp_bartbl:
                ld      a, h
                or      a
                jr      nz, normalize
                ld      a, l
                cp      c
                jr      nc, normalize
                push    bc
                ld      bc, 1Dh
                add     hl, bc
                pop     bc
                inc     d
                jr      lp_bartbl
normalize:
                push    bc
                ld      b, 0
                sbc     hl, bc
                pop     bc
                ld      (ix+0), d
                inc     ix
                djnz    lp_bartbl
                ld      ix, bar
                ret
                                                        ;
;================== Read VGM header ====================;
; РАЗБОР ЗАГОЛОВКА VGM-ФАЙЛА.
; Печатает имя файла и его размер (view_size), определяет чип
; по сигнатурам-офсетам в заголовке (SN76489/YM2203/YM3812/
; YMF262/AY8910/SAA1099 - см. константы offset ниже, not_zero),
; сохраняет номер чипа в curr_chip, выводит название чипа,
; при наличии GD3-тега читает название трека/игры (read_gd3),
; и наконец вычисляет и сохраняет позицию начала VGM-данных
; (data_offset, поле "VGM data offset" в заголовке) в bufPos.
; ======================================================;
rd_header:
                ld      de, $0907                       ; print file name
                ld      bc, (entryFile)
                call    print
                                                        ;
                call    view_size
;---- собрать маску ВСЕХ чипов, объявленных в заголовке -;
; Парсер играет команды всех чипов файла, а curr_chip -  ;
; только один (для строки "Chip:" и детекта). sound_off  ;
; глушит по этой маске, иначе мультичиповый VGM (напр.   ;
; Robocop: YM2203+YM3812) оставляет второй чип звучать   ;
; после выхода - "зависшая нота".                        ;
                xor     a                               ;
                ld      (chips_mask), a                 ;
                ld      ix, mask_tbl                    ;
                ld      d, 7                            ; записей в таблице
bmask_loop:
                ld      c, (ix+0)                       ; offset поля клока
                ld      b, (ix+1)                       ;
                call    not_zero                        ; Z=1 - клок нулевой
                jr      z, bmask_next                   ;
                ld      a, (chips_mask)                 ;
                or      (ix+2)                          ; добавить бит чипа
                ld      (chips_mask), a                 ;
bmask_next:
                inc     ix                              ;
                inc     ix                              ;
                inc     ix                              ;
                dec     d                               ;
                jr      nz, bmask_loop                  ;
;-------------------------------------------------------;
                ld      a, 6
                ld      (curr_chip), a
                ld      bc, 10h                         ; offset: 0x10, name: 'YM2413 OPLL'
                call    not_zero
                ld      bc, txt_chip4
                jp      nz, gd3_offset
;-------------------------------------------------------;
                ld      a, 3
                ld      (curr_chip), a
                ld      bc, 0Ch                         ; offset: 0x0C, name: 'SN76489 PSG'
                call    not_zero
                                                        ;
                jr      z, loc_sn_no
                bit     6, b                            ; bit 30 of clock = dual chip flag
                jr      nz, loc_sn_dual
                ld      bc, txt_chip9                   ; SN76489
                jr      gd3_offset

loc_sn_dual:    ld      a, 8                            ; 2xSN76489
                ld      (curr_chip), a
                ld      bc, txt_chip10                  ; 2xSN76489
                jr      gd3_offset
loc_sn_no:                                              ;
;-------------------------------------------------------;
                ld      a, 4
                ld      (curr_chip), a
                ld      bc, 44h                         ;  offset: 0x44, name: 'YM2203 OPN'
                call    not_zero
                                                        ;
                jr      z, loc_0011
                bit     6, b
                jr      nz, loc_0010
                ld      bc, txt_chip5                   ; YM2203
                jr      gd3_offset

loc_0010:       ld      bc, txt_chip6                   ; 2xYM2203
                jr      gd3_offset
;-------------------------------------------------------;
loc_0011:       ld      a, 1
                ld      (curr_chip), a
                                                        ;
                ld      bc, 50h                         ; offset: 0x50, name: 'YM3812 OPL2'
                call    not_zero
                ld      bc, txt_chip1
                jr      nz, gd3_offset
                                                        ;
                ld      bc, 5Ch                         ; offset: 0x5C, name: 'YMF262 OPL3'
                call    not_zero
                ld      bc, txt_chip2
                jr      nz, gd3_offset
;-------------------------------------------------------;
                ld      a, 2
                ld      (curr_chip), a
                ld      bc, 74h                         ; offset: 0x74, name: 'AY8910 PSG'
                call    not_zero
                ld      bc, txt_chip3
                jr      nz, gd3_offset
;-------------------------------------------------------;
                ld      a, 5
                ld      (curr_chip), a
                ld      bc, 0C8h                        ; offset: 0x0C8, name: 'SAA1099'
                call    not_zero
                                                        ;
                jr      z, loc_saa_no
                bit     6, b                            ; bit 30 of clock = dual chip flag
                jr      nz, loc_saa_dual
                ld      bc, txt_chip7                   ; SAA1099
                jr      gd3_offset

loc_saa_dual:   ld      a, 7                            ; 2xSAA1099
                ld      (curr_chip), a
                ld      bc, txt_chip8                   ; 2xSAA1099
                jr      gd3_offset
;-------------------------------------------------------;
loc_saa_no:     xor     a
                ld      (curr_chip), a
                ld      bc, txt_unsup
;-------------------------------------------------------;
gd3_offset:     ld      de, $0A07                       ;
                call    print
                call    sub_0003
                ld      hl, BUFF_START
                ld      bc, 14h
                add     hl, bc
                ld      e, (hl)
                inc     hl
                ld      d, (hl)
                inc     hl
                ld      c, (hl)
                inc     hl
                ld      b, (hl)
                ld      a, b
                or      c
                or      d
                or      e
                jr      z, data_offset
                call    read_gd3
data_offset:
                ld      hl, BUFF_START
                ld      bc, 34h
                add     hl, bc
                ld      c, (hl)
                inc     hl
                ld      b, (hl)
                dec     hl
                add     hl, bc
                ld      (bufPos), hl
                ld      de, 0
                                                        ;
                call    bar_init
                                                        ;
                ret
                                                        ;
;-------------------------------------------------------;
; -------- Проверка сигнатуры чипа в заголовке VGM -----;
; На входе BC = смещение 4-байтового поля в заголовке (относительно
; BUFF_START). Возвращает Z=1, если все 4 байта нулевые (чип не
; используется в файле), Z=0 - если хотя бы один байт ненулевой.
not_zero:                                               ; check signature
                xor     a
                ld      hl, BUFF_START
                add     hl, bc
                ld      b, (hl)
                or      b
                inc     hl
                ld      b, (hl)
                or      b
                inc     hl
                ld      b, (hl)
                or      b
                inc     hl
                ld      b, (hl)
                or      b
                ret
;================== Read GD3 tag =======================;
; ЧТЕНИЕ GD3-ТЕГА (название трека и игры).
; Вычисляет абсолютное смещение GD3-тега (data-offset + 0x14,
; поле "GD3 offset" в заголовке VGM) и делает F_SEEK+перечитывание
; буфера. Строки в GD3 хранятся в UTF-16LE - читаются побайтово
; через 2 (младший байт символа) в track/game до нулевого символа.
; ======================================================;
read_gd3:
                ld      hl, $0014                       ;
                add     hl, de                          ;
                jr      nc, no_cary                     ;
                inc     bc                              ;
no_cary:        ld      d, h                            ;
                ld      e, l                            ;
                ld      a, (file_handle)                ;
                ld      l, 0                            ; seek from start file
                rst     8                               ;
                defb    ESXDOS_FSEEK                    ;
                call    fill_buf
                ld      hl, (bufPos)
                ld      bc, $000C                       ; add $0C
                add     hl, bc
                                                        ;
                ld      de, track
                ld      b, 22h
loc_0012:
                ld      a, (hl)
                ld      (de), a
                or      a
                jr      z, loc_0013
                inc     de
                inc     hl
                inc     hl
                djnz    loc_0012
                call    sub_0001
                xor     a
                ld      (de), a
loc_0013:
                inc     hl
                inc     hl
                call    sub_0001
                inc     hl
                inc     hl
                ld      de, game
                ld      b, 22h
loc_0014:
                ld      a, (hl)
                ld      (de), a
                or      a
                jr      z, gd3_end
                inc     de
                inc     hl
                inc     hl
                djnz    loc_0014
                xor     a
                ld      (de), a
gd3_end:
                ld      de, 0C07h
                ld      bc, track
                call    print
                ld      de, 0D07h
                ld      bc, game
                call    print
                ld      a, (file_handle)
                ld      bc, 0
                ld      de, 0
                ld      l, 0
                rst     8
                defb    ESXDOS_FSEEK                    ;
                call    fill_buf
                ret
                                                        ;
;-------------------------------------------------------;
; --- вспом. для read_gd3: пропустить строку в 2-байтных символах
; (до нулевого терминатора, максимум 0xFF символов) - используется,
; чтобы перескочить не интересующие плеер поля GD3-тега (System и т.п.)
sub_0001:
                ld      b, 0FFh
loc_0015:
                ld      a, (hl)
                or      a
                ret     z
                inc     hl
                inc     hl
                djnz    loc_0015
                ret
                                                        ;
;=================== View file size ====================;
; ФОРМАТИРОВАНИЕ РАЗМЕРА ФАЙЛА ДЛЯ ЭКРАНА.
; Берёт 24-битный (+1 байт переполнения) размер из fstat_buff,
; при размере > 16 Мб выводит "> 16 Mb". Для размера до 1 Мб
; печатает в Кб (десятичные цифры через sub_0002, с обрезкой
; ведущих нулей), для 1-16 Мб - в формате "NN.N Mb".
; ======================================================;
view_size:
                ld      a, (fstat_buff+$0A)             ; > 16mb
                or      a                               ;
                jr      nz, vwsz_toobig                 ;

                ld      a, (fstat_buff+7)               ; copy size to buff
                ld      (vsize), a                      ; low byte
                ld      a, (fstat_buff+8)               ;
                ld      (vsize+1), a                    ; middle byte
                ld      a, (fstat_buff+9)               ;
                ld      (vsize+2), a                    ; high byte
                                                        ;
                ld      a, (fstat_buff+9)               ; 1-16mb
                and     0F0h
                jr      nz, loc_0017
                                                        ;
                ld      e, 0A0h
                ld      l, 86h
                ld      h, 1
                ld      d, 0
                call    sub_0002
                ld      (txt_kb), a
                ld      e, 10h
                ld      l, 27h
                ld      h, 0
                ld      d, 0
                call    sub_0002
                ld      (txt_kb+1), a
                ld      e, 0E8h
                ld      l, 3
                ld      h, 0
                ld      d, 0
                call    sub_0002
                ld      (txt_kb+2), a
                ld      a, (txt_kb)
                cp      30h
                jr      nz, loc_0016
                ld      a, 20h
                ld      (txt_kb), a
                ld      a, (txt_kb+1)
                cp      30h
                jr      nz, loc_0016
                ld      a, 20h
                ld      (txt_kb+1), a
loc_0016:
                ld      de, 921h
                ld      bc, txt_kb
                call    print
                ret
vwsz_toobig:
                ld      de, 916h
                ld      bc, txt_toobig
                call    print
                ret
loc_0017:
                ld      a, 31h
                ld      (txt_mb), a
                ld      a, (fstat_buff+9)
                rra
                rra
                rra
                rra
                and     0Fh
                ld      b, a
                sub     0Bh
                jr      nc, loc_0018
                ld      a, 20h
                ld      (txt_mb), a
loc_0018:
                ld      a, b
                add     a, 30h
                ld      (txt_mb+1), a
                ld      a, (vsize +2)
                and     0Fh
                ld      (vsize + 2), a
                ld      e, 0A0h
                ld      l, 86h
                ld      h, 1
                ld      d, 0
                call    sub_0002
                ld      (txt_mb+3), a
                ld      de, 920h
                ld      bc, txt_mb
                call    print
                ret
                                                        ;
;-------------------------------------------------------;
; --- вспом. для view_size: извлечь одну десятичную цифру
; из 24-битного числа vsize путём повторного вычитания величины
; DHL (степень десятки); возвращает цифру в виде ASCII-символа (a).
sub_0002:
                inc     d
                ld      a, (vsize)
                sub     e
                ld      (vsize), a
                ld      a, (vsize + 1)
                sbc     a, l
                ld      (vsize +1), a
                ld      a, (vsize + 2)
                sbc     a, h
                ld      (vsize +2), a
                jr      nc, sub_0002
                dec     d
                ld      a, (vsize)
                add     a, e
                ld      (vsize), a
                ld      a, (vsize + 1)
                adc     a, l
                ld      (vsize + 1), a
                ld      a, (vsize + 2)
                adc     a, h
                ld      (vsize + 2), a
                ld      a, d
                add     a, 30h
                ret
                                                        ;
; ======================================================;
; ПРОВЕРКА ФАКТИЧЕСКОГО НАЛИЧИЯ ЗВУКОЧИПА В ЖЕЛЕЗЕ.
; По curr_chip (1=OPL2/OPL3, 2=AY, 4=YM2203) читает
; тестовый/статусный регистр чипа и сравнивает с ожидаемым
; значением; если чип не откликнулся - печатает "NOT DETECTED".
; Для остальных типов чипов (SAA1099, SN76489, YMF262) проверка
; не выполняется (сразу ret).
; ======================================================;
sub_0003:
                ld      a, (curr_chip)
                cp      1                               ; OPL
                jr      z, loc_0019
                cp      2                               ; AY
                jr      z, loc_0021
                cp      4
                jr      z, loc_0022
                ret
; --- проверка OPL2/OPL3: пишем тестовый статус-регистр и ждём
; сброса бита занятости через задержку (loc_0020), читаем статус
loc_0019:
                ld      a, 4
                out     (YMF262_ADDR1), a
                nop
                ld      a, 60h
                out     (YMF262_DATA1), a
                nop
                ld      a, 2
                out     (YMF262_ADDR1), a
                nop
                ld      a, 0FFh
                out     (YMF262_DATA1), a
                nop
                ld      a, 4
                out     (YMF262_ADDR1), a
                nop
                ld      a, 21h
                out     (YMF262_DATA1), a
                ld      b, 0FFh
loc_0020:
                nop
                djnz    loc_0020
                in      a, (YMF262_ADDR1)
                cp      0C0h
                ret     z
                jr      loc_0023
; --- проверка AY: пишем per.7=0, читаем обратно per.7 через AY_ADDR,
; ожидаем получить 0 (реальный чип отвечает на запись) ---
loc_0021:
                ld      a, 0
                ld      bc, AY_ADDR
                out     (c), a
                ld      bc, AY_DATA
                out     (c), a
                ld      bc, AY_ADDR
                in      a, (c)
                cp      0
                ret     z
                jr      loc_0023
; --- проверка второго AY (TurboSound?): читаем регистр 0xFD,
; ожидаем бит 7 = 0 ---
loc_0022:
                ld      a, 0FDh
                ld      bc, AY_ADDR
                out     (c), a
                in      a, (c)
                bit     7, a
                ret     z
                jr      loc_0023
; --- чип не откликнулся - вывести "NOT DETECTED" ---
loc_0023:
                ld      de, 0A10h
                ld      bc, txt_notdet
                call    print
                ret
                                                        ;
; --- таблица для rd_header: offset 4-байтового поля клока ;
; в заголовке VGM + бит чипа для chips_mask ---           ;
mask_tbl:
                dw      10h
                db      MSK_YM2413
                dw      0Ch
                db      MSK_SN
                dw      44h
                db      MSK_YM2203
                dw      50h
                db      MSK_OPL
                dw      5Ch
                db      MSK_OPL
                dw      74h
                db      MSK_AY
                dw      0C8h
                db      MSK_SAA
                                                        ;
;============ Reset all soundchip registers ============;
; ГЛУШЕНИЕ ЗВУКОЧИПОВ (вызывается при остановке/смене трека).
; Глушатся ВСЕ чипы, объявленные в заголовке файла       ;
; (chips_mask из rd_header), а не только curr_chip:      ;
; парсер играет команды всех чипов, и мультичиповый VGM  ;
; иначе оставлял второй чип звучать после выхода.        ;
; Каждый *_reset пишет только в порты чипа, который файл ;
; реально использует - новых побочных обращений к портам ;
; (ULA/#7FFD на частичном декоде #C0/#C4) не появляется. ;
; ======================================================;
sound_off:
                ld      a, (chips_mask)                 ;
                and     MSK_YM2413                      ;
                call    nz, YM2413_reset                ;
                ld      a, (chips_mask)                 ;
                and     MSK_YM2203                      ;
                call    nz, YM2203_reset                ;
                ld      a, (chips_mask)                 ;
                and     MSK_SAA                         ;
                call    nz, SAA_reset                   ; глушит оба SAA
                ld      a, (chips_mask)                 ;
                and     MSK_OPL                         ;
                call    nz, OPL_reset                   ;
                ld      a, (chips_mask)                 ;
                and     MSK_SN                          ;
                call    nz, SN76489_reset               ; оба SN, проваливается в AY_reset
                ld      a, (chips_mask)                 ;
                and     MSK_AY                          ;
                call    nz, AY_reset                    ;
                ret                                     ;
; --- глушение SN76489/SN76496: сброс регистров громкости всех
; 4 каналов (тон 0-2 и шум) через порт SN76489_ADDR (0xC9) ---
; Гасятся оба чипа (SN76489_ADDR и SN76489_ADDR2=$C2) - запись во
; второй чип безопасна, даже если физически он отсутствует.
SN76489_reset:
                ld      a, 80h
                out     (SN76489_ADDR), a
                xor     a
                out     (SN76489_ADDR), a
                ld      a, 0A0h
                out     (SN76489_ADDR), a
                xor     a
                out     (SN76489_ADDR), a
                ld      a, 0C0h
                out     (SN76489_ADDR), a
                xor     a
                out     (SN76489_ADDR), a
                ld      a, 0E0h
                out     (SN76489_ADDR), a
                ld      a, 9Fh
                out     (SN76489_ADDR), a
                ld      a, 0BFh
                out     (SN76489_ADDR), a
                ld      a, 0DFh
                out     (SN76489_ADDR), a
                ld      a, 0FFh
                out     (SN76489_ADDR), a
                                                        ;
                ld      a, 80h                          ; чип 2 ($C2)
                out     (SN76489_ADDR2), a
                xor     a
                out     (SN76489_ADDR2), a
                ld      a, 0A0h
                out     (SN76489_ADDR2), a
                xor     a
                out     (SN76489_ADDR2), a
                ld      a, 0C0h
                out     (SN76489_ADDR2), a
                xor     a
                out     (SN76489_ADDR2), a
                ld      a, 0E0h
                out     (SN76489_ADDR2), a
                ld      a, 9Fh
                out     (SN76489_ADDR2), a
                ld      a, 0BFh
                out     (SN76489_ADDR2), a
                ld      a, 0DFh
                out     (SN76489_ADDR2), a
                ld      a, 0FFh
                out     (SN76489_ADDR2), a

; ------------------ Глушение AY-8910/8912 ------------ ;
; Микшер (per. 7) = 0x3F (все каналы и шум выключены из микса),
; громкости каналов A/B/C (per. 8-10) = 0.
AY_reset:
                ld      a, 7                            ;
                ld      bc, AY_ADDR
                out     (c), a
                ld      a, 3Fh
                ld      bc, AY_DATA
                out     (c), a
                ld      a, 8
                ld      bc, AY_ADDR
                out     (c), a
                xor     a
                ld      bc, AY_DATA
                out     (c), a
                ld      a, 9
                ld      bc, AY_ADDR
                out     (c), a
                xor     a
                ld      bc, AY_DATA
                out     (c), a
                ld      a, 0Ah
                ld      bc, AY_ADDR
                out     (c), a
                xor     a
                ld      bc, AY_DATA
                out     (c), a
                ret
                                                        ;
; ------------------ Глушение SAA1099 ----------------- :
; Регистр 0x1C (управление каналами) = 0 - выключает все каналы.
; Гасятся оба чипа: #01FF/#00FF (чип 1) и #03FF/#02FF (чип 2,;
; выбирается в ПЛИС по addr[9]). Если второй чип на конкретном;
; железе физически отсутствует - запись в неиспользуемый порт;
; безопасна.                                                 ;
SAA_reset:
                ld      a, #1C                          ; Регистр контроля звука SAA
                ld      bc, SAA1099_ADDR                ; Порт регистра, чип 1
                out     (c), a
                ld      a, #00                          ; Выключаем все каналы
                ld      bc, SAA1099_DATA                ; Порт данных, чип 1
                out     (c), a
                                                        ;
                ld      a, #1C                          ; Регистр контроля звука SAA
                ld      bc, SAA1099_ADDR2               ; Порт регистра, чип 2
                out     (c), a
                ld      a, #00                          ; Выключаем все каналы
                ld      bc, SAA1099_DATA2               ; Порт данных, чип 2
                out     (c), a
                ret                                     ;
; ------------------ Глушение YM2413/OPLL ------------- ;
; Регистр 0x0E (ритм-режим) = 0 - отключает ритм.
; Регистры 0x20-0x28 (key-on/блок/старший байт F-Number по 9
; каналам) = 0 - снимает key-on со всех каналов.
; Регистры 0x30-0x38 (тембр/громкость по 9 каналам) = 0x0F -
; громкость выставлена в минимум (тишина) на всех каналах.
YM2413_reset:
                ld      a, 0Eh
                ld      bc, YM2413_ADDR
                out     (c), a
                nop
                nop
                xor     a
                ld      bc, YM2413_DATA
                out     (c), a
                nop
                nop
                ld      d, 20h
ym2413_rst_key:
                ld      a, d
                ld      bc, YM2413_ADDR
                out     (c), a
                nop
                nop
                xor     a
                ld      bc, YM2413_DATA
                out     (c), a
                nop
                nop
                inc     d
                ld      a, d
                cp      29h
                jr      nz, ym2413_rst_key
                ld      d, 30h
ym2413_rst_vol:
                ld      a, d
                ld      bc, YM2413_ADDR
                out     (c), a
                nop
                nop
                ld      a, 0Fh
                ld      bc, YM2413_DATA
                out     (c), a
                nop
                nop
                inc     d
                ld      a, d
                cp      39h
                jr      nz, ym2413_rst_vol
                ret
;-------------------------------------------------------;
; --- глушение YM2203 через встроенный AY-совместимый PSG-блок:
; sub_0004 гасит огибающую/громкости (вызывается для двух "адресов"
; 0xF0/0xF1 - вероятно, переключение между встроенным PSG и
; FM-частью), затем принудительно AY_ADDR=0xFE.
YM2203_reset:
                ld      a, 0F0h
                call    sub_0004
                ld      a, 0F1h
                call    sub_0004
                ld      bc, AY_ADDR
                ld      a, 0FEh
                out     (c), a
                ret
                                                        ;
; ======================================================;
; ГЛУШЕНИЕ OPL2/OPL3 (YM3812/YMF262).
; Обнуляет регистры операторов (release/attack, sustain и т.п.)
; в диапазоне 0x01-0x02 и 0xB0-0xB8/0x08-0xF5 через opl_set0,
; отключает режим OPL3 (Bank2, per. 5 = 0).
; ============================================================
OPL_reset:      ld      d, 1                            ; OPL reset
                ld      e, 2
                call    opl_set0
                ld      a, 4
                out     (YMF262_ADDR1), a
                nop
                ld      a, 60h
                out     (YMF262_DATA1), a
                nop
                ld      a, 80h
                out     (YMF262_DATA1), a
                nop
                ld      a, 5
                out     (YMF262_ADDR2), a
                nop
                ld      a, 1
                out     (YMF262_DATA2), a
                nop
                ld      a, 4
                out     (YMF262_ADDR2), a
                nop
                xor     a
                out     (YMF262_DATA2), a
;-------------------------------------------------------;
                ld      d, 0B0h
                ld      e, 0B8h
                call    opl_set0
                ld      d, 8
                ld      e, 0F5h
                call    opl_set0
                ld      a, 5
                out     (YMF262_ADDR2), a
                nop
                xor     a
                out     (YMF262_DATA2), a
                ret
;-------------------------------------------------------;
; --- вспом. для OPL_reset: для каждого порта d..e пишет 0
; и в банк 1 (YMF262_ADDR1/DATA1), и в банк 2 (ADDR2/DATA2).
; На входе: D = начальный номер регистра, E = конечный.
opl_set0:                                               ; D - start port
               ld       a, d                            ; E - end port
                out     (YMF262_ADDR1), a
                nop
                xor     a
                out     (YMF262_DATA1), a
                nop
                ld      a, d
                out     (YMF262_ADDR2), a
                nop
                xor     a
                out     (YMF262_DATA2), a
                ld      a, d
                cp      e
                ret     z
                inc     d
                jr      opl_set0
                                                        ;
;-------------------------------------------------------;
; --- вспом. для YM2203_reset (глушение YM2203/AY-совместимого PSG):
; на входе A = "адрес" (0xF0 или 0xF1, см. YM2203_reset). Обнуляет
; огибающую (per. 11-13 через 0x28+0/1/2) и устанавливает уровни
; громкости регистров 0x40-0x4E и 0x80-0x8E в тихие значения,
; в конце вызывает общий AY_reset.
sub_0004:
                ld      bc, AY_ADDR
                out     (c), a
                ld      a, 28h
                ld      bc, AY_ADDR
                out     (c), a
                xor     a
                ld      bc, AY_DATA
                out     (c), a
                inc     a
                out     (c), a
                inc     a
                out     (c), a
                ld      bc, AY_ADDR
                ld      a, 27h
                out     (c), a
                ld      bc, AY_DATA
                ld      a, 30h
                out     (c), a
                ld      b, 0Fh
                ld      d, 40h
loc_0024:
                push    bc
                ld      bc, AY_ADDR
                ld      a, d
                out     (c), a
                ld      bc, AY_DATA
                ld      a, 7Fh
                out     (c), a
                inc     d
                pop     bc
                djnz    loc_0024
                ld      b, 0Fh
                ld      d, 80h
loc_0025:
                push    bc
                ld      bc, AY_ADDR
                ld      a, d
                out     (c), a
                ld      bc, AY_DATA
                ld      a, 0Fh
                out     (c), a
                inc     d
                pop     bc
                djnz    loc_0025
                call    AY_reset
                ret
                                                        ;
; ======================================================;
; ОТРИСОВКА СТАРТОВОГО ЭКРАНА/МЕНЮ ПЛЕЕРА.
; Очищает область экрана (0-0x7FF), красит атрибуты рамки текста
; (bright/цвет), печатает заголовок (txt_title), подсказку по
; клавишам (txt_ctr) и нижнюю рамку (txt_bot). Далее (clear_text)
; печатает подписи полей File/Chip/Track/Game - используется и при
; старте, и при переходе к следующему файлу для очистки старых значений.
; =======================================================
menu:
                ld      de, 800h
                call    calc_scr_addr
                ld      bc, 800h
lp_clr:
                ld      (hl), 0
                inc     hl
                dec     bc
                ld      a, b
                or      c
                jr      nz, lp_clr
                                                        ;
                ld      a, 3Bh
                ld      hl, 5900h
                ld      b, 20h
lp_sattr1:
                ld      (hl), a
                inc     hl
                djnz    lp_sattr1

                ld      a, 38h
                ld      hl, 5920h
                ld      b, 0A0h
lp_sattr2:
                ld      (hl), a
                inc     hl
                djnz    lp_sattr2
                                                        ;
                ld      a, 39h
                ld      hl, 59C0h
                ld      b, 20h
lp_sattr3:
                ld      (hl), a
                inc     hl
                djnz    lp_sattr3
                ld      a, 3Bh
                ld      hl, 59E0h
                ld      b, 20h
lp_sattr4:
                ld      (hl), a
                inc     hl
                djnz    lp_sattr4
                                                        ;
                ld      hl, 5920h
                ld      de, 1Fh
                ld      a, 3Bh                          ; white/magenta
                ld      b, 6
lp_sattr5:
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     hl
                djnz    lp_sattr5
                                                        ;
                ld      de, 0B00h
                call    calc_scr_addr
                ld      e, 0
                ld      a, 87h
                call    print_char
                                                        ;
                ld      de, 0B1Fh
                call    calc_scr_addr
                                                        ;
                ld      e, 29h
                ld      a, 85h
                call    print_char
                                                        ;
                ld      de, $0800                       ; d=Y, e=X
                ld      bc, txt_title                   ; BC = string (0-terminated)
                call    print
                                                        ;
                ld      de, 0E00h
                ld      bc, txt_ctr
                call    print
                                                        ;
                ld      de, 0F00h
                ld      bc, txt_bot
                call    print
;-------------------------------------------------------;
clear_text:     ld      de, 900h
                ld      bc, txt_file
                call    print
                                                        ;
                ld      de, 0A00h
                ld      bc, txt_chip
                call    print
                                                        ;
                ld      de, 0C00h
                ld      bc, txt_track
                call    print
                                                        ;
                ld      de, 0D00h
                ld      bc, txt_game
                call    print
                                                        ;
                ret
                                                        ;
;------------------ Print char--------------------------;
; ВЫВОД ОДНОГО СИМВОЛА НА ЭКРАН.
; DE - адрес видеопамяти (из calc_scr_addr), A - код символа.
; Экран разбит на "уплотнённые" колонки по 2 бита на символ
; (см. ветки pos0..pos3 - смещение печати внутри байта экрана
; зависит от (X mod 4)); использует знакогенератор font (8х8,
; символы с кодом 32 = ' ' и далее).
; =======================================================
print_char:
                ex      de, hl                          ; HL -VRAM
; a - char
                ld      c, l                            ;

                sub     32                              ; shift to start table
                ld      l, a
                ld      h, 0
                                                        ;
                ld      a, c
                add     hl, hl
                add     hl, hl
                add     hl, hl
                ld      bc, font
                add     hl, bc
                and     3
                cp      0
                jr      z, pos0
                cp      1
                jr      z, pos1
                cp      2
                jr      z, pos2
                cp      3
                jr      z, pos3
pos0:
                ld      b, 8
lp_pos0:
                ld      a, (de)
                and     0C0h
                ld      c, (hl)
                srl     c
                srl     c
                or      c
                ld      (de), a
                inc     hl
                inc     d
                djnz    lp_pos0
                ret
;-------------------------------------------------------;
pos1:
                ld      b, 8
lp_pos1:
                ld      a, (de)
                and     3
                ld      c, (hl)
                or      c
                ld      (de), a
                inc     hl
                inc     d
                djnz    lp_pos1
                ret
;-------------------------------------------------------;
pos2:
                ld      b, 8
loc_0026:
                ld      a, (hl)
                rlc     a
                rlc     a
                and     3
                ld      c, a
                ld      a, (de)
                and     0FCh
                or      c
                ld      (de), a
                inc     e
                ld      a, (hl)
                sla     a
                sla     a
                ld      c, a
                ld      a, (de)
                and     0Fh
                or      c
                ld      (de), a
                dec     e
                inc     d
                inc     hl
                djnz    loc_0026
                ret
;-------------------------------------------------------;
pos3:
                ld      b, 8
lp_pos3:
                ld      a, (hl)
                srl     a
                srl     a
                srl     a
                srl     a
                ld      c, a
                ld      a, (de)
                and     0F0h
                or      c
                ld      (de), a
                inc     e
                ld      a, (hl)
                sla     a
                sla     a
                sla     a
                sla     a
                ld      c, a
                ld      a, (de)
                and     3Fh
                or      c
                ld      (de), a
                dec     e
                inc     d
                inc     hl
                djnz    lp_pos3
                ret
                                                        ;
;------------------ Print string -----------------------;
; ВЫВОД СТРОКИ (ASCII, 0-terminated).                   ;
; DE = координаты начала (d=строка текста, e=колонка), BC = адрес
; строки. Печатает по одному символу через print_char, продвигая
; координату и указатель на строку, пока не встретит 0. ;
; ======================================================;
print:                                                  ;
                ld      a, (bc)                         ; BC - string addr
                or      a                               ;
                ret     z                               ;
                                                        ;
                push    af                              ;
                push    de                              ;
                ld      a, e                            ;
                and     3Fh                             ;
                add     a, a                            ;
                ld      l, a                            ;
                add     a, a                            ;
                add     a, l                            ;
                add     a, 2                            ;
                srl     a                               ;
                srl     a                               ;
                srl     a                               ;
                ld      e, a                            ;
                call    calc_scr_addr                   ;
                pop     de                              ;
                pop     af                              ;
                push    de                              ;
                push    bc                              ;
                call    print_char                      ;
                pop     bc                              ;
                pop     de                              ;
                inc     e                               ;
                inc     bc                              ;
                jr      print                           ;
                                                        ;
;-------------------------------------------------------;
; --- вычислить адрес экрана ZX Spectrum по координатам ;
; D = номер текстовой строки (Y), E = колонка (X) -> HL = адрес
; в видеопамяти (стандартная нелинейная адресация экрана ZX).
calc_scr_addr:                                          ;
                ld      a, d                            ;
                and     18h                             ;
                or      40h                             ;
                ld      h, a                            ;
                ld      a, d                            ;
                and     7                               ;
                rla                                     ;
                rla                                     ;
                rla                                     ;
                rla                                     ;
                rla                                     ;
                add     a, e                            ;
                ld      l, a                            ;
                ret                                     ;
                                                        ;
;-------------------------------------------------------;
                                                        ;
drive:                  db 0                            ;
file_handle:            db 0                            ;
entryFile:              dw 0                            ;
fstat_buff:             ds 16                           ;
eof:                    dw $FFFF                        ;
bufPos:                 dw 0                            ;
event:                  dw $FFFF                        ; 0x0000 - space key, 0x0001 - "Q" key, 0xFFFF - eof
vsize:                  ds 3                            ;
track:                  ds 35                           ;
game:                   ds 35                           ;
bar:                    ds 29                           ;
curr_chip:              db 0                            ;
chips_mask:             db 0                            ; биты MSK_* - чипы файла
txt_title:              db $80, $84, $84, $84, $84, $84, $84, $84, $84, $84,$84, $84, " VGM Player 0.63 " , $84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$81,0;
txt_file:               db $87, "File:                                   ", $85,0;
txt_chip:               db $87, "Chip:                                   ", $85,0;
txt_ctr:                db $87, "          Space-next,   Q-quit          ", $85,0;
txt_bot:                db $83, $86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$82,0;
                                                        ;
txt_chip1:              db "YM3812",     0              ;
txt_chip2:              db "YMF262",     0              ;
txt_chip3:              db "AY-38910",   0              ;
txt_chip4:              db "YM2413",     0              ;
txt_chip5:              db "YM2203",     0              ;
txt_chip6:              db "2xYM2203",   0              ;
txt_chip7:              db "SAA1099",    0              ;
txt_chip8:              db "2xSAA1099",  0              ;
txt_chip9:              db "SN76489",    0              ;
txt_chip10:             db "2xSN76489",  0              ;
txt_unsup:              db "Unsupported",0              ;
txt_track:              db $87, "Track:                                  ", $85, 0;
txt_game:               db $87, "Game:                                   ", $85, 0;
txt_pause:              db "PAUSE", 0                   ;
txt_error:              db "ERROR",0                    ;
txt_toobig:             db "> 16 Mb",0                  ;
txt_mb:                 db "00.0 Mb",0                  ;
txt_kb:                 db "000 Kb",0                   ;
txt_notdet:             db "NOT DETECTED", 0            ;
                                                        ;
BUFF_START:             EQU $9000                       ;
BUFF_END:               EQU $92                         ;
                                                        ;
font:                   db $00, $00, $00, $00, $00, $00, $00, $00 ; Space
                        db $00, $20, $20, $20, $20, $00, $20, $00 ; !
                        db $00, $90, $90, $00, $00, $00, $00, $00 ; "
                        db $00, $50, $F8, $50, $50, $F8, $50, $00 ; #
                        db $00, $20, $F8, $A0, $F8, $28, $F8, $20 ; $
                        db $00, $00, $C8, $D0, $20, $58, $98, $00 ; %
                        db $00, $20, $50, $20, $58, $90, $68, $00 ; &
                        db $00, $40, $80, $00, $00, $00, $00, $00 ; '
                        db $00, $20, $40, $40, $40, $40, $20, $00 ; (
                        db $00, $40, $20, $20, $20, $20, $40, $00 ; )
                        db $00, $00, $20, $F8, $70, $F8, $20, $00 ; *
                        db $00, $00, $20, $20, $F8, $20, $20, $00 ; +
                        db $00, $00, $00, $00, $00, $20, $20, $40 ; ,
                        db $00, $00, $00, $00, $F0, $00, $00, $00 ; -
                        db $00, $00, $00, $00, $00, $60, $60, $00 ; .
                        db $00, $00, $08, $10, $20, $40, $80, $00 ; /

                        db $00, $70, $88, $98, $A8, $C8, $70, $00 ; 0
                        db $00, $20, $60, $20, $20, $20, $70, $00 ; 1
                        db $00, $70, $88, $08, $70, $80, $F8, $00 ; 2
                        db $00, $70, $88, $30, $08, $88, $70, $00 ; 3
                        db $00, $10, $30, $50, $90, $F8, $10, $00 ; 4
                        db $00, $F8, $80, $F0, $08, $88, $70, $00 ; 5
                        db $00, $70, $80, $F0, $88, $88, $70, $00 ; 6
                        db $00, $F8, $08, $10, $20, $40, $40, $00 ; 7
                        db $00, $70, $88, $70, $88, $88, $70, $00 ; 8
                        db $00, $70, $88, $88, $78, $08, $70, $00 ; 9
                        db $00, $00, $00, $20, $00, $00, $20, $00 ; :
                        db $00, $00, $20, $00, $00, $20, $20, $40 ; ;
                        db $00, $00, $10, $20, $40, $20, $10, $00 ; <
                        db $00, $00, $00, $78, $00, $78, $00, $00 ; =
                        db $00, $00, $40, $20, $10, $20, $40, $00 ; >
                        db $00, $70, $88, $10, $20, $00, $20, $00 ; ?

                        db $00, $70, $A8, $98, $B8, $80, $70, $00 ; @
                        db $00, $70, $88, $88, $F8, $88, $88, $00 ; A
                        db $00, $F0, $88, $F0, $88, $88, $F0, $00 ; B
                        db $00, $70, $88, $80, $80, $88, $70, $00 ; C
                        db $00, $E0, $90, $88, $88, $90, $E0, $00 ; D
                        db $00, $F8, $80, $F0, $80, $80, $F8, $00 ; E
                        db $00, $F8, $80, $F0, $80, $80, $80, $00 ; F
                        db $00, $70, $88, $80, $98, $88, $70, $00 ; G
                        db $00, $88, $88, $F8, $88, $88, $88, $00 ; H
                        db $00, $F8, $20, $20, $20, $20, $F8, $00 ; I
                        db $00, $08, $08, $08, $88, $88, $70, $00 ; J
                        db $00, $90, $A0, $C0, $A0, $90, $88, $00 ; K
                        db $00, $80, $80, $80, $80, $80, $F8, $00 ; L
                        db $00, $88, $D8, $A8, $88, $88, $88, $00 ; M
                        db $00, $88, $C8, $A8, $98, $88, $88, $00 ; N
                        db $00, $70, $88, $88, $88, $88, $70, $00 ; O

                        db $00, $F0, $88, $88, $F0, $80, $80, $00 ; P
                        db $00, $70, $88, $88, $A8, $98, $78, $00 ; Q
                        db $00, $F0, $88, $88, $F0, $88, $88, $00 ; R
                        db $00, $70, $80, $70, $08, $88, $70, $00 ; S
                        db $00, $F8, $20, $20, $20, $20, $20, $00 ; T
                        db $00, $88, $88, $88, $88, $88, $70, $00 ; U
                        db $00, $88, $88, $88, $88, $50, $20, $00 ; V
                        db $00, $88, $88, $88, $88, $A8, $50, $00 ; W
                        db $00, $88, $50, $20, $20, $50, $88, $00 ; X
                        db $00, $88, $88, $50, $20, $20, $20, $00 ; Y
                        db $00, $F8, $08, $10, $20, $40, $F8, $00 ; Z
                        db $00, $70, $40, $40, $40, $40, $70, $00 ; [
                        db $00, $00, $80, $40, $20, $10, $08, $00 ; \
                        db $00, $70, $10, $10, $10, $10, $70, $00 ; ]
                        db $00, $20, $70, $A8, $20, $20, $20, $00 ; ^
                        db $00, $00, $00, $00, $00, $00, $00, $F8 ; _

                        db $00, $30, $48, $E0, $40, $40, $F8, $00;
                        db $00, $00, $70, $08, $78, $88, $78, $00 ; a
                        db $00, $80, $80, $F0, $88, $88, $F0, $00 ; b
                        db $00, $00, $70, $80, $80, $80, $70, $00 ; c
                        db $00, $08, $08, $78, $88, $88, $78, $00 ; d
                        db $00, $00, $70, $88, $F0, $80, $78, $00 ; e
                        db $00, $30, $40, $F0, $40, $40, $40, $00 ; f
                        db $00, $00, $78, $88, $88, $78, $08, $30 ; g
                        db $00, $80, $80, $F0, $88, $88, $88, $00 ; h
                        db $00, $20, $00, $60, $20, $20, $70, $00 ; i
                        db $00, $10, $00, $10, $10, $10, $90, $60 ; j
                        db $00, $80, $A0, $C0, $C0, $A0, $90, $00 ; k
                        db $00, $40, $40, $40, $40, $40, $30, $00 ; l
                        db $00, $00, $D0, $A8, $A8, $A8, $A8, $00 ; m
                        db $00, $00, $F0, $88, $88, $88, $88, $00 ; n
                        db $00, $00, $70, $88, $88, $88, $70, $00 ; o

                        db $00, $00, $F0, $88, $88, $F0, $80, $80 ; p
                        db $00, $00, $70, $90, $90, $70, $10, $18 ; q
                        db $00, $00, $70, $80, $80, $80, $80, $00 ; r
                        db $00, $00, $70, $80, $70, $08, $F0, $00 ; s
                        db $00, $40, $E0, $40, $40, $40, $30, $00 ; t
                        db $00, $00, $88, $88, $88, $88, $70, $00 ; u
                        db $00, $00, $88, $88, $50, $50, $20, $00 ; v
                        db $00, $00, $88, $A8, $A8, $A8, $50, $00 ; w
                        db $00, $00, $88, $50, $20, $50, $88, $00 ; x
                        db $00, $00, $88, $88, $88, $78, $08, $70 ; y
                        db $00, $00, $F8, $10, $20, $40, $F8, $00 ; z
                        db $00, $38, $20, $60, $20, $20, $38, $00 ; {
                        db $00, $20, $20, $20, $20, $20, $20, $00 ; |
                        db $00, $70, $10, $18, $10, $10, $70, $00 ; }
                        db $00, $50, $A0, $00, $00, $00, $00, $00 ; ~
                        db $00, $70, $A8, $C8, $C8, $A8, $70, $00 ; Copyright

                        db $00, $3C, $40, $9C, $A0, $A0, $A0, $A0 ; upper left corner
                        db $00, $F0, $08, $E4, $14, $14, $14, $14 ; right
                        db $14, $14, $14, $14, $E4, $08, $F0, $00 ; lower right corner
                        db $A0, $A0, $A0, $A0, $9C, $40, $3C, $00 ; left
                        db $00, $FC, $00, $FC, $00, $00, $00, $00 ; upper edge
                        db $14, $14, $14, $14, $14, $14, $14, $14 ; right
                        db $00, $00, $00, $00, $FC, $00, $FC, $00 ; lower
                        db $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0 ; left

                        db 0                                      ;
endvgm:

                        SAVEBIN "VGM", vgm_start, endvgm - vgm_start