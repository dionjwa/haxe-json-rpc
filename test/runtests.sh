#! /usr/bin/env sh
mkdir -p build
npm install
haxe -cmd "node build/test/nodejs_test.js" test/travis.hxml

OUT=$?
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
if [ $OUT -eq 0 ];then
   echo "${GREEN}Success!${NC}"
else
   echo "${RED}Failure!${NC}"
fi
