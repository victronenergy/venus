## Venus OS: the Victron Energy Unix like distro with a linux kernel

The problematic part with this name is that it is from the Roman
mythology and not, as most of our products, from the Greek. Phoenix
is already taken though by a charger...

First of all, make sure you really want to rebuild a complete rootfs,
it takes time to compile, lots of diskspace and results in an
image / sdk which already available anyway, in binary form.

Anyway, if you insist: this repo is the starting point to build Venus.
It contains wrapper functions around bitbake and git to fetch, and
compile sources.

For a complete build you need to have access to private repros of Victron
Energy. Building only opensource packages is also possible (but not checked
automatically at the moment).

For further documentation on Venus, see the
[Venus OS wiki](https://github.com/victronenergy/venus/wiki).

Venus uses the OpenEmbedded, the [Yocto Project](https://www.yoctoproject.org/)
build system architecture. For an introduction, start with reading their
[wiki](https://wiki.yoctoproject.org/wiki/) and
the [glossary](https://wiki.yoctoproject.org/wiki/Glossary).

### Getting started
Building Venus requires a Linux. At Victron we use Ubuntu for this.

```
# clone this repository
git clone https://github.com/victronenergy/venus.git
cd venus

# install host packages (Debian based)
sudo make prereq

# fetch needed subtrees
# use make fetch-all instead, if you have access to all the private repos.
make fetch
```

That last fetch command has cloned several things into the `./sources/`
directory. First of all there is [bitbake](https://github.com/openembedded/bitbake),
which is a make-like build tool part of OpenEmbedded. Besides that, you'll find
[openembedded-core](https://github.com/openembedded/openembedded-core/) and
various other layers containing recipes and other metadata defining Venus.

Now its time to actually start building (which can take many hours). Select one
of below example commands:
```
# build all, this will take a while though... it builds for all MACHINES as found
# in conf/machines.
make venus-images

# build for a specific machine
make ccgx-venus-image
make beaglebone-venus-image

# build the swu file only
make ccgx-swu

# build from within the bitbake shell.
# this will have the same end result as make ccgx-swu
make ccgx-bb
bitbake venus-swu
```

### Configs
Above Getting Started instructions will automatically select the config that is
used for Venus OS as distributed. Alternative setups can also be used, e.g. to
build for a newer OE version:

    make CONFIG=rocko fetch-all

To see which config your checkout is using, look at the ./conf symlink. It
will link to one of the configs in the ./configs directories.

For each config there are a few files:

- `repos.conf` contains the repositories which need to be checked out. It can be
rebuild with `make update-repos.conf`.
- `metas.whitelist` contains the meta directory which will be added to
bblayers.conf, but only if they are actually present.
- `machines` contains a list of machines that can be build in this config

To add a new repository, put it in sources, then checkout the branch you want and
set an upstream branch. The result can be made permanent with: `make repos.conf`.

Don't forget to add the directories you want to use from the new repository to
metas.whitelist.

### Using the `repos` command
Repos is just like git submodule foreach -q git, but shorter,
so you can do:

./repos push origin
./repos tag xyz

it will push all, tag all etc. Likewise you can revert to a certain
revision with:

./repos checkout tagname

### managing git remotes and branches

```
# patches not in upstream yet
./repos cherry -v

# local changes with respect to upstream
./repos diff @{u}

# local changes with respect to the push branch
./repos diff 'origin/`git rev-parse --abbrev-ref HEAD`'
or if you have git 2.5+ ./repos diff @{push}

./repos log @{u}..upstream/`git rev-parse --abbrev-ref @{u} | grep -o "[a-Z0-9]*$"` --oneline
````

### Releasing

```
# tag & push venus repo as well as all repos.

git tag v2.21
git push origin v2.21

./repos tag v2.21
./repos push origin v2.21
```

### Maintenance releases 

As a rule, the base branch on which the maintenance releases will be based is
prefixed with a `b`.

This example shows how to create a new maintenance branch. The context is that
master is already working on v2.30. Latest official release was v2.20. So we
make a branch named b2.20 in which the first release will be v2.21; later if
another maintenance release is necessary v2.22 is pushed on top; and so forth.

```
# clone, prep and push the venus repo
git clone git@github.com:victronenergy/venus.git venus-b2.20
git checkout v2.20
git checkout -b b2.20
git push --set-upstream origin b2.20

# fetch all the meta repos
make fetch-all

# clone, prep and push them
./repos checkout v2.20
./repos checkout -b b2.20
./repos push --set-upstream origin b2.20
```

Now you're all set; and ready to start cherry-picking.

The eight golden rules of maintaining the maintenance branch

1. only take changes from master: cherry-picking
2. don't add changes or new versions that are not in master yet
3. `git cherry-pick -x` appends a nice (cherry-picked from [ref]) line to the commit message
4. add and/or increase the PR when adding patches
5. drop the PR again when going to a clean version
6. when adding patches; add a `backported from` note just like
   [this one](https://github.com/victronenergy/meta-victronenergy-private/commit/22ac88f61cc6f13cce1d2fc5455248e066e7a835)
   to the commit message
7. go through the [todo](https://github.com/victronenergy/venus-private/wiki/todo)
   where the team is working on master, and add `(**backported to v2.22**)` to
   each and every patch and version thats been backported
8. double verify everything by cross referencing the todo, the commits logs from
   master as well as your own
   
And the master rule: changes need to be either really small, well tested or very important


### Various notes

#### 1. Linux update
If you encounter problems like this:
 * Solver encountered 1 problem(s):
 * Problem 1/1:
 *   - nothing provides kernel-image-4.14.67 needed by packagegroup-machine-base-1.0-r83.einstein

if can be fixed with:
  make einstein-bb
  bitbake -c cleanall packagegroup-machine-base

and thereafter try again
