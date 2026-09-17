;**********************************************************************************************
;*                               The ROM header                                               *
;**********************************************************************************************
INCLUDE "HARDWARE.INC"

def MainRAM equ $C000

def HDLEN	equ 18

;$0000-$003F: Reset vectors (unused)
SECTION "Reset $0000", ROM0[$0000]
RST_00:
	jp $0100

SECTION "Reset $0008", ROM0[$0008]
RST_08:
	jp $0100
	
SECTION "Reset $0010", ROM0[$0010]
RST_10:
	jp $0100

SECTION "Reset $0018", ROM0[$0018]
RST_18:
	jp $0100
	
SECTION "Reset $0020", ROM0[$0020]
RST_20:
	jp $0100
	
SECTION "Reset $0028", ROM0[$0028]
RST_28:
	jp $0100
	
SECTION "Reset $0030", ROM0[$0030]
RST_30:
	jp $0100
	
SECTION "Reset $0038", ROM0[$0038]
RST_38:
	jp $0100

SECTION "V-Blank IRQ Vector", ROM0[$0040]
VCTR_DRAW:
	reti

SECTION "STAT Vector", ROM0[$0048]
VCTR_STAT:
	reti

SECTION "TimerSec Vector", ROM0[$0050]
VCTR_TIMER:
	reti
	
SECTION "Serial Vector", ROM0[$0058]
VCTR_SERIAL:
	reti
	
SECTION "Joypad Vector", ROM0[$0060]
VCTR_JOYPAD:
	reti
	
;$0100-$0103: Startup handler
SECTION "Start", ROM0[$0100]
nop
jp Main

;$0104-$0133: Nintendo logo
DB $CE, $ED, $66, $66
DB $CC, $0D, $00, $0B
DB $03, $73, $00, $83
DB $00, $0C, $00, $0D
DB $00, $08, $11, $1F
DB $88, $89, $00, $0E
DB $DC, $CC, $6E, $E6
DB $DD, $DD, $D9, $99
DB $BB, $BB, $67, $63
DB $6E, $0E, $EC, $CC
DB $DD, $DC, $99, $9F
DB $BB, $B9, $33, $3E

;$0134-$013E: Title
DB "JAYS"
DS 7

;$013F-$0142: Game code (unused)
DS 4							

;$0143: GBC compatibility flag
DB $00											;$00 = Mono

;$0144-$0145: Licensee code (new)
DB "SW"											;SW = Swift

;$0146: SGB compatibility flag
DB $00											;$00 = No SGB function

;$0147: Cartridge type
DB $01											;$01 = ROM+MBC1

;$0148: ROM size
DB $01											;$01 = 64kb (512 KiB)

;$0149: RAM size
DB $00											;$00 = No RAM

;$014A: Destination code
DB $01											;$01 = Other

;$014B: Licensee code (old)
DB $33											;$33 = Redirect to new

;$014C: ROM version number
DB $00											;$00 = V1.0

;$014D: Header checksum (Needs to be patched)
DB $00

;$014E-$014F: Global checksum (Needs to be patched)
DB $00
DB $00

;**********************************************************************************************
;*                               Main section                                                 *
;**********************************************************************************************
;$0150: Start of the main section

Main:
.ResetScrollXY
	xor a							;Set register A to 0 with exclusive OR
	ld [rSCX], a					;Set SCX to 0
	ld [rSCY], a					;Set SCY to 0

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a
	
.SetPalette
	ld a, %11100100
	ld [rBGP], a					;Set background palette

.InitLogo							;Decompress and load logo image tiles
	ld hl, LogoTiles
	ld de, $8000
	call Unpack
	
.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitLogoMap
	ld hl, CopyNum
	ld [hl], 21						;Tile skip amount (no more registers available)
	ld hl, $98A4
	ld de, LogoMap
	ld b, 7							;Number of columns
	ld c, 11						;Number of rows
	call CopyMap

.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a
	
	jp Splash

;Splash screen (Swift logo)
Splash:
.SetTimerSec
	ld a, 5
	ld [TimerSec], a
	ld a, 60
	ld [TimerFrames], a
	
.WaitLoop							;Wait until the timer is done
	call SplashInput				;Skip the timer if button is pressed
	ld a, [TimerSec]
	or a
	jp z, Presents
	call WaitFrameTick
	ld a, [TimerFrames]				;Check every frame
	dec a
	ld [TimerFrames], a
	or a
	jr nz, .WaitLoop
	ld a, [TimerSec]
	dec a
	ld [TimerSec], a
	or a
	jp z, Presents
	ld a, 60
	ld [TimerFrames], a
	jr .WaitLoop

SplashInput:
	ld a, %00010000						;Check A, B, Start & Select
    ldh [rJOYP], a
    ldh a, [rJOYP]
    ldh a, [rJOYP]						;Multiple read to prevent input lag
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
	cpl
    and %00001111
	ld [CurInputB], a
    ld d, a
	
	ld a, d
	and JOYP_START						;If input, then continue		
	jr z, .Released

	ld a, [StartPrev]
	or a
	jr nz, .PressedAlready
	
	ld a, 1
	ld [StartPrev], a
	
	xor a
	ld [TimerSec], a
	ld [TimerFrames], a

	jp Presents
	
.PressedAlready
	ld a, 1
	ld [StartPrev], a
	ret
	
.Released
	xor a
	ld [StartPrev], a
	ret
	
Presents:							;"Presents" screen

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a

.InitFont
	ld hl, $8800					;Address in VRAM
	ld de, FontTiles				;Start offset of tile data
	ld bc, FontTilesEnd - FontTiles	;Total size of the data
	call CopyFont

.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitText							;Display "presents" text
	ld hl, $98E6					;Address in VRAM (start of BG tilemap)
	ld de, PresentsText
	call CopyText

.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a
	
.SetTimerSec
	ld a, 5
	ld [TimerSec], a
	ld a, 60
	ld [TimerFrames], a
	
.WaitLoop							;Wait until the timer is done
	call PresentsInput				;Skip the timer if button is pressed
	ld a, [TimerSec]
	or a
	jp z, Title
	call WaitFrameTick
	ld a, [TimerFrames]				;Check every frame
	dec a
	ld [TimerFrames], a
	or a
	jr nz, .WaitLoop
	ld a, [TimerSec]
	dec a
	ld [TimerSec], a
	or a
	jp z, Title
	ld a, 60
	ld [TimerFrames], a
	jr .WaitLoop

PresentsInput:
	ld a, %00010000						;Check A, B, Start & Select
    ldh [rJOYP], a
    ldh a, [rJOYP]
    ldh a, [rJOYP]						;Multiple read to prevent input lag
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
	cpl
    and %00001111
	ld [CurInputB], a
    ld d, a
	
	ld a, d
	and JOYP_START						;If input, then continue		
	jr z, .Released

	ld a, [StartPrev]
	or a
	jr nz, .PressedAlready
	
	ld a, 1
	ld [StartPrev], a
	
	xor a
	ld [TimerSec], a
	ld [TimerFrames], a

	jp Title
	
.PressedAlready
	ld a, 1
	ld [StartPrev], a
	ret
	
.Released
	xor a
	ld [StartPrev], a
	ret
	
Title:								;Title page

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a

.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitText							;Display title text
	ld hl, $9885					;Address in VRAM (start of BG tilemap)
	ld de, Title1Text
	call CopyText
	
	ld hl, $98E5					;Address in VRAM (start of BG tilemap)
	ld de, Title2Text
	call CopyText
	
	ld hl, $9945					;Address in VRAM (start of BG tilemap)
	ld de, Title3Text
	call CopyText

.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a

.TitleLoop							;Wait for Start to be pressed
	call TitleInput
	jr .TitleLoop

TitleInput:
	ld a, %00010000						;Check A, B, Start & Select
    ldh [rJOYP], a
    ldh a, [rJOYP]
    ldh a, [rJOYP]						;Multiple read to prevent input lag
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
	cpl
    and %00001111
	ld [CurInputB], a
    ld d, a
	
	ld a, d
	and JOYP_START						;If input, then continue		
	jr z, .Released

	ld a, [StartPrev]
	or a
	jr nz, .PressedAlready
	
	ld a, 1
	ld [StartPrev], a
	jp EurJay
	
.PressedAlready
	ld a, 1
	ld [StartPrev], a
	ret
	
.Released
	xor a
	ld [StartPrev], a
	call WaitVBL
	ret

EurJay:								;Eurasian jay

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a
	
.SetPalette
	ld a, %11100100
	ld [rBGP], a					;Set background palette

.InitEurJay							;Decompress and load Eurasian jay image tiles
	ld hl, EurJayTiles
	ld de, $8000
	call Unpack
	
.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitEurJayMap
	ld hl, CopyNum
	ld [hl], 20						;Tile skip amount (no more registers available)
	ld hl, $98E4
	ld de, EurJayMap
	ld b, 9							;Number of columns
	ld c, 12						;Number of rows
	call CopyMap
	
.InitEurJayText						;Display Eurasian jay text
	ld hl, $9860					;Address in VRAM (start of BG tilemap)
	ld de, EurJayText
	call CopyText


.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a
	
.PlaySample							;Play Eurasian jay sound
	ld hl, EurJaySoundIndex
	call PlaySample
	
.SetTimerSec
	ld a, 2
	ld [TimerSec], a
	ld a, 60
	ld [TimerFrames], a
	
.WaitLoop							;Wait until the timer is done
	ld a, [TimerSec]
	or a
	jp z, BlueJay
	call WaitFrameTick
	ld a, [TimerFrames]				;Check every frame
	dec a
	ld [TimerFrames], a
	or a
	jr nz, .WaitLoop
	ld a, [TimerSec]
	dec a
	ld [TimerSec], a
	or a
	jp z, BlueJay
	ld a, 60
	ld [TimerFrames], a
	jr .WaitLoop
	
BlueJay:							;Blue jay

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a
	
.SetPalette
	ld a, %11100100
	ld [rBGP], a					;Set background palette

.InitBlueJay						;Decompress and load blue jay image tiles
	ld hl, BlueJayTiles
	ld de, $8000
	call Unpack
	
.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitBlueJayMap
	ld hl, CopyNum
	ld [hl], 20						;Tile skip amount (no more registers available)
	ld hl, $98E4
	ld de, BlueJayMap
	ld b, 9							;Number of columns
	ld c, 12						;Number of rows
	call CopyMap
	
.InitBlueJayText					;Display blue jay text
	ld hl, $9860					;Address in VRAM (start of BG tilemap)
	ld de, BlueJayText
	call CopyText


.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a
	
.PlaySample							;Play blue jay sound
	ld hl, BlueJaySoundIndex
	call PlaySample
	
.SetTimerSec
	ld a, 2
	ld [TimerSec], a
	ld a, 60
	ld [TimerFrames], a
	
.WaitLoop							;Wait until the timer is done
	ld a, [TimerSec]
	or a
	jp z, StelJay
	call WaitFrameTick
	ld a, [TimerFrames]				;Check every frame
	dec a
	ld [TimerFrames], a
	or a
	jr nz, .WaitLoop
	ld a, [TimerSec]
	dec a
	ld [TimerSec], a
	or a
	jp z, StelJay
	ld a, 60
	ld [TimerFrames], a
	jr .WaitLoop
	
StelJay:							;Steller's jay

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a
	
.SetPalette
	ld a, %11100100
	ld [rBGP], a					;Set background palette

.InitStelJay						;Decompress and load Steller's jay image tiles
	ld hl, StelJayTiles
	ld de, $8000
	call Unpack
	
.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitStelJayMap
	ld hl, CopyNum
	ld [hl], 20						;Tile skip amount (no more registers available)
	ld hl, $98E4
	ld de, StelJayMap
	ld b, 9							;Number of columns
	ld c, 12						;Number of rows
	call CopyMap
	
.InitStelJayText					;Display Steller's jay text
	ld hl, $9860					;Address in VRAM (start of BG tilemap)
	ld de, StelJayText
	call CopyText


.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a
	
.SwitchToBank						;Switch to ROM bank $2 (contains sample)
	ld a, 2
	ld [CurBank], a
	call SwitchBank
	
.PlaySample							;Play Steller's jay sound
	ld hl, StelJaySoundIndex
	call PlaySample
	
.SwitchBackToBank					;Switch back to ROM bank $1
	ld a, 1
	ld [CurBank], a
	call SwitchBank
	
.SetTimerSec
	ld a, 2
	ld [TimerSec], a
	ld a, 60
	ld [TimerFrames], a
	
.WaitLoop							;Wait until the timer is done
	ld a, [TimerSec]
	or a
	jp z, ScrubJay
	call WaitFrameTick
	ld a, [TimerFrames]				;Check every frame
	dec a
	ld [TimerFrames], a
	or a
	jr nz, .WaitLoop
	ld a, [TimerSec]
	dec a
	ld [TimerSec], a
	or a
	jp z, ScrubJay
	ld a, 60
	ld [TimerFrames], a
	jr .WaitLoop

ScrubJay:							;Western scrub-jay

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a
	
.SetPalette
	ld a, %11100100
	ld [rBGP], a					;Set background palette

.InitScrubJay						;Decompress and load western scrub-jay image tiles
	ld hl, ScrubJayTiles
	ld de, $8000
	call Unpack
	
.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitScrubJayMap
	ld hl, CopyNum
	ld [hl], 20						;Tile skip amount (no more registers available)
	ld hl, $98E4
	ld de, ScrubJayMap
	ld b, 9							;Number of columns
	ld c, 12						;Number of rows
	call CopyMap
	
.InitScrubJayText					;Display western scrub-jay text
	ld hl, $9860					;Address in VRAM (start of BG tilemap)
	ld de, ScrubJayText
	call CopyText


.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a
	
.SwitchToBank						;Switch to ROM bank $2 (contains sample)
	ld a, 2
	ld [CurBank], a
	call SwitchBank
	
.PlaySample							;Play western scrub-jay sound
	ld hl, ScrubJaySoundIndex
	call PlaySample
	
.SwitchBackToBank					;Switch back to ROM bank $1
	ld a, 1
	ld [CurBank], a
	call SwitchBank
	
.SetTimerSec
	ld a, 2
	ld [TimerSec], a
	ld a, 60
	ld [TimerFrames], a
	
.WaitLoop							;Wait until the timer is done
	ld a, [TimerSec]
	or a
	jp z, End
	call WaitFrameTick
	ld a, [TimerFrames]				;Check every frame
	dec a
	ld [TimerFrames], a
	or a
	jr nz, .WaitLoop
	ld a, [TimerSec]
	dec a
	ld [TimerSec], a
	or a
	jp z, End
	ld a, 60
	ld [TimerFrames], a
	jr .WaitLoop
	
End:								;"The end!" screen

.WaitVBL							;Wait for V-Blank (145 frames)
	call WaitVBL
	
.ScreenOff
	xor a
	ld [rLCDC], a

.CleanUp							;"Clean up" the screen's tile data
	ld hl, $9800
	ld bc, $9FFF - $9800
	call Clear
	
	ld hl, $C000					;"Clean up" work RAM
	ld bc, $DFFF - $C000
	call Clear
	
.InitText							;Display title text
	ld hl, $9885					;Address in VRAM (start of BG tilemap)
	ld de, End1Text
	call CopyText
	
	ld hl, $9920					;Address in VRAM (start of BG tilemap)
	ld de, End2Text
	call CopyText

.ScreenOn
	ld a, %10010001					;Turn on screen and BG layer, set bank to $8000
	ld [rLCDC], a

.EndLoop							;Wait for Start to be pressed
	call EndInput
	jr .EndLoop

EndInput:
	ld a, %00010000						;Check A, B, Start & Select
    ldh [rJOYP], a
    ldh a, [rJOYP]
    ldh a, [rJOYP]						;Multiple read to prevent input lag
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
	cpl
    and %00001111
	ld [CurInputB], a
    ld d, a
	
	ld a, d
	and JOYP_START						;If input, then continue		
	jr z, .Released

	ld a, [StartPrev]
	or a
	jr nz, .PressedAlready
	
	ld a, 1
	ld [StartPrev], a
	jp EurJay
	
.PressedAlready
	ld a, 1
	ld [StartPrev], a
	ret
	
.Released
	xor a
	ld [StartPrev], a
	call WaitVBL
	ret

CopyMap:

.StartRow
	push bc
	
.CopyRow
	ld a, [de]
	ld [hli], a
	inc de
	dec c
	jr nz, .CopyRow
	
.EndRow
	ld a, [CopyNum]					;Get tile skip amount (from RAM as we ran out of registers)
	push bc
	ld b, a
	ld a, l
	add b
	pop bc
	jr nc, .NextRow
	inc h

.NextRow
	ld l, a
	pop bc
	dec b
	jr nz, .StartRow
	ret

Clear:								;Fill in both tilemaps with white space
	ld a, $80
	ld [hli], a
	dec bc
	ld a, b
	or c
	jr nz, Clear
	ret
	
ClearSpace:							;Fill in both tilemaps with space text character
	ld a, $30
	ld [hli], a
	dec bc
	ld a, b
	or c
	jr nz, ClearSpace
	ret
	
Copy:								;Multi-purpose data copy function
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, Copy
	ret
	
CopyFont:							;Copy 1-bit font tile data
	ld a, [de]
	ld [hli], a						;Load twice to convert to 2-bit
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, CopyFont
	ret	

;Specialized text data copy function	
CopyText:
	ld a, [de]						;Get current byte from source
	inc de
	dec bc
	cp $FF
	jr z, .CopyDone
	or a							;Check if the value is 0
	jr nz, .WriteByte				;If not, then write to VRAM
	
	ld a, h							;Otherwise, advance to next "row"
	and a							;Get sign
	ld a, l
	and a, $1F						;Get current position in row ($20 = length of row)

	push bc							;Otherwise, add to total position
	push de
	ld b, a
	ld a, $20
	sub b
	pop bc
	
	add l
	ld l, a
	pop bc
	jr nc, .NoCarryAdd
	inc h
.NoCarryAdd
	jr CopyText
	
.WriteByte
	add a, $60						;Convert ASCII values to tile values by adding $60 to each character
	ld [hli], a						;Then write to VRAM
	jr CopyText
	
.CopyDone
	ret

;Play sound sample (4-bit PCM - 8192hz)
PlaySample:
        ld      a,[hl+]         ;get sample length
        ld      c,a
        ld      a,[hl+]
        ld      b,a

        ld      a,$84
        ldh      [rNR52],a      ;enable sound 3

        ld      a,0
        ldh     [rNR30],a
        ldh     [rNR51],a

        ld      a,$77
        ldh     [rNR50],a       ;select speakers
        ld      a,$ff
        ldh     [rNR51],a       ;enable sound 3

        ld      a,$80
        ldh     [rNR31],a       ;sound length
        ld      a,$20
        ldh     [rNR32],a       ;sound level high

        ld      a,$00
        ldh     [rNR33],a       ;sound freq low

.samp2
        ld      de,_AUD3WAVERAM ;12
        push    bc              ;16
        ld      b,16            ;16

        xor     a
        ldh     [rNR30],a
.samp3
        ld      a,[hl+]         ;8
        ld      [de],a          ;8
        inc     de              ;8
        dec     b               ;4
        jr      nz,.samp3       ;12

        ld      a,$80
        ldh     [rNR30],a

        ld      a,$87           ; (256hz)
        ldh     [rNR34],a


        ld      bc,558          ;delay routine
.samp4
        dec     bc              ;8
        ld      a,b             ;4
        or      c               ;4
        jr      nz,.samp4       ;12

        ld      a,0             ;more delay
        ld      a,0
        ld      a,0

        pop     bc              ;12
        dec     bc              ;8
        ld      a,b             ;4
        or      c               ;4
        jr      nz,.samp2       ;12

        ld      a,$bb
        ldh     [rNR51],a       ;disable sound 3
        ret
		
WaitVBL:							;Wait for V-Blank (145 frames)
	ld a, [rLY]
	cp 144
	jr nz, WaitVBL
	ret

WaitFrameTick:
	ld a, [rLY]						;Wait for V-Blank (145 frames)
	cp 144
	jr nc, WaitFrameTick
.WaitFrameTick2
	ld a, [rLY]						;Wait for V-Blank (145 frames)
	cp 144
	jr c, .WaitFrameTick2
	ret
	
SwitchBank:								;Switch the current bank
	ld a, [CurBank]						;Load bank number from RAM
	ld [$2000], a
	ret

;---------------------------------------------------------
; PRO-PACK Unpack Routine - Gameboy, Method 2
;
; On entry,
;   HL points to PACKED data in ROM
;   DE points to RAM area for the UNPACKED data
; On exit,
;   all general purpose registers are undefined - A,B,C,D,E,H,L.
;   ROM bank not preserved
;---------------------------------------------------------

Unpack:
        LD BC,HDLEN
        ADD HL,BC
        SCF
        LD A,[HL+]      ; NOTE: This data fetch requires that the data
        ADC A,A         ; pointed to by HL is in one ROM bank and that the
        ADD A,A         ; fetch will not cross ROM boundaries.
        JP XLOOP

;---------------------------------------------------------

FETCH3:
        LD A,[hl+]
        ADC A,A
        jr BACK3
FETCH4:
        LD A,[hl+]
        ADC A,A
        jr BACK4
FETCH5:
        LD A,[hl+]
        ADC A,A
        Jr BACK5
FETCH6:
        LD A,[hl+]
        ADC A,A
        Jr BACK6
FETCH7:
        LD A,[hl+]
        ADC A,A
        jr BACK7
RAW:
        LD C,4
X4BITS:
        ADD A,A
        JR Z,FETCH7
BACK7:
        RL B
        DEC C
        JR NZ,X4BITS

        PUSH AF
        LD A,3
        ADD A,B
        ADD A,A
        LD C,A
RAWLPB:
        LD A,[hl+]
        LD [DE],A
        INC DE

        LD A,[hl+]
        LD [DE],A
        INC DE

        DEC C
        JR NZ,RAWLPB

        POP AF
        Jr XLOOP

;---------------------------------------------------------

FETCH0:
        LD A,[hl+]
        ADC A,A
        JR C,SMALLS
GETLEN:
        ADD A,A
        JR Z,FETCH3
BACK3:
        RL C
        ADD A,A
        JR Z,FETCH4
BACK4:
        JR NC,COPY
        ADD A,A
        JR Z,FETCH5
BACK5:
        DEC C
        PUSH HL

        LD H,A
        LD A,C
        ADC A,A
        LD C,A
        CP 9
        LD A,H

        POP HL
        JR Z,RAW

;---------------------------------------------------------

COPY:
        ADD A,A
        JR Z,FETCH6
BACK6:
        JR NC,BYTEDISP
        ADD A,A
        JR NZ,SKIP0
        LD A,[hl+]
        ADC A,A
SKIP0:
        RL B
        ADD A,A
        JR NZ,SKIP1
        LD A,[hl+]
        ADC A,A
SKIP1:
        JR C,BIGDISP
        INC B
        DEC B
        JR NZ,BYTEDISP
        INC B
ANOTHER:
        ADD A,A
        JR NZ,DISPX
        LD A,[hl+]
        ADC A,A
DISPX:
        RL B
BYTEDISP:
        PUSH AF
        LD A,E
        SUB [HL]
        PUSH HL
        LD L,A
        LD A,D
        SBC A,B
        LD H,A
        DEC HL
BYTELP:
        LD A,[hl+]
        LD [DE],A
        INC DE
        DEC C
        JR NZ,BYTELP

        POP HL
        INC HL

        POP AF
        JR XLOOP

;---------------------------------------------------------

GETBITS:
        LD A,[hl+]
        ADC A,A
        JR C,STRING
XBYTE:
        ld b,a          ; Took out 'push af' - JF, 99-Jul-25
        LD A,[hl+]
        LD [DE],A
        INC DE
        ld a,b          ; Took out 'pop af' - JF, 99-Jul-25
XLOOP:
        ADD A,A
        JR C,CHKZ

        ld b,a          ; Took out 'push af' - JF, 99-Jul-25
        LD A,[hl+]
        LD [DE],A
        INC DE
        ld a,b          ; Took out 'pop af' - JF, 99-Jul-25

        ADD A,A
        JR NC,XBYTE
CHKZ:
        JR Z,GETBITS

;---------------------------------------------------------

STRING:
        LD BC,2
        ADD A,A
        JR Z,FETCH0
        JR NC,GETLEN
SMALLS:
        ADD A,A
        JR Z,FETCH1
BACK1:
        JR NC,BYTEDISP

        INC C
        ADD A,A
        JR Z,FETCH2
BACK2:
        JR NC,COPY

        LD C,[HL]
        INC HL
        INC C
        DEC C
        JR Z,OVERNOUT

        PUSH AF

        LD A,C
        ADD A,8
        LD C,A

        POP AF
        Jr COPY

;---------------------------------------------------------

BIGDISP:
        ADD A,A
        JR NZ,SKIP2
        LD A,[hl+]
        ADC A,A
SKIP2:
        RL B
        SET 2,B
        ADD A,A
        JR NZ,SKIP3
        LD A,[hl+]
        ADC A,A
SKIP3:
        JR C,BYTEDISP
        Jr ANOTHER
FETCH1:
        LD A,[hl+]
        ADC A,A
        jr BACK1
FETCH2:
        LD A,[hl+]
        ADC A,A
        jr BACK2
OVERNOUT:
        ADD A,A
        JR NZ,CHECK4END

        LD A,[hl+]
        ADC A,A
CHECK4END:
        JR C,XLOOP
        RET

;**********************************************************************************************
;*                               Data                                                         *
;**********************************************************************************************

SECTION "GFX", ROM0 [$0800]
LogoTiles:
	incbin "GFX/RNC/LOGO.GFX"
LogoTilesEnd:
LogoMap:
	incbin "GFX/LOGO.MAP"
LogoMapEnd:
EurJayTiles:
	incbin "GFX/RNC/EURJAY.GFX"
EurJayTilesEnd:
EurJayMap:
	incbin "GFX/EURJAY.MAP"
EurJayMapEnd:
BlueJayTiles:
	incbin "GFX/RNC/BLUEJAY.GFX"
BlueJayTilesEnd:
BlueJayMap:
	incbin "GFX/BLUEJAY.MAP"
BlueJayMapEnd:
StelJayTiles:
	incbin "GFX/RNC/STELJAY.GFX"
StelJayTilesEnd:
StelJayMap:
	incbin "GFX/STELJAY.MAP"
StelJayMapEnd:
ScrubJayTiles:
	incbin "GFX/RNC/SCRUBJAY.GFX"
ScrubJayTilesEnd:
ScrubJayMap:
	incbin "GFX/SCRUBJAY.MAP"
ScrubJayMapEnd:
FontTiles:
	incbin "GFX/FONT.GFX"
FontTilesEnd:

;Text
PresentsText:
db "PRESENTS", 0
db $FF
PresentsTextEnd:
Title1Text:
db "A DEMO", 0
db $FF
Title1TextEnd:
Title2Text:
db "\"JAYS\"", 0
db $FF
Title2TextEnd:
Title3Text:
db "PRESS START!", 0
db $FF
Title3TextEnd:
EurJayText:
db "EURASIAN JAY", 0
db "GARRULUS GLANDARIUS", 0
db $FF
EurJayTextEnd:
BlueJayText:
db "BLUE JAY", 0
db "CYANOCITTA CRISTATA", 0
db $FF
BlueJayTextEnd:
StelJayText:
db "STELLER'S JAY", 0
db "CYANOCITTA STELLERI", 0
db $FF
StelJayTextEnd:
ScrubJayText:
db "WESTERN SCRUB-JAY", 0
db "APHELOCOMA", 0
db "CALIFORNICA", 0
db $FF
ScrubJayTextEnd:
End1Text:
db "THE END!", 0
db $FF
End1TextEnd:
End2Text:
db "PRESS START TO", 0
db "PLAY AGAIN", 0
db $FF
End2TextEnd:

;Samples (bank 1)
SECTION "Samples1", ROMX[$4000], BANK[$1]
EurJaySoundIndex:
dw (EurJaySoundEnd-EurJaySound) / 16
EurJaySound:
incbin "SOUND/EURJAY.GBW"
EurJaySoundEnd:
BlueJaySoundIndex:
dw (BlueJaySoundEnd-BlueJaySound) / 16
BlueJaySound:
incbin "SOUND/BLUEJAY.GBW"
BlueJaySoundEnd:

;Samples (bank 2)
SECTION "Samples2", ROMX[$4000], BANK[$2]
StelJaySoundIndex:
dw (StelJaySoundEnd-StelJaySound) / 16
StelJaySound:
incbin "SOUND/STELJAY.GBW"
StelJaySoundEnd:
ScrubJaySoundIndex:
dw (ScrubJaySoundEnd-ScrubJaySound) / 16
ScrubJaySound:
incbin "SOUND/SCRUBJAY.GBW"
ScrubJaySoundEnd:

;**********************************************************************************************
;*                               RAM Variables                                                *
;**********************************************************************************************
SECTION "Variables", WRAM0[MainRAM]

TimerSec: 					ds 1
TimerFrames:				ds 1
CopyNum:					ds 1
CurInputA: 					ds 1						;D-PAD input
CurInputB: 					ds 1						;Other button input
StartPrev:					ds 1
CurBank: 					ds 1						;Bank number