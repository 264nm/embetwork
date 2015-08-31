*Description: Script to fetch and build packages for node software, pushing to the primary opkg feed and then syncing to all local mirrors*

Dependencies: git, rsync, subversion, git-svn, ipkg-build.sh

NOTE: rsync must be installed on all mirrors

Usage: ./packagepush.sh <folder to be packaged> <mirrorlist> <local|remote>

folder to be packaged -- This refers to a ready made source folder containing 
a valid CONTROL directory and file. It can either be 'local' i.e. folder in the 
directory,  or remote i.e. on our shm-node github in the /packages/ipkg/ folder

mirrorlist -- This refers to a file that contains a list of hosts 
hich contain local opkg mirrors... in our case the gateways.

local|remote -- This refers to whether the folder to be packaged is located
in the current directory, or whether you want to fetch from shm-node github

