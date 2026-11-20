mkdir sub
mkdir sub\deep
copy ka.bat sub\x.txt
copy ka.bat sub\deep\y.dat
find sub\ > a1.lst
find sub\ -name y* > a2.lst
path a:\bin
cd sub
find .\ > a:\a3.lst
find .\ -type d > a:\a4.lst
find deep\ > a:\a5.lst
