;	LSX-Dodgers MEM
;	MZ-2500 : E: EMM (MZ-1R37) / F: RAMディスク(拡張RAM)
;	DPBドライバの呼び出し規約: IX=DPB B=セクタ数 CDE=セクタ番号 HL=アドレス
;	                    戻り値   CF=0 DE=次のセクタ HL=次のアドレス

;	EMM DRIVER (512B/セクタ)
;	ポートACh: B(=A15-A8)の下位4bit=EMMアドレス19-16 / データ=EMMアドレス15-8
;	ポートADh: B(=A15-A8)=EMMアドレス7-0 / データ=読み書き(自動加算なし)
;	セクタ s は 256B x2 : ページ番号 p=2*s と p+1 (p=偶数なのでp+1はビット0を立てるだけ)

EDRD:
	PUSH	BC
	CALL	EMMLAT
	PUSH	BC
	CALL	EMMPG
	CALL	EMMRD
	POP	BC
	INC	C		;mid | 1
	CALL	EMMPG
	CALL	EMMRD
	POP	BC
	INC	DE
	DJNZ	EDRD
	AND	A
	RET

EDWT:
	PUSH	BC
	CALL	EMMLAT
	PUSH	BC
	CALL	EMMPG
	CALL	EMMWR
	POP	BC
	INC	C
	CALL	EMMPG
	CALL	EMMWR
	POP	BC
	INC	DE
	DJNZ	EDWT
	AND	A
	RET

EMMLAT:				;DE=セクタ -> B=アドレス19-16 C=アドレス15-8 (=2*DE)
	LD	A,E
	ADD	A,A
	LD	C,A
	LD	A,D
	ADC	A,A
	AND	00FH
	LD	B,A
	RET

EMMPG:				;BC=(上位,中位) でアドレスラッチを設定。B=0 C=0ADh で戻る
	LD	A,C
	LD	C,0ACH
	OUT	(C),A
	LD	C,0ADH
	LD	B,0
	RET

EMMRD:
	IN	A,(C)
	LD	(HL),A
	INC	HL
	INC	B
	JR	NZ,EMMRD
	RET

EMMWR:
	LD	A,(HL)
	OUT	(C),A
	INC	HL
	INC	B
	JR	NZ,EMMWR
	RET

;	==== MMU 窓の規則(ここに窓を使うコードを足すときは必ず守る) ====
;	1. 窓は CPU のバンク1か3だけ。本体(BDOS=0B006H以降)はバンク5-7にあり、窓の影響を受けない。
;	2. 窓にするバンクは、呼び出し元のバッファがかからないほうを RDSEL で選ぶ(バッファが窓に隠れると読み書きできない)。
;	3. 窓を割り当ててから戻すまでは DI のまま、スタックを使わない(CALL/PUSH/POP/RET 禁止。呼び出し元の SP が窓のバンクにあるかもしれない)。
;	   だから「窓を開ける/閉じる」はサブルーチンにせず、各ドライバにインラインで書く。
;	4. 戻すページは割り当て前に B5h から読んで保存した値(RDWP)。バンク番号と同じとは決め打ちしない。B5h は書いても読んでも B4h(選択)が+1されるので(エミュレータ)、読んだ後は必ず B4h を選び直してから書く。
;	5. IOCS を呼ぶ間はバンク1-3が ROM に替わり、バンク6が VRAM になる(コードとスタックを置かない)。
;
;	RAM DISK DRIVER (拡張RAM ページ10h-1Fh = 128KB, 512B/セクタ x 256)
;	ページを CPU のバンク1(2000H-)またはバンク3(6000H-)へ一時的に割り当て、呼び出し元のバッファへ直接 LDIR する。
;	窓にするバンクは、呼び出し元バッファ(512B)がバンク1にかからなければバンク1、かかればバンク3
;	(バッファと窓が重ならない。バッファは最大2バンクにまたがるが、バンク1と3は離れているので両方にはかからない)。
;	割り当て中は DI で、スタックを使わず LDIR と OUT だけを行う(呼び出し元のスタックが窓のバンクにあっても壊れない)。
;	本体はバンク5(BDOS=0B006H)以降にあるので影響されない。バンク1,3の通常のページは 01h,03h。

RDRD:
	PUSH	BC
	PUSH	DE
	CALL	RDSEL		;B=窓バンク D=窓アドレス上位 E=ページ
	LD	A,B
	DI
	OUT	(0B4H),A
	IN	A,(0B5H)
	LD	(RDWP),A	;窓にするバンクの元のページを保存
	LD	A,B
	OUT	(0B4H),A	;B5h は読んでもバンク選択が+1される(エミュレータ)ので選び直す
	LD	A,E
	OUT	(0B5H),A	;窓にページを割り当て
	LD	E,0
	EX	DE,HL		;HL=窓 DE=ユーザーバッファ
	LD	BC,512
	LDIR			;窓 -> ユーザーバッファ  DE=次のアドレス
	LD	H,D
	LD	L,E		;HL=次のアドレス
	LD	A,(RDWB)
	OUT	(0B4H),A
	LD	A,(RDWP)
	OUT	(0B5H),A	;元のページに戻す
	EI
	POP	DE
	INC	DE
	POP	BC
	DJNZ	RDRD
	AND	A
	RET

RDWT:
	PUSH	BC
	PUSH	DE
	CALL	RDSEL
	LD	A,B
	DI
	OUT	(0B4H),A
	IN	A,(0B5H)
	LD	(RDWP),A	;窓にするバンクの元のページを保存
	LD	A,B
	OUT	(0B4H),A	;B5h は読んでもバンク選択が+1される(エミュレータ)ので選び直す
	LD	A,E
	OUT	(0B5H),A
	LD	E,0		;DE=窓
	LD	BC,512
	LDIR			;ユーザーバッファ -> 窓  HL=次のアドレス
	LD	A,(RDWB)
	OUT	(0B4H),A
	LD	A,(RDWP)
	OUT	(0B5H),A	;元のページに戻す
	EI
	POP	DE
	INC	DE
	POP	BC
	DJNZ	RDWT
	AND	A
	RET

RDWB:	DB	1		;今回の窓のバンク(1か3)
RDWP:	DB	1		;窓にしたバンクの元のページ

RDSEL:				;HL=ユーザーバッファ E=セクタ(0-255) -> B=窓バンク(1か3) D=窓アドレス上位 E=ページ(10h+セクタ/16)。HL保存
	PUSH	HL
	LD	A,H
	RLCA
	RLCA
	RLCA
	AND	7
	LD	D,A		;D=バッファ先頭のバンク
	LD	BC,511
	ADD	HL,BC
	LD	A,H
	RLCA
	RLCA
	RLCA
	AND	7		;A=バッファ末尾のバンク
	CP	1
	JR	Z,RDSEL3
	LD	A,D
	CP	1
	LD	B,1
	JR	NZ,RDSEL1
RDSEL3:
	LD	B,3
RDSEL1:
	LD	A,B
	LD	(RDWB),A
	POP	HL
	LD	A,E
	AND	00FH
	ADD	A,A		;(セクタ%16)*512 の上位バイト
	LD	D,A
	LD	A,B
	RRCA
	RRCA
	RRCA			;バンク*32 = 窓の先頭アドレスの上位バイト
	ADD	A,D
	LD	D,A
	LD	A,E
	RRCA
	RRCA
	RRCA
	RRCA
	AND	00FH
	OR	010H
	LD	E,A
	RET
