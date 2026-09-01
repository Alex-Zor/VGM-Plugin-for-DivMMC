						ORG $8000					;

;=================== Plugin header==================
						jr entry_point:
plugin_info:
						db "BP"							; id
						db 0							; spare
						db 0							; spare
						db PLUGIN_FLAGS1_COPY_SETTINGS	; flags
						db 0							; flags2
plugin_user_data:
						db PLUGIN_SETTING_MAX			; reserve space for settings copy
plugin_id_string:
						defb ".VGM file plugin 0.611 - by Alex Zor", $0

;=================== ESXDOS ========================
ESXDOS_OPEN:			EQU $9A						;
ESXDOS_READ:			EQU $9D						;
ESXDOS_CLOSE:			EQU $9B						;
ESXDOS_GETSETDRV:		EQU $89						;
ESXDOS_FSEEK:			EQU $9F						;
ESXDOS_FSTAT:			EQU $A1						;
ESXDOS_OPENDIR:			EQU $A3						;
ESXDOS_READDIR:			EQU $A4						;

FA_READ:				EQU 1						;

;===================== AY ==========================
AY_ADDR:				EQU $FFFD					;
AY_DATA:				EQU $BFFD					;

;=================== YMG262 ========================
YMF262_ADDR1:			EQU $C4						;
YMF262_DATA1:			EQU $C5						;
YMF262_ADDR2:			EQU $C6						;
YMF262_DATA2:			EQU $C7						;

;===================== VGM =========================
CMD_AY:					EQU $A0						;
CMD_YM3812:				EQU $5A						;
CMD_YMF262_1:			EQU $5E						;
CMD_YMF262_2:			EQU $5F						;
CMD_YM2203_1:			EQU $55						;
CMD_YM2203_2:			EQU $A5						;

CMD_WAIT_N:				EQU $61						;
CMD_WAIT_50:			EQU $63						;
CMD_WAIT_60:			EQU $62						;
CMD_END:				EQU $66						;

;==================== Plugin =======================
PLUGIN_SETTING_MAX:				EQU 14				;
PLUGIN_FLAGS1_COPY_SETTINGS:	EQU 1				;

;==================== ENTRY ========================
entry_point:
						di							;

						ld (entryFile), hl			; ld (currentFile), hl

						ld a, 0						; get default drive
						ld b, 0						; ?
						rst 8						;
						defb ESXDOS_GETSETDRV		;
						ld (drive), a				;

						call menu					;
						call play_file				;
						call next_file				;

						ei							;
						ret							;

;====================Player=========================
play_file:
						call open_file				;
						call fill_buf				;
						call rd_header				;
						set 1, a					;
						ld (eof), a					; set eof false
						ld de, 0					; clear wait error counter

parser_loop:			call parser					; call player_step

						ld bc, (eof)				; exit when eof true
						ld a, b						;
						or c						;
						jr z, stop_eof				;

						ld bc, $7BFE				; exit when keypress
						in a, (c)					;
						bit 0, a					;
						jr z, stop_key				;

						jr parser_loop				;

;------------------ Stop play-----------------------
stop_key:
						xor a						;
						ld h, a						;

						ld bc, $FBFE				; 'q' key
						in a, (c)					;
						bit 0, a					;
						or $FE						;
						cpl							;
						ld l, a						;
						ld (event), hl				;

						jr exit_play				;

stop_eof:				ld hl, $FFFF				;

exit_play:
						ld (event), hl				;
						call close_file				;
						call sound_off				;
						ret							;

end_vgm:				ld hl, 0					;
						ld (eof), hl				;
						ret							;

;---------------------Parser------------------------
parser:
						call get_byte				;

						cp CMD_YMF262_1				;
						jr z, wr_ymf262_1			;

						cp CMD_YMF262_2				;
						jr z, wr_ymf262_2			;

						cp CMD_YM3812				;
						jr z, wr_ymf262_1			;

						cp CMD_AY					;
						jr z, wr_ay					;

						cp CMD_WAIT_N				;
						jr z, do_wait_n				;

						cp CMD_WAIT_50				;
						jr z, do_wait_50			;

						cp CMD_WAIT_60				;
						jr z, do_wait_60			;

						cp CMD_YM2203_1				;
						jr z, wr_ym2203_1			;

						cp CMD_YM2203_2				;
						jr z, wr_ym2203_2			;

						cp CMD_END					;
						jr z, end_vgm				;

						jr parser					;
;------------------- ym2203 write ------------------
													;
wr_ym2203_2:			ld a, $F1					; select chip for dual ym2203
						jr sel_ym2203				;
wr_ym2203_1:			ld a, $F0					;

sel_ym2203:				ld bc, AY_ADDR				;
						out (c), a					;

;-------------------- AY write ---------------------
wr_ay:					call get_byte				;
						ld bc, AY_ADDR				;
						out (c), a					;
						call get_byte				;
						ld bc, AY_DATA				;
						out (c), a					;
						ret							;

;--------------- YMF (YM3812) write ----------------
wr_ymf262_1:			call get_byte				;
						out (YMF262_ADDR1), a		;
						call get_byte				;
						out (YMF262_DATA1), a		;
						nop							;
						ret							;

wr_ymf262_2:			call get_byte				;
						out (YMF262_ADDR2), a		;
						call get_byte				;
						out (YMF262_DATA2), a		;
						ret							;

;------------------ Wait N samples -----------------
do_wait_n:				call get_byte				;
						ld c, a						;
						call get_byte				;
						ld h, a						;
						ld l, c						;

wait_hl:				sbc hl, de					;
						jr c, end_wait				;
loop_delay:

						exx							;
						; progress bar
						ld (hl), $27				; $27 (green)
						ld a, (ix+0)				;
						cp e						;
						jr nz, bar_noinc			;
						inc ix						; next array index
						inc l						; next vram address
bar_noinc:
						exx							;

						ld a, h						;
						or l						;
						dec hl						;
						jr nz, loop_delay			;

end_wait:
						ld a, h						;
						xor $FF						;
						ld d, a						;
						ld a, l						;
						xor $FF						;
						ld e, a						;
						ret							;

;------------------ Wait 1/50 sec ------------------
do_wait_50:
						ld hl, 886					;
						jr wait_hl					;

;------------------ Wait 1/60 sec ------------------
do_wait_60:
						ld hl, 738					;
						jr wait_hl					;

;---------------- Get byte from buffer -------------
get_byte:
						ld hl, (bufPos)				;
						ld a, h						;
						cp BUFF_END					;
						call z, fill_buf			;
						ld a, (hl)					;

						inc hl						;
						ld (bufPos), hl				;

						inc de						;

						ret							;

;==================== LOADER =======================
fill_buf:
						ld a, (file_handle)			;
						ld hl, BUFF_START			;
						ld bc, 512					;
						rst 8						;
						defb ESXDOS_READ			;
						ld (eof), bc				;

						ex de, hl					;
						ld de, 262					;
						add hl, de					;
						ex de, hl					;

						exx							;sector counter for progress bar
						ld a, b						;
						cp c						;
						jr z, move_bar				;
						inc b						;
						exx							;

						ld hl, BUFF_START			;
						ld (bufPos), hl				;

						ret							;

move_bar:
						ld b, 0						;
						inc e						;
						exx							;

						ld hl, BUFF_START			;
						ld (bufPos), hl				;

						ret							;

;=================== OPEN FILE =====================
open_file:
						xor a						; open file
						ld (file_handle), a			;
						ld b, FA_READ				;
						ld hl, (entryFile)			;
						ld a, (drive)				;
						rst 8						;
						defb ESXDOS_OPEN			;
						ld (file_handle), a			;

						ld hl, fstat_buff			; get filesize
						rst 8						;
						defb ESXDOS_FSTAT			;

						ret							;

;----------------- Close file ----------------------
close_file:				ld a, (file_handle)			; close file
						rst 8						;
						defb ESXDOS_CLOSE			;
						xor a						;
						ld (file_handle),a			;
						ret							;

;--------------- Play next file --------------------
next_file:
						ld a, (event)				; exit if press 'Q'
						cp $01						;
						jr nz, space_event			;
						ld a, 3						; PLUGIN_OK=1 + PLUGIN_RESTORE_SCREEN=2
						ret

space_event:			ld a, (event)				; next if press Space
						or a						;
						jr nz, eof_event			;
						ld a, 11					; PLUGIN_OK=1 + PLUGIN_RESTORE_SCREEN=2 + PLUGIN_NAVIGATE=8
						ld bc, 1					; PLUGIN_NAVIGATE_NEXT=1
						ret

eof_event:
						call clear_text				;
						ld de, $0907				;
						ld bc, txt_pause			;
						call print					; print "Pause"

						ld hl, $FFFF				;
loop_pause:				ld bc, (loop_pause)			;
						ld bc, (loop_pause)			;
						ld bc, (loop_pause)
						ld bc, (loop_pause)			;
						dec hl						;
						ld a, l						;
						or h						;
						jr nz, loop_pause			; call pause between tracks

						ld a, 11					; PLUGIN_OK=1 + PLUGIN_RESTORE_SCREEN=2 + PLUGIN_NAVIGATE=8
						ld bc, 1					; PLUGIN_NAVIGATE_NEXT=1
						ret							;

;=============== Set progressbar ===================
bar_init:				ld a, (fstat_buff+9)		; calc step for bar
						ld h, a						;
						ld a, (fstat_buff+8)		;
						ld l, a						;

						or a						; clear C flag
						rr h						; size/512
						rr l						;

						ld a, h						;
						exx							; initial progress bar
						ld c, a						; set divider
						ld b, 0						;
						ld hl, $5961					; ld hl, $5961
						ld e, 0						; ld de, bar

						exx							;

						ld d, 0						; HL/(h+1)
						ld e, h						;
						inc de						;
						ld c, 0						;
lp_div:					or a						;
						sbc hl, de					;
						jr c, done_div				;
						inc c						; c is max value
						jr lp_div					;

done_div:
						ld ix, bar					;
						ld b, 29					;
						xor a						;
						ld hl, 0					;
						ld d, 0						;
lp_bartbl:
						ld a, h						;
						or a						;
						jr nz, normalize			;
						ld a, l						;
						cp c						;
						jr nc, normalize			;
						push bc						;
						ld bc, 29					;
						add hl, bc					;
						pop bc						;
						inc d						;
						jr lp_bartbl				;
normalize:
						push bc						;
						ld b, 0						;
						sbc hl, bc					;
						pop bc						;
						ld (ix+0), d				;
						inc ix						;

						djnz lp_bartbl				;

						ld ix, bar					;

						ret							;

;================== Read VGM header ================
rd_header:
						ld de, $0907				; print file name
						ld bc, (entryFile)			;
						call print					; call print

						call view_size				;

						ld a, $04					; YM2203
						ld (schip), a				;
						ld bc, $0044				; address in header
						call zerocheck				;
						jr z, nextchip				;
						bit 6, b					;
						jr nz, dual_ym2203			;
						ld bc, txt_ym2203			;
						jr chipname					;
dual_ym2203:			ld bc, txt_2xym2203			;
						jr chipname					;

nextchip:				ld a, $01					; YM3812
						ld (schip), a				;
						ld bc, $0050				; address in header
						call zerocheck				;
						ld bc, txt_ym3812			;
						jr nz, chipname				;

													; YMF262
						ld bc, $005C				; address in header
						call zerocheck				;
						ld bc, txt_ymf262			;
						jr nz, chipname				;

						ld a, $02					; AY38910
						ld (schip), a				;
						ld bc, $0074				; address in header
						call zerocheck				;
						ld bc, txt_ay38910			;
						jr nz, chipname				;

						xor a						; Unsupported chip
						ld (schip), a				;
						ld bc, txt_unsupp			;

chipname:				ld de, $0A07				;
						call print					;
						call detect_chip			;

gd3_offset:				ld hl, BUFF_START			; read offset gd3
						ld bc, $0014				;
						add hl, bc					;
						ld e, (hl)					;
						inc hl						;
						ld d, (hl)					;
						inc hl						;
						ld c, (hl)					;
						inc hl						;
						ld b, (hl)					;
						ld a, b						;
						or c						;
						or d						;
						or e						; 0 if not present
						jr z, data_offset			;

						call read_gd3				;

data_offset:			ld hl, BUFF_START			; read VGM data offset
						ld bc, $0034				;
						add hl, bc					;
						ld c, (hl)					;
						inc hl						;
						ld b, (hl)					;
						dec hl						;
						add hl, bc					;
						ld (bufPos), hl				; set start address position
						ld de, 0					;
						call bar_init				;
						ret							;

zerocheck:				xor a						;
						ld hl, BUFF_START			;
						add hl, bc					;
						ld b, (hl)					;
						or b						;
						inc hl						;
						ld b, (hl)					;
						or b						;
						inc hl						;
						ld b, (hl)					;
						or b						;
						inc hl						;
						ld b, (hl)					;
						or b						;
						ret							;

;================== Read GD3 tag ===================
read_gd3:
						ld hl, $0014				;
						add hl, de					;
						jr nc, no_cary				;
						inc bc						;
no_cary:				ld de, hl					;
						ld a, (file_handle)			;
						ld l, 0						; seek from start file
						rst 8						;
						defb ESXDOS_FSEEK			;
						; jr c, error
						call fill_buf				; read data to buffer

						ld hl, (bufPos)				; gd3 header pass
						ld bc,$000C					; add $0C
						add hl, bc					;

						ld de, track				; Track name in English
						ld b, 34					;
lp_gd3track:			ld a, (hl)					;
						ld (de), a					;
						or a						;
						jr z, gd3_jap				;
						inc de						;
						inc hl						;
						inc hl						; +2
						djnz lp_gd3track			;
						call gd3_pass				;
						xor a						;
						ld (de), a					; 0-terminated
gd3_jap:				inc hl						;
						inc hl						;
						call gd3_pass				; in original (pass)

						inc hl						; Game in English
						inc hl						;
						ld de, game					;
						ld b, 34					;
lp_gd3game:				ld a, (hl)					;
						ld (de), a					;
						or a						;
						jr z, gd3_end				;
						inc de						;
						inc hl						;
						inc hl						; +2
						djnz lp_gd3game				;
						xor a						;
						ld (de), a					; 0-terminated

gd3_end:				ld de, $0C07				; view track name
						ld bc, track				;
						call print					;

						ld de, $0D07				; view game name
						ld bc, game					;
						call print					; call print

						ld a, (file_handle)			; seek start
						ld bc, $0000				;
						ld de, $0000				;
						ld l, 0						; seek from start file
						rst 8						;
						defb ESXDOS_FSEEK			;

						call fill_buf				; read data to buffer

						ret							;

gd3_pass:
						ld b, 255					;
lp_gd3pass:				ld a, (hl)					;
						or a						;
						ret z						;
						inc hl						;
						inc hl						;
						djnz lp_gd3pass				;
						ret							;

;=================== View file size ================
view_size:
						ld a, (fstat_buff+$0A)		; > 16mb
						or a						;
						jr nz, vwsz_toobig			;

						ld a, (fstat_buff+7)		; copy size to buff
						ld (vsize), a				; low byte
						ld a, (fstat_buff+8)		;
						ld (vsize+1), a				; middle byte
						ld a, (fstat_buff+9)		;
						ld (vsize+2), a				; high byte

						ld a, (fstat_buff+$09)		; 1-16mb
						and $F0						;
						jr nz, vwsz_mb				;

; < 1mb
						ld e, $A0					; 100000
						ld l, $86					; e - low byte, h - high byte
						ld h, $01					;
						ld d, 0						;
						call sub_n					;
						ld (txt_kb), a				;

						ld e, $10					; 10000
						ld l, $27					; e - low byte, h - high byte
						ld h, $00					;
						ld d, 0						;
						call sub_n					;
						ld (txt_kb+1), a			;

						ld e, $E8					; 1000
						ld l, $03					; e - low byte, h - high byte
						ld h, $00					;
						ld d, 0						;
						call sub_n					;
						ld (txt_kb+2), a			;

						ld a, (txt_kb)				; remove zeros
						cp $30						;
						jr nz, print_kb				;
						ld a, " "					;
						ld (txt_kb), a				;

						ld a, (txt_kb+1)			;
						cp $30						;
						jr nz, print_kb				;
						ld a, " "					;
						ld (txt_kb+1), a			;

print_kb:				ld de, $0921				; print size
						ld bc, txt_kb				;
						call print					;
						ret							;

vwsz_toobig:			ld de, #0916				;
						ld bc, txt_toobig			;
						call print					;
						ret							;

vwsz_mb:				ld a, "1"					;
						ld (txt_mb), a				;
						ld a, (fstat_buff+9)		;
						rra							;
						rra							;
						rra							;
						rra							;
						and $0F						;
						ld b, a						;
						sub 11						; -11
						jr nc, vwsz_mb10			; jump if a > 10
						ld a, " "					;
						ld (txt_mb), a				;

vwsz_mb10:				ld a, b						;
						add a, $30					;
						ld (txt_mb+1), a			;

						ld a, (vsize+2)				; fraction
						and $0F						;
						ld (vsize+2), a				;

						ld e, $A0					; 100000
						ld l, $86					; e - low byte, h - high byte
						ld h, $01					;
						ld d, 0						;
						call sub_n					;

						ld (txt_mb+3), a			;

						ld de, $0920				; print size
						ld bc, txt_mb				;
						call print					;

						ret							;

sub_n:												; subtraction
						inc d						;

						ld a, (vsize)				; low byte
						sub e						;
						ld (vsize), a				;

						ld a, (vsize+1)				; middle byte
						sbc a, l					;
						ld (vsize+1), a				;

						ld a, (vsize+2)				; high byte
						sbc a, h					;
						ld (vsize+2), a				;

						jr nc, sub_n				;

						dec d						; restore previous value

						ld a, (vsize)				; low byte
						add a, e					;
						ld (vsize), a				;

						ld a, (vsize+1)				; middle byte
						adc a, l					;
						ld (vsize+1), a				;

						ld a, (vsize+2)				; high byte
						adc a, h					;
						ld (vsize+2), a				;

						ld a, d						;
						add a, $30					; a to ASCII

						ret							;

;================ Chip detect ======================
;a = 1 - YMF262 or YM3812
;a = 2 - AY38910

detect_chip:
						ld a, (schip)
						cp $01						;
						jr z, chip_opl				;
						cp $02						;
						jr z, chip_ay				;
						cp $04
						jr z, chip_ym2203			;
						ret							;

chip_opl:			 	ld a, $04					;
						out (YMF262_ADDR1), a		;
						nop							;
						ld a, $60					;
						out (YMF262_DATA1), a		;
						nop							;
						ld a, $02					;
						out (YMF262_ADDR1), a		;
						nop							;
						ld a, $FF					;
						out (YMF262_DATA1), a		;
						nop							;
						ld a, $04					;
						out (YMF262_ADDR1), a		;
						nop							;
						ld a, $21					;
						out (YMF262_DATA1), a		;

						ld b,255					; wait
lp_opl:				 	nop							;
						djnz lp_opl					;
						in a, (YMF262_ADDR1)		; read status register
						cp 192						;
						ret z						; return if detected
						jr print_not_detect			;

chip_ay:				ld a, 0						;
						ld bc, AY_ADDR				; AY detect
						out (c), a					; select R0
						ld bc, AY_DATA				;
						out (c), a					; set 0
						ld bc, AY_ADDR				;
						in a, (c)					;
						cp 0						; 0 - detect, FF - not detect
						ret z						;
						jr print_not_detect			;

chip_ym2203:										;
						ld a, $FD					; TSFM status on
						ld bc, $FFFD				;
						out (c), a					;
						in a, (c)					;
						bit 7, a					;
						ret z						;
						jr print_not_detect			;

print_not_detect:		ld de, $0A10				;print not detected
						ld bc, txt_notdet			;
						call print					;
						ret							;

;============ Reset all soundchip registers ========
sound_off:
						ld a, (schip)				;
						cp $01						;
						jr z, opl_off				;
						cp $02						;
						jr z, ay_off				;
						cp $04						;
						jr z, tsfm_off				;
						ret							;

ay_off:					ld a, $07					; AY reset
						ld bc, AY_ADDR				;
						out (c), a					;
						ld a, $3F					;
						ld bc, AY_DATA				;
						out (c), a					;
						ld a, $08					;
						ld bc, AY_ADDR				;
						out (c), a					;
						xor a						;
						ld bc, AY_DATA				;
						out (c), a					;
						ld a, $09					;
						ld bc, AY_ADDR				;
						out (c), a					;
						xor a						;
						ld bc, AY_DATA				;
						out (c), a					;
						ld a, $0A					;
						ld bc, AY_ADDR				;
						out (c), a					;
						xor a						;
						ld bc, AY_DATA				;
						out (c), a					;
						ret							;

tsfm_off:				ld a, $F0					; select chip for dual ym2203
						call ym2203_off				;
						ld a, $F1					;
						call ym2203_off				;
						ld bc, AY_ADDR				; FM - off
						ld a, $FE					;
						out (c), a					;
						ret
													; OPL reset
opl_off:				ld d, $01					;
						ld e, $02					;
						call opl_set0				;
						ld a, $04					;
						out (YMF262_ADDR1), a		;
						nop							;
						ld a, $60					; reset flags
						out (YMF262_DATA1), a		;
						nop							;
						ld a, $80					; mask timers
						out (YMF262_DATA1), a		;
						nop							;

						ld a, $05					; opl3
						out (YMF262_ADDR2), a		;
						nop							;
						ld a, $01					;
						out (YMF262_DATA2), a		;
						nop							;
						ld a, $04					;
						out (YMF262_ADDR2), a		;
						nop							;
						xor a						;
						out (YMF262_DATA2), a		;

						ld d, $B0					; key off
						ld e, $B8					;
						call opl_set0				;

						ld d, $08					; reset all registers
						ld e, $F5					;
						call opl_set0				;

						ld a, $05					; opl3 off
						out (YMF262_ADDR2), a		;
						nop							;
						xor a						;
						out (YMF262_DATA2), a		;
						ret							;
opl_set0:											; D - start port
						ld a, d						; E - finish
						out (YMF262_ADDR1), a		;
						nop							;
						xor a						;
						out (YMF262_DATA1), a		;
						nop							;
						ld a, d						;
						out (YMF262_ADDR2), a		;
						nop							;
						xor a						;
						out (YMF262_DATA2), a		;
						ld a, d						;
						cp e						;
						ret z						;
						inc d						;
						jr opl_set0					;

ym2203_off:				ld bc, AY_ADDR				; key off
						out (c), a					;
						ld a, $28					;
						ld bc, AY_ADDR				;
						out (c), a					;
						xor a						; 0x28 = 0
						ld bc, AY_DATA				;
						out (c), a					;
						inc a						; 0x28 = 1
						out (c), a					;
						inc a						; 0x28 = 2
						out (c), a					;
						ld bc, AY_ADDR				; 0x27 = 0x30
						ld a, $27					; timer off
						out (c), a					;
						ld bc, AY_DATA				;
						ld a, $30					;
						out (c), a					;

						ld b, 15					; Total level = 127
						ld d, $40					;
lp_tl127:				push bc						;
						ld bc, AY_ADDR				;
						ld a, d						;
						out (c), a					;
						ld bc, AY_DATA				;
						ld a, $7F					;
						out (c), a					;
						inc d						;
						pop bc						;
						djnz lp_tl127				;

						ld b, 15					; Release level = 15
						ld d, $80					;
lp_ff15:				push bc						;
						ld bc, AY_ADDR				;
						ld a, d						;
						out (c), a					;
						ld bc, AY_DATA				;
						ld a, $0F					;
						out (c), a					;
						inc d						;
						pop bc						;
						djnz lp_ff15				;
						call ay_off					;
						ret							;

;=================== Draw menu =====================
menu:
						ld de, $0800				;clear scr
						call calc_scr_addr			;
						ld bc, $0800				;
lp_clr:					ld (hl), 0					;
						inc hl						;
						dec bc						;
						ld a, b						;
						or c						;
						jr nz, lp_clr				;
													; set attributes
						ld a, $3B					; white/magenta
						ld hl, 22784				; AT 8,0
						ld b, 32					; 32
lp_sattr1:				ld (hl), a					;
						inc hl						;
						djnz lp_sattr1				;

						ld a, $38					; white/black
						ld hl, 22816				; AT 9,0 -13,0
						ld b, 160					; 32*5
lp_sattr2:				ld (hl), a					;
						inc hl						;
						djnz lp_sattr2				;

						ld a, $39					; white/blue
						ld hl, 22976				; AT 14,0
						ld b, 32					; 32
lp_sattr3:				ld (hl), a					;
						inc hl						;
						djnz lp_sattr3				;

						ld a, $3B					; white/magenta
						ld hl, 23008				; AT 15,0
						ld b, 32					; 32
lp_sattr4:				ld (hl), a					;
						inc hl						;
						djnz lp_sattr4				;

						ld hl, 22816				;
						ld de, 31					;
						ld a, $3B					; white/magenta
						ld b, 6						;
lp_sattr5:				ld (hl), a					;
						add hl, de					;
						ld (hl), a					;
						inc hl						;
						djnz lp_sattr5				;

						ld de, $0B00				;
						call calc_scr_addr			;
						ld e, 0						;
						ld a, $87					;
						call print_char				;

						ld de, $0B1F				;
						call calc_scr_addr			;
						ld e, $29					;
						ld a, $85					;
						call print_char				;

						ld de, $0800				; d=Y, e=X
						ld bc, txt_title			; BC = string (0-terminated)
						call print					;

						ld de, $0E00				;
						ld bc, txt_ctr				;
						call print					;

						ld de, $0F00				;
						ld bc, txt_bot				;
						call print					;

clear_text:				ld de, $0900				; print text
						ld bc, txt_file				;
						call print					;

						ld de, $0A00				;
						ld bc, txt_chip				;
						call print					;

						ld de, $0C00				;
						ld bc, txt_track			;
						call print					;

						ld de, $0D00				;
						ld bc, txt_game				;
						call print					;

						ret							;

;------------------ Print char----------------------
; Input data:
; 	A - char
; 	DE -D - y-pos(0-23), E - x-pos(0-41)
print_char:				
						ld c, e						; store x-pos
												
						ld b, a						; store char						
														
						ld a, e						; 42 to 32 charcell 
						add a, a					; (A*6+2)/8
						ld l, a						; *6
						add a, a					;
						add a, l					;
						add a, 2					; +2
						rra							; /2
						rra							; /4
						rra							; /8
						and $1F
						ld e, a						; E = col (0-31)
	
						ld a, d						; calc scr addr
						and $07						;
						rrca						;
						rrca						;
						rrca						;
						add a, e					;
						ld e, a						;						
						ld a, d						;
						and $18						;
						or $40						; 
						ld d, a						;
						
						ld a, b						; restore char
						
						sub $20						; shift to table start
						
						ld l, a						;
						ld h, 0						;

						ld a, c						; restore x-pos

						add hl, hl					; *2
						add hl, hl					; *4
						add hl, hl					; *8
						ld bc, fonts				;
						add hl, bc					; add font table address						
					
						ld b,8						; 8 lines counter
						and $03						; position on character cell
						cp $01						;
						jr z, pos1					;
						cp $02						;
						jr z, pos2					;
						cp $03						;
						jr z, pos3					;
pos0:				 
						ld a, (de)					; read from vram
						and $C0						; clear needless pixels
						ld c, (hl)					; read byte from table
						srl c						;
						srl c						;
						or c						; add
						ld (de), a					; write to vram
						inc hl						; next line
						inc d						;
						djnz pos0			 		;
						ret							;

pos1:					ld a, (de)					; read from vram
						and $03						; clear needless pixels
						ld c, (hl)					; read byte from table
						or c						; add
						ld (de), a					; write to vram
						inc hl						; next line
						inc d						;
						djnz pos1					;
						ret							;
pos2:
						ld a, (hl)					; read byte from table
						rlc a						;
						rlc a						;
						and $03						;
						ld c, a						;
						ld a, (de)					; read from vram
						and $FC						; clear needless pixels
						or c						; add
						ld (de), a					; write to vram

						inc e						; next char in vram

						ld a, (hl)					; read byte from table
						sla a						;
						sla a						;
						ld c, a						;
						ld a, (de)					; read from vram
						and $0F						; clear needless pixels
						or c						; add
						ld (de), a					; write to vram

						dec e						; previous char cell
						inc d						; next line
						inc hl						;
						djnz pos2					;
						ret							;
pos3:				
						ld a, (hl)					; read byte from table
						rrca						;
						rrca						;
						rrca						;
						rrca						;
						and $0F						;
						ld c, a						;
						ld a, (de)					; read from vram
						and $F0						; clear needless pixels
						or c						; add
						ld (de), a					; write to vram

						inc e						; next char in vram

						ld a, (hl)					; read byte from table
						rlca						;
						rlca						;
						rlca						;
						rlca						;
						and $F0						;
						ld c, a						;
						ld a, (de)					; read from vram
						and $3F						; clear needless pixels
						or c						; add
						ld (de), a					; write to vram

						dec e						; previous char cell
						inc d						; next line
						inc hl						;
						djnz pos3					;
						ret							;

;------------------ Print string -------------------
; Input data:
;	BC - string addr
;	DE - D - y-pos(0-23), E - x-pos(0-41)
; Return:
;	DE - last position
print:
						ld a, (bc)					; 
						or a						;
						ret z						;

						push de						;
						push bc						;
						call print_char				; print char
						pop bc						;
						pop de						;
						inc e						; next char
						inc bc						;
						jr print					;

;------------- get screen address by coordinates ---
; Input data:
;	DE - D - y-pos(0-23), E - x-pos(0-31)
; Return:
;	HL - vram address
calc_scr_addr:			ld a, d						;
						and $18						;
						or $40						;
						ld h, a						;
						ld a, d						;
						and $07						;
						rla							;
						rla							;
						rla							;
						rla							;
						rla							;
						add a, e					;
						ld l, a						;
						ret							;

; --------------------------------------------------
drive:					db 0						; esxdos default drive
file_handle:			db 0						;
entryFile				dw 0						;
fstat_buff:				ds 16						;
eof:					dw $FFFF					;
bufPos:					dw 0						;
event:					dw $FFFF					; 0x0000 - space key, 0x0001 - "Q" key, 0xFFFF - eof
vsize:				 	ds 3						;
track:				 	ds 35						;
game:				 	ds 35						;
bar:					ds 29						;
schip:					ds 0						; 1 - OPL, 2 - AY38910, 4 - YM2203

txt_title:              db $80, $84, $84, $84, $84, $84, $84, $84, $84, $84, $84, $84, " VGM Player 0.61 " , $84, $84, $84, $84, $84, $84, $84, $84,$84, $84, $84, $84, $81, 0;
txt_file:               db $87, "File:                                   ", $85, 0;
txt_chip:               db $87, "Chip:                                   ", $85, 0;
txt_ctr:                db $87, "          Space-next,   Q-quit          ", $85 ,0;
txt_bot:                db $83, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86, $86,$86, $86, $82,0;
txt_ym3812:             db "YM3812",0				;
txt_ymf262:             db "YMF262",0				;
txt_ay38910:            db "AY-38910",0				;
txt_ym2203:             db "YM2203",0				;
txt_2xym2203:           db "2xYM2203",0				;
txt_unsupp:             db "Unsupported",0			;
txt_track:              db $87, "Track:                                  ", $85, 0;
txt_game:               db $87, "Game:                                   ", $85, 0;
txt_pause:              db "PAUSE", 0				;
txt_error:              db "ERROR",0				;
txt_toobig:             db "> 16 Mb",0				;
txt_mb:                 db "00.0 Mb",0				;
txt_kb:                 db "000 Kb",0				;
txt_notdet:             db "NOT DETECTED", 0		;

BUFF_START:				EQU $9000					;
BUFF_END:				EQU $92						;

fonts					db $00, $00, $00, $00, $00, $00, $00, $00; Space
						db $00, $20, $20, $20, $20, $00, $20, $00; !
						db $00, $90, $90, $00, $00, $00, $00, $00; "
						db $00, $50, $F8, $50, $50, $F8, $50, $00; #
						db $00, $20, $F8, $A0, $F8, $28, $F8, $20; $
						db $00, $00, $C8, $D0, $20, $58, $98, $00; %
						db $00, $20, $50, $20, $58, $90, $68, $00; &
						db $00, $40, $80, $00, $00, $00, $00, $00; '
						db $00, $20, $40, $40, $40, $40, $20, $00; (
						db $00, $40, $20, $20, $20, $20, $40, $00; )
						db $00, $00, $20, $F8, $70, $F8, $20, $00; *
						db $00, $00, $20, $20, $F8, $20, $20, $00; +
						db $00, $00, $00, $00, $00, $20, $20, $40; ,
						db $00, $00, $00, $00, $F0, $00, $00, $00; -
						db $00, $00, $00, $00, $00, $60, $60, $00; .
						db $00, $00, $08, $10, $20, $40, $80, $00; /

						db $00, $70, $88, $98, $A8, $C8, $70, $00; 0
						db $00, $20, $60, $20, $20, $20, $70, $00; 1
						db $00, $70, $88, $08, $70, $80, $F8, $00; 2
						db $00, $70, $88, $30, $08, $88, $70, $00; 3
						db $00, $10, $30, $50, $90, $F8, $10, $00; 4
						db $00, $F8, $80, $F0, $08, $88, $70, $00; 5
						db $00, $70, $80, $F0, $88, $88, $70, $00; 6
						db $00, $F8, $08, $10, $20, $40, $40, $00; 7
						db $00, $70, $88, $70, $88, $88, $70, $00; 8
						db $00, $70, $88, $88, $78, $08, $70, $00; 9
						db $00, $00, $00, $20, $00, $00, $20, $00; :
						db $00, $00, $20, $00, $00, $20, $20, $40;;
						db $00, $00, $10, $20, $40, $20, $10, $00; <
						db $00, $00, $00, $78, $00, $78, $00, $00; =
						db $00, $00, $40, $20, $10, $20, $40, $00; >
						db $00, $70, $88, $10, $20, $00, $20, $00; ?

						db $00, $70, $A8, $98, $B8, $80, $70, $00; @
						db $00, $70, $88, $88, $F8, $88, $88, $00; A
						db $00, $F0, $88, $F0, $88, $88, $F0, $00; B
						db $00, $70, $88, $80, $80, $88, $70, $00; C
						db $00, $E0, $90, $88, $88, $90, $E0, $00; D
						db $00, $F8, $80, $F0, $80, $80, $F8, $00; E
						db $00, $F8, $80, $F0, $80, $80, $80, $00; F
						db $00, $70, $88, $80, $98, $88, $70, $00; G
						db $00, $88, $88, $F8, $88, $88, $88, $00; H
						db $00, $F8, $20, $20, $20, $20, $F8, $00; I
						db $00, $08, $08, $08, $88, $88, $70, $00; J
						db $00, $90, $A0, $C0, $A0, $90, $88, $00; K
						db $00, $80, $80, $80, $80, $80, $F8, $00; L
						db $00, $88, $D8, $A8, $88, $88, $88, $00; M
						db $00, $88, $C8, $A8, $98, $88, $88, $00; N
						db $00, $70, $88, $88, $88, $88, $70, $00; O

						db $00, $F0, $88, $88, $F0, $80, $80, $00; P
						db $00, $70, $88, $88, $A8, $98, $78, $00; Q
						db $00, $F0, $88, $88, $F0, $88, $88, $00; R
						db $00, $70, $80, $70, $08, $88, $70, $00; S
						db $00, $F8, $20, $20, $20, $20, $20, $00; T
						db $00, $88, $88, $88, $88, $88, $70, $00; U
						db $00, $88, $88, $88, $88, $50, $20, $00; V
						db $00, $88, $88, $88, $88, $A8, $50, $00; W
						db $00, $88, $50, $20, $20, $50, $88, $00; X
						db $00, $88, $88, $50, $20, $20, $20, $00; Y
						db $00, $F8, $08, $10, $20, $40, $F8, $00; Z
						db $00, $70, $40, $40, $40, $40, $70, $00; [
						db $00, $00, $80, $40, $20, $10, $08, $00; \
						db $00, $70, $10, $10, $10, $10, $70, $00; ]
						db $00, $20, $70, $A8, $20, $20, $20, $00; ^
						db $00, $00, $00, $00, $00, $00, $00, $F8; _

						db $00, $30, $48, $E0, $40, $40, $F8, $00;
						db $00, $00, $70, $08, $78, $88, $78, $00; a
						db $00, $80, $80, $F0, $88, $88, $F0, $00; b
						db $00, $00, $70, $80, $80, $80, $70, $00; c
						db $00, $08, $08, $78, $88, $88, $78, $00; d
						db $00, $00, $70, $88, $F0, $80, $78, $00; e
						db $00, $30, $40, $F0, $40, $40, $40, $00; f
						db $00, $00, $78, $88, $88, $78, $08, $30; g
						db $00, $80, $80, $F0, $88, $88, $88, $00; h
						db $00, $20, $00, $60, $20, $20, $70, $00; i
						db $00, $10, $00, $10, $10, $10, $90, $60; j
						db $00, $80, $A0, $C0, $C0, $A0, $90, $00; k
						db $00, $40, $40, $40, $40, $40, $30, $00; l
						db $00, $00, $D0, $A8, $A8, $A8, $A8, $00; m
						db $00, $00, $F0, $88, $88, $88, $88, $00; n
						db $00, $00, $70, $88, $88, $88, $70, $00; o

						db $00, $00, $F0, $88, $88, $F0, $80, $80; p
						db $00, $00, $70, $90, $90, $70, $10, $18; q
						db $00, $00, $70, $80, $80, $80, $80, $00; r
						db $00, $00, $70, $80, $70, $08, $F0, $00; s
						db $00, $40, $E0, $40, $40, $40, $30, $00; t
						db $00, $00, $88, $88, $88, $88, $70, $00; u
						db $00, $00, $88, $88, $50, $50, $20, $00; v
						db $00, $00, $88, $A8, $A8, $A8, $50, $00; w
						db $00, $00, $88, $50, $20, $50, $88, $00; x
						db $00, $00, $88, $88, $88, $78, $08, $70; y
						db $00, $00, $F8, $10, $20, $40, $F8, $00; z
						db $00, $38, $20, $60, $20, $20, $38, $00; {
						db $00, $20, $20, $20, $20, $20, $20, $00; |
						db $00, $70, $10, $18, $10, $10, $70, $00; }
						db $00, $50, $A0, $00, $00, $00, $00, $00; ~
						db $00, $70, $A8, $C8, $C8, $A8, $70, $00; Copyright

						db $00, $3C, $40, $9C, $A0, $A0, $A0, $A0; upper left corner
						db $00, $F0, $08, $E4, $14, $14, $14, $14; right
						db $14, $14, $14, $14, $E4, $08, $F0, $00; lower right corner
						db $A0, $A0, $A0, $A0, $9C, $40, $3C, $00; left
						db $00, $FC, $00, $FC, $00, $00, $00, $00; upper edge
						db $14, $14, $14, $14, $14, $14, $14, $14; right
						db $00, $00, $00, $00, $FC, $00, $FC, $00; lower
						db $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0; left

endvgm:				 db 0							;

						DEVICE ZXSPECTRUM48
						SAVEBIN "VGM" ,$8000, endvgm - $8000