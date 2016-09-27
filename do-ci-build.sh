#!/bin/sh

if [ "$1" = "" ]; then
	echo usage $0 branch
	echo
	echo Creates a branch with configs adjust to the checkouted
	echo branch, commits them and pushes the result to the build
	echo "server (as in git remote ci)."
	echo
	echo WARNING: it will push the branches hard!!!!. Make sure you
	echo do not use a branch you care about...
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
