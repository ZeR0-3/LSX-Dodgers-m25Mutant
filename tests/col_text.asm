; 色指定のテスト: ESC E で消去して、ESC b n (文字色) / ESC p / ESC q (反転) を出す
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
MSG:	DEFB 27,'E'
	DEFB 27,'b','1','R',27,'b','2','G',27,'b','4','B',27,'p','X',27,'q',27,'b','7','W',27,'b','6','C',27,'b','3','Y',0
