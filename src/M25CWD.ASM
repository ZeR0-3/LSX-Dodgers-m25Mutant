;	LSX-Dodgers MZ-2500  プロンプトにカレントディレクトリを出す
;	環境変数 PROMPT が定義されていると、プロンプトを "A:\DIR\SUB>" の形にする(未定義なら従来の "A>")。
;	LSX にはカレントディレクトリを返す BDOS が無いので、内部コマンド CD が成功するたびにパス文字列を自分で管理する
;	(ドライブ A:〜D: ごとに CWDN バイト。"\" で始まり末尾に区切りなし。ルートは空文字)。
;	CD 以外の方法(外部プログラム)でカレントを変えた場合は反映されない。

CWDN	EQU	40
CWDBUF:	DS	CWDN*4
CWDP:	DW	0
PROMPTNM: DEFM	"PROMPT"
	DB	0

;	A=ドライブ番号 -> NC: HL=そのドライブのパス文字列  C: 対象外
CWDADR:
	CP	4
	CCF
	RET	C
	LD	L,A
	LD	H,0
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL			;*8
	LD	D,H
	LD	E,L
	ADD	HL,HL
	ADD	HL,HL			;*32
	ADD	HL,DE			;*40 (CWDN=40)
	LD	DE,CWDBUF
	ADD	HL,DE
	AND	A
	RET

; 	C_CD の後ろから(M25OVL のスタブが NZ=CD失敗 を除いてから呼ぶ)。成功時に DE の引数でパスを更新する。A とフラグは保存
HND_CDT:
	PUSH	AF
	PUSH	DE
	PUSH	BC
	PUSH	HL
	CALL	CWDUPD
	POP	HL
	POP	BC
	POP	DE
	POP	AF
	RET

;	DE=CD の引数
CWDUPD:
	LD	A,(_DVSW)
	PUSH	DE
	CALL	CWDADR
	POP	DE			;CWDADR は DE を壊す
	RET	C
	LD	(CWDP),HL
CT0:
	LD	A,(DE)
	CP	' '
	JR	NZ,CT1
	INC	DE
	JR	CT0
CT1:
	INC	DE
	LD	A,(DE)
	DEC	DE
	CP	':'
	JR	NZ,CT2
	INC	DE
	INC	DE			;ドライブ指定を読み飛ばす
CT2:
	LD	A,(DE)
	CP	05CH
	JR	Z,CT3
	CP	'/'
	JR	NZ,CL
CT3:
	LD	HL,(CWDP)		;絶対パス: ルートから
	LD	(HL),0
CL:
	LD	A,(DE)
	CP	05CH
	JR	Z,CLS
	CP	'/'
	JR	NZ,CL1
CLS:
	INC	DE
	JR	CL
CL1:
	CP	021H
	RET	C			;空白・CR・0 で終わり
	LD	H,D
	LD	L,E
	LD	B,0
CL2:
	LD	A,(HL)
	CP	05CH
	JR	Z,CL3
	CP	'/'
	JR	Z,CL3
	CP	021H
	JR	C,CL3
	INC	HL
	INC	B
	JR	CL2
CL3:
	LD	A,B			;DE=語の先頭 HL=終わり B=長さ
	CP	1
	JR	NZ,CL4
	LD	A,(DE)
	CP	'.'
	JR	Z,CLN			;"." は何もしない
CL4:
	LD	A,B
	CP	2
	JR	NZ,CL5
	LD	A,(DE)
	CP	'.'
	JR	NZ,CL5
	INC	DE
	LD	A,(DE)
	DEC	DE
	CP	'.'
	JR	NZ,CL5
	PUSH	HL			;".." : 末尾の1語を外す
	LD	HL,(CWDP)
	LD	C,0			;最後の 05CH の位置(HL側)を探す
	LD	D,H
	LD	E,L			;DE=最後の 05CH (無ければ 0 のまま)
	LD	B,0
CP1:
	LD	A,(HL)
	OR	A
	JR	Z,CP3
	CP	05CH
	JR	NZ,CP2
	LD	D,H
	LD	E,L
	INC	B
CP2:
	INC	HL
	JR	CP1
CP3:
	LD	A,B
	OR	A
	JR	Z,CP4			;05CH が無い(ルート)
	XOR	A
	LD	(DE),A
CP4:
	POP	HL
	JR	CLN
CL5:
	PUSH	HL			;語を追加
	PUSH	DE
	LD	HL,(CWDP)
	LD	C,0
CA1:
	LD	A,(HL)
	OR	A
	JR	Z,CA2
	INC	HL
	INC	C
	JR	CA1
CA2:
	LD	A,C			;現在の長さ + 1 + 語長 が収まるか
	ADD	A,B
	ADD	A,2
	CP	CWDN
	JR	C,CA3
	LD	HL,(CWDP)		;収まらない: "\..." にする
	LD	(HL),05CH
	INC	HL
	LD	(HL),'.'
	INC	HL
	LD	(HL),'.'
	INC	HL
	LD	(HL),'.'
	INC	HL
	LD	(HL),0
	POP	DE
	POP	HL
	JR	CLN2
CA3:
	LD	(HL),05CH
	INC	HL
	POP	DE
CA4:
	LD	A,(DE)
	CP	'a'
	JR	C,CA5
	CP	'z'+1
	JR	NC,CA5
	SUB	020H
CA5:
	LD	(HL),A
	INC	HL
	INC	DE
	DJNZ	CA4
	LD	(HL),0
	POP	HL
	JR	CLN2
CLN:
CLN2:
	LD	D,H
	LD	E,L
	JP	CL

;	プロンプトのドライブ文字の後ろから: PROMPT が定義されていれば ":\パス" を出す
HND_PROMPT:
	PUSH	HL
	PUSH	DE
	PUSH	BC
	LD	HL,PROMPTNM
	CALL	ENVFIND
	JR	C,HPX
	LD	A,':'
	CALL	MSG_A
	LD	A,(_DVSW)
	CALL	CWDADR
	JR	C,HPR
	LD	A,(HL)
	OR	A
	JR	Z,HPR
HPL:
	LD	A,(HL)
	OR	A
	JR	Z,HPX
	PUSH	HL
	CALL	MSG_A
	POP	HL
	INC	HL
	JR	HPL
HPR:
	LD	A,05CH
	CALL	MSG_A
HPX:
	POP	BC
	POP	DE
	POP	HL
	RET
