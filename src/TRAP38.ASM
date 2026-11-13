
;	RST 28H (未初期化領域の実行) の異常終了処理
;	TRAP38 に配置される。ユーザマップでも動くよう、表示は共通バンクのゲート経由の UMSGA(= MSG_A)で行う

	ORG	TRAP38
	LD	HL,0
	EX	(SP),HL
	LD	A,'$'
	CALL	UMSGA
	DEC	HL
	LD	A,H
	CALL	PRHX
	LD	A,L
PRHX:
	PUSH	AF
	RLCA
	RLCA
	RLCA
	RLCA
	CALL	PRHX2
	POP	AF
PRHX2:
	AND	00FH
	CP	10
	CCF
	ADC	A,'0'
	DAA
	JP	UMSGA
	DS	4
