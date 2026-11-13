;	LSX-Dodgers MZ-2500  漢字表示(Shift_JIS)。ORG KJBASE で別にアセンブルし、起動時に INIT がカーネル時のバンク5の空きへ写す。
;	本体(M25IO.ASM)からは KJLEAD / KJTRAIL / KJESC(先頭のJP表)だけが呼ばれる。コンソール出力(PRINT)の中でだけ動く。
;
;	使い方: ESC k 1 で漢字モードON、ESC k 0 でOFF(起動時はOFF。KANJI.COM がこれを出す)。
;	ONの間、Shift_JIS の1バイト目(81H-9FH, E0H-FCH)が来たら次のバイトと合わせて全角1文字(横2セル)にする。
;	A1H-DFH(半角カナ)や他のコードは今までどおり。無効な2バイト目(40H未満, 7FH, FDH以上)なら、1バイト目は捨てて
;	2バイト目を普通の文字として出す。
;
;	漢字ROMのセル指定(資料 第7-2表/第7-4表): 1セル=Text1(A10-A5=b7-b2, b1=0左/1右)+Text2(b7=K, b6=L(水準), b5-b0=A16-A11)。
;	JIS区点 → グリフ番号 idx(32バイト単位) = 区21H-28H: (区-21H)*60H + 点-20H
;	                                        区30H-74H: 400H + (区-30H)*60H + 点-20H  (区50H以降は L=1 に当たる)
;	Text1(左)=(idx&3FH)*4, Text1(右)=左+2, Text2=80H|(idx>>6)  (idx は13ビット、bit12 が Text2 の b6 に入る)
;
;	制限: カーソルの移動/BS/削除は1セル単位なので、全角の途中で消すと半分の字が残る。行の途中に挿入するモード(INSERT)は未対応。
;	      行末に全角が来ると、1セル空けて次の行へ出す。

;	入力 E=文字。Z=漢字の1バイト目として取り込んだ(PRINT は何も出さずに戻る) / NZ=普通の文字
KJE0:
	JP	KJL0			;KJBASE+0
KJE1:
	JP	KJTRL			;KJBASE+3
KJE2:
	JP	KJESC2			;KJBASE+6
	JP	KJCOL			;KJBASE+9 (KJCOLE)

KJL0:
	LD	A,(KJEN)
	OR	A
	JR	Z,KJNO
	LD	A,E
	SUB	081H
	CP	01FH
	JR	C,KJL1			;81H-9FH
	SUB	05FH
	CP	01DH
	JR	NC,KJNO			;E0H-FCH 以外
KJL1:
	LD	A,E
	LD	(ESCYP+1),A		;1バイト目の置き場(ESC Y の行指定の作業バイトを借りる。ESC Y のたびに書き直される)
	XOR	A
	LD	(KJST),A
	LD	A,4
	LD	(ESCFLG),A		;次の1文字は ESC2 から KJTRAIL へ
	XOR	A			;Z
	RET
KJNO:
	OR	1			;NZ
	RET

;	ESC1Z から(E=ESC の次の文字)。k なら次の1文字(0/1)を待つ
KJESC2:
	LD	A,E
	LD	B,4
	CP	'k'
	JR	Z,KJE2A
	INC	B
	CP	'b'			;ESC b n : 文字色 n (ANSI順 0黒 1赤 2緑 3黄 4青 5紫 6水色 7白)
	JR	Z,KJE2A
	LD	HL,_COLORF
	CP	'p'			;ESC p : 反転 ON (文字が透明、背景が文字色)
	JR	NZ,KJE2P
	SET	6,(HL)
	RET
KJE2P:
	CP	'q'			;ESC q : 反転 OFF
	JR	NZ,KJE2Q
	RES	6,(HL)
	RET
KJE2Q:
	CP	'['			;ESC [ : CSI。KJST=6 で引数列を CSI(M25IO)へ
	RET	NZ
	LD	B,6
KJE2A:
	LD	A,4
	LD	(ESCFLG),A
	LD	A,B
	LD	(KJST),A		;4=ESC k の引数待ち / 5=ESC b の引数待ち
	RET

;	ESC2 から。スタックは [PRINTE5, HL, BC](ESC が積んだもの)。E=2バイト目
KJTRL:
	LD	A,(KJST)
	OR	A
	JR	Z,KJT1
	CP	6
	JR	NZ,KJT0
	CALL	CSI			;ESC [ の引数列。A=4,NZ:続く / A=0,Z:終わり(KJST は6のまま続く間だけ残す)
	LD	(ESCFLG),A
	RET	NZ
	LD	(KJST),A
	RET
KJT0:
	LD	C,A
	XOR	A
	LD	(KJST),A
	LD	A,E
	SUB	'0'
	LD	B,A
	LD	A,C
	CP	5
	JR	Z,KJCOL
	LD	A,B
	AND	1
	LD	(KJEN),A		;ESC k 0 / ESC k 1
	RET
KJCOL:					;ANSI順(b0=R b1=G b2=B) → MZ-2500(b0=B b1=R b2=G)
	LD	A,B
	AND	1
	ADD	A,A
	LD	C,A
	LD	A,B
	AND	2
	ADD	A,A
	OR	C
	LD	C,A
	LD	A,B
	RRCA
	RRCA
	AND	1
	OR	C
	LD	C,A
	LD	A,(_COLORF)
	AND	0F8H
	OR	C
	LD	(_COLORF),A
	RET
KJT1:
	LD	A,E
	CP	040H
	JP	C,KJBAD
	CP	07FH
	JP	Z,KJBAD
	CP	0FDH
	JP	NC,KJBAD
;	Shift_JIS(1バイト目=(ESCYP+1), 2バイト目=E) → JIS (D=区, E=点)
	LD	A,(ESCYP+1)
	SUB	081H
	CP	05FH
	JR	C,KJC1
	SUB	040H			;E0H以降
KJC1:
	ADD	A,A
	ADD	A,021H
	LD	D,A
	LD	A,E
	CP	09FH
	JR	NC,KJC2
	CP	080H
	CCF				;CF=(2バイト目 >= 80H)
	LD	A,E
	SBC	A,01FH			;40H-7EH: -1FH, 80H-9EH: -20H
	JR	KJC3
KJC2:
	INC	D			;区が1つ上がる
	LD	A,E
	SUB	07EH			;9FH-FCH → 点 21H-7EH
KJC3:
	LD	E,A
;	区の範囲: 21H-28H / 30H-74H。それ以外(記号の空き区、BASIC用の外字区、範囲外)は空白2セル
	LD	A,D
	LD	BC,0
	CP	029H
	JR	C,KJC4			;21H-28H
	CP	030H
	JR	C,KJBLK
	CP	075H
	JR	NC,KJBLK
	LD	BC,0400H
	SUB	030H-021H		;下の SUB 21H と合わせて 区-30H
KJC4:
	SUB	021H			;A=行(0から)
	LD	D,A
	ADD	A,A
	ADD	A,D			;行*3 (最大 68*3=204)
	LD	L,A
	LD	H,0
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL			;行*96
	ADD	HL,BC			;+基準(400H か 0)
	LD	A,E
	SUB	020H
	LD	E,A
	LD	D,0
	ADD	HL,DE			;HL=idx
	LD	A,L
	AND	03FH
	ADD	A,A
	ADD	A,A
	LD	(KJD1),A		;Text1(左)
	LD	A,H
	ADD	A,A
	ADD	A,A
	LD	H,A
	LD	A,L
	RLCA
	RLCA
	AND	3
	OR	H
	OR	080H
	LD	(KJD2),A		;Text2
	JR	KJPUT
KJBLK:
	LD	A,080H
	LD	(KJD1),A
	LD	A,08CH
	LD	(KJD2),A
	LD	A,080H			;空白は右セルも 80H(Text1 は +2 しない)
	LD	(KJSP),A
	JR	KJPUT1
KJPUT:
	XOR	A
	LD	(KJSP),A
KJPUT1:
;	行末(最後の桁)なら1セル空けて次の行から
	CALL	_POS
	LD	A,(WIDTHV)
	SUB	L
	CP	1
	JR	NZ,KJP2
	LD	A,080H
	LD	B,08CH
	CALL	KJCELL
KJP2:
	LD	A,(KJD2)
	LD	B,A
	LD	A,(KJD1)
	CALL	KJCELL			;左セル
	LD	A,(KJD2)
	LD	B,A
	LD	A,(KJSP)
	OR	A
	LD	A,(KJD1)
	JR	Z,KJP3
	LD	A,080H			;空白は右セルも 80H
	JR	KJP4
KJP3:
	OR	2			;右半分
KJP4:
	CALL	KJCELL			;右セル
	RET				;→ PRINTE5
KJBAD:
	POP	HL			;PRINTE5
	POP	HL
	POP	BC
	JP	PRINT			;1バイト目は捨てて、E を普通の文字として出し直す

;	A=Text1, B=Text2 を現在位置のセルに書いてカーソルを1つ進める(属性は現在の色)
KJCELL:
	LD	D,A
	LD	A,(_COLORF)
	LD	C,A
	LD	HL,(_TXADR)
	LD	A,H
	ADD	A,0E0H
	LD	H,A
	DI
	PUSH	HL
	CALL	XLAT
	CALL	VRAM_ON
	LD	(HL),D			;Text1
	SET	3,H
	LD	(HL),C			;属性
	RES	3,H
	SET	4,H
	LD	(HL),B			;Text2
	CALL	VRAM_OFF
	POP	HL
	EI
	JP	CTRL1C			;カーソルを進める(行末なら次の行/スクロール)

KJEN:	DB	0			;1=漢字モード
KJST:	DB	0			;0=漢字の1バイト目待ち / 非0=ESC k の引数待ち
KJD1:	DB	0
KJD2:	DB	0
KJSP:	DB	0
