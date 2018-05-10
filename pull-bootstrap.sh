#! /bin/bash

set -e

echo "pull phi-bootstrap from source"

echo "cd $1"
cd $1

git clone https://github.com/wisnuc/phi-bootstrap

cd phi-bootstrap
git rev-parse HEAD > .revision

npm i
npm run build


