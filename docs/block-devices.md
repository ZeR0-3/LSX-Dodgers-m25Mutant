# ブロックデバイス表(HDD/SASI を載せる枠)

結論: **新しい表は不要。既存の DPB 配列(`src/M25DPB.ASM` の `_DEVICE`)がそのままブロックデバイス表になっている。** SASI(HDD)は H: に DPB を1つ足し、読み書きルーチンを2つ書けば載る。ドライバ枠はステージ1で壊れていない(DPB は共通バンクの F200H にあり、読み書きはカーネルが呼ぶ)。

## 表の構造
- `_DEVICE`(F200H〜)に 32B の DPB が A:〜H: の順に8個。A:,B:=FDD、C:,D:=外付けFDD、E:=EMM、F:=RAMディスク、**G:=未使用(将来用。X1ではGVRAMドライブ)、H:=SASI HDD**。`DPB_FATLN=0` なら未使用。`GETDPB` は A=0〜7 を受け付ける。
- DPB のフィールド(`LDDEF`): `+00` FATLN(FAT のセクタ数、0=未使用)、`+02` DRD(読みルーチン)、`+04` DWT(書きルーチン)、`+06` FATID、`+07` SECPCL、`+08` MAXCL、`+0A` FDMODE、`+0B` DIRSCNT、`+0C` MAXCYL、`+0D` MAXSEC、`+0E` FATPS、`+0F` BPS(bit5=1 で FAT16)、`+10` DIRPS、`+12` DEVICE(bit5=1 で BPB から DPB を作る)、`+13` UNITNO、`+14` ADDCL、`+1A` SDIR、`+1C` 名前(4文字)。

## 読み書きルーチンの規約(`FDRD`/`FDWT`/`RDRD`/`RDWT`/EMM と同じ)
- 入口(カーネルのマップ、IX=DPB): `DE`=論理セクタ番号、`HL`=バッファ(カーネルから見える所。DTBUF=A600H など)、`B`=セクタ数相当(FDRD は DRDBL の B)。
- 出口: 成功=CF0、失敗=CF1・`A`=エラー番号。`DE` は読んだ分だけ進める。
- バッファはカーネル専用 RAM(A000H-B005H)か共通バンクなので、ゲートのバウンスは要らない。ルーチン自身はカーネルのコードとして置く(バンク5/6、または共通バンク7)。

## HDD(SASI)を載せる手順
1. ルーチン `SASRD`/`SASWT` を書く(SASI コマンド Read/Write(6)、`DE`→LBA、512B 単位。SASI ブロック長が 256B/1024B の機種は `--hdf-block` で試せる)。
2. H: の DPB を `_DEVICE+32*7` に設定: `DRD`/`DWT` を上記、`DEVICE` の bit5=1(BPB から作る。パーティション先頭のブートセクタを読む)、`BPS` bit5=1(FAT16)、名前 `"SASI"`。
3. INIT の `MEMDISK` と同様に、SASI の有無を検出したときだけ `FATLN` を非0にする(無ければ H: は未使用のまま)。
4. 参考: エミュレータは `--hdf PATH`(`--hdf-block N`)で SASI HDD を持てる。SASI ドライバ(CC BY-SA 4.0)は参照用で、コードは取り込まない。

## 制約
- FAT16 の大容量では `_FAKEFREE`(残量の概算)が効く。BPB 方式の DPB 作成は FD の標準形式で確認済み、**HDD は未確認**。
- ルーチンが DMA 的に長時間かかる場合でも、割り込みは `EI;RETI` のみなので問題ない。
