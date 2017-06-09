#!/bin/sh

if [ "$1" = "" ]; then
	echo "usage $0 branch"
	echo
	echo "Creates a branch in the venus repo with the configs adjusted"
	echo "to the checkouted branches in ./sources. It then adds a commit"
	echo "with these changes and pushes the branches (hard!) to the git-"
	echo "remote under the name builder. Typically the VE gitlab server,"
	echo "since that is running CI."
	echo
	echo "As an extra bonus it puts the commitlog of all the commits"
	echo "which are not yet in their master in the commit-message."
	echo
	echo "WARNING: it will push the created venus branch hard to the"
	echo "builder!! Make sure you do not use the name of a branch you"
	echo "care about..."
	exit 1
fi

branch=$1

if ! git diff-files --quiet ; then
	echo "make sure all files are committed"
	exit 1
fi

orig=`git rev-parse --abbrev-ref HEAD`

# create a new branch based on the current one
git checkout $orig -B $branch
# update all configures to what checkout version
./repos_cmd git-update-wip-branches.sh

# difference with respect to the original one
echo "feed the builder the following patches" > commit.txt
echo >> commit.txt
./repos cherry -v 'origin/$checkout_branch' --abbrev=8 >> commit.txt

git commit -a -F commit.txt
git checkout $orig -f
git push builder $branch -f
