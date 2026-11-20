echo abc> longnameishere.txt
echo xyz> longnameother.txt
echo s> longname.txt
dir longname*.* > r1.lst
type longnameishere.txt > r2.lst
type longnameother.txt > r3.lst
type longname.txt > r4.lst
ren longnameishere.txt renamedlongnamex.txt
dir *.txt > r5.lst
del longname.txt
dir *.txt > r6.lst
del longnameother.txt
dir *.txt > r7.lst
