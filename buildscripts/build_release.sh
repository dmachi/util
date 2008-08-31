#!/bin/bash

#version should be something like 0.9.0beta or 0.9.0
version=$1
#svnUserName is the name you use to connect to Dojo's subversion.
svnUserName=$2
#The svn revision number to use for tag. Should be a number, like 11203
svnRevision=$3

#If no svnRevision number, get the latest one from he repo.
if [ "$svnRevision" = "" ]; then
	svnRevision=`svn info http://svn.dojotoolkit.org/src/util/trunk/buildscripts/build_release.sh | grep Revision | sed 's/Revision: //'`
fi

tagName=release-$version
buildName=dojo-$tagName

#Make the SVN tag.
svn mkdir -m "Using r$svnRevision to create a tag for the $version release." svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/tags/$tagName
svn copy -r $svnRevision svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/dojo/trunk svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/tags/$tagName/dojo -m "Using r$svnRevision to create a tag for the $version release."
svn copy -r $svnRevision svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/dijit/trunk svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/tags/$tagName/dijit -m "Using r$svnRevision to create a tag for the $version release."
svn copy -r $svnRevision svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/dojox/trunk svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/tags/$tagName/dojox -m "Using r$svnRevision to create a tag for the $version release."
svn copy -r $svnRevision svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/util/trunk svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/tags/$tagName/util -m "Using r$svnRevision to create a tag for the $version release."
svn copy -r $svnRevision svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/demos/trunk svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/dojo/tags/$tagName/demos -m "Using r$svnRevision to create a tag for the $version release."

#Check out the tag
mkdir ../../build
cd ../../build
svn co svn+ssh://$svnUserName@svn.dojotoolkit.org/srv/svn/tags/$tagName $buildName
cd $buildName/util/buildscripts

#Update the dojo version in the tag
java -jar ../shrinksafe/custom_rhino.jar changeVersion.js $version ../../dojo/_base/_loader/bootstrap.js
cd ../../dojo
svn commit -m "Updating dojo version for the tag." _base/_loader/bootstrap.js

#Erase the SVN dir and replace with an exported SVN contents.
cd ../..
rm -rf ./$buildName/
svn export http://svn.dojotoolkit.org/src/tags/$tagName $buildName

# clobber cruft that we don't want in builds
rm -rf ./$buildName/dijit/themes/noir
rm -rf ./$buildName/dojox/off/demos
rm -rf ./$buildName/dijit/bench

#Make a src bundle
srcName=$buildName-src
mv $buildName $srcName
zip -rq $srcName.zip $srcName/
tar -zcf $srcName.tar.gz $srcName/
mv $srcName $buildName

#Make a shrinksafe bundle
shrinksafeName=$buildName-shrinksafe
cp -r $buildName/util/shrinksafe $buildName/util/$shrinksafeName
cd $buildName/util
zip -rq $shrinksafeName.zip $shrinksafeName/
tar -zcf $shrinksafeName.tar.gz $shrinksafeName/
mv $shrinksafeName.zip ../../
mv $shrinksafeName.tar.gz ../../
cd ../..
rm -rf $buildName/util/$shrinksafeName

#Make a -demos bundle (note, this is before build. Build profile=demos-all if you want to release them)
demoName=$buildName-demos
cp -r $buildName/demos $buildName/demos/$demoName
cd $demoName/demos
zip -rq $demoName.zip $demoName/
tar -zcf $demoName.tar.gz $demoName/
mv $demoName.zip ../../
mv $demoName.tar.gz ../../
cd ../..
rm -rf $buildName/demos/$demoName

#Run the build.
cd $buildName/util/buildscripts/
chmod +x ./build.sh
./build.sh profile=standard version=$1 releaseName=$buildName cssOptimize=comments.keepLines optimize=shrinksafe.keepLines cssImportIgnore=../dijit.css action=release 
# run build_mini, removing tests and demos:
chmod +x ./clean_build.sh
./clean_build.sh ../../release $buidName
cd ../../release/

#Pause to allow manual process of packing Dojo.
currDir=`pwd`
echo "You can find dojo in $currDir/$buildName/dojo/dojo.js"
read -p "Build Done. If you want to pack Dojo manually, do it now, then press Enter to continue build packaging..."

#Continuing with packaging up the release.
zip -rq $buildName.zip $buildName/
tar -zcf $buildName.tar.gz $buildName/
mv $buildName.zip ../../
mv $buildName.tar.gz ../../

# md5sum the release files
cd ../../
for i in *.zip; do md5sum $i > $i.md5; done
for i in *.gz; do md5sum $i > $i.md5; done

#Finished.
outDirName=`pwd`
echo "Build complete. Files are in: $outDirName"
cd ../util/buildscripts
