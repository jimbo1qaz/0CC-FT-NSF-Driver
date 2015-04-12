;
; Update track effects
;
ft_run_effects:

	; Volume slide
	lda var_ch_VolSlide, x
	beq @NoVolSlide
	; First calculate volume decrease
	lda var_ch_VolSlide, x
	and #$0F
	sta var_Temp
	sec
	lda var_ch_VolColumn, x
	sbc var_Temp
	bpl :+
	lda #$00
:   sta var_ch_VolColumn, x
	; Then increase
	lda var_ch_VolSlide, x
	lsr a
	lsr a
	lsr a
	lsr a
	sta var_Temp
	clc
	lda var_ch_VolColumn, x
	adc var_Temp
	bpl :+
	lda #$7F
:   sta var_ch_VolColumn, x
@NoVolSlide:

.if 0
	lda var_ch_Effect, x
	bne :+
	; No effect
	rts
:	asl a
	tay
	lda ft_effect_table - 2, y
	sta var_Temp_Pointer
	lda ft_effect_table - 1, y
	sta var_Temp_Pointer + 1
	jmp (var_Temp_Pointer)
.endif

;.if 0
ft_jump_to_effect:
	; Arpeggio and portamento
	lda var_ch_Effect, x
	beq @NoEffect
	cmp #EFF_ARPEGGIO
	beq @EffArpeggio
	cmp #EFF_PORTAMENTO
	beq @EffPortamento
	cmp #EFF_PORTA_UP
	beq @EffPortaUp
	cmp #EFF_SLIDE_UP
	beq @EffSlideUp
	cmp #EFF_SLIDE_DOWN
	beq @EffSlideDown

	cmp #EFF_SLIDE_UP_LOAD
	beq @EffLoadSlide
	cmp #EFF_SLIDE_DOWN_LOAD
	beq @EffLoadSlide

	jmp ft_portamento_down

@EffArpeggio:
	jmp ft_arpeggio
@EffPortamento:
	jmp ft_portamento
@EffPortaUp:
	jmp ft_portamento_up
@EffSlideUp:
	jmp	ft_portamento ; ft_slide_up
@EffSlideDown:
	jmp	ft_portamento ; ft_slide_down
@EffLoadSlide:
	jmp ft_load_slide
@NoEffect:
;.endif
ft_post_effects:
	rts

.if 0
ft_effect_table:
	.word ft_arpeggio, ft_portamento, ft_portamento_up, ft_portamento_down
	.word ft_load_slide, ft_slide_up, ft_load_slide, ft_slide_down
.endif

ft_load_slide:
.if .defined(USE_VRC7)
	lda ft_channel_type, x			;;; ;; ;
	cmp #CHAN_VRC7
	bne :+							; ;; ;;;
	jmp ft_vrc7_load_slide
:	; VRC7 skip
.endif

	lda var_ch_TimerPeriodLo, x
	pha
	lda var_ch_TimerPeriodHi, x
	pha
	; Load note
	lda var_ch_EffParam, x			; Store speed
	and #$0F						; Get note
	sta var_Temp					; Store note in temp
	lda var_ch_Effect, x
	cmp #EFF_SLIDE_UP_LOAD
	beq @Add
	lda var_ch_Note, x
	sec
	sbc var_Temp
	bpl :+
	lda #$01
:   bne :+
	lda #$01
:   jmp @Done
@Add:
	lda var_ch_Note, x
	clc
	adc var_Temp
	cmp #96
	bcc @Done
	lda #96
@Done:
	sta var_ch_Note, x
	sta var_ch_EchoBuffer, x		;;; ;; ;
	jsr	ft_translate_freq_only
	lda var_ch_TimerPeriodLo, x
	sta var_ch_PortaToLo, x
	lda var_ch_TimerPeriodHi, x
	sta var_ch_PortaToHi, x
	; Store speed
	lda var_ch_EffParam, x
	lsr a
	lsr a
	lsr a
	ora #$01
	sta var_ch_EffParam, x
	; Load old period
	pla
	sta var_ch_TimerPeriodHi, x
	pla
	sta var_ch_TimerPeriodLo, x
	; change mode to sliding
	clc
	lda var_ch_Effect, x
	adc #01
.if .defined(USE_FDS)
	; FDS's frequency reg is inverted
	cpx #FDS_OFFSET
	bne :++
	cmp #EFF_SLIDE_UP
	bne :+
	lda #EFF_SLIDE_DOWN
	jmp :++
:	lda #EFF_SLIDE_UP
:
.endif
	sta var_ch_Effect, x
.if .defined(USE_N163)
	lda ft_channel_type, x
	cmp #CHAN_N163
	bne :++
	asl var_ch_EffParam, x
	asl var_ch_EffParam, x
	; Invert
	lda var_ch_Effect, x
	cmp #EFF_SLIDE_UP
	beq :+
	lda #EFF_SLIDE_UP
	sta var_ch_Effect, x
	jmp ft_jump_to_effect
:   lda #EFF_SLIDE_DOWN
	sta var_ch_Effect, x
:
.endif
	; Work-around for noise
	cpx #$03
	bne :++
	cmp #EFF_SLIDE_UP
	beq :+
	lda #EFF_SLIDE_UP
	sta var_ch_Effect, x
	jmp ft_jump_to_effect

;    rts
:   lda #EFF_SLIDE_DOWN
	sta var_ch_Effect, x
:	;rts
	jmp ft_jump_to_effect

ft_calc_period:

	; Load period
	lda var_ch_TimerPeriodLo, x
	sta var_ch_PeriodCalcLo, x
	lda var_ch_TimerPeriodHi, x
	sta var_ch_PeriodCalcHi, x

.if .defined(USE_VRC7)
	lda ft_channel_type, x
	cmp #CHAN_VRC7
	bne :+
	lsr var_ch_PeriodCalcHi, x
	ror var_ch_PeriodCalcLo, x
	lsr var_ch_PeriodCalcHi, x
	ror var_ch_PeriodCalcLo, x
:
.endif

	; Apply fine pitch
	lda var_ch_FinePitch, x
	cmp #$80
	beq @Skip
	lda var_ch_Note, x    ; Skip on note off as well to avoid problems with VRC7
	beq @Skip

;	.if 0

.if .defined(USE_N163)
	lda ft_channel_type, x
	cmp #CHAN_N163
	bne :+
	; N163 pitch
	lda #$00
	sta var_Temp16 + 1
	lda var_ch_FinePitch, x
	asl a
	sta var_Temp16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
	clc
	lda var_ch_PeriodCalcLo, x
	adc #$00
	sta var_ch_PeriodCalcLo, x
	lda var_ch_PeriodCalcHi, x
	adc #$08
	sta var_ch_PeriodCalcHi, x
	sec
	lda var_ch_PeriodCalcLo, x
	sbc var_Temp16
	sta var_ch_PeriodCalcLo, x
	lda var_ch_PeriodCalcHi, x
	sbc var_Temp16 + 1
	sta var_ch_PeriodCalcHi, x
	jmp @Skip
:
.endif

	clc
	lda var_ch_PeriodCalcLo, x
	adc #$80
	sta var_ch_PeriodCalcLo, x
	lda var_ch_PeriodCalcHi, x
	adc #$00
	sta var_ch_PeriodCalcHi, x
	sec
	lda var_ch_PeriodCalcLo, x
	sbc var_ch_FinePitch, x
	sta var_ch_PeriodCalcLo, x
	lda var_ch_PeriodCalcHi, x
	sbc #$00
	sta var_ch_PeriodCalcHi, x
@Skip:

	jsr ft_vibrato
	jsr ft_tremolo

	rts


;
; Portamento
;
ft_portamento:
	lda var_ch_EffParam, x							; Check portamento, if speed > 0
	beq @NoPortamento
	lda var_ch_PortaToLo, x							; and if freq > 0, else stop
	ora var_ch_PortaToHi, x
	beq @NoPortamento
	lda var_ch_TimerPeriodHi, x						; Compare high byte
	cmp var_ch_PortaToHi, x
	bcc @Increase
	bne @Decrease
	lda var_ch_TimerPeriodLo, x						; Compare low byte
	cmp var_ch_PortaToLo, x
	bcc @Increase
	bne @Decrease
	;rts											; done
	jmp ft_post_effects

@Decrease:											; Decrease period
	lda var_ch_EffParam, x
	sta var_Temp16
	lda #$00
	sta var_Temp16 + 1
	jsr ft_period_remove

.if 0
	sec
	lda var_ch_TimerPeriodLo, x
	sbc var_ch_EffParam, x
	sta var_ch_TimerPeriodLo, x
	lda var_ch_TimerPeriodHi, x
	sbc #$00
	sta var_ch_TimerPeriodHi, x
.endif
	; Check if sign bit has changed, if so load the desired period
;	lda var_ch_TimerPeriodHi, x			; Compare high byte
	cmp var_ch_PortaToHi, x
	bcc @LoadPeriod
	bmi @LoadPeriod
	bne @NoPortamento
	lda var_ch_TimerPeriodLo, x						; Compare low byte
	cmp var_ch_PortaToLo, x
	bcc @LoadPeriod
;	rts												; Portamento is done at this point
	jmp ft_post_effects

@Increase:											; Increase period
	lda var_ch_EffParam, x
	sta var_Temp16
	lda #$00
	sta var_Temp16 + 1
	jsr ft_period_add
.if 0
	clc
	lda var_ch_TimerPeriodLo, x
	adc var_ch_EffParam, x
	sta var_ch_TimerPeriodLo, x
	lda var_ch_TimerPeriodHi, x
	adc #$00
	sta var_ch_TimerPeriodHi, x
.endif
	; Check if sign bit has changed, if so load the desired period
	lda var_ch_PortaToHi, x							; Compare high byte
	cmp var_ch_TimerPeriodHi, x
	bcc @LoadPeriod
	bne @NoPortamento
	lda var_ch_PortaToLo, x							; Compare low byte
	cmp var_ch_TimerPeriodLo, x
	bcc @LoadPeriod
;	rts
	jmp ft_post_effects

@LoadPeriod:										; Load the correct period
	lda var_ch_PortaToLo, x
	sta var_ch_TimerPeriodLo, x
	lda var_ch_PortaToHi, x
	sta var_ch_TimerPeriodHi, x
@NoPortamento:
	jmp ft_post_effects

ft_portamento_up:
	lda var_ch_Note, x
	beq :+
	lda var_ch_EffParam, x
	sta var_Temp16
	lda #$00
	sta var_Temp16 + 1
	jsr ft_period_remove
	jsr ft_limit_freq
:	jmp ft_post_effects
ft_portamento_down:
	lda var_ch_Note, x
	beq :+
	lda var_ch_EffParam, x
	sta var_Temp16
	lda #$00
	sta var_Temp16 + 1
	jsr ft_period_add
	jsr ft_limit_freq
:	jmp ft_post_effects

ft_period_add:
.if .defined(USE_N163)
	lda ft_channel_type, x
	cmp #CHAN_N163
	bne :+
	; Multiply by 4
	asl var_Temp16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
:
.endif
	clc
	lda var_ch_TimerPeriodLo, x
	adc var_Temp16
	sta var_ch_TimerPeriodLo, x
	lda var_ch_TimerPeriodHi, x
	adc var_Temp16 + 1
	sta var_ch_TimerPeriodHi, x
	bcc :+                           ; Do not wrap
	lda #$FF
	sta var_ch_TimerPeriodLo, x
	sta var_ch_TimerPeriodHi, x
:   rts
ft_period_remove:
.if .defined(USE_N163)
	lda ft_channel_type, x
	cmp #CHAN_N163
	bne :+
	; Multiply by 4
	asl var_Temp16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
:
.endif
	sec
	lda var_ch_TimerPeriodLo, x
	sbc var_Temp16
	sta var_ch_TimerPeriodLo, x
	lda var_ch_TimerPeriodHi, x
	sbc var_Temp16 + 1
	sta var_ch_TimerPeriodHi, x
	bcs :+                           ; Do not wrap
	lda #$00
	sta var_ch_TimerPeriodLo, x
	sta var_ch_TimerPeriodHi, x
:   rts

.if 0
;
; Note slide
;
ft_slide_up:
	sec
	lda var_ch_TimerPeriodLo, x
	sbc var_ch_EffParam, x
	sta var_ch_TimerPeriodLo, x
	lda var_ch_TimerPeriodHi, x
	sbc #$00
	sta var_ch_TimerPeriodHi, x
	bmi ft_slide_done
	cmp var_ch_PortaToHi, x			    ; Compare high byte
	bcc ft_slide_done
	bne ft_slide_not_done
	lda var_ch_TimerPeriodLo, x
	cmp var_ch_PortaToLo, x				; Compare low byte
	bcc ft_slide_done

	jmp ft_post_effects

ft_slide_down:
	clc
	lda var_ch_TimerPeriodLo, x
	adc var_ch_EffParam, x
	sta var_ch_TimerPeriodLo, x
	lda var_ch_TimerPeriodHi, x
	adc #$00
	sta var_ch_TimerPeriodHi, x

	cmp var_ch_PortaToHi, x			    ; Compare high byte
	bcc ft_slide_not_done
	bne ft_slide_done
	lda var_ch_TimerPeriodLo, x
	cmp var_ch_PortaToLo, x				; Compare low byte
	bcs ft_slide_done
	jmp ft_post_effects

ft_slide_done:
	lda var_ch_PortaToLo, x
	sta var_ch_TimerPeriodLo, x
	lda var_ch_PortaToHi, x
	sta var_ch_TimerPeriodHi, x

	lda #EFF_NONE						; Reset effect
	sta var_ch_Effect, x
	sta var_ch_PortaToLo, x
	sta var_ch_PortaToHi, x

ft_slide_not_done:
	jmp ft_post_effects
.endif

;
; Arpeggio
;
ft_arpeggio:
	lda var_ch_ArpeggioCycle, x
	cmp #$01
	beq @LoadSecond
	cmp #$02
	beq @LoadThird
	lda var_ch_Note, x					; Load first note
	jsr ft_translate_freq_only
	inc var_ch_ArpeggioCycle, x
	jmp ft_post_effects
@LoadSecond:							; Second note (second nybble)
	lda var_ch_EffParam, x
	lsr a
	lsr a
	lsr a
	lsr a
	clc
	adc var_ch_Note, x
	jsr ft_translate_freq_only
	lda var_ch_EffParam, x						; see if cycle should reset here
	and #$0F
	bne @DoNextStep
	sta var_ch_ArpeggioCycle, x
	jmp ft_post_effects
@DoNextStep:
	inc var_ch_ArpeggioCycle, x
	jmp ft_post_effects
@LoadThird:										; Third note (first nybble)
	lda var_ch_EffParam, x
	and #$0F
	clc
	adc var_ch_Note, x
	jsr ft_translate_freq_only
	lda #$00
	sta var_ch_ArpeggioCycle, x
	jmp ft_post_effects

; Vibrato calculation
;
ft_vibrato:
	lda var_ch_VibratoSpeed, x
	bne :+
	rts
:	clc
	adc var_ch_VibratoPos, x		; Get next position
	and #$3F
	sta var_ch_VibratoPos, x
	cmp #$10
	bcc @Phase1
	cmp #$20
	bcc @Phase2
	cmp #$30
	bcc @Phase3
	; Phase 4: - 15 - (Phase - 48) + depth
	sec
	sbc #$30
	sta var_Temp
	sec
	lda #$0F
	sbc var_Temp
	ora var_ch_VibratoDepth, x
	tay
	lda ft_vibrato_table, y
	jmp @Negate
@Phase1:
	; Phase 1: Phase + depth
	ora var_ch_VibratoDepth, x
	tay
	lda ft_vibrato_table, y
	sta var_Temp16
	lda #$00
	sta var_Temp16 + 1
	jmp @Calculate
@Phase2:
	; Phase 2: 15 - (Phase - 16) + depth
	sec
	sbc #$10
	sta var_Temp
	sec
	lda #$0F
	sbc var_Temp
	ora var_ch_VibratoDepth, x
	tay
	lda ft_vibrato_table, y
	sta var_Temp16
	lda #$00
	sta var_Temp16 + 1
	jmp @Calculate
@Phase3:
	; Phase 3: - (Phase - 32) + depth
	sec
	sbc #$20
	ora var_ch_VibratoDepth, x
	tay
	lda ft_vibrato_table, y

@Negate:
	; Invert result
	eor #$FF
	sta var_Temp16
	lda #$FF
	sta var_Temp16 + 1
	clc
	lda var_Temp16
	adc #$01
	sta var_Temp16
	lda var_Temp16 + 1
	adc #$00
	sta var_Temp16 + 1

@Calculate:

	; Remove this if you don't need support for old vibrato
	lda var_SongFlags
	and #$02
	beq :+
	lda #$0F
	clc
	adc var_ch_VibratoDepth, x
	tay
	clc
	lda ft_vibrato_table, y		; add depth + 1
	adc #$01
;	clc
	adc var_Temp16
	sta var_Temp16
	lda var_Temp16 + 1
	adc #$00
	sta var_Temp16 + 1
	lsr var_Temp16 + 1			; divide by 2
	ror var_Temp16
:

.if .defined(USE_N163)
	lda ft_channel_type, x
	cmp #CHAN_N163
	bne @SkipN163
	asl var_Temp16        ; Multiply by 16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
	asl var_Temp16
	rol var_Temp16 + 1
@SkipN163:   ; if (ft_channel_type, x != CHAN_N163)
.endif

.if EXPANSION_FLAG		;;; ;; ;
	lda ft_channel_type, x
	cmp #CHAN_N163
	beq @Inverted
	cmp #CHAN_VRC7
	beq @Inverted
	cmp #CHAN_FDS
	beq @Inverted
.endif

	  ; TODO use ft_period_remove
	sec
	lda var_ch_PeriodCalcLo, x
	sbc var_Temp16
	sta var_ch_PeriodCalcLo, x
	lda var_ch_PeriodCalcHi, x
	sbc var_Temp16 + 1
	sta var_ch_PeriodCalcHi, x
	rts

@Inverted:
	clc
	lda var_ch_PeriodCalcLo, x
	adc var_Temp16
	sta var_ch_PeriodCalcLo, x
	lda var_ch_PeriodCalcHi, x
	adc var_Temp16 + 1
	sta var_ch_PeriodCalcHi, x
	rts

; Tremolo calculation
;
ft_tremolo:
	lda var_ch_TremoloSpeed, x
	bne @DoTremolo
;	lda var_ch_Volume, x
;	sta var_ch_OutVolume, x
	lda #$00
	sta var_ch_TremoloResult, x
	rts
@DoTremolo:
	clc
	adc var_ch_TremoloPos, x		; Get next position
	and #$3F
	sta var_ch_TremoloPos, x
	lsr a							; Divide by 2
	cmp #$10
	bcc @Phase1
; Phase 2
	; 15 - (Phase - 16) + depth
	sec
	sbc #$10
	sta var_Temp
	sec
	lda #$0F
	sbc var_Temp
	ora var_ch_TremoloDepth, x
	tay
	lda ft_vibrato_table, y
	lsr a
	sta var_Temp
	jmp @Calculate
@Phase1:
	; Phase + depth
	ora var_ch_TremoloDepth, x
	tay
	lda ft_vibrato_table, y
	lsr a
	sta var_Temp
@Calculate:
	sta var_ch_TremoloResult, x
.if 0
	sec
	lda var_ch_Volume, x
	sbc var_Temp
	bmi :+
	sta var_ch_OutVolume, x
	rts
:	lda #$00
	sta var_ch_OutVolume, x
.endif
	rts

