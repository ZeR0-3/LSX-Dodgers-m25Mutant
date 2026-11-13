;	LSX-Dodgers MZ-2500  パイプ  a | b | c
;	一時ファイル(F: があれば F:LSXPIP1.TMP / F:LSXPIP2.TMP を交互に、無ければカレントドライブ)で実現する。
;	  段 N : 入力 "< 前の一時ファイル" と 出力 "> 次の一時ファイル" をコマンド行へ付け足し、通常のリダイレクト(HND_REDIR)で走らせる。
;	  段が終わって COMMAND に戻る(外部COMはウォームブートで戻る)とき HND_PIPEK が次の段を始める。
;	  最後の段が終わったら一時ファイルを消す。
;	状態(変数)はオーバーレイのページに置く(ページはウォームブートでも残る)。オーバーレイ化したので常駐側は M25OVL のスタブだけ。

PIPEACT:	DB	0		;パイプライン実行中
PIPEHAS:	DB	0		;続きの段がある(PIPEBUF)
PIPEIN:		DB	0		;今の段の入力一時ファイル番号(0=無し)
PIPEOUT:	DB	0		;今の段の出力一時ファイル番号
PIPECONT:	DB	0		;続きの段としてコマンド行が作られた(HND_PIPE が新しい行かどうか判断する)
PIPEBUF:	DS	128

;	COMMAND2P から: コマンド行(DTA1+2)の '|' を調べ、段の入出力リダイレクトを付け足す
HND_PIPE:
	LD	A,(PIPECONT)
	OR	A
	JR	NZ,HP0
	XOR	A			;新しい行
	LD	(PIPEIN),A
	LD	(PIPEACT),A
HP0:
	XOR	A
	LD	(PIPECONT),A
	LD	(PIPEHAS),A
	LD	HL,DTA1+2
	LD	C,0
HP1:
	LD	A,(HL)
	CP	0DH
	JR	Z,HPEND
	OR	A
	JR	Z,HPEND
	CP	022H
	JR	NZ,HP2
	LD	A,C
	XOR	1
	LD	C,A
	JR	HPN
HP2:
	LD	A,C
	OR	A
	JR	NZ,HPN
	LD	A,(HL)
	CP	'|'
	JR	Z,HPFND
HPN:
	INC	HL
	JR	HP1
HPEND:
;				'|' が無い: 続きの段の最後なら入力だけ付ける
	LD	A,(PIPEIN)
	OR	A
	RET	Z
	LD	B,A
	LD	A,'<'
	JP	PIPEAPP
HPFND:
;				'|' より後ろを PIPEBUF へ退避
	PUSH	HL
	INC	HL
	LD	DE,PIPEBUF
HPC:
	LD	A,(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	CP	0DH
	JR	Z,HPC2
	OR	A
	JR	NZ,HPC
HPC2:
	POP	HL
	LD	A,1
	LD	(PIPEHAS),A
	LD	(PIPEACT),A
	LD	A,(PIPEIN)
	LD	B,A
	OR	A
	JR	Z,HP3
	LD	A,'<'
	PUSH	BC
	CALL	PIPEAPP
	POP	BC
HP3:
	LD	A,B			;次の出力番号: 入力が1なら2、それ以外は1
	CP	1
	LD	B,1
	JR	NZ,HP4
	LD	B,2
HP4:
	LD	A,B
	LD	(PIPEOUT),A
	LD	A,'>'
;	HL=書き込み位置のまま(PIPEAPP は HL を CR の位置に戻す)
	JP	PIPEAPP

;	HL の位置に " <(prefix)LSXPIPn.TMP" + CR,0 を書く。A='<'/'>' B=番号。戻り HL=書いた CR の位置
PIPEAPP:
	LD	(HL),020H
	INC	HL
	LD	(HL),A
	INC	HL
	CALL	PIPENAME
	LD	(HL),0DH
	INC	HL
	LD	(HL),0
	DEC	HL
	RET

;	HL に (F:)LSXPIPn.TMP を書く(終端なし)。B=番号 戻り HL=次の位置
PIPENAME:
	LD	A,(_DEVICE+32*5+DPB_FATLN)
	LD	C,A
	LD	A,(_DEVICE+32*5+DPB_FATLN+1)
	OR	C
	JR	Z,PN1
	LD	(HL),'F'
	INC	HL
	LD	(HL),':'
	INC	HL
PN1:
	EX	DE,HL			;DE=書き込み先
	LD	HL,PIPENM
	PUSH	BC
	LD	BC,6
	LDIR
	POP	BC
	LD	A,B
	ADD	A,'0'
	LD	(DE),A
	INC	DE
	LD	HL,PIPENM2
	LD	BC,4
	LDIR
	EX	DE,HL
	RET
PIPENM:	DEFM	"LSXPIP"
PIPENM2: DEFM	".TMP"

;	COMMAND の先頭(HND_RESET の後)から: 段が終わっていたら一時ファイルを消し、続きの段があれば始める
HND_PIPEK:
	LD	A,(PIPEACT)
	OR	A
	RET	Z
	LD	A,(PIPEIN)
	OR	A
	CALL	NZ,PIPEDEL		;終わった段の入力を消す
	LD	A,(PIPEHAS)
	OR	A
	JR	NZ,HK1
	XOR	A			;パイプライン終わり
	LD	(PIPEACT),A
	LD	(PIPEIN),A
	RET
HK1:
	LD	A,(PIPEOUT)
	LD	(PIPEIN),A
	LD	HL,PIPEBUF
	LD	DE,DTA1+2
HK2:
	LD	A,(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	CP	0DH
	JR	Z,HK3
	OR	A
	JR	NZ,HK2
HK3:
	LD	A,1
	LD	(PIPECONT),A
	SCF				;CY=1: 常駐側のスタブが COMMAND へ戻らず、続きの段をコマンド行として実行する
	RET

;	PIPEIN の一時ファイルを消す
PIPEDEL:
	LD	B,A
	LD	HL,OUTBUF		;作業: 名前
	PUSH	HL
	CALL	PIPENAME
	LD	(HL),0
	POP	HL
	LD	(ARG_DE),HL
	CALL	FINDS
	RET	C
	CALL	PARSEFCB
	RET	C
	LD	C,013H
	JP	FCBCALL
