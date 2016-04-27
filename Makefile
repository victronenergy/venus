.PHONY: build/conf/bblayers.conf bb ccgx clean conf fetch fetch-all install update-repos.conf sdk venus-image $(addsuffix bb-,$(MACHINES))

CONFIG = danny

-include conf/machines

build/conf/bblayers.conf:
	@echo 'LCONF_VERSION = "6"' > build/conf/bblayers.conf
	@echo 'BBPATH = "$${TOPDIR}"' >> build/conf/bblayers.conf
	@echo 'BBFILES ?= ""' >> build/conf/bblayers.conf
	@echo >> build/conf/bblayers.conf
	@echo 'BBLAYERS = " \' >> build/conf/bblayers.conf
	@find . -wholename "*/conf/layer.conf" | sed -e 's,/conf/layer.conf,,g' -e 's,^./,,g' | sort > metas.found
	@comm -1 -2 metas.found metas.whitelist | sed -e 's,$$, \\,g' -e "s,^,$$PWD/,g" >> build/conf/bblayers.conf
	@echo '"' >> build/conf/bblayers.conf

%-bb:
	@export MACHINE=$(subst -bb,,$@) && bash --init-file sources/openembedded-core/oe-init-build-env

bb: build/conf/bblayers.conf
	@bash --init-file sources/openembedded-core/oe-init-build-env

clean:
	@rm -rf build/tmp-eglibc
	@rm -rf build/tmp-glibc
	@rm -rf build/sstate-cache
	@rm -rf deploy
	@rm -f build/conf/bblayers.conf

ccgx: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build && bitbake bpp3-rootfs

conf:
	ln -sfn configs/$(CONFIG) conf

conf/machines: conf
conf/repos.conf: conf

fetch: conf/repos.conf
	@rm -f build/conf/bblayers.conf
	@grep -ve "git.victronenergy.com" conf/repos.conf | while read p; do ./git-fetch-remote.sh $$p; done

fetch-all: conf/repos.conf
	@rm -f build/conf/bblayers.conf
	@while read p; do ./git-fetch-remote.sh $$p; done <${CONF}

install:
	@cd install && make prod && make recover

prereq:
	@sudo apt-get install sed wget cvs subversion git-core \
		coreutils unzip texi2html texinfo docbook-utils \
		gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ \
		desktop-file-utils chrpath u-boot-tools imagemagick

sdk: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build && bitbake meta-toolchain-qte

update-repos.conf:
	@conf=$$PWD/conf/repos.conf; echo -n > $$conf && ./repos_cmd "git-show-remote.sh \$$repo >> $$conf"

%-venus-image: build/conf/bblayers.conf
	export MACHINE=$(subst -venus-image,,$@) && . ./sources/openembedded-core/oe-init-build-env build && bitbake venus-image

venus-image: $(addsuffix -venus-image,$(MACHINES))
