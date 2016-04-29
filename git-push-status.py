#!/usr/bin/python

import subprocess

""" more then likely git can do this itself, I don't know how though """

branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).strip()
removed_log = subprocess.check_output(["git", "log", "--oneline", branch + "..origin/" + branch]).strip()
added_log = subprocess.check_output(["git", "log", "--oneline", "origin/" + branch + ".." + branch]).strip()

removed = {}
rewritten = {}
added = {}

def print_commits(commits):
	for commit, msg in commits.iteritems():
		print(commit + " " + msg)

if removed_log:
	for line in removed_log.split("\n"):
		commit = line.split(' ', 1)[0]
		msg = line[len(commit):].strip()
		removed[commit] = msg

if added_log != "":
	for line in added_log.split("\n"):
		commit = line.split(' ', 1)[0]
		msg = line[len(commit):].strip()

		if msg in removed.values():
			rewritten[commit] = msg
			del removed[removed.keys()[removed.values().index(msg)]]
		else:
			added[commit] = msg

if removed:
	print("")
	print("These will be removed:")
	print("----------------------")
	print_commits(removed)

if added:
	print("")
	print("These will be added:")
	print("--------------------")
	print_commits(added)

if rewritten:
	print("")
	print("These will get rewritten:")
	print("-------------------------")
	print_commits(rewritten)
