;	LSX-Dodgers MZ-2500 : システム情報とページ(8KB)の予約 -- BDOS E0h-E3h(本移植の拡張)
;	他のソフトが「拡張RAMを使ってよいか」を調べ、使うページを OS に届けるための呼び出し。
;	  E0h SYSINFO : A=0  B=機能ビット(0:IOCS 1:EMM(E:) 2:RAMディスク(F:) 3:SASI(H:) 4:漢字表示 5:GVRAMドライブ(G:) 6:ページ管理)
;	                     C=EMMの大きさ(64KB単位。0=なし)  E=この拡張のバージョン(1)  HL=TPAの上端+1
;	  E1h PAGEINFO: E=物理ページ(0-3Fh) -> A=0  B=所有者 0:空き 1:OS 2:TPA(プログラム領域) 3:RAMディスク(F:) 4:予約済み 5:無い/使えない
;	  E2h PAGEALLOC: E=ページ または FFh(空きの最小) -> A=0 B=ページ / 失敗 A=0F0h
;	  E3h PAGEFREE : E=ページ(自分で予約したもの) -> A=0 / 失敗 A=0F0h
;	  E4h LNAMEREG : DE=FCB(名前を 8+3 で入れたもの) HL=名前の9文字目以降(10バイト。余りは00h) -> A=0。長いファイル名(docs/longname.md)を FCB に結びつける。
;	                 このあと同じ FCB(名前を変えない)で 0Fh/11h/13h/16h/17h を呼ぶと、長い名前として扱う。結びつきは新しい4つの FCB まで。
;	予約したページは次のプログラムを起動する直前(LOADCOM)にすべて解放する。 ページを使うときの MMU の操作(B4h/B5h)は呼ぶ側で行う。
;	07h-09h は LSX が使っていない(grep で確認しただけ。IPL ROM / IOCS が使っていないかは未確認)。
E_NOPAGE	EQU	0F0H
RES_DOS:
	CP	0E5H
	JP	NC,_DOS2B
	SUB	0E0H
	JR	Z,RS_INFO
	DEC	A
	JR	Z,RS_PINFO
	DEC	A
	JR	Z,RS_PALLOC
	CP	2
	JP	Z,LN_REG		;E4h
;	E3h
	LD	A,E
	CP	20H
	JR	NC,RS_NO
	CALL	PG_UBIT
	LD	A,(HL)
	AND	D
	JR	Z,RS_NO
	XOR	(HL)
	LD	(HL),A
	XOR	A
	RET
RS_PINFO:
	LD	A,E
	CALL	PG_OWNER
	LD	B,A
	XOR	A
	RET
RS_PALLOC:
	LD	A,E
	INC	A
	LD	C,A			;指定ページ: 1つだけ調べる(C=E+1)
	JR	NZ,PA_LP
	LD	E,0			;FFh: 0からC=20hまで調べて最初の空き
	LD	C,20H
PA_LP:
	LD	A,E
	PUSH	BC
	CALL	PG_OWNER		;C を壊す
	POP	BC
	OR	A
	JR	Z,PA_GOT
	INC	E
	LD	A,E
	CP	C
	JR	C,PA_LP
RS_NO:
	LD	A,E_NOPAGE
	RET
PA_GOT:
	LD	A,E
	CALL	PG_UBIT
	LD	A,(HL)
	OR	D
	LD	(HL),A
	LD	B,E
	XOR	A
	RET
RS_INFO:
	LD	A,(IOCSOK)
	AND	1
	OR	050H			;漢字表示 と ページ管理
	LD	B,A
	LD	A,(_DEVICE+32*4+DPB_FATLN)
	OR	A
	JR	Z,RI1
	SET	1,B
RI1:
	LD	A,(_DEVICE+32*5+DPB_FATLN)
	OR	A
	JR	Z,RI2
	SET	2,B
RI2:
	LD	A,(_DEVICE+32*7+DPB_FATLN)
	OR	A
	JR	Z,RI3
	SET	3,B
RI3:
	LD	A,(EMMN)
	LD	C,A
	LD	E,2
	LD	A,(RDN)
	LD	D,A
	LD	HL,0E000H
	XOR	A
	RET
;	A=ページ -> A=所有者(0-5)。 E は壊さない
PG_OWNER:
	CP	20H
	JR	NC,PO5
	LD	C,A
	CP	10H
	JR	NC,POEXT
	LD	HL,PGMAIN
	ADD	A,L
	LD	L,A
	JR	NC,PO1
	INC	H
PO1:
	LD	A,(HL)
	OR	A
	RET	NZ
	JR	POU			;空き -> ユーザが予約済みか
POEXT:
	LD	A,(RDEXT)
	OR	A
	JR	Z,PO5
	LD	A,C
	SUB	010H
	LD	HL,RDN
	CP	(HL)			;ページ-10h < RDN ならRAMディスク
	JR	NC,POU
	LD	A,3
	RET
POU:	LD	A,C			;RAMディスクの外 -> ユーザが予約済みか
	CALL	PG_UBIT
	LD	A,(HL)
	AND	D
	LD	A,0
	RET	Z
	LD	A,4
	RET
PO5:
	LD	A,5
	RET
;	A=ページ(<20h) -> HL=PGUSER内のバイト D=ビット
PG_UBIT:
	LD	B,A
	SRL	A
	SRL	A
	SRL	A
	LD	HL,PGUSER
	ADD	A,L
	LD	L,A
	JR	NC,PU1
	INC	H
PU1:
	LD	A,B
	AND	7
	LD	B,A
	INC	B
	XOR	A
	SCF
PU2:
	RLA
	DJNZ	PU2
	LD	D,A
	RET
PG_FREEALL:
	LD	HL,0
	LD	(PGUSER),HL
	LD	(PGUSER+2),HL
	RET
PGMAIN:	DB	2,2,2,2,2,2,1,0,0,0,2,1,1,1,1,1	;00-0F: 04,05=TPAの上(ユーザのバンク5,6) 06=カーネルのバンク6 0A=バンク4 0B=カーネルのバンク5 0C,0D=IOCS退避 0E=オーバーレイ 0F=共通
PGUSER:	DB	0,0,0,0
EMMN:	DB	0
;	F:(RAMディスク)の状態は F: のDPB(_DEVICE+32*5)の未使用領域に置く。 RAMDISK.COM がここを直接書き換えて大きさを変える(§page-api)
RDN	EQU	_DEVICE+32*5+016H	;F:のページ数(0-16。8KB単位。0=F:を使わない)
RDEXT	EQU	_DEVICE+32*5+018H	;1:拡張RAM(10h-1Fh)がある(INITが設定)
