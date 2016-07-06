#!/bin/sh

echo "============= fetch upstream ======================"
./repos_cmd '[ -n "$upstream_url" ] && git fetch upstream'

echo "============= list upstream changes ======================"
./repos_cmd -q '[ -n "$upstream_url" ] && echo && echo $repo: && git log --pretty=oneline origin/$upstream_branch..upstream/$upstream_branch'

echo "============= checkout ci base branch ======================"
./repos_cmd '[ -n "$upstream_url" ] && git checkout -B ci_$upstream_branch upstream/$upstream_branch'

echo "================= poor venus juice over it ======================="
./repos_cmd '[ -n "$upstream_url" ] && git rebase --committer-date-is-author-date --onto ci_$upstream_branch origin/$upstream_branch origin/$checkout_branch'

echo "============= checkout ci_checkout_branch  ======================"
./repos_cmd '[ -n "$upstream_url" ] && git checkout -B ci_$checkout_branch'

# upload current branch, new base and combined (so they can be compared)
./repos_cmd '[ -n "$upstream_url" ] && git push git@git.victronenergy.com:venus-ci/$git_repo origin/$upstream_branch:refs/heads/$upstream_branch'
./repos_cmd '[ -n "$upstream_url" ] && git push git@git.victronenergy.com:venus-ci/$git_repo ci_$upstream_branch'

# non fast-forwards
./repos_cmd '[ -n "$upstream_url" ] && git push git@git.victronenergy.com:venus-ci/$git_repo $checkout_branch -f'
./repos_cmd '[ -n "$upstream_url" ] && git push git@git.victronenergy.com:venus-ci/$git_repo ci_$checkout_branch -f'


