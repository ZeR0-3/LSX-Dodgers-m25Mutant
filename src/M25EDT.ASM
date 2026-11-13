; LSX-Dodgers MZ-2500  行編集の拡張(常駐側): 入口だけ。実体(TAB補完・履歴・部分一致検索)はオーバーレイ M25EDTO.ASM
;	CCPのプロンプト行入力(HND_CCPIN 経由, EDT_OK=1)の間だけオーバーレイを呼ぶ。BDOS 0Ah(プログラムの行入力)は元の動作のまま。
;	オーバーレイは窓(バンク4)を使うので、TPAのプログラムの行入力(8000H-9FFFHにバッファがありうる)では呼ばない。
;	履歴・作業バッファはオーバーレイのページの中(起動時に読み込まれたまま残る)。

EDT_OK:		DB	0		;1=CCPのプロンプト行入力中
EDT_START:	DW	0		;入力行の開始位置 (H=行 L=桁)
EDT_POS:	DB	0FFH		;履歴の閲覧位置(0=最新 0FFH=入力中の行)

;	GETL の先頭: 行の開始位置を保存し、履歴の閲覧位置を初期化 (HL 保存)
ED_BEGIN:
	LD	(EDT_START),HL
	LD	A,0FFH
	LD	(EDT_POS),A
	RET

;	COMMAND から: CCPのプロンプト行入力。入力後に履歴へ追加(オーバーレイの入口8 = EDT_ADD)
HND_CCPIN:
	LD	A,1
	LD	(EDT_OK),A
	CALL	_SYS0A
	PUSH	AF
	XOR	A
	LD	(EDT_OK),A
	LD	A,8
	CALL	OVLCALL
	POP	AF
	RET

;	GETL のキー入力後: A=キー。処理したら CF=1、そうでなければ CF=0 で A を保ったまま戻る
ED_KEY:
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	C,A
	CP	01AH			;Ctrl-Z: ハンドル0のコンソール読み(cat > file など)の間だけ「EOFの合図」として行を終える
	JR	NZ,EDT_NZ
	LD	A,(EDT_EOFM)
	OR	A
	JR	Z,EDT_NZ
	LD	A,1
	LD	(EDT_EOFK),A
	LD	C,00DH
EDT_NZ:
	LD	A,(EDT_OK)
	OR	A
	JR	Z,EDT_K0
	LD	A,C
	CP	9			;TAB
	JR	Z,EDT_KO
	CP	010H			;^P
	JR	Z,EDT_KO
	CP	00EH			;^N
	JR	Z,EDT_KO
	CP	006H			;^F
	JR	Z,EDT_KO
	CP	01EH			;↑
	JR	Z,EDT_KO
	CP	01FH			;↓
	JR	Z,EDT_KO
EDT_K0:
	LD	A,C
	OR	A			;CF=0
EDT_KX:
	POP	HL
	POP	DE
	POP	BC
	RET
EDT_KO:
	LD	A,7			;オーバーレイの入口7 = EDO_KEY (C=キー。処理したら CF=1)
	CALL	OVLCALL
	JR	C,EDT_KH
	JR	EDT_K0
EDT_KH:
	SCF
	JR	EDT_KX

EDT_EOFM:	DB	0		;M25HND の CONREAD が行入力している間 1
EDT_EOFK:	DB	0		;その間に Ctrl-Z が押された

	INCLUDE	"M25GATE.ASM"
	INCLUDE	"M25SASI.ASM"		;H: SASI HDD ドライバ(共通バンク7に置く: 本体側が満杯のため)
