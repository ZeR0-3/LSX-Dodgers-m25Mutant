;	LSX-Dodgers MZ-2500 オーバーレイ呼び出し(常駐側)
;	CCPレベルの大きめのコマンドを、8KBのオーバーレイページ(LD2500.BINの後ろに付き、起動時にRAMページへ読み込み済み)に置き、
;	呼ぶときだけ窓(バンク4 = 8000H-9FFFH)へ割り当てて実行する。
;
;	窓がバンク4なのは、CCPのスタックがBDOSの直下(バンク5)にあり、バンク0(コマンドライン 0080H)・バンク5以上(本体)は
;	動かさずに済むから。TPA(8000H-9FFFH)の中身は呼び出し中だけ見えなくなり、戻るときに元のページへ戻る。
;	制約: CCP(コマンド行処理)から呼ぶこと。TPAのプログラムの最中には使わない。オーバーレイからIOCS(RST 18H)は呼ばない。
;	      オーバーレイから別のオーバーレイを呼んでもよい(戻りの元ページはスタックに積む)。
;
;	呼び方: A = オーバーレイ番号<<5 | 入口番号(0-31)、 JP OVLCALL
;	入口は各オーバーレイの先頭(8000H)にある JP 命令の表(1入口3バイト)。BC,DE,HL は素通し、Aは壊れる。戻りのAF,BC,DE,HLは入口の処理の結果のまま。
;	バンク4,B5hの扱いは M25MEM.ASM の規則と同じ(B5hを読むとバンク選択が進むので選び直す)。

OVLCALL:
	DI
	LD	(OVLSV),HL
	LD	(OVLSV+2),DE
	LD	(OVLSV+4),BC
	LD	C,A
	LD	A,4
	OUT	(0B4H),A
	IN	A,(0B5H)
	LD	B,A			;B=窓の元のページ
	LD	A,4
	OUT	(0B4H),A
	PUSH	BC			;戻り用(上位=元のページ)
	LD	HL,OVLRET
	PUSH	HL
	LD	A,C
	RLCA
	RLCA
	RLCA
	AND	7
	LD	E,A
	LD	D,0
	LD	HL,OVLPGT
	ADD	HL,DE
	LD	A,(HL)
	OUT	(0B5H),A		;窓 = オーバーレイのページ
	LD	A,C
	AND	01FH
	LD	E,A
	ADD	A,A
	ADD	A,E
	LD	L,A
	LD	H,080H			;8000H + 入口*3
	PUSH	HL
	LD	BC,(OVLSV+4)
	LD	DE,(OVLSV+2)
	LD	HL,(OVLSV)
	EI
	RET				;入口へ。入口が RET すると OVLRET

OVLRET:
	EX	(SP),HL			;HL上位=元のページ。戻り値のHLはスタックへ
	PUSH	AF
	DI
	LD	A,4
	OUT	(0B4H),A
	LD	A,H
	OUT	(0B5H),A		;窓を元のページへ
	EI
	POP	AF
	POP	HL
	RET

OVLSV:	DS	6			;入力 HL,DE,BC の一時置き場(DIの間だけ使う)
OVLPGT:	DB	00EH			;オーバーレイ番号 → RAMページ (build.pyが数を合わせる)

C_MODE:
	LD	A,0
	JP	OVLCALL
C_SET:
	LD	A,1
	JP	OVLCALL
C_ENV:
	LD	A,2
	JP	OVLCALL
C_HIST:					;HIST (オーバーレイの入口9)
	LD	A,9
	JP	OVLCALL
HND_DIRNAME:				;DIR の名前表示(入口10。M25LNAME.ASM)
	LD	A,10
	JP	OVLCALL

;	---- パイプ・プロンプト用のスタブ(本体はオーバーレイ。入口番号は build.py の OVLS の並び: 3-6) ----
HND_PIPE:				;COMMAND2P から
	LD	A,3
	JP	OVLCALL
HND_PIPEK:				;COMMAND の先頭から。CY=1 で戻ったら続きの段を実行する(COMMAND へは戻らない)
	LD	A,4
	CALL	OVLCALL
	RET	NC
	POP	HL
	JP	COMMAND2P
HND_CDT:				;C_CD の後ろから。NZ(CD失敗)ならそのまま戻る。AFは保存
	RET	NZ
	PUSH	AF
	LD	A,5
	CALL	OVLCALL
	POP	AF
	RET
HND_PROMPT:				;プロンプトのドライブ文字の後ろから
	LD	A,6
	JP	OVLCALL
