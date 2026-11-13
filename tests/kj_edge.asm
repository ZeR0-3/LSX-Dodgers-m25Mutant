; 漢字表示のテスト: (1) 無効な2バイト目(CR)なら1バイト目を捨てて CR を通常どおり処理 (2) 行の最後の桁に全角が来たら1セル空けて次の行へ
	ORG 0100H
	LD HL,MSG
LP:	LD A,(HL)
	OR A
	JP Z,0
	LD E,A
	PUSH HL
	LD C,2
	CALL 5
	POP HL
	INC HL
	JR LP
MSG:	DEFB 27,'k','1','A',081H,13,10,'B',13,10
	DEFB 'x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x'
	DEFB 'x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x'
	DEFB 'x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x'
	DEFB 'x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x','x'
	DEFB 088H,09FH,'z',27,'k','0',0
