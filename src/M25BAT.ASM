;	LSX-Dodgers MZ-2500  シェル機能: 終了コード($?) / バッチ引数($1-$9) / GOTO / IF
;	バッチ引数は環境変数 "1".."9" として設定する($1 は M25ENV の $NAME 展開がそのまま効く)。
;	作業領域は EXBUF(=OUTBUF) を使う(バッチ開始時はリダイレクト出力が空)。

EXITC:	DB	0			;直前のコマンドの終了コード
GOLABP:	DW	0			;GOTO のラベル
IFNEG:	DB	0			;IF NOT

;	BDOS 62h _TERM : B=終了コード。保存してウォームブート
H_TERM:
	LD	A,B
	LD	(EXITC),A
	JP	CPM_WBOOT

;	COMMAND2 から: 終了コードを 0 にしてコマンドを実行。内部コマンドのエラー(CF=1)は 1
HND_RUN:
	XOR	A
	LD	(EXITC),A
	CALL	_COMANL
	RET	NC
	LD	A,1
	LD	(EXITC),A
	SCF
	RET

;	$? の展開: EXITC を10進で EXBUF へ(上位の0は出さない)
EXNUM:
	PUSH	HL
	LD	A,(EXITC)
	LD	H,A
	LD	L,0
	LD	B,100
	CALL	EXDG
	LD	B,10
	CALL	EXDG
	LD	A,H
	ADD	A,'0'
	POP	HL
	JP	EXPUT
EXDG:
	LD	C,0
EXDG1:
	LD	A,H
	SUB	B
	JR	C,EXDG2
	LD	H,A
	INC	C
	JR	EXDG1
EXDG2:
	LD	A,C
	OR	L
	RET	Z
	LD	L,1
	LD	A,C
	ADD	A,'0'
	JP	EXPUT

;	バッチファイル開始時: コマンドラインの残り(COMSWC)の単語を環境変数 1..9 に設定(足りない分は削除)
HND_BARGS:
	LD	HL,(COMSWC)
	LD	C,'1'
BA1:
	LD	DE,EXBUF
	LD	A,C
	LD	(DE),A
	INC	DE
	LD	A,'='
	LD	(DE),A
	INC	DE
BA2:
	LD	A,(HL)
	CP	020H
	JR	NZ,BA3
	INC	HL
	JR	BA2
BA3:
	CP	021H
	JR	C,BA4
	LD	(DE),A
	INC	DE
	INC	HL
	LD	A,(HL)
	JR	BA3
BA4:
	XOR	A
	LD	(DE),A
	PUSH	HL
	PUSH	BC
	LD	DE,EXBUF
	CALL	C_SET
	POP	BC
	POP	HL
	INC	C
	LD	A,C
	CP	'9'+1
	JR	NZ,BA1
	RET

;	GOTO label : バッチファイルの先頭から ":label" の行を探し、その次の行から続ける
C_GOTO:
	CALL	SPCUT
	LD	(GOLABP),DE
	LD	A,(FCB_BAT)
	OR	A
	JR	Z,GOBAD
	LD	HL,FCB_BAT+33		;ランダムレコードを0へ (先頭から読み直す)
	XOR	A
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	CALL	SETDTA100
GOL0:
	CALL	GOGET
	JR	C,GOBAD
	CP	':'
	JR	Z,GOLB
	CP	021H
	JR	C,GOL0			;空白・改行は行頭のまま
GOSKIP:
	CALL	GORST
	JR	GOL0
GOLB:
	LD	DE,(GOLABP)
GOCMP:
	CALL	GOGET			;EOF は A=0
	CALL	CAP
	LD	B,A
	LD	A,(DE)
	CALL	CAP
	CP	021H
	JR	C,GOEND
	INC	DE
	CP	B
	JR	Z,GOCMP
	LD	A,B			;不一致: 行末ならそのまま次の行頭へ
	CP	020H
	JR	NC,GOSKIP
	JR	GOL0
GOEND:
	LD	A,B
	CP	021H
	JR	NC,GOSKIP		;ラベルより長い名前
	CP	020H
	CALL	Z,GORST
	AND	A
	RET
GOBAD:
	XOR	A
	LD	(FCB_BAT),A		;ラベルが無い: バッチを終了 (Error!)
	SCF
	RET
GOGET:				;バッチから1文字。NC=A:文字  CF=EOF(A=0)  DE保存
	PUSH	DE
	CALL	FGETC_BAT
	POP	DE
	JR	NZ,GOEOF
	AND	A
	RET
GOEOF:
	XOR	A
	SCF
	RET
GORST:				;行の残りを読み捨てる
	CALL	GOGET
	RET	C
	CP	020H
	JR	NC,GORST
	RET

;	IF [NOT] EXIST file command   /   IF [NOT] str1==str2 command
C_IF:
	CALL	SPCUT
	XOR	A
	LD	(IFNEG),A
	LD	HL,IFNOTW
	CALL	IFW
	JR	NZ,IF1
	LD	A,1
	LD	(IFNEG),A
	CALL	SPCUT
IF1:
	LD	HL,IFEXW
	CALL	IFW
	JR	Z,IFEX
	LD	H,D			;"==" を探す
	LD	L,E
IFC1:
	LD	A,(HL)
	CP	021H
	JR	C,IFBAD
	INC	HL
	CP	'='
	JR	NZ,IFC1
	LD	A,(HL)
	CP	'='
	JR	NZ,IFC1
	XOR	A
	DEC	HL
	LD	(HL),A			;1つ目の '=' を 0 に (str1 の終端)
	INC	HL
	INC	HL			;HL=str2
	LD	C,0			;C=0:偽
IFC2:
	LD	A,(DE)
	OR	A
	JR	Z,IFC3
	CP	(HL)
	JR	NZ,IFC4
	INC	DE
	INC	HL
	JR	IFC2
IFC3:
	LD	A,(HL)
	CP	021H
	JR	NC,IFC4
	LD	C,1			;一致
IFC4:
	LD	A,(HL)			;str2 の終わりまで進める
	CP	021H
	JR	C,IFRUN
	INC	HL
	JR	IFC4
IFEX:
	CALL	SPCUT
	CALL	FILEC
	PUSH	DE
	LD	HL,FDRV+1
	CALL	CWILD1
	LD	A,0F1H
	LD	(FDRV+13),A
	CALL	OPEN1
	POP	DE
	LD	H,D
	LD	L,E
	LD	C,0
	JR	NZ,IFRUN
	LD	C,1			;見つかった
IFRUN:				;HL=実行するコマンド  C=条件(1:真)
	LD	A,(IFNEG)
	XOR	C
	AND	A
	JR	Z,IFOK			;偽: 何もしない
	EX	DE,HL
	CALL	SPCUT
	JP	_COMANL
IFOK:
	AND	A
	RET
IFBAD:
	SCF
	RET
;	HL=語(0終端・大文字) DE=テキスト。語の後ろに空白があれば Z で DE=その後ろ(空白は飛ばさない)、違えば NZ で DE 不変
IFW:
	PUSH	DE
IFW1:
	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,IFW2
	LD	B,A
	LD	A,(DE)
	INC	DE
	CALL	CAP
	CP	B
	JR	Z,IFW1
IFW3:
	POP	DE
	OR	1
	RET
IFW2:
	LD	A,(DE)
	CP	020H
	JR	NZ,IFW3
	POP	AF
	XOR	A
	RET
IFNOTW:	DB	"NOT",0
IFEXW:	DB	"EXIST",0
