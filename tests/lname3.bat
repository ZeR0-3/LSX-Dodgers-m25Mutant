mkdir sub
echo abc> longnameishere.txt
echo xyz> longnameother.txt
cp longname*.txt sub
dir sub > r1.lst
cp -r sub sub2
dir sub2 > r2.lst
cat sub2\longnameother.txt > r3.lst
cp longnameishere.txt copy.txt
cat copy.txt > r4.lst
mv longnameother.txt moved.txt
cat moved.txt > r5.lst
mv moved.txt longnameagain.txt
cat longnameagain.txt > r6.lst
