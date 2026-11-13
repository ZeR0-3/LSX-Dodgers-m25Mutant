; SED.COM - ストリームエディタ。 sed [-nE] [-e script] [-f file] [script] [file ...]     MIT License
;   コマンド: s/re/repl/[gpI数字]  y/abc/xyz/  p P d D n N g G h H x z q[n] Q[n] =  a i c (a text / a\ 改行 text)
;             b t T [label]  :label  { ... }   # コメント
;   アドレス: 行番号  $  /re/  \cREc  (後ろに I で大小無視)  first,last  first,+N  0,/re/  addr!cmd
;   正規表現: 既定は BRE( \( \) \| \+ \? )、-E / -r で ERE( ( ) | + ? )。 [..] . * ^ $ \< \> \n \t と \1-\9(置換側)。 & は一致全体。
;   置換側: & \1..\9 \n \t \& \\ 。 s の区切りは / 以外も可。 空の正規表現 // は直前に使ったもの。
;   file は複数・ワイルドカード可(同じディレクトリ)。省略=標準入力。 出力は標準出力(> でファイルへ)。
;   無いもの: w r e l F -i -s、{n,m}、\U \L \u \l \E、first~step、変数。 行は1000バイトまで。
;   終了コード: 0 / q の n / 1 スクリプトの誤り / 2 開けないファイルあり
RX_CAPS	equ	1
PSMAX	equ	1000
CMAX	equ	100
	org 0100h
	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld c,a
	ld b,0
	ld de,cmd
	or a
	jr z,s_nc0
	ldir
s_nc0:	xor a
	ld (de),a
	ld de,dtabuf
	ld c,1Ah
	call 5
	ld hl,cmd
; ---- 引数 ----
a_loop:	call skip
	ld a,(hl)
	or a
	jp z,a_done
	cp '-'
	jr nz,a_pos
	inc hl
	ld a,(hl)
	or a
	jr z,a_dash
	cp ' '
	jr z,a_dash
a_ol:	ld a,(hl)
	or a
	jr z,a_loop
	cp ' '
	jr z,a_loop
	inc hl
	cp 'n'
	jr z,a_n
	cp 'E'
	jr z,a_E
	cp 'r'
	jr z,a_E
	cp 'e'
	jr z,a_e
	cp 'f'
	jr z,a_f
	jp usage
a_n:	ld a,1
	ld (nflag),a
	jr a_ol
a_E:	ld a,1
	ld (eflag),a
	jr a_ol
a_dash:	dec hl
	jr a_pos
a_e:	call skip
	ld a,(hl)
	or a
	jp z,usage
	call gettok
	push hl
	ld hl,tokbuf
	call addscript
	pop hl
	ld a,1
	ld (havescr),a
	jp a_loop
a_f:	call skip
	ld a,(hl)
	or a
	jp z,usage
	call gettok
	push hl
	ld hl,tokbuf
	call readscript
	pop hl
	ld a,1
	ld (havescr),a
	jp a_loop
a_pos:	call gettok
	push hl
	ld hl,tokbuf
	call addpos
	pop hl
	jp a_loop
a_done:	ld a,(havescr)
	or a
	jr nz,a_have
	ld a,(nptok)
	or a
	jp z,usage
	ld hl,(ptab)
	call addscript
	ld a,1
	ld (pfirst),a
a_have:	ld hl,(sbp)
	ld (hl),0
	call parse
; ---- 入力ファイル名 ----
	ld a,(pfirst)
	ld (pi),a
fnx:	ld a,(nptok)
	ld c,a
	ld a,(pi)
	cp c
	jr nc,fdone
	ld l,a
	ld h,0
	add hl,hl
	ld de,ptab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld a,(nargf)
	inc a
	ld (nargf),a
	call do_one
	ld hl,pi
	inc (hl)
	jr fnx
fdone:	ld hl,flist
	ld (flrd),hl
	jp cyc
; トークン(引用符つきなら中身)を tokbuf へ。 HL=後ろ
gettok:	ld de,tokbuf
	ld c,0
	ld b,' '
	ld a,(hl)
	cp '"'
	jr z,gt_q
	cp 27h
	jr nz,gt_l
gt_q:	ld b,a
	ld c,1
	inc hl
gt_l:	ld a,(hl)
	or a
	jr z,gt_e
	cp b
	jr z,gt_m
	ld (de),a
	inc de
	inc hl
	jr gt_l
gt_m:	ld a,c
	or a
	jr z,gt_e
	inc hl
gt_e:	xor a
	ld (de),a
	ret
; スクリプトバッファへ A を足す
sput:	push hl
	push de
	ld hl,(sbp)
	ld de,sbuf+2040
	or a
	sbc hl,de
	jp nc,e_big
	ld hl,(sbp)
	ld (hl),a
	inc hl
	ld (sbp),hl
	pop de
	pop hl
	ret
addscript:
	ld a,(hl)
	or a
	jr z,as2
	call sput
	inc hl
	jr addscript
as2:	ld a,0Ah
	jp sput
; -f file
readscript:
	ex de,hl
	ld a,1
	ld c,43h
	call 5
	or a
	jp nz,e_openf
	ld a,b
	ld (fh),a
rs_rd:	ld a,(fh)
	ld b,a
	ld de,ibuf
	ld hl,512
	ld c,48h
	call 5
	or a
	jr nz,rs_end
	ld a,h
	or l
	jr z,rs_end
	ld b,h
	ld c,l
	ld hl,ibuf
rs_b:	ld a,(hl)
	inc hl
	cp 0Dh
	jr z,rs_s
	cp 1Ah
	jr z,rs_s
	call sput
rs_s:	dec bc
	ld a,b
	or c
	jr nz,rs_b
	jr rs_rd
rs_end:	ld a,(fh)
	ld b,a
	ld c,45h
	call 5
	ld a,0Ah
	jp sput
; 位置引数を ptpool へ
addpos:	ld a,(nptok)
	cp 16
	jp nc,usage
	ld e,a
	ld d,0
	push hl
	ld hl,ptab
	add hl,de
	add hl,de
	ld de,(ptp)
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,nptok
	inc (hl)
	pop hl
ap1:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,ap1
	ld (ptp),de
	ret
; ================= スクリプトの構文解析 =================
peek:	ld hl,(scp)
	ld a,(hl)
	ret
getc:	ld hl,(scp)
	ld a,(hl)
	or a
	ret z
	inc hl
	ld (scp),hl
	ret
skipws:	call peek
	cp ' '
	jr z,sw2
	cp 9
	ret nz
sw2:	call getc
	jr skipws
skipsep:
	call peek
	cp ' '
	jr z,ss2
	cp 9
	jr z,ss2
	cp 0Ah
	jr z,ss2
	cp ';'
	ret nz
ss2:	call getc
	jr skipsep
; 10進数 -> DE
getnum:	ld de,0
gn1:	call peek
	sub '0'
	cp 10
	ret nc
	ld c,a
	call getc
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	ld e,c
	ld d,0
	add hl,de
	ex de,hl
	jr gn1
parse:	ld hl,sbuf
	ld (scp),hl
p_next:	call skipsep
	call peek
	or a
	jp z,p_done
	cp '#'
	jr nz,p_cmd
p_cm:	call getc
	jr z,p_next
	cp 0Ah
	jr nz,p_cm
	jr p_next
p_cmd:	ld a,(ncmd)
	cp CMAX
	jp nc,e_many
	call recptr
	push hl
	pop ix
	ld (hl),0
	ld d,h
	ld e,l
	inc de
	ld bc,15
	ldir
	call paddr
	jr nc,p_noaddr
	ld a,(ad_kind)
	ld (ix+2),a
	ld hl,(ad_val)
	ld (ix+3),l
	ld (ix+4),h
	set 2,(ix+1)
	call skipws
	call peek
	cp ','
	jr nz,p_noaddr
	call getc
	call skipws
	call peek
	cp '+'
	jr nz,p_a2n
	call getc
	call getnum
	ld (ix+6),e
	ld (ix+7),d
	ld (ix+5),4
	jr p_a2ok
p_a2n:	call paddr
	jp nc,e_addr
	ld a,(ad_kind)
	ld (ix+5),a
	ld hl,(ad_val)
	ld (ix+6),l
	ld (ix+7),h
p_a2ok:	set 3,(ix+1)
	ld a,(ix+2)
	cp 1
	jr nz,p_noaddr
	ld a,(ix+3)
	or (ix+4)
	jr nz,p_noaddr
	ld a,(ix+5)
	cp 3
	jr nz,p_noaddr
	set 1,(ix+1)
p_noaddr:
	call skipws
p_neg:	call peek
	cp '!'
	jr nz,p_c2
	set 0,(ix+1)
	call getc
	call skipws
	jr p_neg
p_c2:	call getc
	jp z,e_miss
	ld (ix+0),a
	cp '{'
	jp z,c_lb
	cp '}'
	jp z,c_rb
	cp ':'
	jp z,c_lab
	cp 's'
	jp z,c_s
	cp 'y'
	jp z,c_y
	cp 'a'
	jp z,c_text
	cp 'i'
	jp z,c_text
	cp 'c'
	jp z,c_text
	cp 'b'
	jp z,c_br
	cp 't'
	jp z,c_br
	cp 'T'
	jp z,c_br
	cp 'q'
	jp z,c_q
	cp 'Q'
	jp z,c_q
	ld hl,cmdlist
p_c3:	cp (hl)
	jr z,p_end
	inc hl
	ld b,a
	ld a,(hl)
	or a
	jp z,e_unk
	ld a,b
	jr p_c3
cmdlist: defm "pPdDnNgGhHxz=",0
; コマンドの後ろ
p_end:	call skipws
	call peek
	or a
	jr z,p_adv
	cp ';'
	jr z,p_eat
	cp 0Ah
	jr z,p_eat
	cp '}'
	jr z,p_adv
	cp '#'
	jr z,p_adv
	jp e_extra
p_eat:	call getc
p_adv:	ld hl,ncmd
	inc (hl)
	jp p_next
recptr:	ld a,(ncmd)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,cbuf
	add hl,de
	ret
; { }
c_lb:	ld a,(bsp)
	cp 16
	jp nc,e_brace
	ld e,a
	ld d,0
	ld hl,bstk
	add hl,de
	ld a,(ncmd)
	ld (hl),a
	ld hl,bsp
	inc (hl)
	jp p_adv
c_rb:	ld a,(bsp)
	or a
	jp z,e_brace
	dec a
	ld (bsp),a
	ld e,a
	ld d,0
	ld hl,bstk
	add hl,de
	ld l,(hl)
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,cbuf+8
	add hl,de
	ld a,(ncmd)
	ld (hl),a
	inc hl
	ld (hl),0
	jp p_end
; :label  b/t/T label
c_lab:
c_br:	call skipws
	ld hl,(spp)
	ld (ix+8),l
	ld (ix+9),h
	ex de,hl
cb1:	call peek
	or a
	jr z,cb2
	cp ' '
	jr z,cb2
	cp 9
	jr z,cb2
	cp 0Ah
	jr z,cb2
	cp ';'
	jr z,cb2
	cp '}'
	jr z,cb2
	call getc
	call sp_put
	jr cb1
cb2:	xor a
	call sp_put
	ld (spp),de
	jp p_end
; q Q [n]
c_q:	call skipws
	call getnum
	ld (ix+8),e
	jp p_end
; a i c
c_text:	call skipws
	call peek
	cp 5Ch
	jr nz,ct_go
	call getc
	call peek
	cp 0Ah
	jr nz,ct_go
	call getc
ct_go:	ld hl,(spp)
	ld (ix+8),l
	ld (ix+9),h
	ex de,hl
ct_l:	call getc
	jr z,ct_e
	cp 5Ch
	jr nz,ct_n
	call getc
	jr z,ct_e
	call sp_put
	jr ct_l
ct_n:	cp 0Ah
	jr z,ct_e
	call sp_put
	call islead
	jr nc,ct_l
	call getc
	jr z,ct_e
	call sp_put
	jr ct_l
ct_e:	xor a
	call sp_put
	ld (spp),de
	jp p_adv
; 文字列プールへ A を足す (DE=書く場所)
sp_put:	push hl
	ld hl,spool+1500
	or a
	sbc hl,de
	jp nc,sp_ok
	jp e_big
sp_ok:	pop hl
	ld (de),a
	inc de
	ret
; s/re/repl/flags
c_s:	call getc
	jp z,e_unterm
	cp 5Ch
	jp z,e_unterm
	cp 0Ah
	jp z,e_unterm
	call getre
	ld hl,(spp)
	ld (ix+10),l
	ld (ix+11),h
	ex de,hl
c_sr:	call getc
	jp z,e_unterm
	ld c,a
	ld a,(delim)
	cp c
	jr z,c_sre
	ld a,c
	cp 5Ch
	jr z,c_sbs
	cp '&'
	jr z,c_samp
	cp 0Ah
	jp z,e_unterm
	call sp_put
	call islead
	jr nc,c_sr
	call getc
	jp z,e_unterm
	call sp_put
	jr c_sr
c_samp:	ld a,1
	call sp_put
	ld a,'0'
	call sp_put
	jr c_sr
c_sbs:	call getc
	jp z,e_unterm
	ld c,a
	sub '0'
	cp 10
	jr nc,c_sb2
	ld a,1
	call sp_put
	ld a,c
	call sp_put
	jr c_sr
c_sb2:	ld a,c
	cp 'n'
	ld a,0Ah
	jr z,c_sb3
	ld a,c
	cp 't'
	ld a,9
	jr z,c_sb3
	ld a,c
c_sb3:	call sp_put
	jr c_sr
c_sre:	xor a
	call sp_put
	ld (spp),de
	xor a
	ld (sf_g),a
	ld (sf_p),a
	ld (sf_i),a
	ld (sf_n),a
c_sf:	call peek
	cp 'g'
	jr nz,c_sf1
	ld (sf_g),a
	jr c_sf9
c_sf1:	cp 'p'
	jr nz,c_sf2
	ld (sf_p),a
	jr c_sf9
c_sf2:	cp 'I'
	jr z,c_sf3
	cp 'i'
	jr nz,c_sf4
c_sf3:	ld (sf_i),a
	jr c_sf9
c_sf4:	cp 'w'
	jp z,e_unsup
	sub '0'
	cp 10
	jr nc,c_sfe
	call getnum
	ld a,d
	or a
	jp nz,e_unsup
	ld a,e
	or a
	jp z,e_unsup
	ld (sf_n),a
	jr c_sf
c_sf9:	call getc
	jr c_sf
c_sfe:	ld a,(sf_i)
	call addre
	ld (ix+8),a
	ld (ix+9),0
	ld a,(sf_g)
	or a
	ld a,0
	jr z,c_sg1
	inc a
c_sg1:	ld c,a
	ld a,(sf_p)
	or a
	jr z,c_sg2
	set 1,c
c_sg2:	ld (ix+12),c
	ld a,(sf_n)
	ld (ix+13),a
	jp p_end
; y/abc/xyz/
c_y:	call getc
	jp z,e_unterm
	cp 5Ch
	jp z,e_unterm
	cp 0Ah
	jp z,e_unterm
	ld (delim),a
	ld hl,(spp)
	ld (ix+8),l
	ld (ix+9),h
	ex de,hl
	call y_part
	ld (ycnt),bc
	ld hl,(spp)
	ld (spp),de
	ld (ix+10),e
	ld (ix+11),d
	call y_part
	ld hl,(ycnt)
	or a
	sbc hl,bc
	jp nz,e_ylen
	ld (spp),de
	jp p_end
; delim までを DE へ (BC=バイト数)
y_part:	ld bc,0
yp1:	call getc
	jp z,e_unterm
	ld l,a
	ld a,(delim)
	cp l
	jr z,yp_e
	ld a,l
	cp 5Ch
	jr nz,yp3
	call getc
	jp z,e_unterm
	cp 'n'
	jr nz,yp2
	ld a,0Ah
yp2:	call sp_put
	inc bc
	jr yp1
yp3:	call sp_put
	inc bc
	call islead
	jr nc,yp1
	call getc
	jp z,e_unterm
	call sp_put
	inc bc
	jr yp1
yp_e:	xor a
	call sp_put
	ret
; ---- 正規表現の取り出し: A=区切り -> rebuf ----
getre:	ld (delim),a
	ld de,rebuf
	ld a,1
	ld (atst),a
gr_l:	call getc
	jp z,e_unterm
	ld c,a
	ld a,(delim)
	cp c
	jp z,gr_end
	ld a,c
	cp 5Ch
	jp z,gr_bs
	cp '['
	jp z,gr_br
	cp 0Ah
	jp z,e_unterm
	call islead
	jr c,gr_two
	ld b,a
	ld a,(eflag)
	or a
	ld a,b
	jr nz,gr_plain
	cp '('
	jr z,gr_esc
	cp ')'
	jr z,gr_esc
	cp '|'
	jr z,gr_esc
	cp '+'
	jr z,gr_esc
	cp '?'
	jr z,gr_esc
	cp '*'
	jr nz,gr_plain
	ld b,a
	ld a,(atst)
	or a
	ld a,b
	jr z,gr_plain
gr_esc:	ld b,a
	ld a,5Ch
	call gr_put
	ld a,b
	call gr_put
	xor a
	ld (atst),a
	jr gr_l
gr_plain:
	call gr_put
	ld b,a
	xor a
	ld c,a
	ld a,b
	cp '^'
	jr nz,gr_p2
	inc c
gr_p2:	ld a,c
	ld (atst),a
	jr gr_l
gr_two:	call gr_put
	call getc
	jp z,e_unterm
	call gr_put
	xor a
	ld (atst),a
	jr gr_l
gr_bs:	call getc
	jp z,e_unterm
	ld c,a
	ld a,(delim)
	cp c
	jr z,gr_dl
	ld a,c
	cp 'n'
	jr nz,gr_b1
	ld a,0Ah
	jr gr_plain
gr_b1:	cp 't'
	jr nz,gr_b2
	ld a,9
	jr gr_plain
gr_b2:	ld b,a
	ld a,(eflag)
	or a
	ld a,b
	jr nz,gr_pass
	cp '('
	jr z,gr_bare
	cp ')'
	jr z,gr_bare
	cp '|'
	jr z,gr_bare
	cp '+'
	jr z,gr_bare
	cp '?'
	jr z,gr_bare
	cp '{'
	jr z,gr_bare
	cp '}'
	jr z,gr_bare
gr_pass:
	ld b,a
	ld a,5Ch
	call gr_put
	ld a,b
	call gr_put
	xor a
	ld (atst),a
	jp gr_l
gr_bare:
	call gr_put
	ld b,a
	xor a
	cp b
	ld a,b
	ld c,0
	cp '('
	jr z,gr_ba1
	cp '|'
	jr nz,gr_ba2
gr_ba1:	ld c,1
gr_ba2:	ld a,c
	ld (atst),a
	jp gr_l
; 区切り文字そのもの(\/ など)。正規表現で特別な文字なら \ をつけて文字として扱う
gr_dl:	ld hl,respec
gd1:	ld a,(hl)
	or a
	jr z,gd2
	cp c
	jr z,gd3
	inc hl
	jr gd1
gd3:	ld a,5Ch
	call gr_put
gd2:	ld a,c
	call gr_put
	xor a
	ld (atst),a
	jp gr_l
respec:	defm ".*[]^$+?(){}|",0
; [ ... ] はそのまま写す
gr_br:	ld a,'['
	call gr_put
	call peek
	cp '^'
	jr nz,gb1
	call getc
	ld a,'^'
	call gr_put
	call peek
gb1:	cp ']'
	jr nz,gb2
	call getc
	ld a,']'
	call gr_put
gb2:	call getc
	jp z,e_unterm
	cp ']'
	jr z,gb3
	ld c,a
	call gr_put
	ld a,c
	call islead
	jr nc,gb2
	call getc
	jp z,e_unterm
	call gr_put
	jr gb2
gb3:	call gr_put
	xor a
	ld (atst),a
	jp gr_l
gr_end:	xor a
	ld (de),a
	ret
gr_put:	push hl
	ld hl,rebuf+250
	or a
	sbc hl,de
	pop hl
	jp c,e_long
	ld (de),a
	inc de
	ret
; アドレスを1つ読む。 CF=1:あった (ad_kind: 1行 2$ 3正規表現 / ad_val)
paddr:	call peek
	cp '$'
	jr z,pa_dol
	cp '/'
	jr z,pa_re
	cp 5Ch
	jr z,pa_re2
	sub '0'
	cp 10
	jr nc,pa_no
	call getnum
	ld (ad_val),de
	ld a,1
	ld (ad_kind),a
	scf
	ret
pa_dol:	call getc
	ld a,2
	ld (ad_kind),a
	scf
	ret
pa_re2:	call getc
	call getc
	jp z,e_unterm
	jr pa_re3
pa_re:	call getc
pa_re3:	call getre
	ld c,0
	call peek
	cp 'I'
	jr nz,pa_r4
	call getc
	ld c,1
pa_r4:	ld a,c
	call addre
	ld l,a
	ld h,0
	ld (ad_val),hl
	ld a,3
	ld (ad_kind),a
	scf
	ret
pa_no:	and a
	ret
; rebuf を組んで正規表現表へ。 A=1:大小無視 -> A=番号(0FFh=空=直前のもの)
addre:	ld (ic),a
	ld a,(rebuf)
	or a
	jr nz,ar1
	ld a,0FFh
	ret
ar1:	ld a,(ic)
	or a
	jr z,ar2
	ld hl,rebuf
ar_lo:	ld a,(hl)
	or a
	jr z,ar2
	inc hl
	call islead
	jr c,ar_l2
	cp 'A'
	jr c,ar_lo
	cp 'Z'+1
	jr nc,ar_lo
	add a,20h
	dec hl
	ld (hl),a
	inc hl
	jr ar_lo
ar_l2:	ld a,(hl)
	or a
	jr z,ar2
	inc hl
	jr ar_lo
ar2:	ld hl,rebuf
	call re_comp
	jp c,e_re
	ld hl,(rcp)
	ld de,rx_prog
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld hl,(rpp)
	push hl
	add hl,bc
	ld de,5
	add hl,de
	ld de,rpool+3072
	or a
	sbc hl,de
	pop hl
	jp nc,e_pool
	ld a,(nrx)
	cp 32
	jp nc,e_pool
	push hl
	ld e,a
	ld d,0
	ld hl,rtab
	add hl,de
	add hl,de
	pop de
	ld (hl),e
	inc hl
	ld (hl),d
	ex de,hl
	ld a,(anch)
	ld (hl),a
	inc hl
	ld a,(haslsp)
	ld (hl),a
	inc hl
	ld a,(ic)
	ld (hl),a
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ex de,hl
	ld hl,rx_prog
	ldir
	ld (rpp),de
	ld a,(nrx)
	ld c,a
	inc a
	ld (nrx),a
	ld a,c
	ret
p_done:	ld a,(bsp)
	or a
	jp nz,e_brace
	ld ix,cbuf
	xor a
	ld (ri),a
rv1:	ld a,(ncmd)
	ld b,a
	ld a,(ri)
	cp b
	jr nc,rv_end
	ld a,(ix+0)
	cp 'b'
	jr z,rv2
	cp 't'
	jr z,rv2
	cp 'T'
	jr nz,rv_n
rv2:	ld l,(ix+8)
	ld h,(ix+9)
	ld a,(hl)
	or a
	jr nz,rv3
	ld a,(ncmd)
	jr rv_set
rv3:	push ix
	call findlab
	pop ix
	jp nz,e_nolab
rv_set:	ld (ix+8),a
	ld (ix+9),0
rv_n:	ld de,16
	add ix,de
	ld hl,ri
	inc (hl)
	jr rv1
rv_end:	ret
findlab:
	ld (lbn),hl
	ld ix,cbuf
	xor a
	ld (rj),a
fl1:	ld a,(ncmd)
	ld b,a
	ld a,(rj)
	cp b
	jr nc,fl_no
	ld a,(ix+0)
	cp ':'
	jr nz,fl2
	ld e,(ix+8)
	ld d,(ix+9)
	ld hl,(lbn)
	call strcmp
	jr z,fl_yes
fl2:	ld de,16
	add ix,de
	ld hl,rj
	inc (hl)
	jr fl1
fl_yes:	ld a,(rj)
	cp a
	ret
fl_no:	or 1
	ret
strcmp:	ld a,(de)
	cp (hl)
	ret nz
	or a
	ret z
	inc hl
	inc de
	jr strcmp
; ================= 実行 =================
cyc:	ld a,(rstf)
	or a
	jr z,cy_rd
	xor a
	ld (rstf),a
	jr cy_run
cy_rd:	ld hl,ps
	call rline
	jp c,finish
	ld hl,(lno)
	inc hl
	ld (lno),hl
	xor a
	ld (tflag),a
cy_run:	call runscript
	ld (rcode),a
	cp 1
	jr z,cy_end
	cp 2
	jr z,cy_rst
	cp 4
	jp z,finish
	ld a,(nflag)
	or a
	jr nz,cy_q
	ld hl,ps
	call pps
	call pnl
cy_q:	call flushaq
	ld a,(rcode)
	cp 3
	jp z,finish
	jr cyc
cy_end:	call flushaq
	jr cyc
cy_rst:	call flushaq
	ld a,1
	ld (rstf),a
	jr cyc
finish:	call flush
	ld a,(xstat)
	or a
	jr nz,fx
	ld a,(rcopen)
fx:	ld b,a
	ld c,62h
	call 5
	jp 0
; 戻り値 A: 0=自動表示して次へ 1=表示せず次へ 2=D(読まずにやり直し) 3=q(表示して終了) 4=Q(表示せず終了)
runscript:
	ld hl,cbuf
	ld (curc),hl
rs_loop:
	ld a,(ncmd)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,cbuf
	add hl,de
	ex de,hl
	ld hl,(curc)
	or a
	sbc hl,de
	jr c,rs_go
	xor a
	ret
rs_go:	ld ix,(curc)
	call select
	jr c,rs_exec
	ld ix,(curc)
	ld a,(ix+0)
	cp '{'
	jr nz,rs_next
	ld l,(ix+8)
	ld h,(ix+9)
	inc hl
	call idx2addr
	ld (curc),hl
	jr rs_loop
rs_next:
	ld hl,(curc)
	ld de,16
	add hl,de
	ld (curc),hl
	jr rs_loop
idx2addr:
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,cbuf
	add hl,de
	ret
rs_exec:
	ld ix,(curc)
	ld a,(ix+0)
	cp 's'
	jp z,h_s
	cp 'p'
	jp z,h_p
	cp 'd'
	jp z,h_d
	cp '{'
	jp z,rs_next
	cp '}'
	jp z,rs_next
	cp ':'
	jp z,rs_next
	cp 'b'
	jp z,h_b
	cp 't'
	jp z,h_t
	cp 'T'
	jp z,h_T
	cp 'n'
	jp z,h_n
	cp 'N'
	jp z,h_N
	cp 'D'
	jp z,h_D
	cp 'P'
	jp z,h_P
	cp 'g'
	jp z,h_g
	cp 'G'
	jp z,h_G
	cp 'h'
	jp z,h_h
	cp 'H'
	jp z,h_H
	cp 'x'
	jp z,h_x
	cp 'z'
	jp z,h_z
	cp '='
	jp z,h_eq
	cp 'q'
	jp z,h_q
	cp 'Q'
	jp z,h_Q
	cp 'a'
	jp z,h_a
	cp 'i'
	jp z,h_i
	cp 'c'
	jp z,h_c
	cp 'y'
	jp z,h_y
	jp rs_next
h_p:	ld hl,ps
	call pps
	call pnl
	jp rs_next
h_P:	ld hl,ps
hP1:	ld a,(hl)
	or a
	jr z,hP2
	cp 0Ah
	jr z,hP2
	inc hl
	call putch
	jr hP1
hP2:	call pnl
	jp rs_next
h_d:	xor a
	ld (ps),a
	ld a,1
	ret
h_D:	ld hl,ps
hD1:	ld a,(hl)
	or a
	jr z,h_d
	cp 0Ah
	jr z,hD2
	inc hl
	jr hD1
hD2:	inc hl
	ld de,ps
hD3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,hD3
	ld a,2
	ret
h_n:	call fill
	jr c,hn_q
	ld a,(nflag)
	or a
	jr nz,hn1
	ld hl,ps
	call pps
	call pnl
hn1:	call flushaq
	ld hl,ps
	call rline
	ld hl,(lno)
	inc hl
	ld (lno),hl
	jp rs_next
hn_q:	ld a,3
	ret
h_N:	call fill
	jr c,hn_q
	call flushaq
	ld hl,ps
	call strend
	ld (hl),0Ah
	inc hl
	call rline
	ld hl,(lno)
	inc hl
	ld (lno),hl
	jp rs_next
h_g:	ld hl,hs
	ld de,ps
	call strcpy
	jp rs_next
h_h:	ld hl,ps
	ld de,hs
	call strcpy
	jp rs_next
h_G:	ld hl,hs
	ld de,ps
	call catlf
	jp rs_next
h_H:	ld hl,ps
	ld de,hs
	call catlf
	jp rs_next
h_x:	ld hl,ps
	ld de,nbuf
	call strcpy
	ld hl,hs
	ld de,ps
	call strcpy
	ld hl,nbuf
	ld de,hs
	call strcpy
	jp rs_next
h_z:	xor a
	ld (ps),a
	jp rs_next
h_eq:	ld hl,(lno)
	call pdec
	call pnl
	jp rs_next
h_q:	ld a,(ix+8)
	ld (xstat),a
	ld a,3
	ret
h_Q:	ld a,(ix+8)
	ld (xstat),a
	ld a,4
	ret
h_a:	ld a,(aqn)
	cp 8
	jp nc,rs_next
	ld e,a
	ld d,0
	ld hl,aq
	add hl,de
	add hl,de
	ld e,(ix+8)
	ld d,(ix+9)
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,aqn
	inc (hl)
	jp rs_next
h_i:	ld l,(ix+8)
	ld h,(ix+9)
	call pps
	call pnl
	jp rs_next
h_c:	bit 1,(ix+1)
	jr nz,hc1
	ld l,(ix+8)
	ld h,(ix+9)
	call pps
	call pnl
hc1:	jp h_d
h_b:	ld l,(ix+8)
	ld h,(ix+9)
	call idx2addr
	ld (curc),hl
	jp rs_loop
h_t:	ld a,(tflag)
	or a
	jp z,rs_next
	xor a
	ld (tflag),a
	jr h_b
h_T:	ld a,(tflag)
	or a
	jr z,h_b
	xor a
	ld (tflag),a
	jp rs_next
h_y:	ld l,(ix+8)
	ld h,(ix+9)
	ld (y_src),hl
	ld l,(ix+10)
	ld h,(ix+11)
	ld (y_dst),hl
	ld hl,ps
hy1:	ld a,(hl)
	or a
	jp z,rs_next
	call islead
	jr c,hy_two
	ld c,a
	push hl
	ld hl,(y_src)
	ld de,(y_dst)
hy2:	ld a,(hl)
	or a
	jr z,hy_nf
	cp c
	jr z,hy_f
	inc hl
	inc de
	jr hy2
hy_f:	ld a,(de)
	pop hl
	ld (hl),a
	inc hl
	jr hy1
hy_nf:	pop hl
	inc hl
	jr hy1
hy_two:	inc hl
	ld a,(hl)
	or a
	jp z,rs_next
	inc hl
	jr hy1
; ---- s ----
h_s:	ld a,(ix+8)
	ld (s_re),a
	ld l,(ix+10)
	ld h,(ix+11)
	ld (s_rp),hl
	ld a,(ix+12)
	ld (s_fl),a
	ld a,(ix+13)
	or a
	jr nz,hs0
	inc a
hs0:	ld (s_nth),a
	ld a,(s_re)
	call rmatch
	jp nc,rs_next
	ld hl,ps
	ld de,(mbase)
	or a
	sbc hl,de
	ld (s_dif),hl
	ld hl,nbuf
	ld (np),hl
	ld hl,ps
	ld (cpp),hl
	xor a
	ld (s_cnt),a
	ld (s_did),a
	ld hl,0FFFFh
	ld (s_prev),hl
hs_lp:	ld hl,(mend)
	ld de,(mstart)
	or a
	sbc hl,de
	jr nz,hs_ne
	ld hl,(mstart)
	ld de,(s_prev)
	or a
	sbc hl,de
	jr z,hs_adv
hs_ne:	ld hl,s_cnt
	inc (hl)
	ld hl,(mstart)
	ld de,(s_dif)
	add hl,de
	ex de,hl
	ld hl,(cpp)
	call cpyrng
	ld a,(s_cnt)
	ld c,a
	ld a,(s_nth)
	cp c
	jr c,hs_rep
	jr z,hs_rep
	ld hl,(mstart)
	ld de,(s_dif)
	add hl,de
	push hl
	ld hl,(mend)
	add hl,de
	ex de,hl
	pop hl
	call cpyrng
	jr hs_aft
hs_rep:	call expand_repl
	ld a,1
	ld (s_did),a
hs_aft:	ld hl,(mend)
	ld de,(s_dif)
	add hl,de
	ld (cpp),hl
	ld hl,(mend)
	ld (s_prev),hl
	ld a,(s_did)
	or a
	jr z,hs_cont
	ld a,(s_fl)
	and 1
	jr z,hs_fin
hs_cont:
	ld hl,(mend)
	ld de,(mstart)
	or a
	sbc hl,de
	ld hl,(mend)
	jr nz,hs_srch
hs_adv:	ld hl,(cpp)
	ld a,(hl)
	or a
	jr z,hs_fin
	inc hl
	ld (cpp),hl
	call nput
	call islead
	jr nc,hs_pos
	ld hl,(cpp)
	ld a,(hl)
	or a
	jr z,hs_pos
	inc hl
	ld (cpp),hl
	call nput
hs_pos:	ld hl,(cpp)
	ld de,(s_dif)
	or a
	sbc hl,de
hs_srch:
	call rx_from
	jp c,hs_lp
hs_fin:	ld hl,(cpp)
hf1:	ld a,(hl)
	or a
	jr z,hf2
	inc hl
	call nput
	jr hf1
hf2:	ld hl,(np)
	ld (hl),0
	ld a,(s_did)
	or a
	jp z,rs_next
	ld hl,nbuf
	ld de,ps
	call strcpy
	ld a,1
	ld (tflag),a
	ld a,(s_fl)
	and 2
	jp z,rs_next
	ld hl,ps
	call pps
	call pnl
	jp rs_next
; 置換文字列を nbuf へ (\1..\9, &)
expand_repl:
	ld hl,(s_rp)
ex1:	ld a,(hl)
	inc hl
	or a
	ret z
	cp 1
	jr z,exg
	call nput
	jr ex1
exg:	ld a,(hl)
	inc hl
	sub '0'
	push hl
	call grp
	pop hl
	jr ex1
grp:	or a
	jr nz,gr_k
	ld hl,(mstart)
	ld de,(mend)
	jr gr_cp
gr_k:	add a,a
	add a,a
	ld l,a
	ld h,0
	ld de,caps
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld a,d
	or e
	ret z
	ld a,b
	or c
	ret z
	ld h,d
	ld l,e
	ld d,b
	ld e,c
gr_cp:	ld bc,(s_dif)
	add hl,bc
	ex de,hl
	add hl,bc
	ex de,hl
; HL..DE(含まない) を nbuf へ
cpyrng:	push hl
	or a
	sbc hl,de
	pop hl
	ret nc
	ld a,(hl)
	inc hl
	call nput
	jr cpyrng
nput:	push hl
	push de
	ld hl,(np)
	ld de,nbuf+PSMAX
	or a
	sbc hl,de
	jr nc,np_x
	ld hl,(np)
	ld (hl),a
	inc hl
	ld (np),hl
np_x:	pop de
	pop hl
	ret
; ---- 正規表現の照合 ----
; A=番号(0FFh=直前) -> CF=1:ps に一致。 mbase=照合した文字列の先頭
rmatch:	cp 0FFh
	jr nz,rm1
	ld a,(lastre)
	cp 0FFh
	jp z,e_norx
rm1:	ld (lastre),a
	ld l,a
	ld h,0
	add hl,hl
	ld de,rtab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld a,(hl)
	ld (anch),a
	inc hl
	ld a,(hl)
	ld (haslsp),a
	inc hl
	ld a,(hl)
	ld (rcic),a
	inc hl
	inc hl
	inc hl
	ld (rx_cur),hl
	ld hl,ps
	ld (mbase),hl
	ld a,(rcic)
	or a
	jr z,rm2
	ld hl,ps
	ld de,mbuf
	call lowcpy
	ld hl,mbuf
	ld (mbase),hl
rm2:	ld hl,(mbase)
	call rx_find
	ret
; ---- アドレスの判定 ----
a1match:
	ld a,(ix+2)
	cp 1
	jr z,am_ln
	cp 2
	jr z,am_dol
	ld a,(ix+3)
	call rmatch
	ld ix,(curc)
	ret
am_ln:	ld l,(ix+3)
	ld h,(ix+4)
	ld de,(lno)
	or a
	sbc hl,de
	jr nz,am_no
	scf
	ret
am_no:	and a
	ret
am_dol:	call fill
	ld ix,(curc)
	ret
islast:	call fill
	ld ix,(curc)
	ret
; IX=命令 -> CF=1:選ばれた
select:	ld a,(ix+1)
	and 4
	jr z,sl_yes
	ld a,(ix+1)
	and 8
	jr nz,sl_range
	call a1match
	jp sl_neg
sl_yes:	scf
	jp sl_neg
sl_range:
	bit 1,(ix+1)
	jr nz,sl_act
	call a1match
	jp nc,sl_neg
	ld a,(ix+5)
	cp 1
	jr z,sr_ln
	cp 2
	jr z,sr_dol
	cp 3
	jr z,sr_on
	ld l,(ix+6)
	ld h,(ix+7)
	ld a,h
	or l
	jr z,sr_one
	ld de,(lno)
	add hl,de
	ld (ix+14),l
	ld (ix+15),h
	jr sr_on
sr_ln:	ld l,(ix+6)
	ld h,(ix+7)
	ld de,(lno)
	or a
	sbc hl,de
	jr c,sr_one
	jr z,sr_one
	jr sr_on
sr_dol:	call islast
	jr c,sr_one
sr_on:	set 1,(ix+1)
sr_one:	scf
	jp sl_neg
sl_act:	ld a,(ix+5)
	cp 1
	jr z,sa_ln
	cp 2
	jr z,sa_dol
	cp 3
	jr z,sa_re
	ld l,(ix+14)
	ld h,(ix+15)
	ld de,(lno)
	or a
	sbc hl,de
	jr z,sa_end
	jr c,sa_end
	jr sa_yes
sa_ln:	ld l,(ix+6)
	ld h,(ix+7)
	ld de,(lno)
	or a
	sbc hl,de
	jr z,sa_end
	jr c,sa_end
	jr sa_yes
sa_dol:	call islast
	jr c,sa_end
	jr sa_yes
sa_re:	ld a,(ix+6)
	call rmatch
	ld ix,(curc)
	jr c,sa_end
sa_yes:	scf
	jp sl_neg
sa_end:	res 1,(ix+1)
	scf
sl_neg:	bit 0,(ix+1)
	ret z
	ccf
	ret
; ================= 入出力 =================
; 入力に1バイトでもあるか -> CF=1:もう無い
fill:	ld hl,(icnt)
	ld a,h
	or l
	ret nz
fi_a:	ld a,(inh)
	cp 0FFh
	jr z,fi_open
	ld b,a
	ld de,ibuf
	ld hl,512
	ld c,48h
	call 5
	or a
	jr nz,fi_eof
	ld a,h
	or l
	jr z,fi_eof
	ld (icnt),hl
	ld hl,ibuf
	ld (ipos),hl
	and a
	ret
fi_eof:	ld a,(inh)
	or a
	jr z,fi_nc
	ld b,a
	ld c,45h
	call 5
fi_nc:	ld a,0FFh
	ld (inh),a
fi_open:
	ld a,(nfl)
	or a
	jr nz,fi_next
	ld a,(nargf)
	or a
	jr nz,fi_none
	ld a,(stdone)
	or a
	jr nz,fi_none
	ld a,1
	ld (stdone),a
	xor a
	ld (inh),a
	jr fi_a
fi_none:
	scf
	ret
fi_next:
	ld hl,nfl
	dec (hl)
	ld hl,(flrd)
	ld (curnm),hl
fn1:	ld a,(hl)
	inc hl
	or a
	jr nz,fn1
	ld (flrd),hl
	ld hl,(curnm)
	ex de,hl
	ld a,1
	ld c,43h
	call 5
	or a
	jr z,fi_ok
	ld hl,m_sed
	call pps
	ld hl,m_open
	call pps
	ld hl,(curnm)
	call pps
	call pnl
	ld a,2
	ld (rcopen),a
	jr fi_open
fi_ok:	ld a,b
	ld (inh),a
	jp fi_a
; HL に1行(CRを除く)。 CF=1:入力の終わり
rline:	ld (rlst),hl
	ld (rlp),hl
	xor a
	ld (rgot),a
rl1:	call fill
	jr c,rl_eof
	ld hl,(ipos)
	ld a,(hl)
	inc hl
	ld (ipos),hl
	ld hl,(icnt)
	dec hl
	ld (icnt),hl
	cp 1Ah
	jr z,rl1
	ld c,a
	ld a,1
	ld (rgot),a
	ld a,c
	cp 0Ah
	jr z,rl_end
	ld hl,(rlp)
	ld de,ps+PSMAX
	or a
	sbc hl,de
	jr nc,rl1
	ld hl,(rlp)
	ld (hl),c
	inc hl
	ld (rlp),hl
	jr rl1
rl_eof:	ld a,(rgot)
	or a
	jr nz,rl_end
	scf
	ret
rl_end:	ld hl,(rlp)
	ld de,(rlst)
	or a
	sbc hl,de
	jr z,rl_t
	ld hl,(rlp)
	dec hl
	ld a,(hl)
	cp 0Dh
	jr nz,rl_t
	ld (rlp),hl
rl_t:	ld hl,(rlp)
	ld (hl),0
	and a
	ret
; 出力
pps:	ld a,(hl)
	or a
	ret z
	inc hl
	cp 0Ah
	jr nz,pp1
	ld a,0Dh
	call putch
	ld a,0Ah
pp1:	call putch
	jr pps
pnl:	ld a,0Dh
	call putch
	ld a,0Ah
putch:	push hl
	push de
	ld hl,(op)
	ld (hl),a
	inc hl
	ld (op),hl
	ld de,obuf+250
	or a
	sbc hl,de
	call nc,flush
	pop de
	pop hl
	ret
flush:	push af
	push bc
	push de
	push hl
	ld hl,(op)
	ld de,obuf
	or a
	sbc hl,de
	jr z,fl9
	ld b,1
	ld de,obuf
	ld c,49h
	call 5
	ld hl,obuf
	ld (op),hl
fl9:	pop hl
	pop de
	pop bc
	pop af
	ret
flushaq:
	ld a,(aqn)
	or a
	ret z
	xor a
	ld (aqi),a
fq1:	ld a,(aqn)
	ld c,a
	ld a,(aqi)
	cp c
	jr nc,fq2
	ld l,a
	ld h,0
	add hl,hl
	ld de,aq
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call pps
	call pnl
	ld hl,aqi
	inc (hl)
	jr fq1
fq2:	xor a
	ld (aqn),a
	ret
pdec:	ld de,dbuf+5
	xor a
	ld (de),a
pd1:	call div10
	add a,'0'
	dec de
	ld (de),a
	ld a,h
	or l
	jr nz,pd1
pd2:	ld a,(de)
	or a
	ret z
	call putch
	inc de
	jr pd2
div10:	ld b,16
	xor a
dv1:	add hl,hl
	rla
	cp 10
	jr c,dv2
	sub 10
	inc l
dv2:	djnz dv1
	ret
; ---- 文字列 ----
strend:	ld a,(hl)
	or a
	ret z
	inc hl
	jr strend
strcpy:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,strcpy
	ret
; HL(0終端) を DE へ小文字にして写す。 DE は終端の位置で戻る
lowcpy:	ld a,(hl)
	or a
	jr z,lc9
	inc hl
	call islead
	jr c,lc2
	cp 'A'
	jr c,lc1
	cp 'Z'+1
	jr nc,lc1
	add a,20h
lc1:	ld (de),a
	inc de
	jr lowcpy
lc2:	ld (de),a
	inc de
	ld a,(hl)
	or a
	jr z,lc9
	inc hl
	ld (de),a
	inc de
	jr lowcpy
lc9:	ld (de),a
	ret
; DE の文字列の後ろに LF と HL の文字列を足す(PSMAX まで)
catlf:	ld (cbase),de
	push hl
	ex de,hl
	call strend
	ex de,hl
	pop hl
	ld a,0Ah
	call cput
cl1:	ld a,(hl)
	or a
	jr z,cl2
	inc hl
	call cput
	jr cl1
cl2:	xor a
	ld (de),a
	ret
cput:	push hl
	push de
	ex de,hl
	ld de,(cbase)
	or a
	sbc hl,de
	ld de,PSMAX
	or a
	sbc hl,de
	pop de
	pop hl
	ret nc
	ld (de),a
	inc de
	ret
skip:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skip
; ---- ファイル名 (ワイルドカードは展開) ----
do_one:	ld (tokp),hl
	push hl
dw1:	ld a,(hl)
	or a
	jr z,dw2
	inc hl
	cp '*'
	jr z,dwx
	cp '?'
	jr nz,dw1
dwx:	pop hl
	jp expand
dw2:	pop hl
	jp addflist
addflist:
	ld de,(flw)
	push hl
	ld hl,flist+780
	or a
	sbc hl,de
	pop hl
	jp c,e_big
afl1:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,afl1
	ld (flw),de
	ld hl,nfl
	inc (hl)
	ret
expand:	ld hl,(tokp)
	ld c,0
	ld b,0
xs1:	ld a,(hl)
	or a
	jr z,xs2
	inc hl
	inc b
	cp 5Ch
	jr z,xs3
	cp ':'
	jr z,xs3
	cp '/'
	jr nz,xs1
xs3:	ld c,b
	jr xs1
xs2:	ld a,c
	ld (pfxlen),a
	ld hl,fcbbuf
	ld d,h
	ld e,l
	inc de
	ld (hl),0
	ld bc,47
	ldir
	ld hl,fcbbuf
	ld de,(tokp)
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcbbuf+13),a
	ld hl,(tokp)
xe1:	ld a,(hl)
	or a
	jr z,xe3
	inc hl
	cp '*'
	jr nz,xe1
	ld a,(fcbbuf+9)
	cp ' '
	jr nz,xe3
	ld hl,fcbbuf+9
	ld (hl),'?'
	inc hl
	ld (hl),'?'
	inc hl
	ld (hl),'?'
xe3:	ld a,(fcbbuf+1)
	cp ' '
	jr nz,xe4
	ld hl,fcbbuf+1
	ld de,fcbbuf+2
	ld (hl),'?'
	ld bc,10
	ldir
xe4:	xor a
	ld (nlist),a
	ld de,fcbbuf
	ld c,11h
xl:	call 5
	or a
	jr nz,xdone
	ld a,(dtabuf+12)
	and 18h
	jr nz,xnext
	ld a,(nlist)
	cp 20
	jr nc,xnext
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,nlbuf
	add hl,de
	ex de,hl
	ld hl,dtabuf+1
	ld b,8
xn1:	ld a,(hl)
	cp ' '
	jr z,xn3
	ld (de),a
	inc de
	inc hl
	djnz xn1
xn3:	ld a,b
	or a
	call z,ln_app
	ld hl,dtabuf+9
	ld a,(hl)
	cp ' '
	jr z,xn5
	ld a,'.'
	ld (de),a
	inc de
	ld b,3
xn4:	ld a,(hl)
	cp ' '
	jr z,xn5
	ld (de),a
	inc de
	inc hl
	djnz xn4
xn5:	xor a
	ld (de),a
	ld hl,nlist
	inc (hl)
xnext:	ld de,fcbbuf
	ld c,12h
	jr xl
xdone:	ld a,(nlist)
	or a
	jr nz,xd2
	ld hl,m_sed
	call pps
	ld hl,m_nomatch
	call pps
	ld hl,(tokp)
	call pps
	call pnl
	ld a,2
	ld (rcopen),a
	ret
xd2:	xor a
	ld (xi),a
xp1:	ld a,(xi)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,nlbuf
	add hl,de
	push hl
	ld hl,(tokp)
	ld de,fnbuf
	ld a,(pfxlen)
	or a
	jr z,xp2
	ld c,a
	ld b,0
	ldir
xp2:	pop hl
xp3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,xp3
	ld hl,fnbuf
	call addflist
	ld hl,xi
	inc (hl)
	ld a,(nlist)
	cp (hl)
	jr nz,xp1
	ret
; ---- エラー ----
usage:	ld de,musage
	ld c,9
	call 5
	ld b,1
	ld c,62h
	call 5
	jp 0
fatal:	push hl
	ld hl,m_sed
	call pps
	pop hl
	call pps
	call pnl
	call flush
	ld b,1
	ld c,62h
	call 5
	jp 0
e_big:	ld hl,m_big
	jp fatal
e_long:	ld hl,m_long
	jp fatal
e_many:	ld hl,m_many
	jp fatal
e_addr:	ld hl,m_addr
	jp fatal
e_miss:	ld hl,m_miss
	jp fatal
e_unk:	ld hl,m_unk
	jp fatal
e_extra:
	ld hl,m_extra
	jp fatal
e_brace:
	ld hl,m_brace
	jp fatal
e_unterm:
	ld hl,m_unterm
	jp fatal
e_unsup:
	ld hl,m_unsup
	jp fatal
e_ylen:	ld hl,m_ylen
	jp fatal
e_re:	ld hl,m_re
	jp fatal
e_pool:	ld hl,m_pool
	jp fatal
e_nolab:
	ld hl,m_nolab
	jp fatal
e_norx:	ld hl,m_norx
	jp fatal
e_openf:
	ld hl,m_openf
	jp fatal
; ---- 変数 ----
nflag:	defb 0
eflag:	defb 0
havescr: defb 0
pfirst:	defb 0
nptok:	defb 0
nargf:	defb 0
pi:	defb 0
ncmd:	defb 0
bsp:	defb 0
ri:	defb 0
rj:	defb 0
nrx:	defb 0
atst:	defb 0
ic:	defb 0
rcic:	defb 0
tflag:	defb 0
rstf:	defb 0
rcode:	defb 0
xstat:	defb 0
rcopen:	defb 0
inh:	defb 0FFh
stdone:	defb 0
rgot:	defb 0
aqn:	defb 0
aqi:	defb 0
nfl:	defb 0
nlist:	defb 0
xi:	defb 0
pfxlen:	defb 0
fh:	defb 0
delim:	defb 0
ad_kind: defb 0
sf_g:	defb 0
sf_p:	defb 0
sf_i:	defb 0
sf_n:	defb 0
s_re:	defb 0
s_fl:	defb 0
s_nth:	defb 0
s_cnt:	defb 0
s_did:	defb 0
lastre:	defb 0FFh
ad_val:	defw 0
sbp:	defw sbuf
scp:	defw 0
spp:	defw spool
rpp:	defw rpool
ptp:	defw ptpool
flw:	defw flist
flrd:	defw flist
curc:	defw 0
lno:	defw 0
icnt:	defw 0
ipos:	defw 0
rlst:	defw 0
rlp:	defw 0
op:	defw obuf
cbase:	defw 0
tokp:	defw 0
curnm:	defw 0
lbn:	defw 0
ycnt:	defw 0
y_src:	defw 0
y_dst:	defw 0
mbase:	defw 0
np:	defw 0
cpp:	defw 0
s_rp:	defw 0
s_dif:	defw 0
s_prev:	defw 0
ptab:	defs 32
bstk:	defs 16
aq:	defs 16
dbuf:	defs 6
musage:	defm "usage: sed [-nE] [-e script] [-f file] [script] [file ...]",13,10,"$"
m_sed:	defm "sed: ",0
m_open:	defm "cannot open ",0
m_nomatch:
	defm "no match: ",0
m_big:	defm "script too big",0
m_long:	defm "regular expression too long",0
m_many:	defm "too many commands",0
m_addr:	defm "bad address",0
m_miss:	defm "missing command",0
m_unk:	defm "unknown command",0
m_extra: defm "extra characters after command",0
m_brace: defm "unmatched { or }",0
m_unterm:
	defm "unterminated command",0
m_unsup: defm "unsupported option or flag",0
m_ylen:	defm "y strings differ in length",0
m_re:	defm "bad regular expression",0
m_pool:	defm "too many regular expressions",0
m_nolab: defm "can't find label",0
m_norx:	defm "no previous regular expression",0
m_openf: defm "cannot open script file",0
	include "re.inc"
	include "lnd.inc"
endimg:
ps	equ	endimg
hs	equ	ps+1024
mbuf	equ	hs+1024
nbuf	equ	mbuf+1024
ibuf	equ	nbuf+1024
obuf	equ	ibuf+512
cbuf	equ	obuf+272
sbuf	equ	cbuf+1600
spool	equ	sbuf+2048
rtab	equ	spool+1536
rpool	equ	rtab+64
rebuf	equ	rpool+3072
flist	equ	rebuf+264
ptpool	equ	flist+800
tokbuf	equ	ptpool+700
cmd	equ	tokbuf+260
fcbbuf	equ	cmd+130
dtabuf	equ	fcbbuf+48
fnbuf	equ	dtabuf+32
nlbuf	equ	fnbuf+80
bssend	equ	nlbuf+640
