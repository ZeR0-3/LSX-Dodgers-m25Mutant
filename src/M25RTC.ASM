;	LSX-Dodgers MZ-2500  時計 (RP5C15)。BDOS 2Ah (日付の獲得) / 2Ch (時刻の獲得)
;	ポート CCh。16ビットI/Oデコードで、アドレス A11-A8 (= B レジスタ) がレジスタ番号 (4ビット幅):
;	  0,1=秒(1の位,10の位) 2,3=分 4,5=時 6=曜日 7,8=日 9,10=月 11,12=年(下2桁)  13=モード(bit0=バンク選択)
;	前提: 24時間表示 (バンク1のレジスタ10のbit0=1。エミュレータの初期値。実機のIOCSが12時間にしていると時が狂う=未確認)。
;	ファイルの作成・更新時刻 (SETTMSX) がこれを使う。年は 2000 + 下2桁。
;	_SYS2A: HL=年 D=月 E=日 A=曜日   _SYS2C: H=時 L=分 D=秒   (BC は保つ)

;	バンク0 (時刻のレジスタ) にする。モードレジスタの他のビットは保つ
RTCBK0:
	LD	B,0DH
	LD	C,0CCH
	IN	A,(C)
	AND	0EH
	OUT	(C),A
	RET

;	B=レジスタ -> A=その4ビット (C を壊す)
RTC1:
	LD	C,0CCH
	IN	A,(C)
	AND	0FH
	RET

;	B=下位桁のレジスタ -> A=10進2桁の値 (B,C を壊す)
RTC2:
	CALL	RTC1
	PUSH	AF
	INC	B
	CALL	RTC1
	LD	C,A
	ADD	A,A
	ADD	A,A
	ADD	A,C
	ADD	A,A
	LD	C,A
	POP	AF
	ADD	A,C
	RET

_SYS2A:		;(BDOS)日付の獲得
	PUSH	BC
	CALL	RTCBK0
	LD	B,11
	CALL	RTC2
	LD	L,A
	LD	H,0
	LD	DE,2000
	ADD	HL,DE
	LD	B,9
	CALL	RTC2
	LD	D,A
	LD	B,7
	CALL	RTC2
	LD	E,A
	LD	B,6
	CALL	RTC1
	POP	BC
	RET

_SYS2C:		;(BDOS)時刻の獲得
	PUSH	BC
	CALL	RTCBK0
	LD	B,4
	CALL	RTC2
	LD	H,A
	LD	B,2
	CALL	RTC2
	LD	L,A
	LD	B,0
	CALL	RTC2
	LD	D,A
	POP	BC
	RET
