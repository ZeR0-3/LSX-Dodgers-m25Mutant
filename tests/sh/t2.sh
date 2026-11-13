NAME=world
echo "hello $NAME"
if [ -f c1.txt ]; then
  echo found
else
  echo none
fi
for f in a b; do
  echo item $f
done
[ -d sub ] || echo nodir
[ "$NAME" = world ] && echo same
test -z "$EMPTY" && echo empty
exit
echo notreached
