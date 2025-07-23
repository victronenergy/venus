#!/usr/bin/python

import argparse, os, re, subprocess, textwrap
from typing import Optional

sources = os.path.abspath("sources")
bp_git = os.path.abspath("sources/meta-venus-backports")

metas = {
	"openembedded-core": {
		"since": "2024-04-scarthgap",
		"branch": "upstream/master"
	},
	"meta-openembedded": {
		"since": "a0a114361758cd07143c6d960dde311479e79d27",
		"branch": "upstream/master"
	}
}

def split_bbfile(bbfile: str):
	base = os.path.basename(bbfile)
	stem, ext = os.path.splitext(base)
	if ext != ".bb":
		raise Exception(bbfile + " is not a bitbake file")
	parts = stem.split("_")
	if len(parts) > 2:
		raise Exception(bbfile + " has more than 1 underscore")
	pn = parts[0]
	pv = parts[1] if len(parts) > 1 else None
	return pn, pv

def track_trailer(repo: str, hash: str):
	footer = [
		f"Upstream-Hash: {hash}",
		f"Upstream-Url: https://git.openembedded.org/{repo}/commit/?id={hash}",
		f"Upstream-GitHub: https://github.com/openembedded/{repo}/commit/{hash}"
	]
	return "\n".join(footer)

# Find a recipe by package name in any git repo / branch.
def find_bb_in_git(pn: str, git :str=".", branch="HEAD"):
	files = subprocess.check_output(["git", "-C", git, "ls-tree", "-r", "--name-only", branch], text=True)
	for file in files.split("\n"):
		bbfile = os.path.basename(file)
		if bbfile.endswith(".bb") and (bbfile.startswith(pn + "_") or bbfile.startswith(pn + ".")):
			bbdir = os.path.dirname(file)
			return bbdir, bbfile

	return None, None

# Only importing complete dirs at the moment..
# It is more difficult to find related patches / files etc if not, and in the
# core layers bb files are typically in their own directory anyway.
def check_bb_equals_dir(bbdir: str, bbfile: str):
	dir = os.path.basename(bbdir)
	pn = re.split(r"_.", bbfile)[0]
	if dir != pn:
		msg = f"dir {dir} is not equal to pn {pn}, that is not supported"
		raise Exception(msg)

# Get a dict of changes of dir made, oldest first.
def find_refs_in_git(bbdir, git: str=".", branch: str="HEAD", since: Optional[str]=None):
	refs = {}
	args = ["git", "-C", git, "log", "--oneline", "--reverse", "--pretty=format:%H %s", f"{since}..{branch}" if since else branch, "--", bbdir]
	output = subprocess.check_output(args, text=True)

	for line in output.split("\n"):
		if line == "":
			continue
		rev, _, msg = line.partition(" ")
		refs[rev] = {"title": msg, "branch": branch}

	return refs

def git_last_log(bbdir, git: str=".", branch: str="HEAD"):
	refs = {}
	output = subprocess.check_output(["git", "-C", git, "log", "-1", "--oneline", "--pretty=format:%H %s", branch, "--", bbdir], text=True)

	for line in output.split("\n"):
		if line == "":
			continue
		rev, _, msg = line.partition(" ")
		refs[rev] = {"title": msg, 'branch': branch}

	return refs

# Import bbdir from src_git into tg_dir.
def import_bb_dir(src_git: str, tg_dir: str, hash: str, bbdir: str):
	print(f"importing {src_git}/{bbdir} hash {hash} into {tg_dir}")
	subprocess.run(["git", "-C", src_git, "--work-tree=" + tg_dir, "checkout", hash, "--", bbdir], capture_output=True, text=True)

def add_commits(refs: dict, git: str):
	for hash, ref in refs.items():
		msg = subprocess.check_output(["git", "-C", git, "show", "--no-patch", "--format=%B", hash], text=True)
		ref["message"] = msg
		match = re.search(r"Upstream-Hash: ([0-9a-f]+)", msg)
		ref["upstream-hash"] = match[1] if match else None

def last_upstream_hash(refs: dict):
	for ref in reversed(refs.values()):
		if ref["upstream-hash"]:
			return ref["upstream-hash"]
	return None

def print_patches(refs: dict):
	for hash, ref in refs.items():
		print(hash[:8] + " " + ref["title"])

def git_commit_dir(git: str, path: str, msg: str):
	subprocess.run(["git", "-C", git, "add", path])
	subprocess.run(["git", "-C", git, "commit", "-e", "-m", msg])

def apply_patches(patches: dict, src_git :str, tg_git: str, bbdir: str):
	repo = os.path.basename(src_git)
	for hash, ref in patches.items():
		print(f"appyling {hash}")
		patch = subprocess.check_output(["git", "-C", src_git, "format-patch", "--stdout", "-1", hash, bbdir], text=True)
		p = subprocess.run(["git", "-C", tg_git, "am", "--directory", repo], input=patch, capture_output=True, text=True)
		if p.returncode != 0:
			raise Exception("applying patch failed" + p.stderr)

		trailer = track_trailer(repo, hash)
		subprocess.check_output(["git", "-C", tg_git, "commit", "--amend", "--no-edit", "--trailer", trailer], text=True)

# Split repo / dir as done in the backport repository.
def split_pb_dir(path: str):
	parts = path.split(os.sep)
	repo = parts[0]
	path = os.sep.join(parts[1:])
	return repo, path

def update(bbdir: str, bp_git: str, repo: str, sources: str, upstream_branch: str):
	# find the last applied patch
	bp_refs = find_refs_in_git(bbdir, git=os.path.join(bp_git, repo))
	add_commits(bp_refs, bp_git)
	last_upstream_commit = last_upstream_hash(bp_refs)
	print(f"last upstream commit is {last_upstream_commit} for {bbdir}")

	# find new patches
	src_git = os.path.join(sources, repo)
	new_patches = find_refs_in_git(bbdir, git=src_git, branch=upstream_branch, since=last_upstream_commit)
	if len(new_patches) == 0:
		print("no updates found")
		return

	print("-" * 80)
	print("The following patches are available:")
	print("-" * 80)
	print_patches(new_patches)

	print()
	apply_patches(new_patches, src_git=src_git, tg_git=bp_git, bbdir=bbdir)

def find_recipe_repo(pn: str, src_git: str, since: str, branch):
	# already there since the last release?
	bbdir, bbfile = find_bb_in_git(pn, git=src_git, branch=since)
	if bbdir:
		refs = git_last_log(bbdir=bbdir, git=src_git, branch=since)
		return bbdir, bbfile, refs

	# added later on?
	bbdir, bbfile = find_bb_in_git(pn, git=src_git, branch=branch)
	if bbdir:
		refs = find_refs_in_git(bbdir, git=src_git, branch=branch)
		return bbdir, bbfile, refs

	return None, None, None


parser = argparse.ArgumentParser()
parser.add_argument('package_name', nargs='?', help='The package name of the recipe to update or add')
args = parser.parse_args()

if not args.package_name:
	parser.print_help()
	exit(1)

# =============== update ===================
bp_dir, bbfile = find_bb_in_git(args.package_name, git=bp_git)
if bbfile:
	pn, pv = split_bbfile(bbfile)
	repo, bbdir = split_pb_dir(bp_dir)
	print(f"already backported {bbfile}, current verion {pv}, {repo} {bbdir}, checking for updates..")
	update(bbdir, bp_git=bp_git, repo=repo, sources=sources, upstream_branch=metas[repo]['branch'])
	exit(0)

# =========== try to find it ================
for repo, meta in metas.items():
	src_git = os.path.join(sources, repo)
	bbdir, bbfile, refs = find_recipe_repo(args.package_name, src_git=src_git, since=meta['since'], branch=meta['branch'])

	if refs:
		break

if not refs:
	print(f"could not find {args.package_name}")
	exit(1)

# ======= import & commit ========

# only dirs are supported, will throw if not the case
check_bb_equals_dir(bbdir, bbfile)

# do import
hash = next(iter(refs))
tg_dir = os.path.join(bp_git, repo)
print(f"{bbdir} {bbfile} {tg_dir}")
import_bb_dir(src_git=src_git, tg_dir=tg_dir, hash=hash, bbdir=bbdir)

# do commit
pn, pv = split_bbfile(bbfile)
name = pn + (f" v{pv}" if pv else "")
short_hash = hash[:8]
title = refs[hash]['title']
branch = refs[hash]['branch']

text = f"Import {name} from {repo} / {branch} (commit {short_hash} - {title}).\n\n"
text = "\n".join(textwrap.wrap(text, width=80))

msg = f"import {name}\n\n"
msg += text + "\n\n"
msg += track_trailer(repo, hash)

# commit and find updates as well
bp_bbdir = os.path.join(repo, bbdir)
git_commit_dir(git=bp_git, path=bp_bbdir, msg=msg)
update(bbdir, bp_git=bp_git, repo=repo, sources=sources, upstream_branch=metas[repo]['branch'])
