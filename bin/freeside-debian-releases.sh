#!/bin/bash

DISTRO="$1"
FS_VERSION="$2"
FS_REPO="$3"

if [[ $# -ne 3 ]]
  then
    echo "We need 3 arguments"
    exit;
fi

DATE=`date +"%Y%m%d%H"`
DIR="/home/autobuild/packages/staging/freeside$FS_VERSION/$FS_REPO"
TARGET="/home/autobuild/public_html/freeside$FS_VERSION-$DISTRO-$FS_REPO"

if [ ! -d "$DIR" -a -d $TARGET ]; then

echo "Staging or Target directories do not exist"

fi

GIT_VERSION=`grep '^$VERSION' $DIR/freeside/FS/FS.pm | cut -d\' -f2`

# Pull any changes
cd $DIR/freeside
git checkout -- debian/changelog

LOCAL=`git rev-parse FREESIDE_${FS_VERSION}_BRANCH`
REMOTE=`git ls-remote origin -h refs/heads/FREESIDE_${FS_VERSION}_BRANCH | cut -f1`

if [ $LOCAL = $REMOTE ]; then
  echo "No new changes in git; aborting build."
  exit #there's no new changes
fi
echo "New changes in git since last build; building new packages."

git pull
#STATUS=`git pull`

# Add the build information to changelog
if [ $FS_REPO != "stable" ]; then
	dch -b --newversion $GIT_VERSION-$DATE "Auto-Build"
fi

# Using pbuilder and pdebuild in chroot instead of building directly : dpkg-buildpackage -b -rfakeroot -uc -us

pdebuild --pbuilderroot sudo --debbuildopts "-b -rfakeroot -uc -us" --buildresult $TARGET --architecture all -- --distribution $DISTRO  --basetgz /var/cache/pbuilder/$DISTRO.tgz

#--buildresult gets the file where it needs to be, may need to clean up DIR

cd $DIR && rm -f freeside_*
cd $TARGET && rm -f *.gz

apt-ftparchive -qq packages ./ >Packages
gzip -c Packages >Packages.gz
#bzip2 -c Packages >Packagez.bz2
apt-ftparchive -qq sources ./ >Sources
gzip -c Sources >Sources.gz
#bzip2 -c Sources >Sources.bz2
rm *bz2 || true
apt-ftparchive -qq release ./ >Release
