.PHONY: bb ccgx clean fetch-full fetch-opensource fetch-install install update-repos.conf sdk venus-full venus-opensource $(addsuffix bb-,$(MACHINES)) $(addsuffix -venus-full,$(MACHINES)) $(addsuffix -venus-opensource,$(MACHINES))

CONFIG = danny

-include conf/machines

build/conf/bblayers.conf:
	@echo 'LCONF_VERSION = "6"' > build/conf/bblayers.conf
	@echo 'BBPATH = "$${TOPDIR}"' >> build/conf/bblayers.conf
	@echo 'BBFILES ?= ""' >> build/conf/bblayers.conf
	@echo >> build/conf/bblayers.conf
	@echo 'BBLAYERS = " \' >> build/conf/bblayers.conf
	@find . -wholename "*/conf/layer.conf" | sed -e 's,/conf/layer.conf,,g' -e 's,^./,,g' | sort > metas.found
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

# Use only for bpp3 old style build. New machines should use the venus-full image, see below!
ccgx: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake bpp3-rootfs

conf:
	ln -s configs/$(CONFIG) conf

conf/machines: conf
conf/repos.conf: conf

fetch-opensource: conf/repos.conf
	@rm -f build/conf/bblayers.conf
	@grep -ve "git.victronenergy.com" conf/repos.conf | while read p; do ./git-fetch-remote.sh $$p; done

fetch-full: conf/repos.conf
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
		desktop-file-utils chrpath u-boot-tools imagemagick zip

sdk: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake meta-toolchain-qte

update-repos.conf:
	@conf=$$PWD/conf/repos.conf; echo -n > $$conf && ./repos_cmd "git-show-remote.sh \$$repo >> $$conf" && sed -i -e '/^install /d' $$conf

%-venus-full: build/conf/bblayers.conf
	export MACHINE=$(subst -venus-full,,$@) && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-full-image

venus-full: $(addsuffix -venus-full,$(MACHINES))

%-venus-opensource: build/conf/bblayers.conf
	export MACHINE=$(subst -venus-opensource,,$@) && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-opensource-image

venus-opensource: $(addsuffix -venus-opensource,$(MACHINES))
