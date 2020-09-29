#!/bin/bash

# prepares aide.conf file and directory structure for the test

test "$#" -eq "1" && test -d $1  || exit 1   # testuji predane parametry
tmpdir="$1" || exit 1   # the only parameter is the temporary directory
cp aide.conf $tmpdir || exit 1  # copy config file
sed -i -e "s:AIDE_DIR:$tmpdir:g" $tmpdir/aide.conf || exit 1  # udpate config file with tmp path
mkdir $tmpdir/db || exit 1  # make directory structure for the test
mkdir $tmpdir/data || exit 1
mkdir $tmpdir/log || exit 1
touch $tmpdir/data/perm || exit 1
touch $tmpdir/data/inode || exit 1
touch $tmpdir/data/hlink || exit 1
touch $tmpdir/data/user || exit 1
touch $tmpdir/data/group || exit 1
touch $tmpdir/data/size || exit 1
echo "long content" > $tmpdir/data/Ssize || exit 1
touch $tmpdir/data/selinux || exit 1
touch $tmpdir/data/mtime || exit 1
touch $tmpdir/data/atime || exit 1
touch $tmpdir/data/ctime || exit 1
touch $tmpdir/data/sha256 || exit 1
touch $tmpdir/data/sha512 || exit 1
touch $tmpdir/data/xattrs && setfattr -n user.comment -v "original comment" $tmpdir/data/xattrs || exit 1
touch $tmpdir/data/acl || exit 1
touch $tmpdir/data/e2fsattrs || exit 1
mkdir $tmpdir/data/subdir || exit 1
touch $tmpdir/data/subdir/tobedeleted || exit 1
