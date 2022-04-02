.PHONY: bb clean clean-keep-sstate fetch fetch-all fetch-install help update-repos.conf sdk venus-image venus-images $(addsuffix bb-,$(MACHINES)) $(addsuffix -venus-image,$(MACHINES))

SHELL = bash
CONFIG ?= dunfell

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
	@echo "  Venus uses swupdate (https://github.com/sbabic/swupdate) for reliable firmware updates"
	@echo "    make beaglebone-swu"
	@echo "      - Builds a swu file for the beaglebone, which can be installed by sd / usb / or remotely"
	@echo "    make beaglebone-swu-large"
	@echo "      - Builds the large variant of the same"
	@echo "    make swus"
	@echo "      - Builds swu files for all MACHINES"
	@echo "    make swus-large"
	@echo "      - Builds swu files for all MACHINES_LARGE"
	@echo
	@echo "  Building (bootable) images is also supported, but it depends on the machine"
	@echo "    make beaglebone-venus-image"
	@echo "      - Build an image for the beaglebone. beaglebone can be substituted by another supported MACHINE."
	@echo "    make venus-images"
	@echo "      - Build images for all MACHINES supported for this CONFIG."
	@echo
	@echo "  Optional packages"
	@echo "    make beaglebone-machine"
	@echo "      - Builds everything for a given machine. This includes the image / optional packages"
	@echo "        etc. Hence this make take some time (building java, nodejs etc). I doesn't build a sdk"
	@echo "    make machines"
	@echo "      - like above, but for all MACHINES"
	@echo
	@echo "  Software development kits"
	@echo "    make sdks"
	@echo "       Builds a SDK per architecture. This takes time!"
	@echo
	@echo "  Venus"
	@echo "    make venus"
	@echo "      - builds everything supported, all MACHINES and optional things."
	@echo
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
	@echo
	@echo "multiconfig targets exists, which contain mc-, which is mainly useful for big builds on a machine"
	@echo "which can run many threads in parallel. For common tasks it is slower since it parses more configs."

build/conf/bblayers.conf: metas.whitelist
	@echo 'LCONF_VERSION = "6"' > build/conf/bblayers.conf
	@echo 'BBPATH_EXTRA ??= ""' >> build/conf/bblayers.conf
	@echo 'BBPATH = "$${BBPATH_EXTRA}$${TOPDIR}"' >> build/conf/bblayers.conf
	@echo 'BBFILES ?= ""' >> build/conf/bblayers.conf
	@echo >> build/conf/bblayers.conf
	@echo 'BBLAYERS = " \' >> build/conf/bblayers.conf
	@find sources -wholename "*/conf/layer.conf" | sed -e 's,/conf/layer.conf,,g' -e 's,^./,,g' | sort > metas.found
	@sort metas.whitelist > metas.whitelist.sorted.tmp
	@comm -1 -2 metas.found metas.whitelist.sorted.tmp | sed -e 's,$$, \\,g' -e "s,^,$$PWD/,g" >> build/conf/bblayers.conf
	@rm metas.whitelist.sorted.tmp
	@echo '"' >> build/conf/bblayers.conf

%-bb: build/conf/bblayers.conf
	@export BITBAKEDIR=sources/bitbake MACHINE=$(subst -bb,,$@) && bash --init-file venus-init-build-env

bb: build/conf/bblayers.conf
	@export BITBAKEDIR=sources/bitbake && bash --init-file venus-init-build-env

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
	@grep -ve "meta-victronenergy-private" conf/repos.conf | while read p; do ./git-fetch-remote.sh $$p || exit 1; done

fetch-all: conf/repos.conf
	@rm -f build/conf/bblayers.conf
	@while read p; do ./git-fetch-remote.sh $$p || exit 1; done <conf/repos.conf

fetch-install:
	git clone git@git.victronenergy.com:ccgx/install.git

prereq:
	@sudo apt-get install sed wget cvs subversion git-core \
		coreutils unzip texi2html texinfo docbook-utils \
		gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ \
		desktop-file-utils chrpath u-boot-tools imagemagick zip \
		python-gobject python-gtk2 python-dev

cortexa7hf-sdk: build/conf/bblayers.conf
	export MACHINE=raspberrypi2 && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-sdk
	export MACHINE=raspberrypi2 && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake package-index

cortexa8hf-sdk: build/conf/bblayers.conf
	export MACHINE=dummy-cortexa8hf && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-sdk
	export MACHINE=dummy-cortexa8hf && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake package-index

sdks: cortexa7hf-sdk cortexa8hf-sdk

%-swu: build/conf/bblayers.conf
	export MACHINE=$(subst -swu,,$@) && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-swu

%-swu-large: build/conf/bblayers.conf
	export MACHINE=$(subst -swu-large,,$@) && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-swu-large

swu: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-swu

swu-large: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-swu-large

swus: $(addsuffix -swu,$(MACHINES))

swus-large: $(addsuffix -swu-large,$(MACHINES_LARGE))

# complete machine specific build / no sdk
%-machine: build/conf/bblayers.conf
	export MACHINE=$(subst -machine,,$@) && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && \
	bitbake packagegroup-venus packagegroup-venus-machine && \
	bitbake package-index

machines: $(addsuffix -machine,$(MACHINES))

update-repos.conf:
	@conf=$$PWD/conf/repos.conf; echo -n > $$conf && ./repos_cmd "git-show-remote.sh \$$repo >> $$conf" && sed -i -e '/^install /d' $$conf

# complete venus, build all machines and all SDKs
venus: machines sdks

%-venus-image: build/conf/bblayers.conf
	export MACHINE=$(subst -venus-image,,$@) && . ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-image

venus-image: build/conf/bblayers.conf
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake venus-image

venus-images: $(addsuffix -venus-image,$(MACHINES))


### multiconfig build targets

MC_VENUS = $(addprefix mc:,$(addsuffix :packagegroup-venus,$(MACHINES)))
MC_MACHINE = $(addprefix mc:,$(addsuffix :packagegroup-venus-machine,$(MACHINES)))
MC_A8_SDK = mc:ccgx:venus-sdk
MC_SDKS = $(MC_A8_SDK)

%-mc-swu: build/conf/bblayers.conf
	@export BB_ENV_EXTRAWHITE="BBMULTICONFIG" BBMULTICONFIG="$(subst -mc-swu,,$@)" && \
	export MACHINES_LARGE="$(MACHINES_LARGE)" MACHINES_LARGE_CMD="venus-swu-large" && \
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && ./bitbake-mc.sh venus-swu

mc-swus: build/conf/bblayers.conf
	@export BB_ENV_EXTRAWHITE="BBMULTICONFIG" BBMULTICONFIG="$(MACHINES)" && \
	export MACHINES_LARGE="$(MACHINES_LARGE)" MACHINES_LARGE_CMD="venus-swu-large" && \
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && ./bitbake-mc.sh venus-swu

mc-sdks: build/conf/bblayers.conf
	@export BB_ENV_EXTRAWHITE="BBMULTICONFIG" BBMULTICONFIG="ccgx" && \
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && ./bitbake-mc.sh venus-sdk

mc-venus: build/conf/bblayers.conf
	export BB_ENV_EXTRAWHITE="BBMULTICONFIG" BBMULTICONFIG="$(MACHINES)" && \
	. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake $(MC_SDKS) $(MC_VENUS) $(MC_MACHINE) && \
	unset BBMULTICONFIG && bitbake package-index

%-mc-bb: build/conf/bblayers.conf
	@export BITBAKEDIR=sources/bitbake MACHINE=$(subst -mc-bb,,$@) BB_ENV_EXTRAWHITE="BBMULTICONFIG" BBMULTICONFIG="$(subst -mc-bb,,$@)" && \
	bash --init-file venus-init-build-env

mc-bb:  build/conf/bblayers.conf
	@export BITBAKEDIR=sources/bitbake BB_ENV_EXTRAWHITE="BBMULTICONFIG" BBMULTICONFIG="$(MACHINES)" && \
	bash --init-file venus-init-build-env
