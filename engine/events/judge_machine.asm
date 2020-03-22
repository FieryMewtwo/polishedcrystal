JUDGE_UP_DOWN_TILE    EQU $00
JUDGE_UNDERLINE_TILE  EQU $01
JUDGE_LINE_END_TILE   EQU $02
JUDGE_MALE_TILE       EQU $07
JUDGE_FEMALE_TILE     EQU $08
JUDGE_STAR_TILE       EQU $09
JUDGE_LEFT_RIGHT_TILE EQU $0a
JUDGE_BORDER_TILE     EQU $13
JUDGE_BLANK_TILE      EQU $64
JUDGE_WHITE_TILE      EQU $6d

JudgeMachine:
; Check that the machine is activated
	ld hl, wStatusFlags3
	bit 0, [hl] ; ENGINE_JUDGE_MACHINE
	ld hl, NewsMachineOffText
	jr z, .done
; Introduce machine
	ld hl, NewsMachineIntroText
.continue
	call PrintText
	call YesNoBox
	jr c, .cancel
; Choose a party Pokémon
	ld hl, NewsMachineWhichMonText
	call PrintText
	farcall SelectMonFromParty
	jr c, .cancel
; Can't judge an Egg
	ld a, MON_IS_EGG
	call GetPartyParamLocation
	bit MON_IS_EGG_F, [hl]
	ld hl, NewsMachineEggText
	jr nz, .done
; Show the EV and IV charts
	ld hl, NewsMachinePrepText
	call PrintText
	call FadeToMenu
	call JudgeSystem
	call ExitAllMenus
	ld hl, NewsMachineContinueText
	jr .continue

.cancel
	ld hl, NewsMachineCancelText
.done
	jp PrintText

NewsMachineOffText:
	text "It's the #mon"
	line "Judge Machine!"

	para "It's not in"
	line "operation yet…"
	done

NewsMachineIntroText:
	text "It's the #mon"
	line "Judge Machine!"

	para "Would you like to"
	line "judge a #mon's"
	cont "overall power?"
	done

NewsMachineWhichMonText:
	text "Please select"
	line "a #mon."
	prompt

NewsMachinePrepText:
	text "Visualizing your"
	line "#mon's power…"
	prompt

NewsMachineContinueText:
	text "Would you like"
	line "to judge another"
	cont "#mon?"
	done

NewsMachineCancelText:
	text "Goodbye!"
	done

NewsMachineEggText:
	text "An Egg doesn't"
	line "have any power"
	cont "yet to judge!"
	done

JudgeSystem::
; Clear the screen
	call ClearBGPalettes
	call ClearTileMap
	call DisableLCD

; Load the party struct into wTempMon
	ld hl, wPartyMons
	ld a, [wCurPartyMon]
	call GetPartyLocation
	ld de, wTempMon
	ld bc, PARTYMON_STRUCT_LENGTH
	rst CopyBytes

; Load the frontpic graphics
	ld hl, wTempMonForm
	predef GetVariant
	call GetBaseData
	ld de, vTiles2
	predef GetFrontpic

; Load the blank chart graphics
	ld a, $1
	ldh [rVBK], a
	ld hl, JudgeSystemGFX
	ld de, vTiles5
	lb bc, BANK(JudgeSystemGFX), 10 * 12
	call DecompressRequest2bpp
	xor a
	ldh [rVBK], a

; Load the max stat sparkle graphics
	ld hl, MaxStatSparkleGFX
	ld de, vTiles0
	ld bc, 1 tiles
	call CopyBytes

; Place the up/down arrows and nickname
	ld hl, wPartyMonNicknames
	ld a, [wCurPartyMon]
	call SkipNames
	ld d, h
	ld e, l
	hlcoord 0, 0
	ld [hl], JUDGE_UP_DOWN_TILE
	inc hl
	rst PlaceString

; Place the level
	hlcoord 14, 0
	call PrintLevel

; Place the gender icon
	farcall GetGender
	ld a, JUDGE_WHITE_TILE
	jr c, .got_gender
	ld a, JUDGE_MALE_TILE
	jr nz, .got_gender
	ld a, JUDGE_FEMALE_TILE
.got_gender
	hlcoord 18, 0
	ld [hli], a

; Place the shiny icon
	ld bc, wTempMonShiny
	farcall CheckShininess
	; a = carry ? JUDGE_STAR_TILE : JUDGE_WHITE_TILE
	sbc a
	and JUDGE_STAR_TILE - JUDGE_WHITE_TILE
	add JUDGE_WHITE_TILE
	ld [hli], a

; Place the top border
	ld bc, SCREEN_WIDTH
	ld a, JUDGE_BORDER_TILE
	rst ByteFill

; Place the frontpic graphics
	hlcoord 0, 6
	farcall Pokedex_PlaceFrontpicAtHL

; Place the Pokédex number
	ld a, [wCurPartySpecies]
	ld [wd265], a
	hlcoord 1, 13
	ld [hl], "№"
	inc hl
	ld [hl], "."
	inc hl
	lb bc, PRINTNUM_LEADINGZEROS | 1, 3
	ld de, wd265
	call PrintNum

; Place the chart
	hlcoord 8, 4
	ld de, SCREEN_WIDTH
	xor a
	ld b, 12
.chart_row
	ld c, 10
	push hl
.chart_col
	ld [hli], a
	inc a
	dec c
	jr nz, .chart_col
	pop hl
	add hl, de
	dec b
	jr nz, .chart_row

; Clear some non-chart tiles
	ld a, JUDGE_BLANK_TILE
	hlcoord 9, 4
	ld [hli], a
	ld [hl], a
	hlcoord 15, 4
	ld [hli], a
	ld [hl], a
	hlcoord 9, 15
	ld [hli], a
	ld [hl], a
	hlcoord 15, 15
	ld [hli], a
	ld [hl], a

; Place the stat names and values
	hlcoord 12, 2
	ld de, .HP
	ld bc, wTempMonMaxHP
	call .PrintTopStat
	hlcoord 17, 4
	ld de, .Atk
	ld bc, wTempMonAttack
	call .PrintTopStat
	hlcoord 17, 15
	ld de, .Def
	ld bc, wTempMonDefense
	call .PrintBottomStat
	hlcoord 12, 17
	ld de, .Spd
	ld bc, wTempMonSpeed
	call .PrintBottomStat
	hlcoord 6, 15
	ld de, .SDf
	ld bc, wTempMonSpclDef
	call .PrintBottomStat
	hlcoord 6, 4
	ld de, .SAt
	ld bc, wTempMonSpclAtk
	call .PrintTopStat

; Show the screen
	call EnableLCD
	call ApplyTilemapInVBlank
	ld a, CGB_JUDGE_SYSTEM
	call GetCGBLayout
	call SetPalettes

; Start with the EV chart
	xor a
	ldh [hChartScreen], a

.render
	farcall ClearSpriteAnims

; Display the current chart, EVs or IVs
	ldh a, [hChartScreen]
	and a
	jr z, .evs
	ld hl, IVChartPals
	ld de, .IVHeading
	ld bc, RenderIVChart
	jr .got_config
.evs
	ld hl, EVChartPals
	ld de, .EVHeading
	ld bc, RenderEVChart
.got_config
	call .PrepareChart

; Load the rendered chart graphics
	ld a, $1
	ldh [rVBK], a
	ld hl, vTiles5
	ld de, wDecompressScratch
	lb bc, BANK(wDecompressScratch), 10 * 12
	call Request2bppInWRA6
	xor a
	ldh [rVBK], a

; Wait for input
.input_loop
	farcall PlaySpriteAnimations
	call DelayFrame
	call JoyTextDelay
	ldh a, [hJoyLast]
	; B button quits
	bit B_BUTTON_F, a
	ret nz
	; Up or down switches between party members
	bit D_UP_F, a
	jr nz, .prev_mon
	bit D_DOWN_F, a
	jr nz, .next_mon
	; Left or right toggles between EVs and IVs
	and D_LEFT | D_RIGHT
	jr z, .input_loop
	ldh a, [hChartScreen]
	cpl
	ldh [hChartScreen], a
	jr .render

.prev_mon
	ld a, [wCurPartyMon]
	and a
	jr z, .input_loop
	dec a
	ld [wCurPartyMon], a
	ld a, MON_IS_EGG
	call GetPartyParamLocation
	bit MON_IS_EGG_F, [hl]
	jr nz, .prev_mon
	jr .switch_mon

.next_mon
	ld a, [wPartyCount]
	ld b, a
	ld a, [wCurPartyMon]
	inc a
	cp b
	jr z, .input_loop
	ld [wCurPartyMon], a
	ld a, MON_IS_EGG
	call GetPartyParamLocation
	bit MON_IS_EGG_F, [hl]
	jr nz, .next_mon
.switch_mon
	ld a, [wCurPartyMon]
	ld c, a
	ld b, 0
	ld hl, wPartySpecies
	add hl, bc
	inc a
	ld [wPartyMenuCursor], a
	ld a, [hl]
	ld [wCurPartySpecies], a
	farcall ClearSpriteAnims
	jp JudgeSystem

.EVHeading:
	db JUDGE_LEFT_RIGHT_TILE
	db "Effort   <LNBRK>"
rept 10
	db JUDGE_UNDERLINE_TILE
endr
	db JUDGE_LINE_END_TILE, "@"

.IVHeading:
	db JUDGE_LEFT_RIGHT_TILE
	db "Potential<LNBRK>"
rept 10
	db JUDGE_UNDERLINE_TILE
endr
	db JUDGE_LINE_END_TILE, "@"

.PrintTopStat:
; hl = coords, de = string, bc = stat
	push bc
	rst PlaceString
	ld de, SCREEN_WIDTH
	jr ._FinishPrintStat

.PrintBottomStat:
; hl = coords, de = string, bc = stat
	push bc
	rst PlaceString
	ld de, -SCREEN_WIDTH
._FinishPrintStat:
	add hl, de
	pop de
	lb bc, 2, 3
	jp PrintNum

.HP:  db "HP@"
.Atk: db "Atk@"
.Def: db "Def@"
.Spd: db "Spd@"
.SDf: db "SDf@"
.SAt: db "SAt@"

.PrepareChart:
; hl = palettes, de = title string, bc = chart function
	push bc
	push de
; Load the palettes
	ld de, wBGPals
	ld bc, 6 palettes
	call FarCopyColorWRAM
	ld a, $1
	ldh [hCGBPalUpdate], a
; Place the title
	pop de
	hlcoord 0, 2
	rst PlaceString
; Render the chart
	ret

SparkleMaxStat:
; Show a sparkle sprite at (d, e) if a is 255
	inc a
	ret nz
	ld a, SPRITE_ANIM_INDEX_MAX_STAT_SPARKLE
	jp _InitSpriteAnimStruct

RenderEVChart:
; Read the EVs and round them up to the nearest 4
; HP
	ld a, [wTempMonHPEV]
	or %11
	ldh [hChartHP], a
	depixel 2, 12
	call SparkleMaxStat
; Atk
	ld a, [wTempMonAtkEV]
	or %11
	ldh [hChartAtk], a
	depixel 4, 17
	call SparkleMaxStat
; Def
	ld a, [wTempMonDefEV]
	or %11
	ldh [hChartDef], a
	depixel 15, 17
	call SparkleMaxStat
; Spd
	ld a, [wTempMonSpdEV]
	or %11
	ldh [hChartSpd], a
	depixel 17, 12
	call SparkleMaxStat
; SAt
	ld a, [wTempMonSatEV]
	or %11
	ldh [hChartSat], a
	depixel 4, 6
	call SparkleMaxStat
; SDf
	ld a, [wTempMonSdfEV]
	or %11
	ldh [hChartSdf], a
	depixel 15, 6
	call SparkleMaxStat
	jr RenderChart

RenderIVChart:
; Read the IVs and scale them to 255 instead of 31
; HP
	ld a, [wTempMonHPAtkDV]
	and $f0
	ld b, a
	swap a
	or b
	ldh [hChartHP], a
	depixel 2, 12
	call SparkleMaxStat
; Atk
	ld a, [wTempMonHPAtkDV]
	and $0f
	ld b, a
	swap a
	or b
	ldh [hChartAtk], a
	depixel 4, 17
	call SparkleMaxStat
; Def
	ld a, [wTempMonDefSpdDV]
	and $f0
	ld b, a
	swap a
	or b
	ldh [hChartDef], a
	depixel 15, 17
	call SparkleMaxStat
; Spd
	ld a, [wTempMonDefSpdDV]
	and $0f
	ld b, a
	swap a
	or b
	ldh [hChartSpd], a
	depixel 17, 12
	call SparkleMaxStat
; SAt
	ld a, [wTempMonSatSdfDV]
	and $f0
	ld b, a
	swap a
	or b
	ldh [hChartSat], a
	depixel 4, 6
	call SparkleMaxStat
; SDf
	ld a, [wTempMonSatSdfDV]
	and $0f
	ld b, a
	swap a
	or b
	ldh [hChartSdf], a
	depixel 15, 6
	call SparkleMaxStat
	; fallthrough

RenderChart:
; Decompress blank chart graphics
	ld hl, JudgeSystemGFX
	ld b, BANK(JudgeSystemGFX)
	call FarDecompressWRA6InB
; Render the radar chart onto the graphics
	ld a, BANK(wDecompressScratch)
	ldh [rSVBK], a
	call OutlineRadarChart
	ld a, $1
	ldh [rSVBK], a
	ret

CalcBTimesCOver256:
; a = b * c / 256
	xor a
	ldh [hMultiplicand + 0], a
	ldh [hMultiplicand + 1], a
	ld a, b
	ldh [hMultiplicand + 2], a
	ld a, c
	ldh [hMultiplier], a
	call Multiply
	ldh a, [hProduct + 2]
	ret

OutlineRadarChart:
; de = point for HP axis
	ldh a, [hChartHP]
	ld b, a
	; x = 39
	ld a, 39
	ld d, a
	; y = 46 - v * 47 / 256
	ld c, 47
	call CalcBTimesCOver256
	cpl
	add 46 + 1 ; a = 46 - a
	ld e, a

; Store the HP point to close the polygon
	push de
	push de

; de = Atk point
	ldh a, [hChartAtk]
	ld b, a
	; x = 41 + v * 39 / 256
	ld c, 39
	call CalcBTimesCOver256
	add 41
	ld d, a
	; y = 46 - v * 23 / 256
	ld c, 23
	call CalcBTimesCOver256
	cpl
	add 46 + 1 ; a = 46 - a
	ld e, a

; Draw a line from HP to Atk
	pop bc
	push de
	ld a, LOW(FillRadarDown)
	ldh [hFunctionTargetLo], a
	ld a, HIGH(FillRadarDown)
	ldh [hFunctionTargetHi], a
	call DrawRadarLineBCToDE

; de = Def point
	ldh a, [hChartDef]
	ld b, a
	; x = 41 + v * 39 / 256
	ld c, 39
	call CalcBTimesCOver256
	add 41
	ld d, a
	; y = 49 + v * 23 / 256
	ld c, 23
	call CalcBTimesCOver256
	add 49
	ld e, a

; Draw a line from Atk to Def
	pop bc
	push de
	ld a, LOW(FillRadarLeft)
	ldh [hFunctionTargetLo], a
	ld a, HIGH(FillRadarLeft)
	ldh [hFunctionTargetHi], a
	call DrawRadarLineBCToDE

; de = Spd point
	ldh a, [hChartSpd]
	ld b, a
	; x = 40
	ld a, 40
	ld d, a
	; y = 49 + v * 47 / 256
	ld c, 47
	call CalcBTimesCOver256
	add 49
	ld e, a

; Draw a line from Def to Spd
	pop bc
	push de
	ld a, LOW(FillRadarUp)
	ldh [hFunctionTargetLo], a
	ld a, HIGH(FillRadarUp)
	ldh [hFunctionTargetHi], a
	call DrawRadarLineBCToDE

; de = SDf point
	ldh a, [hChartSdf]
	ld b, a
	; x = 38 - v * 39 / 256
	ld c, 39
	call CalcBTimesCOver256
	cpl
	add 38 + 1 ; a = 38 - a
	ld d, a
	; y = 49 + v * 23 / 256
	ld c, 23
	call CalcBTimesCOver256
	add 49
	ld e, a

; Draw a line from Spd to SDf
	pop bc
	push de
	; hFunctionTarget is already FillRadarUp
	call DrawRadarLineBCToDE

; de = SAt point
	ldh a, [hChartSat]
	ld b, a
	; x = 38 - v * 39 / 256
	ld c, 39
	call CalcBTimesCOver256
	cpl
	add 38 + 1 ; a = 38 - a
	ld d, a
	; y = 46 - v * 23 / 256
	ld c, 23
	call CalcBTimesCOver256
	cpl
	add 46 + 1 ; a = 46 - a
	ld e, a

; Draw a line from SDf to SAt
	pop bc
	push de
	ld a, LOW(FillRadarRight)
	ldh [hFunctionTargetLo], a
	ld a, HIGH(FillRadarRight)
	ldh [hFunctionTargetHi], a
	call DrawRadarLineBCToDE

; Draw a line from SAt to HP, closing the polygon
	pop bc
	pop de
	ld a, LOW(FillRadarDown)
	ldh [hFunctionTargetLo], a
	ld a, HIGH(FillRadarDown)
	ldh [hFunctionTargetHi], a
	; fallthrough

DrawRadarLineBCToDE:
; Draw a line from (b, c) to (d, e)

; Calculate |x1 - x0|
	ld a, d
	sub b
	jr nc, .x_sorted
	cpl
	inc a ; a = -a
.x_sorted
	ldh [hDX], a
	ld l, a

; Calculate |y1 - y0|
	ld a, e
	sub c
	jr nc, .y_sorted
	cpl
	inc a ; a = -a
.y_sorted
	ldh [hDY], a

; Branch based on slope
	cp l
	jr nc, DrawHighRadarLine ; dy (a) >= dx (l)
	; fallthrough

DrawLowRadarLine:
; Draw a line from (b, c) to (d, e), left to right, where dx > dy

; Ensure that x0 < x1 (b < d)
	ld a, b
	cp d
	jr c, .x_sorted
	; swap bc and de
	ld a, b
	ld b, d
	ld d, a
	ld a, c
	ld c, e
	ld e, a
.x_sorted

; Shift up or down depending on dy
	ld a, c
	cp e
	ld a, $0c ; inc c
	jr c, .y_sorted
	jr z, DrawHorizontalRadarLine ; c == e, so y is constant
	inc a ; $0d ; dec c
.y_sorted
	ldh [hSingleOpcode], a

; D = 2 * dy - dx
	ldh a, [hDX]
	ld l, a
	ldh a, [hDY]
	add a
	sub l
	ldh [hErr], a

; For x from b to d, draw a point at (x, c)
.loop
	call DrawRadarPointBC

; Update D and y
	ldh a, [hErr]
	cp $80 ; high bit means negative
	jr nc, .not_positive
	call hSingleOperation
	ldh a, [hDX]
	ld l, a
	ldh a, [hErr]
	sub l
	sub l
	ldh [hErr], a
.not_positive
	ld hl, hDY
	add [hl]
	add [hl]
	ldh [hErr], a

	inc b
	ld a, d
	cp b
	jr nc, .loop
	ret

DrawHighRadarLine:
; Draw a line from (b, c) to (d, e), top to bottom, where dx <= dy

; Ensure that y0 < y1 (c < e)
	ld a, c
	cp e
	jr c, .y_sorted
	; swap bc and de
	ld a, b
	ld b, d
	ld d, a
	ld a, c
	ld c, e
	ld e, a
.y_sorted

; Shift right or left depending on dx
	ld a, b
	cp d
	ld a, $04 ; inc b
	jr c, .x_sorted
	jr z, DrawVerticalRadarLine ; b == d, so x is constant
	inc a ; $05 ; dec b
.x_sorted
	ldh [hSingleOpcode], a

; For y from c to e, draw a point at (b, y)
.loop
	call DrawRadarPointBC

; Update D and x
	ldh a, [hErr]
	cp $80
	jr nc, .not_positive
	call hSingleOperation
	ldh a, [hDY]
	ld l, a
	ldh a, [hErr]
	sub l
	sub l
	ldh [hErr], a
.not_positive
	ld hl, hDX
	add [hl]
	add [hl]
	ldh [hErr], a

	inc c
	ld a, e
	cp c
	jr nc, .loop
	ret

DrawHorizontalRadarLine:
; Draw from (b, c) to (d, e), where c == e and b < d

; Ensure that x0 < x1 (b < d)
	ld a, b
	cp d
	jr c, .x_sorted
	jr z, DrawRadarPointBC ; b == d and c == e, so draw one point
	ld b, d
	ld d, a
.x_sorted

; For x from b to d, draw a point at (x, c)
.loop
	call DrawRadarPointBC
	inc b
	ld a, d
	cp b
	jr nc, .loop
	ret

DrawVerticalRadarLine:
; Draw a line from (b, c) to (d, e), where b == d

; Ensure that y0 < y1 (c < e)
	ld a, c
	cp e
	jr c, .y_sorted
	jr z, DrawRadarPointBC ; b == d and c == e, so draw one point
	ld c, e
	ld e, a
.y_sorted

; For y from c to e, draw a point at (b, y)
.loop
	call DrawRadarPointBC
	inc c
	ld a, e
	cp c
	jr nc, .loop
	ret

DrawRadarPointBC:
; Draw a point at (b, c), where 0 <= b < 80 and 0 <= c < 96
	push de

; Byte: wDecompressScratch + ((y & $f8) * 10 + (x & $f8) + (y & $7)) * 2
	; hl = (y & $f8) * 10
	ld a, c
	and $f8
	ld hl, .Times10
	srl a
	srl a
	ld d, 0
	ld e, a
	add hl, de
	ld a, [hli]
	ld h, [hl]
	ld l, a
	; hl += (x & $f8) + (y & $7)
	ld a, b
	and $f8
	ld d, 0
	ld e, a
	ld a, c
	and $7
	add e
	ld e, a
	add hl, de
	; hl = wDecompressScratch + hl * 2
	add hl, hl
	ld de, wDecompressScratch
	add hl, de

; Bit: 7 - (x & $7)
	ld a, b
	and $7
	cpl
	add 7 + 1 ; a = 7 - a

; Dark color %01: res in the first byte, set in the second byte
	; $86 | (a << 3) = the 'res {a}, [hl]' opcode
	add a
	add a
	add a
	or $86
	ldh [hBitwiseOpcode], a
	call hBitwiseOperation
	; $c6 | (a << 3) = the 'set {a}, [hl]' opcode
	inc hl
	xor $86 ^ $c6
	ldh [hBitwiseOpcode], a
	call hBitwiseOperation

	pop de
	jp hFunction

.Times10:
	dw %0000000000 ; == %00000xxx * 10 ($00-07)
	dw %0001010000 ; == %00001xxx * 10 ($08-0f)
	dw %0010100000 ; == %00010xxx * 10 ($10-17)
	dw %0011110000 ; == %00011xxx * 10 ($18-1f)
	dw %0101000000 ; == %00100xxx * 10 ($20-27)
	dw %0110010000 ; == %00101xxx * 10 ($28-2f)
	dw %0111100000 ; == %00110xxx * 10 ($30-37)
	dw %1000110000 ; == %00111xxx * 10 ($38-3f)
	dw %1010000000 ; == %01000xxx * 10 ($40-47)
	dw %1011010000 ; == %01001xxx * 10 ($48-4f)
	dw %1100100000 ; == %01010xxx * 10 ($50-57)
	dw %1101110000 ; == %01011xxx * 10 ($58-5f)

FillRadarUp:
FillRadarRight:
FillRadarDown:
FillRadarLeft:
; TODO: fill in the direction until reaching a black or dark pixel
	; $46 | (a << 3) = the 'bit {a}, [hl]' opcode
	xor $c6 ^ $46
	ldh [hBitwiseOpcode], a
	ret

JudgeSystemGFX:
INCBIN "gfx/stats/judge.2bpp.lz"

MaxStatSparkleGFX:
INCBIN "gfx/stats/sparkle.2bpp"

EVChartPals:
if !DEF(MONOCHROME)
	RGB 23,28,21, 22,26,20, 10,17,16, 00,00,00 ; main bg
	RGB 31,31,31, 23,28,21, 31,25,02, 00,00,00 ; top text (incl. shiny)
	RGB 23,28,21, 31,31,31, 00,00,00, 02,06,13 ; stat values and B button
	RGB 23,28,21, 31,00,31, 31,00,31, 03,15,29 ; lowered stat
	RGB 23,28,21, 31,00,31, 31,00,31, 23,07,03 ; raised stat
	RGB 18,27,29, 23,28,21, 02,10,20, 10,17,16 ; chart
else
; main bg
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_DARK
	RGB_MONOCHROME_BLACK
; top text
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_BLACK
; stat values and B button
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_BLACK
	RGB_MONOCHROME_BLACK
; lowered stat
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_BLACK
; raised stat
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_BLACK
; chart
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_BLACK
	RGB_MONOCHROME_DARK
endc

IVChartPals:
if !DEF(MONOCHROME)
	RGB 28,21,14, 26,20,13, 27,14,13, 00,00,00 ; main bg
	RGB 31,31,31, 28,21,14, 31,25,02, 00,00,00 ; top text (incl. shiny)
	RGB 28,21,14, 31,31,31, 00,00,00, 02,06,13 ; stat values and B button
	RGB 28,21,14, 31,00,31, 31,00,31, 03,15,29 ; lowered stat
	RGB 28,21,14, 31,00,31, 31,00,31, 23,07,03 ; raised stat
	RGB 18,27,29, 28,21,14, 02,10,20, 27,14,13 ; chart
else
; main bg
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_DARK
	RGB_MONOCHROME_BLACK
; top text
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_BLACK
; stat values and B button
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_BLACK
	RGB_MONOCHROME_BLACK
; lowered stat
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_BLACK
; raised stat
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_BLACK
; chart
	RGB_MONOCHROME_WHITE
	RGB_MONOCHROME_LIGHT
	RGB_MONOCHROME_BLACK
	RGB_MONOCHROME_DARK
endc