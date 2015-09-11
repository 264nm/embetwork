#!/bin/bash

## Dependencies: git, rsync, subversion, git-svn, ipkg-build.sh

## NOTE: rsync must be installed on all mirrors

## Usage: ./packagepush.sh <folder to be packaged> <mirrorlist> <local|remote>

## <folder to be packaged> -- This refers to a ready made source folder containing
## a valid CONTROL directory and file. It can either be 'local' i.e. folder in the
## directory,  or remote i.e. on our shm-node github in the /packages/ipkg/ folder

## <mirrorlist> -- This refers to a file that contains a list of hosts
##which contain local opkg mirrors... in our case the gateways.

## <local|remote> -- This refers to whether the folder to be packaged is located
## in the current directory, or whether you want to fetch from shm-node github


##Path to primary opkg repo
mainrepo="www.obfuscatedforgithub"

package=$1
mirrorfile=$2
getsource=$3

mirrors=$(cat $mirrorfile |  sed 's/#.*//g')

vers=$(echo $package | sed 's/armv7a.*//g' | sed 's/[A-Za-z]*//g')

_fetch() {
  ## This uses subversion + git to checkout a single folder rather than clone the entire repo.
  ## It should be noted that this creates hidden .svn files\folders which need to be cleaned
  ## before packaging
  /usr/bin/svn checkout https://github.inside.someobfuscatedrepo.com/shm/shm-node/trunk/packages/ipkg/"$package" > /tmp/fetchout.log

  ## Clean-out subversion hidden directory
  /usr/bin/find ./$package -type d -name "*.svn" -print0 | xargs -0 rm -Rf

  ## Check for errors
  results=$(cat /tmp/fetchout.log)
  reserr=$(echo "$results" | awk '{ print $2 }' | sed 's/://g')
  ressuc=$(echo "$results" | tail -1 | grep "Checked")
  err="E170000"
  if [[ "$reserr" == "$err" ]]; then
    echo 'invalid package name.. Available package folders to download:'
    listpackages=$(svn ls https://github.inside.nicta.com.au/shm/shm-node/trunk/packages/ipkg/)
    echo "$listpackages"
  fi

}

_buildpackage() {
  ## This calls ipkg-build to build the package itself into an ipk file. It should be noted
  ## that our version is customised to be compatable with dpkg-scanpackages on the main
  ## repo (due to changes in packaging order introduced in ubuntu 14.04

  if test -f ./ipkg-build.sh; then
    echo "ipkg-build.sh file found.. Continuing"
    for x in $(/usr/bin/md5sum ./ipkg-build.sh | awk '{ print $1 }'); do
      if [ "$x" == "090cd528cb2a863b85bbb04d1b7d76a6" ]; then
        break
      else
        echo -e "md5sum of ipkg-build.sh doesn't match."
        echo -e "Try fetching manually from: \nhttps://$mainrepo/opkg/ipkg-build.sh"
      fi
    done
  else
    echo "ipkg-build.sh file not found. Attempting to fetch remotely"
    /usr/bin/wget https://bridgemonitor.research.nicta.com.au/opkg/ipkg-build.sh
    /bin/chmod +x ./ipkg-build.sh
  fi

  ## Change ownership of package tree to root (will prompt for sudo password)
  sudo /bin/chown -R root:root ./$package/
  sudo ./ipkg-build.sh ./$package/

}

_feednsync() {
  ## NOTE: Assumes your pubkey is in opkguser's authorized_keys file on main repo

  # ensure the package file exists:
  if test -f "$package".ipk; then
    echo "Using package: "$package".ipk"
  else
    echo "** Package file "$package".ipk is missing?"
    exit 1
  fi

  ## Upload ipk file to repo
  scp "$package".ipk opkguser@"$mainrepo":~/public

  ## Backup previous feed index
  ssh opkguser@"$mainrepo" "/bin/cp ~/public/opkg/Packages.gz ~/public/Packages_pre"$bkupfname".gz"

  ## Move ipk into feed folder and rebuild package feed i.e. Packages.gz file
  ssh opkguser@"$mainrepo" "/bin/mv ~/public/"$package".ipk ~/public/opkg/"$package".ipk; cd ~/public/opkg; /usr/bin/dpkg-scanpackages -t ipk . /dev/null | gzip -9c > Packages.gz"

  # ensure the node list file is not empty:
  if test -f $mirrorfile; then
    echo "Node-list $mirrorfile is being used"
  else
    echo "** Node list $mirrorfile is missing?"
    exit 1
  fi

  # Sync package feed to mirrors
  for i in $mirrors; do
    echo "Syncing to $i"
    ssh opkguser@"$mainrepo" "rsync -avz ~/public/opkg/ opkguser@$i:~/opkg"
  done

}

# Enforce CLI Args
if test $# -lt 1; then
  echo "** Syntax: packagepush.sh <packagename> <mirrorfile> <local|remote>"
  exit 1
elif test $# -lt 2; then
  echo "** Syntax: packagepush.sh <packagename> <mirrorfile> <local|remote>"
  exit
elif test $# -lt 3; then
  echo "** Syntax: packagepush.sh <packagename> <mirrorfile> <local|remote>"
  exit
fi

if [[ $getsource == "remote" ]]; then
  # remove previous package data
  rm -Rf ./"$package"*
  _fetch
  _buildpackage
  _feednsync
elif [[ $getsource == "local" ]]; then
  _feednsync
fi


