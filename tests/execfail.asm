; execfail - 空きページが足りないとき(F: が128KBのまま)E5h は A=0F0h を返し、何も変えない。
	org 0100h
	ld sp,7F00h
	ld de,c_child
	ld c,0E5h
	call 5
	cp 0F0h
	jr nz,ng
	ld de,m_ok
	ld c,9
	call 5
	jp 0
ng:	ld de,m_ng
	ld c,9
	call 5
	jp 0
c_child:	defm "CHILD",0
m_ok:	defm "EXECFAIL-OK",13,10,"$"
m_ng:	defm "EXECFAIL-NG",13,10,"$"
