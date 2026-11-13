; AWK.COM - awk の部分集合(整数のみ)。 awk [-F fs] [-v 変数=値] [-f プログラムfile | 'プログラム'] [file ...]     MIT License
	org 0100h
	jp m_start
RX_PMAX	equ	1200
NVARS	equ	48
ASZ	equ	64
AESZ	equ	71
NRULES	equ	24
NRX	equ	24
CODESZ	equ	2048
RPSZ	equ	1536
PROGSZ	equ	2048
	include "re.inc"
	include "awku.inc"
	include "awkv.inc"
	include "awkb.inc"
	include "awkp.inc"

; ---- 小さな変数 (ここは image の中) ----
na:	defs 4
nb:	defs 4
nr:	defs 4
tmp4:	defs 4
sgn1:	defb 0
sgn2:	defb 0
n2p:	defw 0
dbuf2:	defs 16
vsp:	defw 0
vpc:	defw 0
vflag:	defb 0
exitcode: defw 0
as_idx:	defb 0
asg_t:	defb 0
asg_cap: defb 0
asg_db:	defw 0
asg_dc:	defw 0
af_a:	defb 0
af_cre:	defb 0
af_free: defw 0
af_k:	defw 0
ar_s:	defw 0
arrtmp:	defb 0
bf_first: defw 0
bf_id:	defb 0
bf_n:	defb 0
bf_res:	defs 6
bt_up:	defb 0
cat_a:	defw 0
cat_b:	defw 0
cat_la:	defw 0
cbuf:	defs 4
cdep:	defb 0
chead:	defw 0
cmp_b:	defw 0
cptr:	defw 0
do_c:	defw 0
dynanch: defb 0
dynlsp:	defb 0
dynok:	defb 0
dynpat:	defs 82
dummyent: defs AESZ
emptys:	defb 0
fi_arr:	defb 0
fi_var:	defw 0
fm_arg:	defw 0
fm_base: defb 0
fm_c:	defb 0
fm_fill: defb 0
fm_fmt:	defw 0
fm_i:	defb 0
fm_isn:	defb 0
fm_left: defb 0
fm_n:	defb 0
fm_num:	defb 0
fm_prec: defb 0
fm_pv:	defb 0
fm_s:	defw 0
fm_w:	defw 0
fm_wt:	defb 0
fm_wv:	defb 0
fm_zero: defb 0
fn_end:	defw 0
fn_ent:	defw 0
fn_i:	defw 0
fn_key:	defw 0
fn_tmpc: defs 6
fn_var:	defb 0
inc_f:	defb 0
inc_fl:	defb 0
inc_n:	defw 0
inc_old: defs 4
ix_s:	defw 0
ix_t:	defw 0
lg_h:	defw 0
lg_v:	defb 0
lpsp:	defb 0
lv_end:	defw 0
lv_idx:	defb 0
lv_kind: defb 0
lv_ld:	defw 0
lvidx:	defb 0
lxsv:	defs 8
mt_len:	defw 0
mt_s:	defw 0
nfld:	defw 0
nlb:	defb 0
nogt:	defb 0
nrules:	defb 0
nrx:	defb 0
op:	defw 0
outh:	defb 1
lastc:	defb 0
pbuf3:	defs 24
pm_n:	defb 0
pr_cnt:	defb 0
pr_first: defw 0
pr_kind:	defb 0
pr_md:	defb 0
pr_mode: defb 0
pr_n:	defb 0
pw_a:	defs 4
pw_c:	defs 4
pw_r:	defs 4
rd_mode: defb 0
rd_name: defw 0
rd_slot: defw 0
rpp:	defw 0
rul_j:	defw 0
seed:	defs 4
sf_p:	defw 0
sg_cnt:	defb 0
sg_g:	defb 0
sg_out:	defw 0
sg_rep:	defw 0
sg_src:	defw 0
sg_tgt:	defb 0
sp_arr:	defb 0
sp_cnt:	defb 0
sp_dst:	defw 0
sp_i:	defb 0
sp_max:	defb 0
sp_ptr:	defw 0
sp_src:	defw 0
spp:	defw 0
ss_len:	defw 0
ss_m:	defw 0
ss_n:	defw 0
ss_s:	defw 0
src:	defw 0
tok:	defb 0
ptok:	defb 0
tokv:	defs 4
tokv2:	defw 0
tmpc:	defs 6
tmpp:	defw 0
wbuf:	defs 16
pm_x:	defb 0
; 分割(欄)
sp_x:	defb 0
sp_n:	defb 0
sp_fs:	defw 0
sp_a:	defw 0
sp_e:	defw 0
sp_stop: defb 0
sp_c:	defb 0
fcur:	defw 0
fscr:	defw 0
sf_k:	defb 0
sf_new:	defw 0
sf_n:	defb 0
jp_p:	defw 0
; 入力
inh:	defb 0FFh
ipos:	defw 0
iend:	defw 0
fidx:	defb 0
nfiles:	defb 0
rr_n:	defb 0
rr_p:	defw 0
progset: defb 0
ri:	defb 0
sv_t:	defb 0
sv_i:	defb 0
sv_d:	defw 0
fn_name: defw 0
; 文字列
msgsyn:	defm "syntax error",0
msgvars: defm "too many variables",0
msgre:	defm "bad or too many regular expressions",0
msgbig:	defm "program too big",0
msgdiv:	defm "division by zero",0
msgusage: defm "usage: awk [-F fs] [-v var=val] [-f progfile | 'prog'] [file ...]",13,10,"       (man awk)",13,10,0
msgopen: defm "awk: cannot open ",0
msgfat:	defm "awk: ",0
msgnear: defm "  near: ",0
spnames: defm "NR",0,"NF",0,"FNR",0,"FS",0,"OFS",0,"ORS",0,"FILENAME",0,"RSTART",0,"RLENGTH",0
strone:	defm " ",0
strnl:	defb 10,0
strempty: defb 0

; ---------------------------------------------------------------
m_start:
	ld sp,0A000h
	ld hl,endimg		; 大きな領域を 0 に
	ld de,endimg+1
	ld bc,bssend-endimg-1
	ld (hl),0
	ldir
	ld a,r
	ld h,a
	ld l,5Ah
	ld (seed),hl
	ld hl,3C6Eh
	ld (seed+2),hl
	ld a,1
	ld (outh),a
	ld hl,obuf
	ld (op),hl
	ld hl,tmpbuf
	ld (tmpp),hl
	ld hl,spool
	ld (spp),hl
	ld hl,code
	ld (cptr),hl
	ld hl,rpool
	ld (rpp),hl
	ld hl,prog
	ld (src),hl
	ld hl,vars		; 変数は未設定(T_UNK)
	ld b,NVARS
	ld de,6
m_i1:	ld (hl),T_UNK
	add hl,de
	djnz m_i1
	ld hl,spnames		; 特別な変数の名前 (番号は 0..8)
	ld b,9
m_i2:	push bc
	ld de,wbuf
m_i3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,m_i3
	push hl
	call lookvar
	pop hl
	pop bc
	djnz m_i2
	ld hl,0
	ld (na),hl
	ld (na+2),hl
	ld a,0
	call setvnum
	ld a,1
	call setvnum
	ld a,2
	call setvnum
	ld a,7
	call setvnum
	ld a,8
	call setvnum
	ld b,T_STR
	ld hl,strone
	ld a,3			; FS
	call setvstr
	ld b,T_STR
	ld hl,strone
	ld a,4			; OFS
	call setvstr
	ld b,T_STR
	ld hl,strnl
	ld a,5			; ORS
	call setvstr
	ld b,T_STR
	ld hl,strempty
	ld a,6
	call setvstr
	ld de,dtabuf
	ld c,1Ah
	call 5
; ---- コマンドライン ----
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld c,a
	ld b,0
	ld de,cmd
	or a
	jr z,m_c0
	ldir
m_c0:	xor a
	ld (de),a
	ld hl,cmd
m_al:	call m_skip
	ld a,(hl)
	or a
	jp z,m_adone
	ld a,(progset)
	or a
	jp nz,m_afile
	ld a,(hl)
	cp '-'
	jp nz,m_aprog
	inc hl
	ld a,(hl)
	cp 'F'
	jr z,m_oF
	cp 'v'
	jp z,m_ov
	cp 'f'
	jp z,m_of
	cp '-'
	jr z,m_odd
	dec hl
	jp m_aprog
m_odd:	inc hl
	jr m_al
; -F fs
m_oF:	inc hl
	call m_opt_arg
	ld hl,tbuf
	ld a,(hl)
	cp 't'
	jr nz,m_F1
	inc hl
	ld a,(hl)
	or a
	jr nz,m_F2
	ld a,9
	ld (tbuf),a
	jr m_Fs
m_F1:	cp 5Ch
	jr nz,m_Fs
	inc hl
	ld a,(hl)
	cp 't'
	jr nz,m_Fs
	inc hl
	ld a,(hl)
	or a
	jr nz,m_Fs
	ld a,9
	ld (tbuf),a
	xor a
	ld (tbuf+1),a
	jr m_Fs
m_F2:
m_Fs:	ld hl,tbuf
	ld b,T_STR
	ld a,3
	call m_setv
	ld hl,(fn_name)
	jp m_al
; HL=オプションの直後 : 同じトークンの残り、無ければ次のトークン -> tbuf, HL=進めた位置 (fn_name にも)
m_opt_arg:
	ld a,(hl)
	or a
	jr z,moa1
	cp ' '
	jr nz,moa2
moa1:	call m_skip
moa2:	ld de,tbuf
	call m_gettok
	ld (fn_name),hl
	ret
; -v var=val
m_ov:	inc hl
	call m_opt_arg
	ld hl,tbuf
	ld de,wbuf
	ld b,12
m_v1:	ld a,(hl)
	or a
	jr z,m_vbad
	cp '='
	jr z,m_v2
	ld (de),a
	inc hl
	inc de
	djnz m_v1
m_vbad:	ld hl,(fn_name)
	jp m_al
m_v2:	xor a
	ld (de),a
	inc hl
	push hl
	call lookvar
	pop hl
	ld b,T_SNUM
	call m_setv
	ld hl,(fn_name)
	jp m_al
; -f file
m_of:	inc hl
	call m_opt_arg
	ld de,tbuf
	ld a,1
	ld c,43h
	call 5
	or a
	jr z,m_f1
	ld hl,tbuf
	jp m_cantopen
m_f1:	ld a,b
	ld (m_fh),a
	ld hl,prog
	ld (m_fp),hl
m_f2:	ld hl,(m_fp)
	ld de,prog+PROGSZ-8
	or a
	sbc hl,de
	jr nc,m_f9
	ld a,(m_fh)
	ld b,a
	ld de,(m_fp)
	ld hl,400
	ld c,48h
	call 5
	or a
	jr nz,m_f9
	ld a,h
	or l
	jr z,m_f9
	ld de,(m_fp)
	add hl,de
	ld (m_fp),hl
	jr m_f2
m_f9:	ld hl,(m_fp)
	ld (hl),0
	ld hl,prog		; 1A(EOF)で打ち切る
m_f3:	ld a,(hl)
	or a
	jr z,m_f4
	cp 1Ah
	jr z,m_f4
	inc hl
	jr m_f3
m_f4:	ld (hl),0
	ld a,(m_fh)
	ld b,a
	ld c,45h
	call 5
	ld a,1
	ld (progset),a
	ld hl,(fn_name)
	jp m_al
; プログラム本文
m_aprog:ld de,prog
	call m_gettok
	ld a,1
	ld (progset),a
	jp m_al
; ファイル名
m_afile:ld de,tbuf
	call m_gettok
	push hl
	ld a,(nfiles)
	cp 8
	jr nc,m_af9
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,ftab
	add hl,de
	ex de,hl
	ld hl,tbuf
	ld b,31
m_af1:	ld a,(hl)
	ld (de),a
	or a
	jr z,m_af2
	inc hl
	inc de
	djnz m_af1
	xor a
	ld (de),a
m_af2:	ld hl,nfiles
	inc (hl)
m_af9:	pop hl
	jp m_al
m_skip:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr m_skip
; HL=入力 DE=出力 : 1トークン取り出す(" または ' で囲めば空白も入る)
m_gettok:
	ld a,(hl)
	cp '"'
	jr z,m_gq
	cp 27h
	jr z,m_gq
m_g1:	ld a,(hl)
	or a
	jr z,m_gend
	cp ' '
	jr z,m_gend
	ld (de),a
	inc hl
	inc de
	jr m_g1
m_gq:	ld b,a
	inc hl
m_g2:	ld a,(hl)
	or a
	jr z,m_gend
	inc hl
	cp b
	jr z,m_gend
	ld (de),a
	inc de
	jr m_g2
m_gend:	xor a
	ld (de),a
	ret
; A=変数番号 B=型 HL=文字列 -> 変数に入れる
m_setv:	jp setvstr
; ---- 構文解析 ----
m_adone:ld a,(progset)
	or a
	jr nz,m_p1
	ld hl,msgusage
	call m_pstr
	ld b,1
	ld c,62h
	call 5
	jp 0
m_p1:	call parse_prog
	ld a,1
	ld (m_run),a
	; 実行
	ld hl,0
	ld (exitcode),hl
	xor a
	ld (ri),a
m_b1:	call m_nextrule		; BEGIN (種類 0)
	jr c,m_b9
	or a
	jr nz,m_b1
	ld c,a
	call m_runrule
	ld a,(vflag)
	cp 2
	jp z,m_finish
	jr m_b1
m_b9:	; 本体か END があるか
	xor a
	ld (m_need),a
	ld hl,rules
	ld a,(nrules)
	ld b,a
	or a
	jr z,m_n9
m_n1:	ld a,(hl)
	or a
	jr z,m_n2
	ld a,1
	ld (m_need),a
m_n2:	inc hl
	inc hl
	inc hl
	djnz m_n1
m_n9:	ld a,(m_need)
	or a
	jp z,m_finish
; レコードのループ
m_rl:	call readrec
	jr nc,m_end
	xor a
	ld (ri),a
m_r1:	call m_nextrule
	jr c,m_rl
	cp 1
	jr nz,m_r1
	call m_runrule
	ld a,(vflag)
	cp 1
	jr z,m_rl
	cp 2
	jr z,m_end
	jr m_r1
m_end:	xor a
	ld (ri),a
m_e1:	call m_nextrule
	jr c,m_finish
	cp 2
	jr nz,m_e1
	call m_runrule
	ld a,(vflag)
	cp 2
	jr nz,m_e1
m_finish:
	call closeall
	ld a,(exitcode)
	ld b,a
	ld c,62h
	call 5
	jp 0
; 次の規則 -> A=種類 (CF=1:もう無い) , m_ra=命令列
m_nextrule:
	ld a,(ri)
	ld hl,nrules
	cp (hl)
	jr c,mn1
	scf
	ret
mn1:	ld e,a
	ld d,0
	ld l,a
	ld h,0
	add hl,hl
	add hl,de
	ld de,rules
	add hl,de
	inc a
	ld (ri),a
	ld a,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (m_ra),de
	and a
	ret
m_runrule:
	ld hl,(m_ra)
	jp vm_run
; ---- エラー ----
fatal:	push hl
	call flush
	ld hl,msgfat
	call m_pstr
	pop hl
	call m_pstr
	ld a,(m_run)
	or a
	jr nz,m_ft2
	ld hl,msgnear
	call m_pstr
	ld hl,(src)
	ld b,24
m_ft1:	ld a,(hl)
	or a
	jr z,m_ft2
	cp 0Ah
	jr z,m_ft2
	call m_pch
	inc hl
	djnz m_ft1
m_ft2:	call m_crlf
	ld b,2
	ld c,62h
	call 5
	jp 0
m_cantopen:
	push hl
	ld hl,msgopen
	call m_pstr
	pop hl
	call m_pstr
	call m_crlf
	ld b,2
	ld c,62h
	call 5
	jp 0
m_pstr:	ld a,(hl)
	or a
	ret z
	call m_pch
	inc hl
	jr m_pstr
m_pch:	push hl
	push bc
	ld e,a
	ld c,2
	call 5
	pop bc
	pop hl
	ret
m_crlf:	ld a,13
	call m_pch
	ld a,10
	jp m_pch
; ---- 変数の設定 ----
; A=番号 : na の数を入れる
setvnum:call varaddr
	push hl
	pop ix
	jp setnum
; A=番号 B=型 HL=文字列
setvstr:ld c,a
	ld a,b
	ld (sv_t),a
	ld a,c
	ld (sv_i),a
	push hl
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,vstrb
	add hl,de
	ex de,hl
	pop hl
	ld (sv_d),de
	ld b,63
m_sv1:	ld a,(hl)
	ld (de),a
	or a
	jr z,m_sv2
	inc hl
	inc de
	djnz m_sv1
	xor a
	ld (de),a
m_sv2:	ld a,(sv_i)
	call varaddr
	ld a,(sv_t)
	ld (hl),a
	inc hl
	ld de,(sv_d)
	ld (hl),e
	inc hl
	ld (hl),d
	ret
; A=番号: 1 増やす
incvar:	call varaddr
	push hl
	pop ix
	call getnum
	ld hl,(na)
	inc hl
	ld (na),hl
	ld a,h
	or l
	jr nz,m_iv9
	ld hl,(na+2)
	inc hl
	ld (na+2),hl
m_iv9:	jp setnum
; ---- 入力 ----
getc:	ld hl,(ipos)
	ld de,(iend)
	or a
	sbc hl,de
	jr nc,gc_fill
	ld hl,(ipos)
	ld a,(hl)
	inc hl
	ld (ipos),hl
	and a
	ret
gc_fill:ld a,(inh)
	ld b,a
	ld de,ibuf
	ld hl,512
	ld c,48h
	call 5
	or a
	jr nz,gc_eof
	ld a,h
	or l
	jr z,gc_eof
	ld de,ibuf
	ld (ipos),de
	add hl,de
	ld (iend),hl
	jr getc
gc_eof:	scf
	ret
; 次の入力ファイルを開く -> CF=1 で開けた
nextfile:
m_nf0:	ld a,(nfiles)
	or a
	jr nz,m_nf1
	ld a,(fidx)
	or a
	jr nz,m_nfn
	inc a
	ld (fidx),a
	xor a
	ld (inh),a
	jr m_nfok
m_nf1:	ld a,(fidx)
	ld b,a
	ld a,(nfiles)
	cp b
	jr z,m_nfn
	ld a,b
	inc a
	ld (fidx),a
	ld l,b
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,ftab
	add hl,de
	push hl
	ex de,hl
	ld a,1
	ld c,43h
	call 5
	pop hl
	or a
	jr z,m_nf2
	push hl
	ld hl,msgopen
	call m_pstr
	pop hl
	call m_pstr
	call m_crlf
	ld a,2
	ld (exitcode),a
	jr m_nf0
m_nf2:	ld a,b
	ld (inh),a
	push hl
	ld b,T_STR
	ld a,6
	call setvstr
	pop hl
	ld hl,0
	ld (na),hl
	ld (na+2),hl
	ld a,2
	call setvnum
m_nfok:	ld hl,ibuf
	ld (ipos),hl
	ld (iend),hl
	scf
	ret
m_nfn:	and a
	ret
; 1行読む -> CF=1 読めた ($0 と欄、NR NF FNR を更新)
readrec:
rr0:	ld a,(inh)
	cp 0FFh
	jr nz,rr1
	call nextfile
	ret nc
rr1:	ld hl,rbuf
	ld (rr_p),hl
	xor a
	ld (rr_n),a
rr2:	call getc
	jr c,rr_eof
	cp 0Ah
	jr z,rr_done
	cp 0Dh
	jr z,rr2
	cp 1Ah
	jr z,rr_eof
	ld c,a
	ld a,(rr_n)
	cp 255
	jr nc,rr2
	inc a
	ld (rr_n),a
	ld hl,(rr_p)
	ld (hl),c
	inc hl
	ld (rr_p),hl
	jr rr2
rr_eof:	ld a,(rr_n)
	or a
	jr nz,rr_done
	ld a,(inh)
	or a
	jr z,rr_e2
	ld b,a
	ld c,45h
	call 5
rr_e2:	ld a,0FFh
	ld (inh),a
	jr rr0
rr_done:ld hl,(rr_p)
	ld (hl),0
	ld a,0
	call incvar
	ld a,2
	call incvar
	call resplit
	scf
	ret
; $0 を FS で欄に分ける
resplit:ld a,3
	call varaddr
	push hl
	pop ix
	call getstr
	ex de,hl
	ld hl,fbuf1
	ld (fcur),hl
	ld (sp_dst),hl
	ld hl,fptr
	ld (sp_ptr),hl
	ld a,60
	ld (sp_max),a
	ld hl,rbuf
	call splitter
	ld (nfld),bc
setnf:	ld hl,(nfld)
	ld (na),hl
	ld hl,0
	ld (na+2),hl
	ld a,1
	jp setvnum
; HL=元 DE=区切り(FS) : sp_dst に欄の文字列、sp_ptr に番地を並べる -> BC=個数
splitter:
	ld (sp_fs),de
	xor a
	ld (sp_n),a
	ld (sp_stop),a
	ld a,(hl)
	or a
	jr nz,spl1
	ld bc,0
	ret
spl1:	ld de,(sp_fs)
	ld a,(de)
	ld (sp_c),a
	inc de
	ld a,(de)
	or a
	jr nz,spl_re
	ld a,(sp_c)
	cp ' '
	jr z,spl_bl
; 1文字の区切り
spl_ch:	ld (sp_a),hl
spc1:	ld a,(hl)
	or a
	jr z,spc9
	ld b,a
	ld a,(sp_c)
	cp b
	jr z,spc9
	call islead
	inc hl
	jr nc,spc1
	ld a,(hl)
	or a
	jr z,spc1
	inc hl
	jr spc1
spc9:	ld (sp_e),hl
	call sp_emit
	ld a,(sp_stop)
	or a
	jr nz,spl_end
	ld a,(hl)
	or a
	jr z,spl_end
	inc hl
	jr spl_ch
; 空白(スペース/タブ/改行)の連なり
spl_bl:
spb1:	ld a,(hl)
	cp ' '
	jr z,spb2
	cp 09h
	jr z,spb2
	cp 0Ah
	jr nz,spb3
spb2:	inc hl
	jr spb1
spb3:	or a
	jr z,spl_end
	ld (sp_a),hl
spb4:	ld a,(hl)
	or a
	jr z,spb6
	cp ' '
	jr z,spb6
	cp 09h
	jr z,spb6
	cp 0Ah
	jr z,spb6
	inc hl
	jr spb4
spb6:	ld (sp_e),hl
	call sp_emit
	ld a,(sp_stop)
	or a
	jr z,spb1
spl_end:ld a,(sp_n)
	ld c,a
	ld b,0
	ret
; 正規表現の区切り
spl_re:	ld (sp_src),hl
	ld hl,(sp_fs)
	call rxdyn
	jr c,spl_end
	ld hl,(sp_src)
	ld (sp_a),hl
	call rx_find
	jr spq2
spr_n:	ld hl,(sp_pos)
	call rx_from
spq2:	jr nc,spr_last
	ld hl,(mend)
	ld de,(mstart)
	or a
	sbc hl,de
	jr nz,spr3
	ld hl,(mend)		; 空の一致: 1文字進めて探し直す
	ld a,(hl)
	or a
	jr z,spr_last
	inc hl
	ld (sp_pos),hl
	jr spr_n
spr3:	ld hl,(mstart)
	ld (sp_e),hl
	call sp_emit
	ld a,(sp_stop)
	or a
	jr nz,spl_end
	ld hl,(mend)
	ld (sp_a),hl
	ld (sp_pos),hl
	jr spr_n
spr_last:
	ld hl,(sp_a)
	call m_strend
	ld (sp_e),hl
	call sp_emit
	jr spl_end
m_strend:
	ld a,(hl)
	or a
	ret z
	inc hl
	jr m_strend
; sp_a から sp_e の手前までを 1欄として追加 (HL, DE, BC 以外は壊れる)
sp_emit:
	push hl
	ld a,(sp_n)
	ld b,a
	ld a,(sp_max)
	cp b
	jr nz,spe1
	ld a,1
	ld (sp_stop),a
	pop hl
	ret
spe1:	ld hl,(sp_e)
	ld de,(sp_a)
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld hl,(sp_ptr)
	ld de,(sp_dst)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (sp_ptr),hl
	ld hl,(sp_a)
	ld a,b
	or c
	jr z,spe2
	ldir
spe2:	xor a
	ld (de),a
	inc de
	ld (sp_dst),de
	ld hl,sp_n
	inc (hl)
	pop hl
	ret
sp_pos:	defw 0
; ---- $n への代入: DE=n HL=文字列 ----
setfield:
	ld a,d
	or a
	ret nz
	ld a,e
	or a
	jr nz,sfd1
	ld de,rbuf		; $0
	push hl
	or a
	sbc hl,de
	pop hl
	jp z,resplit
	ld b,255
sfd0:	ld a,(hl)
	ld (de),a
	or a
	jr z,sfd0e
	inc hl
	inc de
	djnz sfd0
	xor a
	ld (de),a
sfd0e:	jp resplit
sfd1:	cp 61
	ret nc
	ld (sf_k),a
	ld (sf_new),hl
	ld hl,(fcur)		; 書き込み先は今使っていない方
	ld de,fbuf1
	or a
	sbc hl,de
	ld hl,fbuf1
	jr nz,sfd2
	ld hl,fbuf2
sfd2:	ld (fscr),hl
	ld (sp_dst),hl
	ld a,(nfld)
	ld b,a
	ld a,(sf_k)
	cp b
	jr c,sfd3
	ld b,a
sfd3:	ld a,b			; 欄の数 K
	ld (sf_n),a
	ld c,1
sfd4:	ld a,(sf_n)
	cp c
	jr c,sfd9
	push bc
	ld a,(sf_k)
	cp c
	jr nz,sfd5
	ld hl,(sf_new)
	jr sfd6
sfd5:	ld l,c
	ld h,0
	call fieldaddr
sfd6:	ld de,(sp_dst)		; 書き込み先に写す
	pop bc
	push bc
	ld a,c
	ld c,a
	ld b,0
	push hl
	ld hl,fptr-2
	add hl,bc
	add hl,bc
	ld (hl),e
	inc hl
	ld (hl),d
	pop hl
	ld b,255
sfd7:	ld a,(hl)
	ld (de),a
	inc de
	or a
	jr z,sfd8
	inc hl
	djnz sfd7
	xor a
	ld (de),a
	inc de
sfd8:	ld (sp_dst),de
	pop bc
	inc c
	jr sfd4
sfd9:	ld a,(sf_n)
	ld l,a
	ld h,0
	ld (nfld),hl
	ld hl,(fscr)
	ld (fcur),hl
	; $0 を OFS でつなぎ直す
	ld a,4
	call varaddr
	push hl
	pop ix
	call getstr
	ld (sp_x2),hl
	ld hl,rbuf
	ld (jp_p),hl
	ld c,1
sfj1:	ld a,(sf_n)
	cp c
	jr c,sfj9
	push bc
	ld a,c
	cp 1
	jr z,sfj2
	ld hl,(sp_x2)
	call m_app
sfj2:	pop bc
	push bc
	ld l,c
	ld h,0
	call fieldaddr
	call m_app
	pop bc
	inc c
	jr sfj1
sfj9:	ld hl,(jp_p)
	ld (hl),0
	jp setnf
sp_x2:	defw 0
; HL=文字列を jp_p の所へ追加 (rbuf の 255 文字まで)
m_app:	ld de,(jp_p)
m_ap1:	ld a,(hl)
	or a
	jr z,m_ap9
	push hl
	ld hl,rbuf+255
	or a
	sbc hl,de
	pop hl
	jr z,m_ap9
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	jr m_ap1
m_ap9:	ld (jp_p),de
	ret
m_fh:	defb 0
m_run:	defb 0
m_fp:	defw 0
m_need:	defb 0
m_ra:	defw 0
; ---- 大きな領域 (COM の中身ではない: 起動時に 0 で埋める) ----
endimg:
vars	equ	endimg
vstrb	equ	vars+6*NVARS
atab	equ	vstrb+64*NVARS
nmtab	equ	atab+AESZ*ASZ
rtab	equ	nmtab+14*(NVARS+2)
rules	equ	rtab+2*NRX
lpstk	equ	rules+3*NRULES
cstk	equ	lpstk+32
vstk	equ	cstk+32
code	equ	vstk+6*(VSZ+4)
rpool	equ	code+CODESZ
spool	equ	rpool+RPSZ
prog	equ	spool+1024
tmpbuf	equ	prog+PROGSZ
tmpend	equ	tmpbuf+1280
rbuf	equ	tmpend
fbuf1	equ	rbuf+260
fbuf2	equ	fbuf1+340
fptr	equ	fbuf2+340
spbuf	equ	fptr+130
spptr	equ	spbuf+340
obuf	equ	spptr+130
sfbuf	equ	obuf+270
sgbuf	equ	sfbuf+300
ibuf	equ	sgbuf+270
ofn	equ	ibuf+520
ftab	equ	ofn+4*34
cmd	equ	ftab+8*32
tbuf	equ	cmd+130
dtabuf	equ	tbuf+130
bssend	equ	dtabuf+40

