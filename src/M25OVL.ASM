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
OVLPGT:	DB	00EH,009H		;オーバーレイ番号 → RAMページ (build.py の OVL_PAGES と同じ並び。1=E5h EXEC のオーバーレイ)

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

;	---- E5h EXEC(常駐側の入口): 子プログラムを新しいページ(0100H から)で起動し、終了したら親の BDOS 呼び出しの続きへ戻る ----
;	入力: DE=コマンド行(00h/0Dh終端。79文字まで。内部コマンド・COM。.BAT は未対応)
;	出力: 子の終了後に A=終了コード(0=正常 1=コマンドの失敗 他は子の 62h _TERM の B) / 起動できなかったとき A=0F0h(空きページ不足) 0F1h(深すぎ)
;	親のTPA・ゼロページ・予約したページには触らない(子は空きページ7枚をバンク0-6に出して動く)。親の SP/IFF/DMA/UMAP/予約は記録(PROCS)に保存する。
;	準備と後始末の本体はオーバーレイ1(M25PROC.ASM)。ここは常駐に残す小さな部分(バンク0-4 のハード反映と、コマンドの起動)だけ。
;	未対応: 子が変えたカレントディレクトリ/開いたままのハンドル/環境変数は親に残る。カレントドライブ(0004H)は子のゼロページ側。
SETBK04:				;UMAP のバンク0-4 をハードに反映(カーネル実行中。バンク5-7 は動かさない)
	DI
	LD	HL,UMAP
	XOR	A
	OUT	(0B4H),A
	LD	B,5
SB1:	LD	A,(HL)
	OUT	(0B5H),A
	INC	HL
	DJNZ	SB1
	RET
RS_EXEC:
	LD	H,D			;コマンド行を STAGE へ(親のメモリが見えるうちに)
	LD	L,E
	LD	DE,STAGE
	LD	B,79
XE2:	LD	A,(HL)
	CP	00DH
	JR	Z,XE3
	OR	A
	JR	Z,XE3
	LD	(DE),A
	INC	HL
	INC	DE
	DJNZ	XE2
XE3:	XOR	A
	LD	(DE),A
	LD	A,E			;STAGE=xx00H なので E=長さ
	LD	(PXLEN),A
	LD	A,32			;オーバーレイ1 の入口0: 深さ・ページの確保・親の状態の保存・子のゼロページ・UMAP
	CALL	OVLCALL
	OR	A
	RET	NZ			;A=0F0h/0F1h: 何も変えていない
	CALL	SETBK04			;子のページをバンク0-4 に出す
	LD	A,80			;子のコマンド行(子のゼロページ 0080H 以降)
	LD	(DTA1),A
	LD	A,(PXLEN)
	LD	(DTA1+1),A
	LD	HL,STAGE
	LD	DE,DTA1+2
	LD	BC,80
	LDIR
	CALL	SETDTA1
	CALL	HND_EXPAND		;$変数の展開とリダイレクト(> >> <)は CCP と同じ。パイプ(|)は解釈しない
	CALL	HND_REDIR
	JR	NC,XE4
	LD	A,1			;リダイレクトの失敗(メッセージは出ている)
	LD	(EXITC),A
	JR	PEXIT
XE4:	LD	DE,DTA1+2
	CALL	HND_RUN			;COM なら戻らない(ULAUNCH へ)。内部コマンドなら戻る
	CALL	C,SHOW_ERROR		;(失敗は JP CPM_BOOT -> 0000H -> UWBOOT -> PEXIT で戻る)
;	子の終了: UWBOOT(カーネルのマップ・SP=KSTK)からも来る。親の記録を戻して、親の E5h 呼び出しの続きへ(UXRET)
PEXIT:
	LD	A,34			;オーバーレイ1 の入口2: 子のコマンド行にリダイレクトがあったときだけ HND_RESET(親のリダイレクトは残す)
	CALL	OVLCALL
	DI
	LD	A,33			;オーバーレイ1 の入口1: 親の UMAP/USP/UIFF/UDMA/予約を戻し、戻り値を設定
	CALL	OVLCALL
	CALL	SETBK04			;親のページをバンク0-4 に戻す
	JP	UXRET
