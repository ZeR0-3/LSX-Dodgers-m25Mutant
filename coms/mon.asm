; MON.COM - LSX-Dodgers MZ-2500 用モニタ (IOCS非依存。BDOS 2/9/0Ah だけで動く)
;
;   D [始 [終]]      メモリダンプ(省略時は続き)        M 番地 [バイト...]  書き換え(バイトなしは対話。空行=次、. =終了)
;   F 始 終 値        埋める                             G 番地             CALL する(RETで戻る)
;   L [番地 [行数]]   逆アセンブル(省略時16行・続き)     A 番地             簡易アセンブラ(. か空行で終了)
;   I ポート / O ポート 値   I/O 読み/書き               P                  I/Oポート一覧
;   H または ?        ヘルプ                             Q                  終了
; 数値はすべて16進。アセンブラの数値は 0-9 で始める(例 0FFH、10、5)。H は付けても付けなくてもよい。
; 逆アセンブラのテキストを「テンプレート」にして候補を総当たりで入力と照合する方式のアセンブラ。
; 対応: 公式Z80命令(IX/IY、CB/ED系を含む)。未公開命令(IXH 等)・疑似命令 DB/DW だけ。RST は "RST 38" の形。

	org	0100h

START:	ld	sp,STK
	ld	de,MBANNER
	call	PUTS
MAIN:	ld	sp,STK
	ld	a,'*'
	call	PUTC
	call	GETLINE
	ld	de,LBUF+2
	call	SKSP
	ld	a,(de)
	or	a
	jr	z,MAIN
	inc	de
	cp	'D'
	jp	z,CMD_D
	cp	'M'
	jp	z,CMD_M
	cp	'F'
	jp	z,CMD_F
	cp	'G'
	jp	z,CMD_G
	cp	'L'
	jp	z,CMD_L
	cp	'A'
	jp	z,CMD_A
	cp	'I'
	jp	z,CMD_I
	cp	'O'
	jp	z,CMD_O
	cp	'P'
	jp	z,CMD_P
	cp	'H'
	jp	z,CMD_H
	cp	'?'
	jp	z,CMD_H
	cp	'Q'
	jp	z,0
ERR:	ld	a,'?'
	call	PUTC
	call	CRLF
	jr	MAIN

; ---------------------------------------------------------------- 入出力
PUTC:	push	bc
	push	de
	push	hl
	ld	e,a
	ld	c,2
	call	5
	pop	hl
	pop	de
	pop	bc
	ret

CRLF:	ld	a,13
	call	PUTC
	ld	a,10
	jp	PUTC

PUTS:	ld	a,(de)		; DE=0終端の文字列
	inc	de
	or	a
	ret	z
	call	PUTC
	jr	PUTS

PHEX8:	push	af
	rrca
	rrca
	rrca
	rrca
	call	PH1
	pop	af
PH1:	and	15
	add	a,'0'
	cp	'9'+1
	jr	c,PH2
	add	a,7
PH2:	jp	PUTC

PHEX16:	ld	a,h
	call	PHEX8
	ld	a,l
	jp	PHEX8

SPC:	ld	a,' '
	jp	PUTC

; 1行入力 -> LBUF+2 に大文字化して0終端
GETLINE:
	push	de
	ld	de,LBUF
	ld	c,0Ah
	call	5
	call	CRLF
	ld	hl,LBUF+1
	ld	e,(hl)
	ld	d,0
	ld	hl,LBUF+2
	add	hl,de
	ld	(hl),0
	ld	hl,LBUF+2
GL1:	ld	a,(hl)
	or	a
	jr	z,GL3
	cp	'a'
	jr	c,GL2
	cp	'z'+1
	jr	nc,GL2
	sub	20h
	ld	(hl),a
GL2:	inc	hl
	jr	GL1
GL3:	pop	de
	ret

; ---------------------------------------------------------------- 構文解析 (DE=行の位置)
SKSP:	ld	a,(de)
	cp	' '
	ret	nz
	inc	de
	jr	SKSP

; A=文字 -> NC で A=0-15 / CY=1 なら16進ではない
HEXV:	cp	'0'
	jr	c,HBAD
	cp	'9'+1
	jr	c,HNUM
	cp	'A'
	jr	c,HBAD
	cp	'F'+1
	jr	nc,HBAD
	sub	'A'-10
	or	a
	ret
HNUM:	sub	'0'
	or	a
	ret
HBAD:	scf
	ret

; DE=位置から16進数を読む -> HL=値 DE=進める CY=1 なら数字なし。末尾の H は読み飛ばす
PHEX:	ld	hl,0
	ld	b,0
PHX1:	ld	a,(de)
	call	HEXV
	jr	c,PHX2
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	or	l
	ld	l,a
	inc	de
	inc	b
	jr	PHX1
PHX2:	ld	a,b
	or	a
	jr	nz,PHX3
	scf
	ret
PHX3:	ld	a,(de)
	cp	'H'
	jr	nz,PHX4
	inc	de
PHX4:	or	a
	ret

GETHEX:	call	SKSP
	jr	PHEX

; ---------------------------------------------------------------- D
CMD_D:	call	GETHEX
	jr	c,CD_NOA
	ld	(DADDR),hl
	call	GETHEX
	jr	c,CD_NOA
	ld	(DEND),hl
	jr	CD_GO
CD_NOA:	ld	hl,(DADDR)
	ld	bc,127
	add	hl,bc
	jr	nc,CD_S
	ld	hl,0FFFFh
CD_S:	ld	(DEND),hl
CD_GO:	ld	hl,(DADDR)
	call	PHEX16
	ld	a,':'
	call	PUTC
	ld	hl,(DADDR)
	ld	b,16
CD_B:	call	SPC
	ld	a,(hl)
	call	PHEX8
	inc	hl
	djnz	CD_B
	call	SPC
	call	SPC
	ld	hl,(DADDR)
	ld	b,16
CD_C:	ld	a,(hl)
	inc	hl
	cp	20h
	jr	c,CD_D
	cp	7Fh
	jr	c,CD_E
CD_D:	ld	a,'.'
CD_E:	call	PUTC
	djnz	CD_C
	call	CRLF
	ld	(DADDR),hl
	ld	a,h
	or	l
	jr	z,CD_END		; 0000へ回り込んだら終わり
	ex	de,hl
	ld	hl,(DEND)
	or	a
	sbc	hl,de
	jr	nc,CD_GO
CD_END:	jp	MAIN

; ---------------------------------------------------------------- M
CMD_M:	call	GETHEX
	jp	c,ERR
	ld	(MADDR),hl
	xor	a
	ld	(MFLAG),a
CM_I:	call	GETHEX
	jr	c,CM_N
	ld	a,l
	ld	hl,(MADDR)
	ld	(hl),a
	inc	hl
	ld	(MADDR),hl
	ld	a,1
	ld	(MFLAG),a
	jr	CM_I
CM_N:	ld	a,(MFLAG)
	or	a
	jp	nz,MAIN
CM_L:	ld	hl,(MADDR)
	call	PHEX16
	ld	a,'='
	call	PUTC
	ld	a,(hl)
	call	PHEX8
	ld	a,' '
	call	PUTC
	call	GETLINE
	ld	de,LBUF+2
	call	SKSP
	ld	a,(de)
	or	a
	jr	z,CM_X
	cp	'.'
	jp	z,MAIN
CM_P:	call	GETHEX
	jr	c,CM_L
	ld	a,l
	ld	hl,(MADDR)
	ld	(hl),a
	inc	hl
	ld	(MADDR),hl
	jr	CM_P
CM_X:	ld	hl,(MADDR)
	inc	hl
	ld	(MADDR),hl
	jr	CM_L

; ---------------------------------------------------------------- F
CMD_F:	call	GETHEX
	jp	c,ERR
	ld	(MADDR),hl
	call	GETHEX
	jp	c,ERR
	ld	(DEND),hl
	call	GETHEX
	jp	c,ERR
	ld	a,l
	ld	hl,(MADDR)
CF_L:	ld	(hl),a
	push	af
	ld	de,(DEND)
	or	a
	sbc	hl,de
	add	hl,de
	jr	z,CF_E
	inc	hl
	pop	af
	jr	CF_L
CF_E:	pop	af
	jp	MAIN

; ---------------------------------------------------------------- G
CMD_G:	call	GETHEX
	jp	c,ERR
	call	JPHL
	jp	MAIN
JPHL:	jp	(hl)

; ---------------------------------------------------------------- I / O
CMD_I:	call	GETHEX
	jp	c,ERR
	ld	c,l
	in	a,(c)
	call	PHEX8
	call	CRLF
	jp	MAIN

CMD_O:	call	GETHEX
	jp	c,ERR
	push	hl
	call	GETHEX
	pop	bc
	jp	c,ERR
	ld	a,l
	out	(c),a
	jp	MAIN

CMD_P:	ld	de,PORTS
	call	PUTS
	jp	MAIN

CMD_H:	ld	de,MHELP
	call	PUTS
	jp	MAIN

; ---------------------------------------------------------------- L
CMD_L:	call	GETHEX
	jr	c,CL_N
	ld	(LADDR),hl
	call	GETHEX
	jr	c,CL_N
	ld	a,l
	ld	(LCNT),a
	jr	CL_G
CL_N:	ld	a,16
	ld	(LCNT),a
CL_G:	ld	hl,(LADDR)
	ld	(ISRC),hl
	ld	(IPC),hl
	xor	a
	ld	(TMPLF),a
	call	DIS
	ld	hl,(LADDR)
	call	PHEX16
	call	SPC
	call	SPC
	ld	hl,(LADDR)
	ld	a,(LEN)
	ld	b,a
	ld	c,4
CL_H:	ld	a,(hl)
	call	PHEX8
	call	SPC
	inc	hl
	dec	c
	djnz	CL_H
	ld	a,c
	or	a
	jr	z,CL_T
CL_P:	call	SPC
	call	SPC
	call	SPC
	dec	c
	jr	nz,CL_P
CL_T:	call	SPC
	ld	de,TBUF
	call	PUTS
	call	CRLF
	ld	a,(LEN)
	ld	e,a
	ld	d,0
	ld	hl,(LADDR)
	add	hl,de
	ld	(LADDR),hl
	ld	hl,LCNT
	dec	(hl)
	jr	nz,CL_G
	jp	MAIN

; ---------------------------------------------------------------- A (アセンブラ)
CMD_A:	call	GETHEX
	jp	c,ERR
	ld	(AADDR),hl
CA_L:	ld	hl,(AADDR)
	call	PHEX16
	ld	a,' '
	call	PUTC
	call	GETLINE
	call	NORMAL
	ld	a,(NBUF)
	or	a
	jp	z,MAIN
	cp	'.'
	jp	z,MAIN
	ld	hl,(AADDR)
	ld	(ASTART),hl
	call	ASMLINE
	jr	c,CA_E
	ld	hl,(ASTART)		; 出力したバイトを見せる
	ld	de,(AADDR)
	ld	a,'='
	call	PUTC
CA_S:	or	a
	push	hl
	sbc	hl,de
	pop	hl
	jr	z,CA_D
	ld	a,(hl)
	call	PHEX8
	call	SPC
	inc	hl
	jr	CA_S
CA_D:	call	CRLF
	jr	CA_L
CA_E:	ld	a,'?'
	call	PUTC
	call	CRLF
	jr	CA_L

; LBUF の行を NBUF へ(空白を除く。; 以降は捨てる)
NORMAL:	ld	hl,LBUF+2
	ld	de,NBUF
NM1:	ld	a,(hl)
	inc	hl
	or	a
	jr	z,NM9
	cp	';'
	jr	z,NM9
	cp	' '
	jr	z,NM1
	ld	(de),a
	inc	de
	jr	NM1
NM9:	xor	a
	ld	(de),a
	ret

; NBUF の1行を (AADDR) へ組み立てる。成功 CY=0 (AADDRは進む)、失敗 CY=1
ASMLINE:
	ld	a,(NBUF)
	cp	'D'
	jr	nz,AS_I
	ld	a,(NBUF+1)
	cp	'B'
	jr	z,AS_DB
	cp	'W'
	jr	z,AS_DW
AS_I:	ld	a,1
	ld	(TMPLF),a
	xor	a
	ld	(TRI),a
AS_T:	xor	a
	ld	(OPCD),a
AS_O:	call	BUILD
	call	TRYONE
	jr	nc,AS_OK
	ld	hl,OPCD
	inc	(hl)
	jr	nz,AS_O
	ld	hl,TRI
	inc	(hl)
	ld	a,(hl)
	cp	7
	jr	c,AS_T
	scf
	ret
AS_OK:	jp	EMIT

AS_DB:	ld	b,0		; DB n,n,...
	jr	AS_D
AS_DW:	ld	b,1
AS_D:	ld	a,(NBUF+2)
	sub	'0'
	cp	10
	jr	nc,AS_BAD
	ld	de,NBUF+2
AS_DL:	push	bc
	call	PHEX
	pop	bc
	jr	c,AS_BAD
	push	de
	ex	de,hl
	ld	hl,(AADDR)
	ld	(hl),e
	inc	hl
	ld	a,b
	or	a
	jr	z,AS_DS
	ld	(hl),d
	inc	hl
AS_DS:	ld	(AADDR),hl
	pop	de
	ld	a,(de)
	or	a
	ret	z
	cp	','
	jr	nz,AS_BAD
	inc	de
	jr	AS_DL
AS_BAD:	scf
	ret

; 試行TRIの前置き + OPCD で TB (4バイト) を作る。スキップすべき組なら TB[0]=0FFh,TRYONE が失敗にする
BUILD:	ld	a,(TRI)
	add	a,a
	add	a,a		; 表は1行4バイト
	ld	e,a
	ld	d,0
	ld	hl,PFXT
	add	hl,de
	ld	a,(hl)		; 前置きバイト数
	ld	(NPFX),a
	inc	hl
	ld	de,TB
	ld	bc,3
	ldir
	ld	hl,TB
	ld	a,(NPFX)
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,(OPCD)
	ld	(hl),a
	inc	hl
	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ret

PFXT:	defb	0,0,0,0		; 前置きなし
	defb	1,0CBh,0,0
	defb	1,0EDh,0,0
	defb	1,0DDh,0,0
	defb	1,0FDh,0,0
	defb	3,0DDh,0CBh,0	; DD CB d op
	defb	3,0FDh,0CBh,0

; TB を逆アセンブル(テンプレート)して NBUF と照合する。CY=0 一致
TRYONE:	ld	a,(TRI)		; 前置きなし/DD/FD の試行で opcode が前置きバイトなら飛ばす
	cp	1
	jr	z,TR_G
	cp	2
	jr	z,TR_G
	cp	5
	jr	nc,TR_G
	ld	a,(OPCD)
	cp	0CBh
	jr	z,TR_S
	cp	0EDh
	jr	z,TR_S
	cp	0DDh
	jr	z,TR_S
	cp	0FDh
	jr	z,TR_S
TR_G:	ld	hl,TB
	ld	(ISRC),hl
	ld	hl,(AADDR)
	ld	(IPC),hl
	call	DIS
	jp	MATCH
TR_S:	scf
	ret

; ---------------------------------------------------------------- 照合
; TBUF のテンプレート(小文字 n w d e が数値の置き場)と NBUF を比べる。
MATCH:	xor	a
	ld	(OPN),a
	ld	(NEGF),a
	ld	hl,TBUF
	ld	de,NBUF
MT1:	ld	a,(hl)
	or	a
	jr	z,MT9
	cp	' '
	jr	nz,MT1B
	inc	hl
	jr	MT1
MT1B:
	cp	'a'
	jr	nc,MTPH
	cp	'+'
	jr	nz,MTL
	ld	a,(de)
	cp	'-'
	jr	nz,MTL2
	ld	a,1
	ld	(NEGF),a
	inc	de
	inc	hl
	jr	MT1
MTL2:	ld	a,'+'
MTL:	ld	b,a
	ld	a,(de)
	cp	b
	jr	nz,MTF
	inc	hl
	inc	de
	jr	MT1
MT9:	ld	a,(de)
	or	a
	jr	nz,MTF
	or	a
	ret
MTF:	scf
	ret
MTPH:	ld	(PHC),a		; n/w/d/e
	push	hl
	ld	a,(de)
	sub	'0'
	cp	10
	jr	nc,MTPF		; 数値は10進の数字で始める
	call	PHEX		; HL=値 DE進む
	ld	a,(PHC)
	cp	'n'
	jr	z,MTN
	cp	'w'
	jr	z,MTW
	cp	'd'
	jr	z,MTD
	; 'e' 相対ジャンプ: 目標 - (AADDR + LEN)
	push	de
	ex	de,hl
	ld	hl,(AADDR)
	ld	a,(LEN)
	ld	c,a
	ld	b,0
	add	hl,bc
	ex	de,hl
	or	a
	sbc	hl,de
	pop	de
	ld	a,l
	ld	c,a
	ld	a,h
	or	a
	jr	nz,MTE1
	bit	7,c
	jr	nz,MTPF
	jr	MTAP
MTE1:	cp	0FFh
	jr	nz,MTPF
	bit	7,c
	jr	z,MTPF
	jr	MTAP
MTN:	ld	a,h
	or	a
	jr	nz,MTPF
	ld	c,l
	jr	MTAP
MTW:	ld	c,l
	ld	a,h
	push	af
	ld	a,c
	call	OPAPP
	pop	af
	ld	c,a
	jr	MTAP
MTD:	ld	a,h
	or	a
	jr	nz,MTPF
	ld	a,l
	cp	80h
	jr	nc,MTPF
	ld	c,a
	ld	a,(NEGF)
	or	a
	jr	z,MTAP
	ld	a,c
	neg
	ld	c,a
	xor	a
	ld	(NEGF),a
MTAP:	ld	a,c
	call	OPAPP
	pop	hl
	inc	hl
	jp	MT1
MTPF:	pop	hl
	scf
	ret

OPAPP:	push	hl
	push	de
	ld	hl,OPB
	ld	a,(OPN)
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,c		; 呼び出し側は値を C か A に入れている
	ld	(hl),a
	ld	hl,OPN
	inc	(hl)
	pop	de
	pop	hl
	ret

; 一致した命令を (AADDR) へ出力する
EMIT:	ld	a,(NPFX)
	cp	3
	jr	nz,EM1
	ld	a,(OPB)		; DD CB d op
	ld	(TB+2),a
	xor	a
	ld	(OPN),a
EM1:	ld	a,(NPFX)
	inc	a
	ld	b,a
	ld	hl,TB
	ld	de,(AADDR)
EM2:	ld	a,(hl)
	ld	(de),a
	inc	hl
	inc	de
	djnz	EM2
	ld	a,(OPN)
	or	a
	jr	z,EM4
	ld	b,a
	ld	hl,OPB
EM3:	ld	a,(hl)
	ld	(de),a
	inc	hl
	inc	de
	djnz	EM3
EM4:	ld	(AADDR),de
	or	a
	ret

; ---------------------------------------------------------------- 逆アセンブラ
; 入力: ISRC=命令バイトの場所 IPC=その番地(相対ジャンプ表示用) TMPLF=1 ならテンプレート(数値は n w d e)
; 出力: TBUF=0終端のテキスト LEN=命令の長さ
DIS:	xor	a
	ld	(LEN),a
	ld	(PFX),a
	ld	(DCBF),a
	ld	hl,TBUF
	ld	(TP),hl
	call	DISX
	ld	hl,(TP)
	ld	(hl),0
	ret

DISX:	call	FETCH
	cp	0DDh
	jr	z,DX_P
	cp	0FDh
	jr	z,DX_P
	cp	0CBh
	jp	z,DX_CB
	cp	0EDh
	jp	z,DX_ED
	jp	DECODE
DX_P:	ld	(PFX),a
	call	FETCH
	cp	0CBh
	jr	z,DX_PCB
	cp	0EDh
	jp	z,DX_ED
	jp	DECODE
DX_PCB:	call	FETCH		; DD CB d op
	ld	(DVAL),a
	ld	a,1
	ld	(DCBF),a
	call	FETCH
	jp	DCB
DX_CB:	call	FETCH
	jp	DCB
DX_ED:	call	FETCH
	jp	DED

FETCH:	push	hl
	ld	hl,(ISRC)
	ld	a,(hl)
	inc	hl
	ld	(ISRC),hl
	ld	hl,LEN
	inc	(hl)
	pop	hl
	ret

TC:	push	hl
	ld	hl,(TP)
	ld	(hl),a
	inc	hl
	ld	(TP),hl
	pop	hl
	ret

TS:	ld	a,(hl)		; HL=0終端文字列 -> 終了後 HL は終端の次
	inc	hl
	or	a
	ret	z
	call	TC
	jr	TS

TLIT:	pop	hl		; 呼び出し直後に置いた文字列を出力して続きへ
	call	TS
	jp	(hl)

TSEL:	or	a		; HL=文字列表 A=番号
	jr	z,TS
TSL1:	push	af
TSL2:	ld	a,(hl)
	inc	hl
	or	a
	jr	nz,TSL2
	pop	af
	dec	a
	jr	nz,TSL1
	jr	TS

THEX2:	push	af
	rrca
	rrca
	rrca
	rrca
	call	THEX1
	pop	af
THEX1:	and	15
	add	a,'0'
	cp	'9'+1
	jr	c,THX
	add	a,7
THX:	jp	TC

TN8:	push	af
	and	0F0h
	cp	0A0h
	jr	c,TN8A
	ld	a,'0'
	call	TC
TN8A:	pop	af
	call	THEX2
	ld	a,'H'
	jp	TC

TN16:	ld	a,h
	and	0F0h
	cp	0A0h
	jr	c,TN16A
	ld	a,'0'
	call	TC
TN16A:	ld	a,h
	call	THEX2
	ld	a,l
	call	THEX2
	ld	a,'H'
	jp	TC

PN8:	ld	a,(TMPLF)
	or	a
	jr	z,PN8A
	call	FETCH
	ld	a,'n'
	jp	TC
PN8A:	call	FETCH
	jp	TN8

PNW:	ld	a,(TMPLF)
	or	a
	jr	z,PNWA
	call	FETCH
	call	FETCH
	ld	a,'w'
	jp	TC
PNWA:	call	FETCH
	ld	l,a
	call	FETCH
	ld	h,a
	jp	TN16

PE:	call	FETCH		; 相対ジャンプの目標(絶対番地)
	ld	c,a
	ld	a,(TMPLF)
	or	a
	jr	z,PEA
	ld	a,'e'
	jp	TC
PEA:	ld	hl,(IPC)
	ld	a,(LEN)
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,c
	ld	e,a
	add	a,a
	sbc	a,a
	ld	d,a
	add	hl,de
	jp	TN16

PIXR:	ld	a,(PFX)
	cp	0DDh
	jr	nz,PXRY
	call	TLIT
	defm	"IX",0
	ret
PXRY:	call	TLIT
	defm	"IY",0
	ret

PIXD:	ld	a,'('
	call	TC
	call	PIXR
	ld	a,(TMPLF)
	or	a
	jr	z,PIXD1
	ld	a,'+'
	call	TC
	ld	a,'d'
	call	TC
	ld	a,(DCBF)
	or	a
	jr	nz,PIXD2
	call	FETCH
	jr	PIXD2
PIXD1:	ld	a,(DCBF)
	or	a
	ld	a,(DVAL)
	jr	nz,PIXD3
	call	FETCH
PIXD3:	ld	c,'+'
	bit	7,a
	jr	z,PIXD4
	neg
	ld	c,'-'
PIXD4:	push	af
	ld	a,c
	call	TC
	pop	af
	call	TN8
PIXD2:	ld	a,')'
	jp	TC

PR8:	cp	6		; A=0-7
	jr	nz,PR8A
	ld	a,(PFX)
	or	a
	jp	nz,PIXD
	ld	a,6
PR8A:	ld	hl,T_R8
	jp	TSEL

PRP:	cp	2		; HL/IX/IY を含む rp
	jr	nz,PRP1
	ld	a,(PFX)
	or	a
	jr	z,PRP0
	jp	PIXR
PRP0:	ld	a,2
PRP1:	ld	hl,T_RP
	jp	TSEL

PRP2:	cp	2
	jr	nz,PRP21
	ld	a,(PFX)
	or	a
	jr	z,PRP20
	jp	PIXR
PRP20:	ld	a,2
PRP21:	ld	hl,T_RP2
	jp	TSEL

PCC:	ld	hl,T_CC
	jp	TSEL

SETXYZ:	ld	(OPC),a
	ld	b,a
	and	7
	ld	(OPZ),a
	ld	a,b
	rrca
	rrca
	rrca
	and	7
	ld	(OPY),a
	ld	a,b
	rlca
	rlca
	and	3
	ld	(OPX),a
	ret

DECODE:	call	SETXYZ
	or	a
	jp	z,X0
	dec	a
	jp	z,X1
	dec	a
	jp	z,X2
	jp	X3

; ---- x=0
X0:	ld	a,(OPZ)
	or	a
	jr	z,X0Z0
	dec	a
	jp	z,X0Z1
	dec	a
	jp	z,X0Z2
	dec	a
	jp	z,X0Z3
	dec	a
	jp	z,X0Z4
	dec	a
	jp	z,X0Z5
	dec	a
	jp	z,X0Z6
	ld	a,(OPY)
	ld	hl,T_ACC
	jp	TSEL
X0Z0:	ld	a,(OPY)
	or	a
	jr	nz,Z0A
	call	TLIT
	defm	"NOP",0
	ret
Z0A:	dec	a
	jr	nz,Z0B
	call	TLIT
	defm	"EX AF,AF'",0
	ret
Z0B:	dec	a
	jr	nz,Z0C
	call	TLIT
	defm	"DJNZ ",0
	jp	PE
Z0C:	dec	a
	jr	nz,Z0D
	call	TLIT
	defm	"JR ",0
	jp	PE
Z0D:	call	TLIT
	defm	"JR ",0
	ld	a,(OPY)
	sub	4
	call	PCC
	ld	a,','
	call	TC
	jp	PE
X0Z1:	ld	a,(OPY)
	bit	0,a
	jr	nz,Z1B
	call	TLIT
	defm	"LD ",0
	ld	a,(OPY)
	rrca
	and	3
	call	PRP
	ld	a,','
	call	TC
	jp	PNW
Z1B:	call	TLIT
	defm	"ADD ",0
	ld	a,2
	call	PRP
	ld	a,','
	call	TC
	ld	a,(OPY)
	rrca
	and	3
	jp	PRP
X0Z2:	ld	a,(OPY)
	cp	4
	jr	nc,Z2B
	ld	hl,T_LDBD
	jp	TSEL
Z2B:	call	TLIT
	defm	"LD ",0
	ld	a,(OPY)
	cp	6
	jr	nc,Z2C
	cp	5
	jr	z,Z2D
	ld	a,'('
	call	TC
	call	PNW
	call	TLIT
	defm	"),",0
	ld	a,2
	jp	PRP
Z2D:	ld	a,2
	call	PRP
	call	TLIT
	defm	",(",0
	call	PNW
	ld	a,')'
	jp	TC
Z2C:	cp	6
	jr	z,Z2E
	call	TLIT
	defm	"A,(",0
	call	PNW
	ld	a,')'
	jp	TC
Z2E:	ld	a,'('
	call	TC
	call	PNW
	call	TLIT
	defm	"),A",0
	ret
X0Z3:	ld	a,(OPY)
	bit	0,a
	jr	nz,Z3B
	call	TLIT
	defm	"INC ",0
	jr	Z3C
Z3B:	call	TLIT
	defm	"DEC ",0
Z3C:	ld	a,(OPY)
	rrca
	and	3
	jp	PRP
X0Z4:	call	TLIT
	defm	"INC ",0
	ld	a,(OPY)
	jp	PR8
X0Z5:	call	TLIT
	defm	"DEC ",0
	ld	a,(OPY)
	jp	PR8
X0Z6:	call	TLIT
	defm	"LD ",0
	ld	a,(OPY)
	call	PR8
	ld	a,','
	call	TC
	jp	PN8

; ---- x=1,2
X1:	ld	a,(OPC)
	cp	76h
	jr	nz,X1A
	call	TLIT
	defm	"HALT",0
	ret
X1A:	call	TLIT
	defm	"LD ",0
	ld	a,(OPY)
	call	PR8
	ld	a,','
	call	TC
	ld	a,(OPZ)
	jp	PR8
X2:	ld	a,(OPY)
	ld	hl,T_ALU
	call	TSEL
	ld	a,(OPZ)
	jp	PR8

; ---- x=3
X3:	ld	a,(OPZ)
	or	a
	jr	z,X3Z0
	dec	a
	jr	z,X3Z1
	dec	a
	jr	z,X3Z2
	dec	a
	jp	z,X3Z3
	dec	a
	jp	z,X3Z4
	dec	a
	jp	z,X3Z5
	dec	a
	jp	z,X3Z6
	call	TLIT
	defm	"RST ",0
	ld	a,(OPY)
	add	a,a
	add	a,a
	add	a,a
	jp	THEX2
X3Z0:	call	TLIT
	defm	"RET ",0
	ld	a,(OPY)
	jp	PCC
X3Z1:	ld	a,(OPY)
	bit	0,a
	jr	nz,Z1O
	call	TLIT
	defm	"POP ",0
	ld	a,(OPY)
	rrca
	and	3
	jp	PRP2
Z1O:	rrca
	and	3
	cp	2
	jr	c,Z1P
	jr	z,Z1Q
	call	TLIT
	defm	"LD SP,",0
	ld	a,2
	jp	PRP
Z1Q:	call	TLIT
	defm	"JP (",0
	ld	a,2
	call	PRP
	ld	a,')'
	jp	TC
Z1P:	ld	hl,T_RE
	jp	TSEL
X3Z2:	call	TLIT
	defm	"JP ",0
	ld	a,(OPY)
	call	PCC
	ld	a,','
	call	TC
	jp	PNW
X3Z3:	ld	a,(OPY)
	or	a
	jr	nz,Y3A
	call	TLIT
	defm	"JP ",0
	jp	PNW
Y3A:	cp	2
	jr	nz,Y3B
	call	TLIT
	defm	"OUT (",0
	call	PN8
	call	TLIT
	defm	"),A",0
	ret
Y3B:	cp	3
	jr	nz,Y3C
	call	TLIT
	defm	"IN A,(",0
	call	PN8
	ld	a,')'
	jp	TC
Y3C:	cp	4
	jr	nz,Y3D
	call	TLIT
	defm	"EX (SP),",0
	ld	a,2
	jp	PRP
Y3D:	cp	5
	jr	nz,Y3E
	call	TLIT
	defm	"EX DE,HL",0
	ret
Y3E:	cp	6
	jr	nz,Y3F
	call	TLIT
	defm	"DI",0
	ret
Y3F:	call	TLIT
	defm	"EI",0
	ret
X3Z4:	call	TLIT
	defm	"CALL ",0
	ld	a,(OPY)
	call	PCC
	ld	a,','
	call	TC
	jp	PNW
X3Z5:	ld	a,(OPY)
	bit	0,a
	jr	nz,Z5B
	call	TLIT
	defm	"PUSH ",0
	ld	a,(OPY)
	rrca
	and	3
	jp	PRP2
Z5B:	call	TLIT
	defm	"CALL ",0
	jp	PNW
X3Z6:	ld	a,(OPY)
	ld	hl,T_ALU
	call	TSEL
	jp	PN8

; ---- CB
DCB:	call	SETXYZ
	or	a
	jr	nz,CB1
	ld	a,(OPY)
	ld	hl,T_ROT
	call	TSEL
	ld	a,' '
	call	TC
	ld	a,(OPZ)
	jp	PR8
CB1:	dec	a
	ld	hl,T_BIT
	call	TSEL
	ld	a,(OPY)
	add	a,'0'
	call	TC
	ld	a,','
	call	TC
	ld	a,(OPZ)
	jp	PR8

; ---- ED
DED:	call	SETXYZ
	cp	1
	jr	z,ED1
	cp	2
	jr	z,ED2
EDBAD:	call	TLIT
	defm	"??",0
	ret
ED2:	ld	a,(OPZ)
	cp	4
	jr	nc,EDBAD
	ld	a,(OPY)
	cp	4
	jr	c,EDBAD
	ld	a,(OPZ)
	add	a,a
	add	a,a
	ld	b,a
	ld	a,(OPY)
	sub	4
	add	a,b
	ld	hl,T_BLK
	jp	TSEL
ED1:	ld	a,(OPZ)
	or	a
	jr	nz,E1
	call	TLIT
	defm	"IN ",0
	ld	a,(OPY)
	cp	6
	jr	nz,E0A
	ld	a,'F'
	call	TC
	jr	E0B
E0A:	call	PR8
E0B:	call	TLIT
	defm	",(C)",0
	ret
E1:	dec	a
	jr	nz,E2
	call	TLIT
	defm	"OUT (C),",0
	ld	a,(OPY)
	cp	6
	jr	nz,E1A
	ld	a,'0'
	jp	TC
E1A:	jp	PR8
E2:	dec	a
	jr	nz,E3
	ld	a,(OPY)
	bit	0,a
	jr	nz,E2A
	call	TLIT
	defm	"SBC HL,",0
	jr	E2B
E2A:	call	TLIT
	defm	"ADC HL,",0
E2B:	ld	a,(OPY)
	rrca
	and	3
	ld	hl,T_RP
	jp	TSEL
E3:	dec	a
	jr	nz,E4
	call	TLIT
	defm	"LD ",0
	ld	a,(OPY)
	bit	0,a
	jr	nz,E3A
	ld	a,'('
	call	TC
	call	PNW
	call	TLIT
	defm	"),",0
	jr	E3B
E3A:	ld	a,(OPY)
	rrca
	and	3
	ld	hl,T_RP
	call	TSEL
	call	TLIT
	defm	",(",0
	call	PNW
	ld	a,')'
	jp	TC
E3B:	ld	a,(OPY)
	rrca
	and	3
	ld	hl,T_RP
	jp	TSEL
E4:	dec	a
	jr	nz,E5
	call	TLIT
	defm	"NEG",0
	ret
E5:	dec	a
	jr	nz,E6
	ld	a,(OPY)
	cp	1
	jr	z,E5A
	call	TLIT
	defm	"RETN",0
	ret
E5A:	call	TLIT
	defm	"RETI",0
	ret
E6:	dec	a
	jr	nz,E7
	call	TLIT
	defm	"IM ",0
	ld	a,(OPY)
	and	3
	ld	hl,T_IM
	jp	TSEL
E7:	ld	a,(OPY)
	ld	hl,T_ED7
	jp	TSEL

; ---------------------------------------------------------------- 文字列表
T_R8:	defm	"B",0,"C",0,"D",0,"E",0,"H",0,"L",0,"(HL)",0,"A",0
T_RP:	defm	"BC",0,"DE",0,"HL",0,"SP",0
T_RP2:	defm	"BC",0,"DE",0,"HL",0,"AF",0
T_CC:	defm	"NZ",0,"Z",0,"NC",0,"C",0,"PO",0,"PE",0,"P",0,"M",0
T_ALU:	defm	"ADD A,",0,"ADC A,",0,"SUB ",0,"SBC A,",0,"AND ",0,"XOR ",0,"OR ",0,"CP ",0
T_ROT:	defm	"RLC",0,"RRC",0,"RL",0,"RR",0,"SLA",0,"SRA",0,"SLL",0,"SRL",0
T_BIT:	defm	"BIT ",0,"RES ",0,"SET ",0
T_ACC:	defm	"RLCA",0,"RRCA",0,"RLA",0,"RRA",0,"DAA",0,"CPL",0,"SCF",0,"CCF",0
T_LDBD:	defm	"LD (BC),A",0,"LD A,(BC)",0,"LD (DE),A",0,"LD A,(DE)",0
T_RE:	defm	"RET",0,"EXX",0
T_IM:	defm	"0",0,"0",0,"1",0,"2",0
T_ED7:	defm	"LD I,A",0,"LD R,A",0,"LD A,I",0,"LD A,R",0,"RRD",0,"RLD",0,"NOP",0,"NOP",0
T_BLK:	defm	"LDI",0,"LDD",0,"LDIR",0,"LDDR",0
	defm	"CPI",0,"CPD",0,"CPIR",0,"CPDR",0
	defm	"INI",0,"IND",0,"INIR",0,"INDR",0
	defm	"OUTI",0,"OUTD",0,"OTIR",0,"OTDR",0

MBANNER:
	defm	"MON for MZ-2500 LSX  (H=help)",13,10,0

MHELP:	defm	"D [s [e]]  dump      M a [b..]  modify (no bytes: ask, . ends)",13,10
	defm	"F s e v   fill       G a        call (RET returns)",13,10
	defm	"L [a [n]]  disasm     A a        assemble (. ends)",13,10
	defm	"I p  in   O p v  out  P  I/O port list   Q  quit",13,10
	defm	"numbers are hex; asm numbers start with 0-9 (0FFH)",13,10,0

PORTS:	defm	"B4 W   MMU bank select (bit0-2)",13,10
	defm	"B5 R/W MMU page of the bank (bit0-5); B4 steps +1",13,10
	defm	"C6 W   interrupt enable (bit3=VBLANK; LSX needs 08h)",13,10
	defm	"D8 R/W FDC command/status (inverted bus)",13,10
	defm	"D9 R/W FDC track      DA R/W FDC sector",13,10
	defm	"DB R/W FDC data       DC W   FDD select/motor",13,10
	defm	"DD W   FDD head (bit0) DE W  FDD density (0=double)",13,10
	defm	"E1 R   PB: bit0=/VBLANK (0=blanking)",13,10
	defm	"E8 R/W PIO A: key strobe (bit4=1+column), bit5=CH80",13,10
	defm	"EA R   key data (0=pressed)",13,10
	defm	"AC W   EMM address (b3-0 = A19-16)  AD R/W EMM addr/data",13,10
	defm	"F4 W   CRTC register no.   F5 W  CRTC data",13,10,0

; ---------------------------------------------------------------- 変数
LBUF:	defb	60,0
	defs	64,0
NBUF:	defs	64,0
TBUF:	defs	40,0
TB:	defs	6,0
OPB:	defs	6,0
DADDR:	defw	0100h
DEND:	defw	0
MADDR:	defw	0
LADDR:	defw	0100h
AADDR:	defw	0
ASTART:	defw	0
ISRC:	defw	0
IPC:	defw	0
TP:	defw	0
LCNT:	defb	0
MFLAG:	defb	0
TMPLF:	defb	0
PFX:	defb	0
DCBF:	defb	0
DVAL:	defb	0
LEN:	defb	0
OPC:	defb	0
OPX:	defb	0
OPY:	defb	0
OPZ:	defb	0
OPN:	defb	0
NEGF:	defb	0
TRI:	defb	0
OPCD:	defb	0
NPFX:	defb	0
PHC:	defb	0
	defs	64,0
STK:
