.PHONY: bb clean clean-keep-sstate fetch fetch-all fetch-install help update-repos.conf sdk venus-image venus-images $(addsuffix bb-,$(MACHINES)) $(addsuffix -venus-image,$(MACHINES))

SHELL = bash
CONFIG ?= jethro

-include conf/machines

help:
	@echo "usage:"
	@echo
	@echo "Setup"
	@echo "  make prereq"
	@echo "   - Installs required host packages for Debian based distro's."
	@echo
	@echo "Checking out:"
	@echo "  make CONFIG='jethro' fetch"
	@echo "   - Downloads public available repositories needed to build for jethro."
	@echo "  make CONFIG='jethro' fetch-all"
	@echo "   - Downloads all repositories needed to build for jethro, needs victron git access."
	@echo
	@echo "  note: It is assumed you only checkout once, iow switching between CONFIGs is not"
	@echo "        supported on purpose, since it would require resetting git branches forcefully"
	@echo "        and that might throw away any pending, not yet pushed work."
	@echo "        After a 'rm -rf sources && make clean' fetching should work again"
	@echo
	@echo "Building:"
	@echo "  make beaglebone-venus-image"
	@echo "   - Build an image for the beaglebone. beaglebone can be substituted by another supported machine."
	@echo "  make venus-images"
	@echo "   - Build images for all MACHINES supported for this CONFIG."
	@echo ""
	@echo "Problem resolving:"
	@echo "  make beaglebone-bb"
	@echo "    - Drops you to a shell with oe script being sourced and MACHINE set."
	@echo "  make clean-keep-sstate"
	@echo "    - Throw away the tmp / deploy dir but keep sstate (the cached build output) to quickly"
	@echo "      repopulate them. If you run out of disk space / want to cleanup deploy this can help you.."
	@echo "  make clean"
	@echo "    - Throw away the tmp / deploy dir, including sstate."
	@echo
	@echo "Checking in:"
	@echo "  make update-repos.conf"
	@echo "    - Updates repos.conf to the checked out git branches. It still needs to be committed to git though."
	@echo
	@echo "Internals / needed when modifying whitelist etc:"
	@echo "  make build/conf/bblayers.conf"
	@echo "    - Creates the bblayers.conf by looking at the repositories being checkout in sources"
	@echo "      and being in metas.whitelist, if it doesn't exist. Just remove the mentioned file if"
	@echo "      you want to update it forcefully, it will be regenerated."

build/conf/bblayers.conf:
	@echo 'LCONF_VERSION = "6"' > build/conf/bblayers.conf
	@echo 'BBPATH = "$${TOPDIR}"' >> build/conf/bblayers.conf
	@echo 'BBFILES ?= ""' >> build/conf/bblayers.conf
	@echo >> build/conf/bblayers.conf
	@echo 'BBLAYERS = " \' >> build/conf/bblayers.conf
	@find sources -wholename "*/conf/layer.conf" | sed -e 's,/conf/layer.conf,,g' -e 's,^./,,g' | sort > metas.found
	@sort metas.whitelist > metas.whitelist.sorted.tmp
	@comm -1 -2 metas.found metas.whitelist.sorted.tmp | sed -e 's,$$, \\,g' -e "s,^,$$PWD/,g" >> build/conf/bblayers.conf
	@rm metas.whitelist.sorted.tmp
	@echo '"' >> build/conf/bblayers.conf
ifdef DL_DIR
	@echo 'DL_DIR = "${DL_DIR}"' >> build/conf/bblayers.conf
endif
ifdef PERSISTENT_DIR_PREFIX
	@echo 'PERSISTENT_DIR_PREFIX = "${PERSISTENT_DIR_PREFIX}"' >> build/conf/bblayers.conf
endif

%-bb: build/conf/bblayers.conf
	@export BITBAKEDIR=sources/bitbake MACHINE=$(subst -bb,,$@) && bash --init-file sources/openembedded-core/oe-init-build-env

bb: build/conf/bblayers.conf
	@export BITBAKEDIR=sources/bitbake && bash --init-file sources/openembedded-core/oe-init-build-env

clean-keep-sstate:
	@rm -rf build/tmp-eglibc
	@rm -rf build/tmp-glibc
	@rm -rf deploy
	@rm -f build/conf/bblayers.conf

clean: clean-keep-sstate
	@rm -rf build/sstate-cache

conf:
	ln -s configs/$(CONFIG) conf

reconf:
	if [ -f build/conf/bblayers.conf ]; then rm build/conf/bblayers.conf; fi
	ln -sfn configs/$(CONFIG) conf

conf/machines: conf
conf/repos.conf: conf

fetch: conf/repos.conf
	@rm -f build/conf/bblayers.conf
	@grep -ve "git.victronenergy.com" conf/repos.conf | while read p; do ./git-fetch-remote.sh $$p; done

fetch-all: conf/repos.conf
	@rm -f build/conf/bblayers.conf
	@while read p; do ./git-fetch-remote.sh $$p; done <conf/repos.conf

fetch-install:
	git clone git@git.victronenergy.com:ccgx/install.git

prereq:
	@sudo apt-get install sed wget cvs subversion git-core \
		coreutils unzip texi2html texinfo docbook-utils \
		gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ \
		desktop-file-utils chrpath u-boot-tools imagemagick zip \
		python-gobject python-gtk2

sdk: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake meta-toolchain-qte

update-repos.conf:
	@conf=$$PWD/conf/repos.conf; echo -n > $$conf && ./repos_cmd "git-show-remote.sh \$$repo >> $$conf" && sed -i -e '/^install /d' $$conf

%-venus-image: build/conf/bblayers.conf
	export MACHINE=$(subst -venus-image,,$@) && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-image

venus-image: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-image

venus-images: $(addsuffix -venus-image,$(MACHINES))
