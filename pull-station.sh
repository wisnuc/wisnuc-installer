#! /bin/bash

set -e

echo "pull phi-station from source"

echo "cd $1"
cd $1

git clone https://github.com/wisnuc/phi-station appifi

cd appifi
git rev-parse HEAD > .revision

npm i --production

rm -rf build
mv src build

rm -rf LICENSE
rm -rf .editorconfig
rm -rf .git
rm -rf .gitignore
rm -rf .eslintignore
rm -rf .eslintrc.js
rm -rf README.md
rm -rf assets.js
rm -rf backpack.config.js
rm -rf backpack.js
rm -rf docs
rm -rf graph.sh
rm -rf jsdoc.conf.json
rm -rf markdown
rm -rf meta-test
rm -rf misc
rm -rf patch
rm -rf prepare.sh
rm -rf release.sh
rm -rf public
rm -rf sandbox
rm -rf serveJsdoc.js
rm -rf static.js
rm -rf storage.sample.json
rm -rf test
rm -rf trashbin
rm -rf webpack.config.js
rm -rf remote

