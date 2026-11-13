set NAME=world
echo "hello $NAME"
if not exist c1.txt goto E002
echo found
goto F001
:E002
echo none
:F001
set f=a
echo item $f
set f=b
echo item $f
:X003
if exist sub goto G004
echo nodir
:G004
if not _$NAME==_world goto G005
echo same
:G005
if not _$EMPTY==_ goto G006
echo empty
:G006
goto QIT
echo notreached
:QIT
