stack exec site clean
stack exec site build

node renderMathjax.js

cp -a _site/* ~/blg/

cd ~/blg

git add -A
git commit -m "Publish"

git push
