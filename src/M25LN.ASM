;	LSX-Dodgers MZ-2500 長いファイル名(Human68k / TwentyOne 方式。docs/longname.md)
;	名前の9文字目以降(name2。ディレクトリエントリ +0Ch の10バイト)を、検索・作成・名前変更で扱う。
;	FCB は 8+3 の11バイトしか持てないので、ファイル名の解析(BDOS 29h)が拾った name2 を、FCB の住所つきで小さな表に覚えておく。
;	  - FN2   : 直前の解析(FILED)で拾った name2(10バイト。余りは00h)。パス解析の作業FCB(FDRV)はこれを使う
;	  - LNTAB : 4枠 x (FCBの住所2 + 名前11 + name2 10)。FCB の名前が今も同じ枠だけ有効(プログラムが名前を書き換えたら無効)
;	検索の一致(LNMAT): パターンの name1 に ? があれば name2 は比べない(一覧)。それ以外は、パターンの name2(無ければ空)と
;	ディレクトリエントリの name2(有効でなければ空)を、大文字小文字を区別せず・全角の2バイト目に気をつけて比べる。
;	名前の後ろに * があると name2 は全部 ? になる(LONGNAME*.TXT など)。
;	呼び出し元(パッチ): build.py の patch_src(LDFILE / LDOS)

LNZERO:	DB	0,0,0,0,0,0,0,0,0,0

;	FILED の先頭: FN2 を空に。C は壊さない
LNCLR:
	PUSH	HL
	LD	HL,FN2
	LD	B,10
	XOR	A
LNCL1:	LD	(HL),A
	INC	HL
	DJNZ	LNCL1
	POP	HL
	RET

;	FILE3 の代わり: name1 の8文字の後ろ〜'.'までを FN2 に拾う。DE=文字列 C=全角状態(CCHKF が更新)。
;	Z で戻れば終端(元の FILE3 と同じく呼び出し側が RET Z)。NZ なら '.' まで読んだ(FILE4 へ続く)
LNCAP:
	PUSH	HL
	PUSH	BC
	CALL	LNCAQ
	POP	HL			;古いBCは捨てる(Cは全角状態なので新しい値を残す)
	LD	B,H
	POP	HL
	RET

LNCAQ:
	LD	HL,FN2
	LD	B,10
LNCP1:	CALL	CCHKF
	RET	Z
	CP	'.'
	JR	Z,LNCPD
	INC	B
	DEC	B
	JR	Z,LNCP1			;10文字を超えた分は捨てる
	CP	'*'
	JR	NZ,LNCP2
	LD	A,'?'			;* 以降は全部 ?
LNCPF:	LD	(HL),A
	INC	HL
	DJNZ	LNCPF
	JR	LNCP1
LNCP2:	LD	(HL),A
	INC	HL
	DEC	B
	JR	LNCP1
LNCPD:	OR	A			;A='.' なので NZ
	RET

;	_SYS29 の後ろ(S29X1 の LDIR のあと)から。DE=FCB+16。FN2 を FCB の住所つきで表に覚える
LNREC:
	PUSH	HL
	PUSH	DE
	PUSH	BC
	PUSH	IX
	LD	HL,-16
	ADD	HL,DE
	EX	DE,HL			;DE=FCB
	LD	IX,LNTAB
	LD	B,LNSLOTS
LNR1:	LD	A,(IX+0)
	CP	E
	JR	NZ,LNR2
	LD	A,(IX+1)
	CP	D
	JR	Z,LNR5			;同じ住所の枠
LNR2:	PUSH	BC
	LD	BC,LNSZ
	ADD	IX,BC
	POP	BC
	DJNZ	LNR1
	LD	A,(FN2)			;枠が無い: name2 が空なら何もしない
	OR	A
	JR	Z,LNRX
	LD	A,(LNNXT)		;次の枠(順番に上書き)
	LD	C,A
	ADD	A,LNSZ
	CP	LNSZ*LNSLOTS
	JR	C,LNR3
	XOR	A
LNR3:	LD	(LNNXT),A
	LD	B,0
	LD	IX,LNTAB
	ADD	IX,BC
LNR5:	LD	(IX+0),E
	LD	(IX+1),D
	EX	DE,HL
	INC	HL			;HL=FCB+1
	PUSH	IX
	POP	DE
	INC	DE
	INC	DE			;DE=枠+2
	LD	BC,11
	LDIR
	LD	HL,FN2
	LD	BC,10
	LDIR				;name2(空なら先頭00h = 無効)
LNRX:	POP	IX
	POP	BC
	POP	DE
	POP	HL
	RET

;	IY=FCB の name2。NZ: HL=name2(10バイト) / Z: なし。DE,BC,IX は保つ
LNGET:
	PUSH	DE
	PUSH	BC
	PUSH	IX
	PUSH	IY
	POP	DE			;DE=FCB
	LD	HL,FDRV
	OR	A
	SBC	HL,DE
	LD	HL,FN2
	JR	Z,LNGX			;パス解析の作業FCBは直前の解析結果
	LD	IX,LNTAB
	LD	B,LNSLOTS
LNG1:	LD	A,(IX+0)
	CP	E
	JR	NZ,LNG4
	LD	A,(IX+1)
	CP	D
	JR	NZ,LNG4
	PUSH	IX
	POP	HL
	INC	HL
	INC	HL			;HL=枠の名前
	PUSH	DE
	INC	DE			;DE=FCB+1
	LD	C,11
LNG2:	LD	A,(DE)
	XOR	(HL)
	AND	0DFH			;大文字小文字だけの違いは同じ名前とみなす(FCB の名前は途中で大文字化されることがある)
	JR	NZ,LNG3
	INC	DE
	INC	HL
	DEC	C
	JR	NZ,LNG2
	POP	DE			;HL=枠の name2
	JR	LNGX
LNG3:	POP	DE
LNG4:	PUSH	BC
	LD	BC,LNSZ
	ADD	IX,BC
	POP	BC
	DJNZ	LNG1
	LD	HL,0
LNGX:	LD	A,H
	OR	L
	JR	Z,LNGE
	LD	A,(HL)
	OR	A			;先頭が00h なら name2 なし(Z)
LNGE:	POP	IX
	POP	BC
	POP	DE
	RET

;	HL=名前(8バイト) → C の bit0 = 最後が全角の1バイト目(次が2バイト目)か。A,B,C を壊す
LNST:
	LD	B,8
	LD	C,0
LNS1:	LD	A,(HL)
	CALL	FKANX
	INC	HL
	DJNZ	LNS1
	RET

;	HL=ディレクトリエントリ: NZ=有効な name2 がある。HL,DE,BC は保つ
;	有効 = name1 の8バイト目が空白でない / LA バイナリの印(+10h=A0h)でない / 先頭が00hでない /
;	00hまでが20h以上(7Fh,FFhでない) / 00h のあとは最後まで00h (Windows が +0Ch 以降に入れる大文字小文字フラグや時刻を取り違えない)
LN2V:
	PUSH	HL
	PUSH	BC
	PUSH	DE
	LD	DE,7
	ADD	HL,DE
	LD	A,(HL)
	CP	' '
	JR	Z,LV0
	LD	DE,9
	ADD	HL,DE
	LD	A,(HL)
	CP	0A0H
	JR	Z,LV0
	DEC	HL
	DEC	HL
	DEC	HL
	DEC	HL
	LD	B,10
	LD	A,(HL)
	OR	A
	JR	Z,LV0
LV1:	LD	A,(HL)
	OR	A
	JR	Z,LV2
	CP	020H
	JR	C,LV0
	CP	07FH
	JR	Z,LV0
	CP	0FFH
	JR	Z,LV0
	INC	HL
	DJNZ	LV1
	JR	LV9
LV2:	DEC	B
	JR	Z,LV9
	INC	HL
	LD	A,(HL)
	OR	A
	JR	NZ,LV0
	JR	LV2
LV9:	LD	A,1
	OR	A			;NZ
	JR	LVX
LV0:	XOR	A			;Z
LVX:	POP	DE
	POP	BC
	POP	HL
	RET

;	FILESE / SOPENX から(CPFILE が一致したあと)。HL=ディレクトリエントリ+0Bh IY=FCB。Z=名前(name2)が一致。HL,DE,BC は保つ
LNMAT:
	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	DE,-11
	ADD	HL,DE			;CPFILE のあとなので HL=エントリ+0Bh
	LD	(LNTMP),HL
	PUSH	IY
	POP	DE
	INC	DE
	LD	B,8
LNM1:	LD	A,(DE)
	CP	'?'
	JR	Z,LNM9			;name1 に ? があれば比べない(Z のまま)
	INC	DE
	DJNZ	LNM1
	CALL	LNGET
	JR	NZ,LNM2
	LD	HL,LNZERO
LNM2:	LD	(LNTMP+2),HL		;パターンの name2
	LD	HL,(LNTMP)
	CALL	LN2V
	JR	Z,LNM5
	CALL	LNST			;C の bit0 = name1 の最後が全角の1バイト目か
	LD	A,C
	AND	1
	LD	C,A
	ADD	A,A
	OR	C
	LD	C,A			;bit0=エントリ側 bit1=パターン側
	LD	HL,(LNTMP)
	LD	DE,12
	ADD	HL,DE
	JR	LNM6
LNM5:	LD	C,0
	LD	HL,LNZERO
LNM6:	LD	DE,(LNTMP+2)
	LD	B,10
	CALL	LNM7			;10バイト比べる(?は何とでも一致、大文字小文字同一視、全角の2バイト目は変換しない)
LNM9:	POP	BC
	POP	DE
	POP	HL
	RET

LNM7:	PUSH	BC			;CPSTR1 は終わりに POP BC するので、CPFILE と同じく BC を積んでから入る
	JP	CPSTR1

;	SDIRENT から: DE=エントリの +0Ch、IY=FCB。name2 を(大文字化して)10バイト書く(無ければ0)。DE は10進む
LNFILL:
	PUSH	HL
	PUSH	BC
	CALL	LNGET
	JR	NZ,LNF1
	LD	B,10
	XOR	A
LNF0:	LD	(DE),A
	INC	DE
	DJNZ	LNF0
	JR	LNFX
LNF1:	PUSH	HL
	PUSH	IY
	POP	HL
	INC	HL
	CALL	LNST			;C の bit0 = FCB の name1 の最後が全角の1バイト目か
	POP	HL
	LD	B,10
LNF2:	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,LNF3
	CALL	FKANC			;大文字化と全角状態の更新
	LD	(DE),A
	INC	DE
	DJNZ	LNF2
	JR	LNFX
LNF3:	XOR	A			;残りを0で埋める
LNF4:	LD	(DE),A
	INC	DE
	DJNZ	LNF4
LNFX:	POP	BC
	POP	HL
	RET

;	SETNAME(新しい名前の書き込み。作成と名前変更の両方)の最後から: HL=新しい名前の FCB+12、DE=エントリの +0Bh。
;	LA バイナリ(+10h=A0h)のエントリは予約領域をそのままにする。HL,DE,BC,IY は保つ
LNREN:
	PUSH	HL
	PUSH	DE
	PUSH	BC
	PUSH	IY
	LD	BC,-12
	ADD	HL,BC
	PUSH	HL
	POP	IY			;IY=新しい名前の FCB
	LD	HL,5
	ADD	HL,DE
	LD	A,(HL)
	CP	0A0H
	JR	Z,LNRN9
	INC	DE
	CALL	LNFILL
LNRN9:	POP	IY
	POP	BC
	POP	DE
	POP	HL
	RET

;	CHKWILD(? があるか)の最後から: HL=FCB+12。name2 に ? があればワイルドカード(CY=1)、無ければ CY=0。A=0 のとき CY=0
LNWILD:
	PUSH	HL
	PUSH	BC
	PUSH	IY
	LD	BC,-12
	ADD	HL,BC
	PUSH	HL
	POP	IY
	CALL	LNGET
	JR	Z,LNW9
	LD	B,10
LNW1:	LD	A,(HL)
	CP	'?'
	JR	Z,LNWY
	INC	HL
	DJNZ	LNW1
LNW9:	POP	IY
	POP	BC
	POP	HL
	XOR	A
	RET
LNWY:	POP	IY
	POP	BC
	POP	HL
	SCF
	RET

;	BDOS E4h (M25RES.ASM から): DE=FCB HL=name2(10バイト) -> A=0
LN_REG:
	PUSH	DE
	LD	DE,FN2
	LD	BC,10
	LDIR
	POP	DE
	LD	HL,16
	ADD	HL,DE
	EX	DE,HL
	CALL	LNREC
	XOR	A
	RET
