#!/bin/bash

test "$#" -eq "1" && test -d $1  || exit 1   # testuji predane parametry
tmpdir="$1" || exit 1   # the only parameter is the temporary directory

chmod g+w $tmpdir/data/perm || exit 3

# change inode
echo "Changing inode for $tmpdir/data/inode"
ls -i $tmpdir/data/inode
touch $tmpdir/data/inode2 || exit 4
mv -f $tmpdir/data/inode2 $tmpdir/data/inode || exit 5
ls -i $tmpdir/data/inode

# change no. of links
echo "updating number of hard links for $tmpdir/data/hlink"
ls -l $tmpdir/data/hlink
ln $tmpdir/data/hlink $tmpdir/data/hlink2 || exit 5
ls -l $tmpdir/data/hlink

echo "changing ownership of $tmpdir/data/user"
ls -l $tmpdir/data/user
chown daemon $tmpdir/data/user || exit 6
ls -l $tmpdir/data/user

echo "changing group ownership of $tmpdir/data/group"
ls -l $tmpdir/data/group
chown :daemon $tmpdir/data/group || exit 7
ls -l $tmpdir/data/group

echo "increasing the size of $tmpdir/data/size"
ls -l $tmpdir/data/size
echo "test" >> $tmpdir/data/size || exit 8
ls -l $tmpdir/data/size

echo "reducing the size of $tmpdir/data/Ssize"
ls -l $tmpdir/data/Ssize
echo "short" > $tmpdir/data/Ssize || exit 9
ls -l $tmpdir/data/Ssize

# change selinux context
echo "changing selinux context of $tmpdir/data/selinux"
ls -Z $tmpdir/data/selinux
chcon -t root_t $tmpdir/data/selinux || exit 10
ls -Z $tmpdir/data/selinux

echo "changing timestamps for $tmpdir/data/*time"
touch $tmpdir/data/*time || exit 11

# change sha
echo "changing $tmpdir/data/sha256 content to change checksum"
echo 1 > $tmpdir/data/sha256 || exit 12
echo "changing $tmpdir/data/sha512 content to change checksum"
echo 1 > $tmpdir/data/sha512 || exit 13

# change extended attributes
echo "changing user.comment for $tmpdir/data/xattrs"
setfattr -n user.comment -v "changed comment" $tmpdir/data/xattrs

# change acl
echo "changing acl perms for $tmpdir/data/acl"
setfacl -m u:mail:000 $tmpdir/data/acl

# change e2fsattrs
echo "changing e2fsattrs for $tmpdir/data/e2fsattrs"
chattr +d $tmpdir/data/e2fsattrs

# remove a file
echo "removing file $tmpdir/data/subdir/tobedeleted"
rm -f $tmpdir/data/subdir/tobedeleted

# add a new file
echo "creating new file $tmpdir/data/subdir/newfile"
touch $tmpdir/data/subdir/newfile

