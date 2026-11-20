; execrd - 親が `>R.TXT` でリダイレクトされているとき、E5h から戻ったあとも親の出力が R.TXT へ行くこと。
;   `ramdisk 64` の後、`execrd >r.txt` を実行し、`type r.txt` に RD-BEFORE / CHILD-OK / RD-AFTER が並べば OK。
	org 0100h
	ld sp,7F00h
	ld de,m_b
	ld c,9
	call 5
	ld de,c_child
	ld c,0E5h
	call 5
	ld de,m_a
	ld c,9
	call 5
	ld de,c_quote		; 引用符の中の > はリダイレクトではない(親のリダイレクトを閉じない)
	ld c,0E5h
	call 5
	ld de,m_a2
	ld c,9
	call 5
	jp 0
c_quote:	defm "DIR \"X>Y\"",0
c_child:	defm "CHILD",0
m_b:	defm "RD-BEFORE",13,10,"$"
m_a2:	defm "RD-AFTER2",13,10,"$"
m_a:	defm "RD-AFTER",13,10,"$"
