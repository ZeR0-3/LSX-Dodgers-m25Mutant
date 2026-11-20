;	LSX-Dodgers MZ-2500  オーバーレイ1: E5h EXEC の準備と後始末(常駐側の入口は M25RES.ASM の RS_EXEC / PEXIT)
;	窓(バンク4)で実行される。呼ぶ側のカーネルのスタックはバンク5。ここからIOCSは呼ばない。
;	プロセスの記録(PROCS+32*深さ, 32B): +0..6 親のUMAP +7,8 USP +9 UIFF +10,11 UDMA +12..15 親のPGUSER +16..19 親のPGHELD +20..26 子のTPAのページ
;	PGHELD = 止まっている親の予約と子のTPAのページ。PG_OWNER は PGUSER と PGHELD の両方を「予約済み」として見る。

PR_REC:				;HL=現在の深さの記録の先頭
	LD	A,(PDEPTH)
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,PROCS&0FFH
	LD	L,A
	LD	H,PROCS/256
	RET

;	入口0: STAGE=コマンド行 PXLEN=長さ。 A=0 成功(UMAP は子のページ表になった。ハードのバンク0-4 は呼んだ側が SETBK04 で反映) / 0F0h 空きページ不足 / 0F1h 深すぎ(どちらも何も変えない)
PR_EXEC:
	LD	A,(PDEPTH)
	CP	4
	JR	C,PE1
	LD	A,0F1H
	RET
PE1:	CALL	PR_REC
	PUSH	HL
	POP	IY			;IY=記録
	PUSH	IY
	POP	HL
	LD	DE,20
	ADD	HL,DE
	PUSH	HL
	POP	IX			;IX=子のページ表
	LD	E,7			;候補ページ 07h-1Fh から空きを7枚
	LD	A,7
	LD	(PXCNT),A
PE2:	LD	A,E
	CP	020H
	JR	NC,PENO
	CALL	PG_OWNER		;E は壊さない
	OR	A
	JR	NZ,PE3
	LD	(IX+0),E
	INC	IX
	LD	A,(PXCNT)
	DEC	A
	LD	(PXCNT),A
	JR	Z,PE4
PE3:	INC	E
	JR	PE2
PENO:	LD	A,0F0H
	RET
PE4:	LD	HL,STAGE		;コマンド行に > か < があるか(あれば記録の +27 を1。子の終了で HND_RESET する。$展開で現れるものは数えない)
	LD	BC,0			;B=印 C=引用符の中か(HND_REDIR と同じ規則)
PX1:	LD	A,(HL)
	OR	A
	JR	Z,PX3
	INC	HL
	CP	022H
	JR	NZ,PX4
	LD	A,C
	XOR	1
	LD	C,A
	JR	PX1
PX4:	LD	D,A
	LD	A,C
	OR	A
	JR	NZ,PX1
	LD	A,D
	CP	'>'
	JR	Z,PX2
	CP	'<'
	JR	NZ,PX1
PX2:	LD	B,1
PX3:	LD	(IY+27),B
	PUSH	IY			;親の状態を記録へ
	POP	DE
	LD	HL,UMAP
	LD	BC,7
	LDIR
	LD	HL,(USP)
	LD	(IY+7),L
	LD	(IY+8),H
	LD	A,(UIFF)
	LD	(IY+9),A
	LD	HL,(UDMA)
	LD	(IY+10),L
	LD	(IY+11),H
	PUSH	IY
	POP	HL
	LD	DE,12
	ADD	HL,DE
	EX	DE,HL
	LD	HL,PGUSER		;PGUSER(4)+PGHELD(4) をまとめて
	LD	BC,8
	LDIR
	LD	A,3			;子のバンク0のページへ親のゼロページを写す(0000H の JP、0005H の JP、0038H の EI/RETI、0004H のドライブ)。窓はバンク3
	OUT	(0B4H),A
	LD	A,(IY+20)
	OUT	(0B5H),A
	LD	HL,0
	LD	DE,06000H
	LD	BC,00100H
	LDIR
	LD	A,3
	OUT	(0B4H),A
	LD	A,(UMAP+3)
	OUT	(0B5H),A
	LD	HL,PGUSER		;親の予約と子のページを PGHELD へ(子や自動解放から守る)
	LD	DE,PGHELD
	LD	B,4
PE5:	LD	A,(DE)
	OR	(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	DJNZ	PE5
	CALL	PG_FREEALL		;子の予約は空から始める
	LD	A,7
	LD	(PXCNT),A
	PUSH	IY
	POP	HL
	LD	DE,20
	ADD	HL,DE
	PUSH	HL
	POP	IX
PE6:	LD	A,(IX+0)
	CALL	PG_UBIT			;HL=PGUSER内のバイト D=ビット
	INC	HL
	INC	HL
	INC	HL
	INC	HL			;PGHELD の同じバイト
	LD	A,(HL)
	OR	D
	LD	(HL),A
	INC	IX
	LD	A,(PXCNT)
	DEC	A
	LD	(PXCNT),A
	JR	NZ,PE6
	PUSH	IY			;UMAP = 子のページ表
	POP	HL
	LD	DE,20
	ADD	HL,DE
	LD	DE,UMAP
	LD	BC,7
	LDIR
	LD	HL,PDEPTH
	INC	(HL)
	XOR	A
	RET

;	入口1: 子の終了。親の UMAP/USP/UIFF/UDMA/予約を戻し、戻り値(A=EXITC F=0 BC=DE=HL=0)を URAF 等へ。ハードのバンク0-4 は呼んだ側が SETBK04 で反映
PR_RST:				;入口2: 終わる子(深さ=PDEPTH)の記録の +27 が1なら HND_RESET(子のリダイレクトを閉じる)
	LD	A,(PDEPTH)
	DEC	A
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,(PROCS&0FFH)+27
	LD	L,A
	LD	H,PROCS/256
	LD	A,(HL)
	OR	A
	RET	Z
	JP	HND_RESET

PR_EXIT:
	LD	A,(PDEPTH)
	DEC	A
	LD	(PDEPTH),A
	CALL	PR_REC
	PUSH	HL
	POP	IY
	PUSH	IY
	POP	HL
	LD	DE,12
	ADD	HL,DE
	LD	DE,PGUSER
	LD	BC,8
	LDIR
	PUSH	IY
	POP	HL
	LD	DE,UMAP
	LD	BC,7
	LDIR
	LD	L,(IY+7)
	LD	H,(IY+8)
	LD	(USP),HL
	LD	A,(IY+9)
	LD	(UIFF),A
	LD	L,(IY+10)
	LD	H,(IY+11)
	LD	(UDMA),HL
	LD	A,(EXITC)
	LD	(URAF+1),A
	XOR	A
	LD	(URAF),A
	LD	(EXITC),A		;親に戻ったら終了コードは0から(子/孫の値を親の終了コードに持ち越さない)
	LD	H,A
	LD	L,A
	LD	(URBC),HL
	LD	(URDE),HL
	LD	(URHL),HL
	RET
