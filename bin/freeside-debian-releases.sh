#!/bin/bash

DISTRO="$1"
FS_VERSION="$2"
FS_REPO="$3"

if [[ $# -ne 3 ]]
  then
    echo "We need 3 arguments"
    exit;
fi

DATE=`date +"%Y%m%d"`
DIR="/home/autobuild/packages/staging/freeside$FS_VERSION/$FS_REPO"
TARGET="/home/jeremyd/public_html/freeside$FS_VERSION-$DISTRO-$FS_REPO"

if [ ! -d "$DIR" -a -d $TARGET ]; then

echo "Staging or Target directories do not exist"

fi

GIT_VERSION=`grep '^$VERSION' $DIR/freeside/FS/FS.pm | cut -d\' -f2`

# Clean configuration file
rm -fr $DIR/freeside/debian/freeside-ng-selfservice.conffiles

# Pull any changes
cd $DIR/freeside
STATUS=`git pull`

#Assign the proper config files for freeside-ng-selfservice
if [ $DISTRO = "wheezy" ]; then
	ln -s $DIR/freeside/debian/freeside-ng-selfservice.deb7 $DIR/freeside/debian/freeside-ng-selfservice.conffiles
else
	ln -s $DIR/freeside/debian/freeside-ng-selfservice.deb8 $DIR/freeside/debian/freeside-ng-selfservice.conffiles
fi

# Add the build information to changelog

dch -b --newversion $GIT_VERSION~$DATE "Auto-Build"

# Using pbuilder and pdebuild in chroot instead of building directly : dpkg-buildpackage -b -rfakeroot -uc -us

pdebuild --pbuilderroot sudo --debbuildopts "-b -rfakeroot -uc -us" --buildresult $TARGET --architecture all -- --distribution $DISTRO  --basetgz /var/cache/pbuilder/$DISTRO.tgz

#--buildresult gets the file where it needs to be, may need to clean up DIR

cd $DIR; rm -f freeside_*
cd $TARGET; rm -f *.gz

$TARGET/APT
