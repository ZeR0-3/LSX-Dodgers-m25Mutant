; 色指定のテスト: ESC E で消去して、ESC [ ... m (VT-100 SGR) を出す
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
	DEFB 27,'[','3','1','m','R',27,'[','3','2','m','G',27,'[','3','4','m','B'
	DEFB 27,'[','7',';','3','4','m','X',27,'[','m','W',27,'[','9','6','m','C'
	DEFB 27,'[','?','2','5','h',27,'[','3','3',';','1','m','Y',0
