.PHONY: bb ccgx clean fetch fetch-all fetch-install install update-repos.conf sdk venus-image venus-images $(addsuffix bb-,$(MACHINES)) $(addsuffix -venus-image,$(MACHINES))

CONFIG ?= danny

-include conf/machines

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

%-bb:
	@export BITBAKEDIR=sources/bitbake MACHINE=$(subst -bb,,$@) && bash --init-file sources/openembedded-core/oe-init-build-env

bb: build/conf/bblayers.conf
	@export BITBAKEDIR=sources/bitbake && bash --init-file sources/openembedded-core/oe-init-build-env

clean:
	@rm -rf build/tmp-eglibc
	@rm -rf build/tmp-glibc
	@rm -rf build/sstate-cache
	@rm -rf deploy
	@rm -f build/conf/bblayers.conf

ccgx: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake bpp3-rootfs

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

install:
	@cd sources/meta-ccgx/scripts/install && make prod && make recover

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
