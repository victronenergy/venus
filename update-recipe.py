#!/bin/python3

import argparse
import glob
import pathlib
import os
import re
import subprocess
import sys
import tempfile
import textwrap
import urllib

verbose = False
git = False

def info(*args, **kwargs):
	global verbose

	if not verbose:
		return
	print(*args, file=sys.stderr, **kwargs)

def warn(*args, **kwargs):
	print(*args, file=sys.stderr, **kwargs)

# sources contains several different git repositories, this contains the repository and the bbfile inside it
class GitInfo:
	repo = ""
	bbfile = ""

	def __str__(self):
		return "repo: " + self.repo + ", bbfile: " + self.bbfile

def find_repo(bbfile):
	if os.path.isabs(bbfile):
		bbfile = os.path.relpath(os.path.realpath(bbfile), os.getcwd())

	ret = GitInfo()
	parts = pathlib.Path(bbfile).parts
	if len(parts) < 2 or parts[0] != "sources":
		warn("invalid path")
		return None
	ret.repo = os.path.join(parts[0], parts[1])
	ret.bbfile = os.path.relpath(bbfile, ret.repo)
	return ret

# returns the srcrev for a given git tag
def get_src_rev(url, tag):
	info("get_src_rev trying %s with %s" % (url, tag))
	rsp = subprocess.check_output(["git", "ls-remote", url, tag], text=True)
	if not rsp:
		return None
	return rsp.split()[0]

def git_rm(file):
	info = find_repo(file)
	subprocess.run(["git", "-C", info.repo, "rm", info.bbfile])

def git_add(file):
	info = find_repo(file)
	subprocess.run(["git", "-C", info.repo, "add", info.bbfile])

def git_diff(file):
	info = find_repo(file)
	subprocess.run(["git", "-C", info.repo, "diff", "--staged"])

def git_commit(file, msg):
	info = find_repo(file)
	with tempfile.NamedTemporaryFile(mode='w+t', encoding='utf-8', delete_on_close=False) as fh:
		fh.write(msg)
		fh.close()
		subprocess.run(["git", "-C", info.repo, "commit", "-e", "-F", fh.name])

def git_nothing_to_commit(file):
	info = find_repo(file)
	rsp = subprocess.check_output(["git", "-C", info.repo, "diff", "--staged"], text=True)
	return rsp == ""

# locate a variable definition in a bb recipe while preserving whitespace / formatting.
# NOTE: single quotes are not supported, e.g. SRC_URI = 'something' will not be found.
class BitbakeVarDef(object):
	_name = ""
	_definition = None
	_orig = None
	_recipe = None

	def __init__(self, name, recipe):
		self._name = name
		self._recipe = recipe
		self._re = re.compile(re.escape(self._name) + r'\s*=\s*"([^"]*)"')
		self.search()

	def search(self):
		if self._recipe is None or self._recipe._content is None:
			self.warn("Warning recipe not set\n")
			return

		m = re.search(self._re, self._recipe._content)
		self._orig = self._definition = None if not m else m[0]

	def found(self):
		return self._definition != None

	# Most bitbake values are word based, so this is likely more useful then preserving
	# whitespace inside a line.
	#
	# Note: this function is not strictly correct:
	#
	# SRC_URI = "FOO\
	# BAR"
	#
	# equals the single word FOOBAR. Simply don't do that, it is evil!
	# Make sure there is space before the \, so FOO \ or it won't be updated.
	def words(self):
		words = []
		m = re.search(self._re, self._definition)
		if m:
			mlines = m[1].split("\n")
			for mline in mlines:
				mline = mline.rstrip()
				if mline.endswith("\\"):
					orig = mline
					mline = mline[:-1]
					if not mline.endswith(" "):
						# complain about non space seperated words, since they cannot be
						# blindly substituted back (it is valid bb syntax though).
						warn("Please prepend the \\ with add a space in '" + orig.strip() + "'")
						warn("in " + self._recipe._bbfile)
					mline = mline.strip()
				if not mline:
					continue
				words += mline.split()
		return words

	# replaces whole words
	def replace(self, what, new):
		new = new.replace('"', "'")
		regex = re.compile(r'(' + re.escape(self._name) + r'\s*=\s*)"([^"]*)"')
		m = re.match(regex, self._definition)
		if m:
			words = re.split(r'(\s+)', m[2])
			for i in range(len(words)):
				if words[i] == what:
					words[i] = new
			self._definition = m[1] + '"' + "".join(words) + '"'
			self.update()
		else:
			warn("something is wrong:")
			warn(str(self))
			exit(1)

	@staticmethod
	def var_def(name, value):
		if '"' in value:
			warn("doubles quotes in values isn't supported %s %s" % (name, value))
			value.replace('"', "'")
		return name + ' = "' + value + '"'

	def set(self, value):
		self._definition = BitbakeVarDef.var_def(self._name, value)
		self.update()

	def define_var_before(self, name, value):
		self._definition = BitbakeVarDef.var_def(name, value) + "\n" + self._definition
		self.update()
		self.search()

	def define_var_after(self, name, value):
		self._definition += "\n" + BitbakeVarDef.var_def(name, value)
		self.update()
		self.search()

	def update(self):
		self._recipe._content = self._recipe._content.replace(self._orig, self._definition)
		self._orig = self._definition

	def __str__(self):
		return "\n".join(["=" * 80, self._definition, "=" * 80])

class Recipe(object):
	def __init__(self, bbfile):
		self._bbfile = bbfile
		p = pathlib.Path(bbfile).stem.split("_")
		self._known_pv = None if len(p) <= 1 else p[1]
		self._known_pn = pathlib.Path(bbfile).stem if len(p) < 1 else p[0]

		with open(bbfile, "r") as fh:
			self._content = fh.read()

		self._src_uris = BitbakeVarDef("SRC_URI", recipe=self)
		self._src_rev = BitbakeVarDef("SRCREV", recipe=self)
		self._pv = BitbakeVarDef("PV", recipe=self)
		self._tag_regex = BitbakeVarDef("UPSTREAM_CHECK_GITTAGREGEX", recipe=self)

	def valid(self):
		return self._src_uris.found() and self.is_git_checkout()

	def _save(self, filename):
		if self._content is None:
			warn("no content to be saved!")
			return False

		with open(filename, "w") as fh:
			fh.write(self._content)

	def save(self):
		global git
		filename = os.path.join(os.path.dirname(self._bbfile), self._known_pn + "_" + self._known_pv + ".bb")
		self._save(filename)
		if git:
			if filename != self._bbfile:
				git_rm(self._bbfile)
			git_add(filename)

	def set_src_rev(self, rev):
		info("Setting SRCREV to " + rev)
		if not self._src_rev.found():
			self._src_uris.define_var_after("SRCREV", rev)
			self._src_rev.search()
		else:
			self._src_rev.set(rev)

	def set_pv(self, pv):
		# store the pv in the filename, not in the recipe itself
		self._known_pv = pv
		return

		if self._pv.found():
			self._pv.set(pv)
			return

		if not self._src_rev.found():
			warn("make sure src_rev is set before settings a PV")
			return False

		self._src_rev.define_var_after("PV", pv)
		self._pv.search()

	def set_tag_regex(self, regex):
		if self._tag_regex.found():
			self._tag_regex.set(regex)
			return

		self._src_uris.define_var_before("UPSTREAM_CHECK_GITTAGREGEX", regex)
		self._tag_regex.search()

	def get_tag_from_pv(self, pv):
		if not self._tag_regex.found():
			return pv

		# note: this assumes there is only one named regex group called pver, which
		# will be replaced by pv.
		regex = self._tag_regex.words()[0]
		regex = regex.replace('\\', '')
		match = '(?P<pver>'
		begin = regex.find(match)
		if begin >= 0:
			pos = begin + len(match)
			brackets = 1
			for n in range(pos, len(regex)):
				if regex[n] == '(':
					brackets += 1
				elif regex[n] == ')':
					brackets -= 1
					if brackets == 0:
						return regex[:begin] + pv + regex[n + 1:]

		warn("regex doesn't contain <pver>")
		return None

	def get_pv_from_tag(self, tag):
		if not self._tag_regex.found():
			return tag
		regex = self._tag_regex.words()[0]
		m = re.match(regex, tag)
		if not m:
			warn("could not find tag %s %s" % (regex, tag))
			return None
		return m['pver']

	def update_by_pv(self, pv):
		giturl = self.get_git_url()
		if giturl is None:
			warn("no git url found\n")
			return False

		tag = self.get_tag_from_pv(pv)
		if not tag:
			return False
		srcrev = get_src_rev(giturl, tag)
		if srcrev is None:
			warn("Could not get SRCREV for " + tag + "\n")
			return False
		self.set_src_rev(srcrev)
		self.set_pv(pv)
		return True

	def is_git_checkout(self):
		for src_uri in self._src_uris.words():
			url = urllib.parse.urlparse(src_uri.split(";")[0])
			if url.scheme == "git" or url.scheme == "gitsm":
				return True

		return False

	def get_git_bburl(self):
		if not self._src_uris.found():
			warn("not valid recipe loaded")
			return None

		for src_uri in self._src_uris.words():
			url = urllib.parse.urlparse(src_uri.split(";")[0])
			if not url.scheme == "git" and not url.scheme == "gitsm":
				continue
			return src_uri

		return None

	def get_git_url(self):
		bburl = self.get_git_bburl()
		if bburl is None:
			return None

		if self._known_pn:
			bburl = bburl.replace('${BPN}', self._known_pn)
		url = urllib.parse.urlparse(bburl.split(";")[0])

		m = re.search(r';protocol=([^;]*)', bburl)
		if not m or m[1] == "https":
			url = url._replace(scheme="https")
			return url.geturl()

		if m[1] == "ssh":
			m = re.search(r';user=([^;]*)', bburl)
			user = m[1] if m else "git"
			return user + "@" + url.hostname + ":" + url.path

		warn("don't know how to handle " + m[1])
		return None

	def check_tag_in_git_url(self):
		bburl = self.get_git_bburl()
		if bburl is None:
			return False

		# check if there is a tag in the URI, if so replace it with a SRCREV.
		m = re.search(r';tag=([^;]*)', bburl)
		if m:
			new_uri = re.sub(r';tag=[^;]*', '', bburl)
			info("Replacing SRC_URI " + bburl + ' with ' + new_uri)
			self._src_uris.replace(bburl, new_uri)

			if not self._known_pv:
				warn("trouble: pv must be known to replace a tag=")
				return False

			# voo... to rewrite something-${PV} to the regex as expected by OE
			tag = m[1]

			# fixup recipes containing a v in the recipe name and move it to the tag format
			if self._known_pv.startswith("v"):
				self._known_pv = self._known_pv[1:]
				tag = "v" + tag

			regex = r'(?P<pver>\S+)'.join([re.escape(x) for x in tag.split('${PV}')])
			self.set_tag_regex(regex)

			# doo... check if the reverse regex works...
			tag_val = tag.replace('${PV}', self._known_pv)
			tag_check = self.get_tag_from_pv(self._known_pv)
			if not tag_check or tag_val != tag_check:
				warn("error: tag was: " + tag_val + " and is: " + str(tag_check))
				return False

			# and check if pv gets returned again
			pv = self.get_pv_from_tag(tag_val)
			if pv is None or pv != self._known_pv:
				warn("trouble: " + str(pv) + " != " + self._known_pv)

			# with all set and done, lets update the recipe
			self.update_by_pv(pv)

		elif not self._known_pv:
			# if no version is known, just give up
			return False

		return True

def lspaces(string):
	n = 0
	for s in string:
		if s != ' ':
			return n

		n += 1
	return 0

def commit_msg(pnline, lines):
	lspace = 100
	aligned = []
	for line in lines:
		if not line:
			continue

		line = line.rstrip()
		if not line.endswith('.'):
			line += '.'

		n = lspaces(line)
		if n < lspace:
			lspace = n
		aligned.append(line)

	last = 0
	ident = 0
	msg = pnline + "\n\n"
	for line in aligned:
		line = line[lspace:]
		n = lspaces(line)
		line = line.lstrip()
		if n > last:
			ident += 1
		elif n < last:
			ident -= 1

		init = "  " * (ident - 1) + ("- " if ident > 0 else "")
		sub = "  " * ident
		msg += "\n".join(textwrap.wrap(line, initial_indent=init, subsequent_indent=sub)) + "\n"
		last = n

	return msg

def yes(msg):
	answer = input(msg).strip().lower()
	return answer in ('y', 'yes', '')

parser = argparse.ArgumentParser(
	description = "Update SRCREV / PV etc in a recipe.",
	epilog =	"When started without a filename, pasting items from the " +
				"TODO page the script will try to update the corresponding recipe and commit it." +
				"It will read till EOF, which is CTRL-D."
	)
parser.add_argument("-g", "--git", action="store_true", help = "stage change for commit (only useful for non-interactive mode)")
parser.add_argument("-v", "--verbose", action="store_true", help = "be more verbose")
parser.add_argument("-s", "--save", action="store_true", help = "update the recipe itself")
parser.add_argument("file", type=str, nargs='?', help="bb file")
args = parser.parse_args()

if args.verbose:
	verbose = True
if args.git:
	git = True

if not args.file is None:
	info("----------------------------- " + args.file + " -----------------------------------\n")

	recipe = Recipe(args.file)
	if not recipe.valid():
		warn("not a recipe which directly checks out with git\n")
		exit(1)

	if not recipe.check_tag_in_git_url():
		warn("check_tag_in_git_url failed\n")
		exit(1)

	if args.save:
		recipe.save()
	else:
		print(recipe._content)

else:
	git = True
	os.system('clear')

	while True:
		print("how can I help?")
		text = sys.stdin.read().strip()

		lines = text.split('\n')
		if len(lines) == 0 or lines[0] == '':
			print("quiting")
			exit(1)

		for i, line in enumerate(lines):
			lines[i] = re.sub(r'^(\s*)\*', r'\1', line)

		pnline = lines[0].strip()
		pnwords = pnline.split()
		if len(pnwords) < 2:
			print("expected at least pn and version as the first line")
			continue

		# lets find the recipe..
		pn = pnwords[0]
		pv = pnwords[-1]
		if pv.startswith('v'):
			pv = pv[1:]

		srcdir = 'sources'
		files = glob.glob('**/' + glob.escape(pn) + '*.bb', root_dir=srcdir, recursive=True)

		filtered = []
		matchversion = re.compile(re.escape(pn) + r"(_.+)?\.bb$")
		for file in files:
			basename = os.path.basename(file)
			if matchversion.match(basename):
				filtered.append(file)
		files = filtered

		if len(files) == 0:
			print("No file found for " + pn)
			continue

		if len(files) > 1:
			print("More then one recipe find for " + pn + ":")
			print(" - \n".join(files))
			continue

		bbfile = os.path.join(srcdir, files[0])

		# update the recipe
		recipe = Recipe(bbfile)
		if not recipe.valid():
			print("not a recipe which directly checks out with git\n")
			continue
		recipe.check_tag_in_git_url()
		if not recipe.update_by_pv(pv):
			print("Failed to update " + pv)
			continue
		recipe.save()

		# and commit the changes (if any)
		if git_nothing_to_commit(recipe._bbfile):
			print("nothing to commit, try again..")
			continue

		git_diff(recipe._bbfile)
		if not yes("Does that look ok? [y]"):
			print("Sorry, giving up....")
			exit(1)

		msg = commit_msg(pnline, lines[1:])
		git_commit(recipe._bbfile, msg)
