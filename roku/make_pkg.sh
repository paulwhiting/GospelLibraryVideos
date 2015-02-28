pushd .

cd `dirname $0`

rm GLV.zip
cd package
zip ../GLV.zip -9 -r .
cd ..

popd
