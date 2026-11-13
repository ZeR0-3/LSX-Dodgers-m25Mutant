;	LSX-Dodgers MZ-2500 長いファイル名(Human68k / TwentyOne 方式。docs/longname.md)の表示 (オーバーレイ)
;	ディレクトリエントリ +0Ch から10バイトの name2(名前の9文字目以降)を、name1 と拡張子の間に連結して出す。
;	CCP の DIR の名前表示(P_NAME)から HND_DIRNAME で呼ばれる。HL=ディレクトリエントリの先頭(名前)。

LNV:	DB	0			;name2 が有効なら 1
LNB:	DW	0			;エントリの先頭

;	name2 が有効か。HL=エントリ先頭。LNV に 0/1 を入れる。
;	有効 = name1 の8バイト目が空白でない / LA バイナリの印(+10h=A0h)でない / 先頭が00hでない /
;	00hまでが20h以上(7Fh,FFhでない) / 00h のあとは最後まで00h
;	(Windows が +0Ch 以降に入れる大文字小文字フラグや作成時刻を名前と取り違えないための条件)
LN2OK:
	LD	DE,7
	ADD	HL,DE
	LD	A,(HL)
	CP	' '
	JR	Z,LNNO
	LD	DE,9
	ADD	HL,DE			;+10h
	LD	A,(HL)
	CP	0A0H
	JR	Z,LNNO
	DEC	HL
	DEC	HL
	DEC	HL
	DEC	HL			;+0Ch
	LD	B,10
	LD	A,(HL)
	OR	A
	JR	Z,LNNO
LNL:	LD	A,(HL)
	OR	A
	JR	Z,LNZ
	CP	020H
	JR	C,LNNO
	CP	07FH
	JR	Z,LNNO
	CP	0FFH
	JR	Z,LNNO
	INC	HL
	DJNZ	LNL
	JR	LNYES
LNZ:	DEC	B
	JR	Z,LNYES
	INC	HL
	LD	A,(HL)
	OR	A
	JR	NZ,LNNO
	JR	LNZ
LNYES:	LD	A,1
	LD	(LNV),A
	RET
LNNO:	XOR	A
	LD	(LNV),A
	RET

;	HL=エントリ先頭。name1 + name2 + ".ext" を MSG_A で出す(従来の FPRNT と同じ書式)
HND_DIRNAME:
	LD	(LNB),HL
	CALL	LN2OK
	LD	HL,(LNB)
	LD	B,8
LN1:	LD	A,(HL)
	CP	5
	JR	NZ,LN1A
	LD	A,0E5H			;先頭の 05h は E5h
	JR	LN1P
LN1A:	LD	C,A
	LD	A,(LNV)
	OR	A
	LD	A,C
	JR	NZ,LN1P			;name2 があるときは name1 の8バイトを全部出す
	CP	021H
	JR	C,LN2			;空白で name1 の終わり
LN1P:	CALL	MSG_A
	INC	HL
	DJNZ	LN1
LN2:	LD	A,(LNV)
	OR	A
	JR	Z,LN3
	LD	HL,(LNB)
	LD	DE,12
	ADD	HL,DE
	LD	B,10
LN2L:	LD	A,(HL)
	OR	A
	JR	Z,LN3
	CALL	MSG_A
	INC	HL
	DJNZ	LN2L
LN3:	LD	HL,(LNB)
	LD	DE,8
	ADD	HL,DE
	LD	A,(HL)
	CP	021H
	RET	C			;拡張子が無い
	LD	A,'.'
	CALL	MSG_A
	LD	HL,(LNB)
	LD	DE,8
	ADD	HL,DE
	LD	B,3
LN3L:	LD	A,(HL)
	CP	021H
	RET	C
	CALL	MSG_A
	INC	HL
	DJNZ	LN3L
	RET
