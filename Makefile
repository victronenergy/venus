.PHONY: bb ccgx clean distclean fetch fetch-all install repos.conf sdk ve-image

build/conf/bblayers.conf:
	@echo 'LCONF_VERSION = "6"' > build/conf/bblayers.conf
	@echo 'BBPATH = "$${TOPDIR}"' >> build/conf/bblayers.conf
	@echo 'BBFILES ?= ""' >> build/conf/bblayers.conf
	@echo >> build/conf/bblayers.conf
	@echo 'BBLAYERS = " \' >> build/conf/bblayers.conf
	@find . -wholename "*/conf/layer.conf" | sed -e 's,/conf/layer.conf,,g' -e 's,^./,,g' | sort > metas.found
	@comm -1 -2 metas.found metas.whitelist | sed -e 's,$$, \\,g' -e "s,^,$$PWD/,g" >> build/conf/bblayers.conf
	@echo '"' >> build/conf/bblayers.conf

bb: build/conf/bblayers.conf
	@bash --init-file sources/openembedded-core/oe-init-build-env

clean:
	@rm -rf build/tmp-eglibc
	@rm -rf build/sstate-cache
	@rm -rf deploy
	@rm -f build/conf/bblayers.conf

ccgx: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build && bitbake bpp3-rootfs

distclean: clean
	@rm -rf downloads

fetch:
	grep -ve "git.victronenergy.com" repos.conf | while read p; do ./git-fetch-remote.sh $$p; done

fetch-all:
	@rm -f build/conf/bblayers.conf
	@while read p; do ./git-fetch-remote.sh $$p; done <repos.conf

# note: different MACHINE as this build a live image as well
ve-image: build/conf/bblayers.conf
	export MACHINE=ccgx && . ./sources/openembedded-core/oe-init-build-env build && bitbake ve-image

install:
	@cd install && make prod && make recover

prereq:
	@sudo apt-get install sed wget cvs subversion git-core \
		coreutils unzip texi2html texinfo docbook-utils \
		gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ \
		desktop-file-utils chrpath u-boot-tools imagemagick

repos.conf:
	@conf=$$PWD/repos.conf; rm $$conf; ./repos_cmd "git-show-remote.sh \$$repo >> $$conf"

sdk: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build && bitbake meta-toolchain-qte
