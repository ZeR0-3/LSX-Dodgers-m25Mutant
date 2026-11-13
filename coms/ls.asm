; LS.COM - ファイル一覧。ls [-l1am] [パス/パターン]     MIT License
;   既定: 名前順に、画面幅に合わせて桁を組む(ディレクトリは名前の後ろに \ )。標準出力がコンソールでなければ1行1ファイル。
;   -l : 属性(d=ディレクトリ r=読み取り専用 h=隠し s=システム)、サイズ、名前   -1 : 1行1ファイル   -a : 隠し/システム/"." ".." も出す
;   パターンは DIR と同じ(ワイルドカード、ドライブ、サブディレクトリ)。パターンがディレクトリ1つだけに一致したら、その中身を出す。
	org 0100h
	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld c,a
	ld b,0
	ld de,argbuf
	or a
	jr z,cp0
	ldir
cp0:	xor a
	ld (de),a
	ld (flags),a
	ld hl,0
	ld (patp),hl
	ld hl,argbuf
ploop:	ld a,(hl)
	or a
	jr z,pdone
	cp ' '
	jr nz,ptok
	inc hl
	jr ploop
ptok:	cp '-'
	jr z,popt
	ld (patp),hl
pend:	ld a,(hl)
	or a
	jr z,pdone
	cp ' '
	jr z,pterm
	inc hl
	jr pend
pterm:	ld (hl),0
	inc hl
	jr ploop
popt:	inc hl
oloop:	ld a,(hl)
	or a
	jr z,pdone
	cp ' '
	jr z,ploop
	or 20h
	ld b,1
	cp 'l'
	jr z,oset
	ld b,2
	cp 'a'
	jr z,oset
	ld b,4
	cp '1'
	jr z,oset
	ld b,8
	cp 'm'
	jr z,oset
	jp usage
oset:	ld a,(flags)
	or b
	ld (flags),a
	inc hl
	jr oloop
pdone:
	ld de,dtabuf
	ld c,1Ah
	call 5
	ld hl,(patp)
	ld a,h
	or l
	jr nz,havepat
	ld hl,defpat
havepat:ld (curpat),hl
	xor a
	ld (desc),a
run:	xor a
	ld (n),a
	ld (ovf),a
	ld hl,(curpat)
	ex de,hl		; DE=パターン文字列
	ld hl,fcb		; FCB を消してパターンを解析
	push de
	push hl
	ld d,h
	ld e,l
	inc de
	ld (hl),0
	ld bc,47
	ldir
	pop hl
	pop de
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcb+13),a
	ld hl,(curpat)		; パターンに * があって拡張子が空なら拡張子も ? にする(t* で TYPE.COM も)
st1:	ld a,(hl)
	or a
	jr z,st3
	inc hl
	cp '*'
	jr nz,st1
	ld a,(fcb+9)
	cp ' '
	jr nz,st3
	ld hl,fcb+9
	ld (hl),'?'
	inc hl
	ld (hl),'?'
	inc hl
	ld (hl),'?'
st3:	ld a,(fcb+1)
	cp ' '
	jr nz,nm1
	ld hl,fcb+1		; 名前が空(例 "sub\")なら全部
	ld de,fcb+2
	ld (hl),'?'
	ld bc,10
	ldir
nm1:	ld de,fcb
	ld c,11h
sl:	call 5
	or a
	jr nz,sdone
	call addent
	ld de,fcb
	ld c,12h
	jr sl
sdone:	ld a,(n)
	cp 1
	jr nz,show
	ld a,(desc)
	or a
	jr nz,show
	ld a,(arr+23)		; 1つだけ見つかって、それがディレクトリでパターンにワイルドカードが無いなら中身を出す
	and 10h
	jr z,show
	ld hl,(curpat)
wl:	ld a,(hl)
	or a
	jr z,nowild
	cp '*'
	jr z,show
	cp '?'
	jr z,show
	inc hl
	jr wl
nowild:	ld hl,(curpat)
	ld de,patbuf
cpp:	ld a,(hl)
	ld (de),a
	or a
	jr z,cpe
	inc hl
	inc de
	jr cpp
cpe:	ld hl,tail
	ld bc,5
	ldir
	ld hl,patbuf
	ld (curpat),hl
	ld a,1
	ld (desc),a
	jp run
show:	ld a,(n)
	or a
	jr nz,out0
	ld de,mnone
	ld c,9
	call 5
	jp 0
; ---- 出力 ----
out0:	ld b,1			; 標準出力がコンソールで -m が無ければ色を付ける
	xor a
	ld c,4Bh
	call 5
	ld a,e
	and 80h
	jr z,oc0
	ld a,(flags)
	and 8
	jr nz,oc0
	ld a,1
	ld (colon),a
oc0:	ld a,(flags)
	and 1
	jp nz,longfmt
	ld b,1			; 標準出力がコンソールか (IOCTL 0: E bit7)
	xor a
	ld c,4Bh
	call 5
	ld a,e
	and 80h
	ld c,1			; C = 桁数 (既定 1 = 1行1ファイル)
	jr z,setcols
	ld a,(flags)
	and 4
	jr nz,setcols
	ld b,2
	ld a,4
	ld c,4Bh
	call 5			; E = 画面の桁数
	ld a,e
	ld (width),a
	xor a			; 最長の名前(\を含む)
	ld (maxl),a
	ld a,(n)
	ld b,a
	ld hl,arr
ml:	push bc
	push hl
	call reclen
	ld a,(maxl)
	cp b
	jr nc,ml2
	ld a,b
	ld (maxl),a
ml2:	pop hl
	ld de,32
	add hl,de
	pop bc
	djnz ml
	ld a,(maxl)
	add a,2
	ld (cw),a
	ld b,a
	ld a,(width)
	ld c,0			; C = 幅 / cw
dv:	cp b
	jr c,dvd
	sub b
	inc c
	jr dv
dvd:	ld a,c
	or a
	jr nz,setcols
	ld c,1
setcols:ld a,c
	ld (cols),a
	ld a,(n)		; rows = ceil(n / cols)
	ld b,0
	ld hl,cols
rl:	or a
	jr z,rld
	inc b
	sub (hl)
	jr nc,rl
	xor a
	jr rl
rld:	ld a,b
	ld (rows),a
	xor a
	ld (row),a
rowlp:	ld a,(row)
	ld (idx),a
	xor a
	ld (col),a
collp:	ld a,(idx)
	ld hl,n
	cp (hl)
	jr nc,eol
	call recadr
	call pname
	ld a,(rows)
	ld b,a
	ld a,(idx)
	add a,b
	ld (idx),a
	ld hl,n
	cp (hl)
	jr nc,eol
	ld a,(col)
	inc a
	ld (col),a
	ld hl,cols
	cp (hl)
	jr nc,eol
	ld a,(idx)		; 直前の名前の長さ分を cw まで空白で埋める
	ld hl,rows
	sub (hl)
	call recadr
	call reclen
	ld a,(cw)
	sub b
	ld b,a
pad:	ld a,' '
	call putc
	djnz pad
	jr collp
eol:	call crlf
	ld a,(row)
	inc a
	ld (row),a
	ld hl,rows
	cp (hl)
	jr nz,rowlp
	jp fin
; ---- -l ----
longfmt:xor a
	ld (idx),a
lloop:	ld a,(idx)
	ld hl,n
	cp (hl)
	jp nc,fin
	call recadr
	ld (recp),hl
	ld de,23
	add hl,de
	ld c,(hl)		; C = 属性
	ld a,c
	and 10h
	ld b,'d'
	call attrc
	ld a,c
	and 1
	ld b,'r'
	call attrc
	ld a,c
	and 2
	ld b,'h'
	call attrc
	ld a,c
	and 4
	ld b,'s'
	call attrc
	ld a,' '
	call putc
	ld a,c
	and 10h
	jr z,lsz
	ld de,mdir
	ld c,9
	call 5
	jr lnm
lsz:	ld hl,(recp)
	call psize
lnm:	ld a,' '
	call putc
	ld hl,(recp)
	call pdate
	ld a,' '
	call putc
	ld hl,(recp)
	call pname
	call crlf
	ld a,(idx)
	inc a
	ld (idx),a
	jp lloop
fin:	ld a,(ovf)
	or a
	jp z,0
	ld de,mtrunc
	ld c,9
	call 5
	jp 0
usage:	ld de,musage
	ld c,9
	call 5
	jp 0
; HL=レコード: "YYYY-MM-DD HH:MM" を出す (日付が0なら空白で埋める)
pdate:	ld de,28
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)		; DE=日付 BC=時刻(C=下位)
	ld a,d
	or e
	jr nz,pd1
	ld b,16
pd0:	ld a,' '
	call putc
	djnz pd0
	ret
pd1:	push bc
	push de
	ld a,d
	srl a			; 年-1980
	cp 20
	jr nc,pd2
	add a,80
	ld b,a
	ld a,19
	jr pd3
pd2:	sub 20
	ld b,a
	ld a,20
pd3:	push bc
	call p2
	pop bc
	ld a,b
	call p2
	ld a,'-'
	call putc
	pop de
	ld a,d
	and 1
	rlca
	rlca
	rlca
	ld b,a
	ld a,e
	rlca
	rlca
	rlca
	and 7
	or b			; 月
	push de
	call p2
	ld a,'-'
	call putc
	pop de
	ld a,e
	and 1Fh
	call p2
	ld a,' '
	call putc
	pop bc
	ld a,b
	rrca
	rrca
	rrca
	and 1Fh
	push bc
	call p2
	ld a,':'
	call putc
	pop bc
	ld a,b
	and 7
	rlca
	rlca
	rlca
	ld b,a
	ld a,c
	rlca
	rlca
	rlca
	and 7
	or b			; 分
	jp p2
; A=0..99 を2桁で出す
p2:	ld b,0
p2a:	cp 10
	jr c,p2b
	sub 10
	inc b
	jr p2a
p2b:	push af
	ld a,b
	add a,'0'
	call putc
	pop af
	add a,'0'
	jp putc
; A!=0 なら B、0 なら '-' を出す
attrc:	or a
	jr nz,ac1
	ld b,'-'
ac1:	ld a,b
	jp putc
; HL=レコード: サイズを右詰め8桁
psize:	ld de,24
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld h,d
	ld l,e
	ld d,b
	ld e,c			; DEHL = サイズ
	push hl
	ld hl,dbuf
	ld b,8
	ld a,' '
pz1:	ld (hl),a
	inc hl
	djnz pz1
	pop hl
	ld a,7
	ld (dpos),a
pz2:	call div10
	add a,'0'
	push hl
	push af
	ld a,(dpos)
	ld c,a
	ld b,0
	ld hl,dbuf
	add hl,bc
	pop af
	ld (hl),a
	pop hl
	ld a,h
	or l
	or d
	or e
	jr z,pz3
	ld a,(dpos)
	or a
	jr z,pz3
	dec a
	ld (dpos),a
	jr pz2
pz3:	ld hl,dbuf
	ld b,8
pz4:	ld a,(hl)
	call putc
	inc hl
	djnz pz4
	ret
; DEHL /= 10, A=余り
div10:	xor a
	ld b,32
d10l:	add hl,hl
	rl e
	rl d
	rla
	cp 10
	jr c,d10n
	sub 10
	inc l
d10n:	djnz d10l
	ret
; A=idx -> HL=arr+idx*32
recadr:	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,arr
	add hl,de
	ret
; HL=レコード -> B=表示の長さ(ディレクトリは \ を含む)
reclen:	ld b,0
	push hl
rln1:	ld a,(hl)
	or a
	jr z,rln2
	inc b
	inc hl
	jr rln1
rln2:	pop hl
	push hl
	ld de,23
	add hl,de
	ld a,(hl)
	and 10h
	jr z,rln3
	inc b
rln3:	pop hl
	ret
; HL=レコード: 名前を出す(ディレクトリは \ 付き)
pname:	push hl
	ld a,(colon)
	or a
	jr z,pn1
	push hl
	call pcol
	pop hl
pn1:	ld a,(hl)
	or a
	jr z,pn2
	call putc
	inc hl
	jr pn1
pn2:	pop hl
	ld de,23
	add hl,de
	ld a,(hl)
	and 10h
	jr z,pn3
	ld a,5Ch
	call putc
pn3:	ld a,(colused)
	or a
	ret z
	ld c,7			; 名前の後は白に戻す
	call pcset
	xor a
	ld (colused),a
	ret
; HL=レコード: 種類で色を決めて ESC b n を出す。ディレクトリ=水色 隠し/システム=紫 読み取り専用=黄 COM/BAT=緑 ZIP/LZH=赤 他=無し
pcol:	push hl
	ld de,23
	add hl,de
	ld b,(hl)
	pop hl
	ld a,b
	and 10h
	ld c,6
	jr nz,pcset
	ld a,b
	and 6
	ld c,5
	jr nz,pcset
	ld a,b
	and 1
	ld c,3
	jr nz,pcset
	push hl
pce:	ld a,(hl)
	or a
	jr z,pcn
	inc hl
	cp '.'
	jr nz,pce
	ld de,extab
pct:	ld a,(de)
	or a
	jr z,pcn
	push hl
	push de
	ld b,3
pcc:	ld a,(de)
	cp (hl)
	jr nz,pcx
	inc hl
	inc de
	djnz pcc
	ld a,(de)
	ld c,a
	pop de
	pop hl
	pop hl
	jr pcset
pcx:	pop de
	pop hl
	inc de
	inc de
	inc de
	inc de
	jr pct
pcn:	pop hl
	ret
pcset:	ld a,27
	call putc
	ld a,'b'
	call putc
	ld a,'0'
	add a,c
	call putc
	ld a,1
	ld (colused),a
	ret
extab:	defm "COM"
	defb 2
	defm "BAT"
	defb 2
	defm "ZIP"
	defb 1
	defm "LZH"
	defb 1
	defb 0
colon:	defb 0
colused:defb 0
putc:	push af
	push bc
	push de
	push hl
	ld e,a
	ld c,2
	call 5
	pop hl
	pop de
	pop bc
	pop af
	ret
crlf:	ld a,13
	call putc
	ld a,10
	jp putc
; 検索結果(dtabuf)を n 個のレコード(名前,属性,サイズ)として名前順に挿入する
addent:	ld a,(dtabuf+1)
	cp '.'
	jr nz,ae1
	ld a,(flags)
	and 2
	ret z
ae1:	ld a,(dtabuf+12)
	and 08h			; ボリュームラベルは出さない
	ret nz
	ld a,(dtabuf+12)
	and 06h			; 隠し/システム
	jr z,ae2
	ld a,(flags)
	and 2
	ret z
ae2:	ld a,(n)
	cp 150
	jr c,ae3
	ld a,1
	ld (ovf),a
	ret
ae3:	call n2ok		; 名前の9文字目以降(name2)があるか(h2)
	ld hl,dtabuf+1		; 名前を NAME[name2].EXT に整える
	ld de,tmprec
	ld b,8
cn1:	ld a,(hl)
	ld c,a
	ld a,(h2)
	or a
	jr nz,cn1a		; name2 があるときは name1 の8バイトをそのまま
	ld a,c
	cp ' '
	jr z,cn2
cn1a:	ld a,c
	ld (de),a
	inc de
	inc hl
	djnz cn1
cn2:	ld a,(h2)
	or a
	jr z,cn3
	ld hl,dtabuf+13
	ld b,10
cn2l:	ld a,(hl)
	or a
	jr z,cn3
	ld (de),a
	inc de
	inc hl
	djnz cn2l
cn3:	ld hl,dtabuf+9
	ld a,(hl)
	cp ' '
	jr z,cn5
	ld a,'.'
	ld (de),a
	inc de
	ld b,3
cn4:	ld a,(hl)
	cp ' '
	jr z,cn5
	ld (de),a
	inc de
	inc hl
	djnz cn4
cn5:	xor a
	ld (de),a
	ld a,(dtabuf+12)
	ld (tmprec+23),a
	ld hl,(dtabuf+29)
	ld (tmprec+24),hl
	ld hl,(dtabuf+31)
	ld (tmprec+26),hl
	ld hl,(dtabuf+25)
	ld (tmprec+28),hl
	ld hl,(dtabuf+23)
	ld (tmprec+30),hl
	ld a,(n)		; 挿入位置を探す
	ld b,a
	ld c,0
	ld hl,arr
fp:	ld a,c
	cp b
	jr z,fpend
	push hl
	push bc
	call cmpname
	pop bc
	pop hl
	jr c,fpend
	ld de,32
	add hl,de
	inc c
	jr fp
fpend:	push hl			; HL=挿入位置, C=番号
	ld a,(n)
	sub c
	jr z,ins1
	ld l,a			; (n-番号)*32 バイトを32バイト後ろへずらす
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld b,h
	ld c,l
	pop hl
	push hl
	add hl,bc
	dec hl
	ld d,h
	ld e,l
	ld hl,32
	add hl,de
	ex de,hl		; DE=末尾+32  HL=末尾
	lddr
ins1:	pop de
	ld hl,tmprec
	ld bc,32
	ldir
	ld hl,n
	inc (hl)
	ret
; 検索結果(dtabuf)に name2(+0Ch から10バイト。Human68k/TwentyOne 方式)があれば h2=1。
; name1 の最後(8バイト目)が空白でない / LA バイナリの印(+10h=A0h)でない / 先頭が00hでない /
; 00h になるまでが 20h 以上(7Fh,FFh でない) / 00h のあとは最後まで00h  のときだけ有効とする
; (Windows が +0Ch 以降に入れる大文字小文字フラグや作成時刻を名前と取り違えないため)
n2ok:	ld a,(dtabuf+8)
	cp ' '
	jr z,n2no
	ld a,(dtabuf+17)
	cp 0A0h
	jr z,n2no
	ld hl,dtabuf+13
	ld b,10
	ld a,(hl)
	or a
	jr z,n2no
n2l:	ld a,(hl)
	or a
	jr z,n2z
	cp 20h
	jr c,n2no
	cp 7Fh
	jr z,n2no
	cp 0FFh
	jr z,n2no
	inc hl
	djnz n2l
	jr n2yes
n2z:	dec b
	jr z,n2yes
	inc hl
	ld a,(hl)
	or a
	jr nz,n2no
	jr n2z
n2yes:	ld a,1
	ld (h2),a
	ret
n2no:	xor a
	ld (h2),a
	ret
; tmprec < (HL) ならキャリー
cmpname:ld de,tmprec
cm1:	ld a,(de)
	cp (hl)
	ret nz
	or a
	ret z
	inc de
	inc hl
	jr cm1
flags:	defb 0
h2:	defb 0
patp:	defw 0
curpat:	defw 0
desc:	defb 0
n:	defb 0
ovf:	defb 0
width:	defb 80
maxl:	defb 0
cw:	defb 0
cols:	defb 1
rows:	defb 1
row:	defb 0
col:	defb 0
idx:	defb 0
dpos:	defb 0
recp:	defw 0
defpat:	defm "*.*"
	defb 0
tail:	defb 5Ch,'*','.','*',0
mnone:	defm "ls: no match",13,10,"$"
mdir:	defm "   <DIR>$"
mtrunc:	defm "ls: too many files (150 shown)",13,10,"$"
musage:	defm "usage: ls [-l1am] [path]",13,10,"$"
; 作業領域(ファイルに含めない。TPAの 4000H から)
dbuf	equ 4000h
argbuf	equ 4010h
patbuf	equ 40A0h
fcb	equ 4130h
dtabuf	equ 4170h
tmprec	equ 41A0h
arr	equ 41C0h		; 150レコード x 32バイト (名前23(NUL含む。8+10+.+3) 属性1 サイズ4 日付2 時刻2)
