#!/bin/sh

branch=`git rev-parse --abbrev-ref HEAD`

if [ "$branch" != "$checkout_branch" ]; then
	src="sources/$(basename $PWD)"
	echo "branch changed $src $checkout_branch => $branch"
	for conf in $(find ../../configs -name repos.conf); do
		# change the branch to the current WIP branches, but only if the checkout-branches where equal in the first place
		awk -v src=$src -v checkout_branch=$checkout_branch -v branch=$branch '$1==src && $5==checkout_branch {$5=branch}1' $conf > tmp && mv tmp $conf
	done
fi


