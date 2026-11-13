
;	LSX-Dodgers IO
;	MZ-2500
;	テキストVRAM(ページ38h)をバンク7(0E000H-0FFFFH)に出し入れしてアクセスする。
;	VRAMを見ている間は0E000H-0FFFFH(ワーク・テーブル)が見えないので、
;	このファイルのルーチンは0E000H未満に置き、スタックも0E000H未満であること。
;
;	VRAMの構造(1文字=3プレーン,行間隔80バイト)
;	  +0000H テキスト1 : (コード AND 3FH) * 4   (16ライン文字モード: F7h bit0=0。偶数コード=R0)
;	  +0800H アトリビュート : bit7 BL / bit6 RV / bit2 G / bit1 R / bit0 B
;	  +1000H テキスト2 : 8CH + (コード / 64)
;	  消去セル/空白は 80H / 属性 / 8CH。8ライン文字モード(F7h bit0=1)では +2(R=1) が必要

IO_BDOS:
	LD	(HND_A),A		;MSX-DOS2のハンドル呼び出し(43h-4Bh)がAを使う
	JP	BDOS0

;	ハードウェアスクロール(40桁・80桁とも。2026-11-12に40桁へも拡張)。CRT-C(F4h/F5h)のレジスタ01h/02hが「表示開始セル」。
;	論理セル(行*WIDTH+桁, 0-1999)の物理位置は (論理セル+VSTART)&7FFh。
;	VRAMを触る低レベルルーチンはHL=0E000H+論理セル(+プレーン)を受け取り、ここで物理位置に変換する。
VSTART:	DW	0

;	画面幅(実行時に MODE 40/80 で切り替える)。WIDTHV は前後のバイトが0なので LD DE,(WIDTHV) / LD HL,(WIDTHV-1) が使える
	DB	0
WIDTHV:	DB	WIDTH
	DB	0
WIDM1:	DB	WIDTH-1

;	HL=0E000H+論理セル(bit3,4=プレーン) -> 物理位置。HL以外は保存
XLAT:
	PUSH	AF
	PUSH	DE
	LD	A,H
	AND	018H
	PUSH	AF		;プレーンのビット
	LD	A,H
	AND	007H
	LD	H,A
	LD	DE,(VSTART)
	ADD	HL,DE
	LD	A,H
	AND	007H
	LD	H,A
	POP	AF
	OR	H
	OR	0E0H
	LD	H,A
	POP	DE
	POP	AF
	RET

;	HL=0E000H+物理位置(プレーン0) -> 0E000H+論理セル。HL以外は保存
UNXLAT:
	PUSH	AF
	PUSH	DE
	LD	A,H
	AND	007H
	LD	H,A
	LD	DE,(VSTART)
	OR	A
	SBC	HL,DE
	LD	A,H
	AND	007H
	OR	0E0H
	LD	H,A
	POP	DE
	POP	AF
	RET

;	VSTARTをCRT-Cに反映する(全レジスタ保存)
CRTCSET:
	PUSH	AF
	PUSH	HL
	LD	HL,(VSTART)
	LD	A,1
	OUT	(0F4H),A
	LD	A,L
	OUT	(0F5H),A
	LD	A,2
	OUT	(0F4H),A
	LD	A,H
	AND	7
	OUT	(0F5H),A
	POP	HL
	POP	AF
	RET

;	VSTART=0にそろえる(画面を物理的に回転)。外部プログラムはVRAMを直接触るので、起動前とMON前に呼ぶ。
;	3プレーンそれぞれ(2048セル)を、VSTARTだけ左へ回す。小さい方(<=1024)をTPAの 4000H-43FFH へ退避して LDIR/LDDR で動かす。VSTART=0なら何もしない。
VNORM:
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	HL,(VSTART)
	LD	A,H
	OR	L
	JP	Z,VNORM9
	DI
	CALL	VN_BLANK		;回転の途中の崩れた絵を見せない(表示範囲の右端=左端にして表示を空に)
	CALL	VRAM_ON
	LD	BC,0E000H
VNORM1:
	LD	(VNPL),BC		;プレーンの先頭
	LD	HL,(VSTART)
	LD	DE,1025
	OR	A
	SBC	HL,DE
	JR	NC,VNRGT
;	k<=1024: 先頭のk個を退避 → 残りを前へ詰める → 退避を後ろへ
	LD	BC,(VSTART)
	LD	HL,(VNPL)
	LD	DE,VBUF
	LDIR				;HL=P+k
	PUSH	HL
	LD	HL,2048
	LD	BC,(VSTART)
	OR	A
	SBC	HL,BC
	LD	B,H
	LD	C,L			;BC=2048-k
	POP	HL
	LD	DE,(VNPL)
	LDIR				;DE=P+2048-k
	LD	HL,VBUF
	LD	BC,(VSTART)
	LDIR
	JR	VNNXT
;	k>1024: 右へ(2048-k)回す。末尾のm個を退避 → 前のk個を後ろへずらす → 退避を先頭へ
VNRGT:
	LD	HL,(VSTART)
	LD	DE,(VNPL)
	ADD	HL,DE			;P+k
	PUSH	HL
	LD	HL,2048
	LD	BC,(VSTART)
	OR	A
	SBC	HL,BC
	LD	B,H
	LD	C,L			;BC=m=2048-k
	POP	HL
	LD	DE,VBUF
	LDIR
	LD	HL,(VSTART)
	LD	DE,(VNPL)
	ADD	HL,DE
	DEC	HL			;P+k-1
	PUSH	HL
	LD	HL,2047
	ADD	HL,DE
	EX	DE,HL			;DE=P+2047
	POP	HL
	LD	BC,(VSTART)
	LDDR
	LD	HL,2048
	LD	BC,(VSTART)
	OR	A
	SBC	HL,BC
	LD	B,H
	LD	C,L
	LD	HL,VBUF
	LD	DE,(VNPL)
	LDIR
VNNXT:
	LD	BC,(VNPL)
	LD	A,B
	ADD	A,8
	LD	B,A
	CP	0F8H
	JP	NZ,VNORM1
	LD	HL,0
	LD	(VSTART),HL
	CALL	CRTCSET
	CALL	VRAM_OFF
	CALL	VN_SHOW
	EI
VNORM9:
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	RET

;	CRT-Cレジスタ8(横表示範囲の右端)を、左端(レジスタ7: 40桁=08h 80桁=09h)と同じにして表示を空にする / 元(+50h)に戻す。AF破壊
VN_BLANK:
	CALL	VN_LEFT
	JR	VN_W8
VN_SHOW:
	CALL	VN_LEFT
	ADD	A,050H
VN_W8:
	PUSH	AF
	LD	A,8
	OUT	(0F4H),A
	POP	AF
	OUT	(0F5H),A
	RET
VN_LEFT:
	LD	A,(WIDTHV)
	CP	80
	LD	A,8
	RET	NZ
	INC	A
	RET

VNPL:	DW	0			;VNORM: 回転中のプレーンの先頭
VBUF	EQU	04000H		;VNORM: 退避用(1024バイト。TPAの中。COM起動前/MON前/MODEでしか使わない)

;	COMを起動する直前(LDCCPのS27BUF_COM)にVSTARTを0に戻してから読み込みに進む
S27BUF_COM	EQU	COMNORM
COMNORM:
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
	CALL	VNORM
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	JP	LOADCOM

VRAM_ON:
	PUSH	AF
	LD	A,7
	OUT	(0B4H),A	;マッピングレジスタ(バンク7)
	LD	A,VRAM_PG
	OUT	(0B5H),A	;テキストVRAM
	POP	AF
	RET

VRAM_OFF:
	PUSH	AF
	LD	A,7
	OUT	(0B4H),A
	LD	A,RAM7_PG
	OUT	(0B5H),A	;RAM
	POP	AF
	RET

IO_CLR:
	LD	A,D
	OR	E
	JR	NZ,IO_CLR0
	LD	HL,0		;画面全体を消すときはVSTARTも0に戻す(再同期)
	LD	(VSTART),HL
	CALL	CRTCSET
IO_CLR0:
	CALL	VRAM_ON
C1AX1:
	PUSH	DE		;DE=論理セル
	LD	HL,(VSTART)
	ADD	HL,DE
	LD	A,H
	AND	007H
	ADD	A,0E0H
	LD	D,A
	LD	E,L		;DE=0E000H+物理セル
	LD	A,080H
	LD	(DE),A		;Text1
	SET	3,D
	LD	A,0		;自己書き換え
				;BDOS0+13Hが外部から書き換えされても動くようにする
ICSMC	EQU	$-1
	LD	(DE),A		;Attribute
	RES	3,D
	SET	4,D
	LD	A,08CH
	LD	(DE),A		;Text2
	POP	DE
	INC	DE
	LD	HL,0-WIDTH*LINE
_NEG_PAGE_SWC	EQU	$-2
	ADD	HL,DE
	JR	NC,C1AX1
	CALL	VRAM_OFF
	POP	HL
	POP	DE
	EI
	RET

;	キーボード: A=ストローブ列(0-13) -> A=列のデータ(0=押されている)
;	PIO E8h: bit5=CH80(80桁なら1) bit4=1で列指定 bit3-0=列。上位3ビットは読み戻して保持
RDKEYDATA:
	PUSH	BC
	LD	B,A
	IN	A,(0E8H)	;E8hは読み戻せる(ROMのTWIDも読み戻して使う)
	AND	0E0H		;DISP/HCLG/CH80 を保持
	OR	010H		;bit4=1: 列指定
	OR	B
	OUT	(0E8H),A
	NOP
	NOP
	IN	A,(0EAH)
	POP	BC
	RET

;	A bit7 = VBLANK中=1  (8255 PB bit0 は /VBLANK: 0=ブランク中)
RD556VSYNC:
	IN	A,(0E1H)
	CPL
	RRCA
	RET

RDMMIO:
	DI
	PUSH	HL
	CALL	XLAT
	CALL	VRAM_ON
	LD	A,(HL)
	CALL	VRAM_OFF
	POP	HL
	EI
	RET

WRMMIO:
	DI
	PUSH	HL
	CALL	XLAT
	CALL	VRAM_ON
	LD	(HL),A
	CALL	VRAM_OFF
	POP	HL
	EI
	RET

RDMMIO_BC:
	DI
	PUSH	HL
	LD	H,B
	LD	L,C
	CALL	XLAT
	CALL	VRAM_ON
	LD	A,(HL)
	CALL	VRAM_OFF
	POP	HL
	EI
	RET

WRMMIO_BC:
	DI
	PUSH	HL
	LD	H,B
	LD	L,C
	CALL	XLAT
	CALL	VRAM_ON
	LD	(HL),A
	CALL	VRAM_OFF
	POP	HL
	EI
	RET

;	HL=0E000H+桁行オフセット, E=文字コード, C=属性
IO_PRINT:
	DI
	PUSH	HL
	CALL	XLAT
	CALL	VRAM_ON
	LD	A,E
	ADD	A,A
	ADD	A,A
	LD	(HL),A		;Text1 (16ライン文字: R=0,x=0 の偶数コード)
	SET	3,H
	LD	(HL),C		;Attribute
	RES	3,H
	SET	4,H
	LD	A,E
	RLCA
	RLCA
	AND	3
	OR	08CH
	LD	(HL),A		;Text2
	CALL	VRAM_OFF
	POP	HL
	EI
	RET

;	HL=0E000H+オフセット, B=個数, C=属性 を消去セルで埋める
IO_CLLINE:
	DI
	CALL	XLAT
	CALL	VRAM_ON
CLLINE1:
	LD	(HL),080H	;Text1
	SET	3,H
	LD	(HL),C		;Attribute
	RES	3,H
	SET	4,H
	LD	(HL),08CH	;Text2
	RES	4,H
	INC	HL
	RES	3,H		;2048セルで折り返し(0E800H->0E000H)
	DJNZ	CLLINE1
	CALL	VRAM_OFF
	EI
	RET

;	行内の挿入/削除(1セル=3プレーンを順送り)
;	入力 A=Text1, C=属性, E=Text2, B=個数, HL=開始位置(0E000H+),
;	     IO_INCDEC=INC HL(挿入)/DEC HL(削除)
;	出力 A=押し出されたText1, C=その属性, B=その Text2, HL=最後の次, D保存
IO_INSBS:
	DI
	CALL	XLAT
	CALL	VRAM_ON
	PUSH	DE
	LD	D,B
IO_INSBS1:
	LD	B,(HL)
	LD	(HL),A
	LD	A,B
	SET	3,H
	LD	B,(HL)
	LD	(HL),C
	LD	C,B
	RES	3,H
	SET	4,H
	LD	B,(HL)
	LD	(HL),E
	LD	E,B
	RES	4,H
IO_INCDEC	EQU	$	; 自己書き換え
	INC	HL		;INS->INC HL or BS->DEC HL
	BIT	5,H		;DEC HLで0DFxxHになったら0E7xxHへ
	JR	NZ,INSBS2
	LD	H,0E7H
INSBS2:
	RES	3,H		;INC HLで0E8xxHになったら0E0xxHへ(2048セルで折り返し)
	DEC	D
	JR	NZ,IO_INSBS1
	LD	B,E
	POP	DE
	CALL	VRAM_OFF
	CALL	UNXLAT		;呼び出し側は論理位置で続けて使う
	EI
	RET

IO_SCRUP:
	DI
	CP	LINE-1
	JR	NZ,SCRP0
	JR	HWSCRL0		;全画面スクロール(40桁・80桁とも): 表示開始セルを1行ぶん進めるだけ(コピーしないので、途中の画面が見えない)
SCRP0:
	OR	A		;A=0のときZを立て直す
	CALL	VRAM_ON
SCRUP1:
	JR	Z,SCRCL
	PUSH	AF
	CALL	COPYROW
	POP	AF
	DEC	A
	JR	SCRUP1

HWSCRL0:
HWSCRL:
	LD	HL,(VSTART)
	LD	DE,(WIDTHV)
	ADD	HL,DE
	LD	A,H
	AND	007H
	LD	H,A
	LD	(VSTART),HL
;	先に新しい最下行を消してから(旧最上行の左32桁=80桁のとき、と重なるセルは、どうせすぐ画面から消える行)、表示開始セルを切り替える。
;	逆順(切り替えてから消す)だと、消すまでの間、新しい最下行に古い内容(旧最上行の断片など)がゴミとして見える。
	LD	DE,0E000H+80*(LINE-1)	;最下行の先頭(論理。VSTART は新しい値)
	LD	A,(WIDTHV)
	CP	80
	JR	Z,HWSC2
	LD	DE,0E000H+40*(LINE-1)
HWSC2:	LD	A,(WIDTHV)
	LD	B,A
	EX	DE,HL
	CALL	VRAM_OFF
	CALL	CLLINE
	CALL	CRTCSET
	POP	HL
	POP	DE
	POP	BC
	RET

;	論理行HL(0E000H+セル)の1行をDEの論理行へコピーする(3プレーン、折り返し対応)。HL,DEは1行ぶん進む
COPYROW:
	PUSH	HL
	PUSH	DE
	CALL	XLAT
	EX	DE,HL
	CALL	XLAT		;DE=コピー元の物理, HL=コピー先の物理
	LD	A,(WIDTHV)
	LD	B,A
COPYR1:
	LD	A,(DE)
	LD	(HL),A
	SET	3,D
	SET	3,H
	LD	A,(DE)
	LD	(HL),A
	RES	3,D
	RES	3,H
	SET	4,D
	SET	4,H
	LD	A,(DE)
	LD	(HL),A
	RES	4,D
	RES	4,H
	INC	DE
	INC	HL
	RES	3,D
	RES	3,H
	DJNZ	COPYR1
	POP	DE
	POP	HL
	LD	BC,(WIDTHV)
	ADD	HL,BC
	EX	DE,HL
	ADD	HL,BC
	EX	DE,HL
	RET

SCRCL:
	LD	A,(WIDTHV)
	LD	B,A
	EX	DE,HL
	CALL	VRAM_OFF
	CALL	CLLINE
	POP	HL
	POP	DE
	POP	BC
	RET

IO_MON:
;	MON : IOCSのモニタ(機能00h MONOP)を呼ぶ。モニタのコマンド R で戻ってくる(S-OS移植版で確認済みの動作)
;	IOCSのRAM(0000h-25FFh)はLSXのTPA/ページ0に使われて壊れているので、起動時(M25INIT)に
;	ページ0Ch,0Dへ退避しておいた内容を戻してから呼ぶ。LSXのページ0(0000h-00FFh)は6600hに退避して、戻ったら復元する。
;	TPAのプログラムは消える(CCPから呼ぶ前提)。
	DI
	LD	SP,0AE00H
	CALL	VNORM			;IOCSのモニタは表示開始セル=0を前提にVRAMを触る
	DI
	CALL	MON_MAP
	LD	HL,0
	LD	DE,06600H
	LD	BC,00100H
	LDIR				;LSXのページ0を退避
	LD	HL,04000H
	LD	DE,0
	LD	BC,02600H
	LDIR				;IOCSのRAMを復元
	CALL	MON_UNMAP
#IF EXISTS USE_TINIT
#ELSE
#IF EXISTS COLS80
	IN	A,(0E8H)		;IOCS内部は40桁のつもりなので、IOCSなし80桁ではハードを40桁に戻す
	AND	0DFH
	OUT	(0E8H),A
	LD	A,7
	OUT	(0F4H),A
	LD	A,008H
	OUT	(0F5H),A
	LD	A,8
	OUT	(0F4H),A
	LD	A,058H
	OUT	(0F5H),A
#ENDIF
#ENDIF
	LD	A,007H
	OUT	(0C6H),A		;IPL終了時の割り込み許可に戻す(S-OS版が動いている状態)
	LD	A,2
	LD	I,A
	IM	2
	LD	SP,01900H		;スタックは低位RAM(S-OS版と同じ1900h)。バンク7(FC00h)に置くとモニタのメモリ表示で暴走する
	EI
	RST	18H
	DB	000H			;MONOP
	DI
	IM	1
#IF EXISTS USE_TINIT
#ELSE
#IF EXISTS COLS80
	IN	A,(0E8H)
	OR	020H
	OUT	(0E8H),A
	LD	A,7
	OUT	(0F4H),A
	LD	A,009H
	OUT	(0F5H),A
	LD	A,8
	OUT	(0F4H),A
	LD	A,059H
	OUT	(0F5H),A
#ENDIF
#ENDIF
	LD	A,008H
	OUT	(0C6H),A		;VBLANKだけ許可に戻す
	LD	SP,0AE00H
	CALL	MON_MAP
	LD	HL,06600H
	LD	DE,0
	LD	BC,00100H
	LDIR				;LSXのページ0を復元
	CALL	MON_UNMAP
	LD	C,00CH
	CALL	CONOUT1		;画面を消してホームへ
	JP	CPM_WBOOT

MON_MAP:				;バンク2,3 = ページ0Ch,0Dh (IOCS RAMの退避先)
	LD	A,2
	OUT	(0B4H),A
	LD	A,00CH
	OUT	(0B5H),A
	LD	A,00DH
	OUT	(0B5H),A
	RET

MON_UNMAP:				;バンク2,3 = 標準(ページ02h,03h)
	LD	A,2
	OUT	(0B4H),A
	LD	A,002H
	OUT	(0B5H),A
	LD	A,003H
	OUT	(0B5H),A
	RET

;	IM1の割り込み処理(VBLANKのみ許可: C6h=08h)。E1h bit0(/VBLANK)はこの許可があるときだけ動き、
;	RD556VSYNC(キーリピート・FDCのREADYタイムアウトの時間基準)が使う。許可が無いと常に1のまま止まる。
IO_INT8253:
	EI
	RETI
