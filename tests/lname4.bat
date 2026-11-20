mkdir longdirone
mkdir longdirtwo
echo aaa> longdirone\f.txt
echo bbbbbb> longdirtwo\f.txt
echo hello> longnameishere.txt
echo world> longname.txt
find . -name f.txt > r1.lst
du > r2.lst
egrep hello *.txt > r3.lst
egrep world *.txt > r4.lst
sed -n p longname*.txt > r5.lst
echo x> longbatname.bat
which longbatname > r6.lst
