# -*- tab-width: 4 -*-

SRC_DIR						= source
DST_DIR						= ${HOME}/local
export C_INCLUDE_PATH		:= ${DST_DIR}/include
export CPLUS_INCLUDE_PATH	:= ${DST_DIR}/include
export TARGET				:= mn10300-elf
export PREFIX				:= ${DST_DIR}/mn10300
export CFLAGS				:= -O2 -fcommon -w
export CXXFLAGS				:= -O2 -fcommon -w -std=gnu++11
export GRAPHITE_LOOP_OPT	:= yes
export PATH					:= ${DST_DIR}/bin:${PREFIX}/bin:${PATH}

SRCS	= \
	https://ftp.tsukuba.wide.ad.jp/software/gcc/releases/gcc-5.5.0/gcc-5.5.0.tar.xz \
	https://ftp.gnu.org/gnu/binutils/binutils-2.25.1.tar.bz2 \
	https://sourceware.org/pub/newlib/newlib-2.2.0.20150423.tar.gz \

##############################################################################

para:
	nice -n 19 $(MAKE) -j8 all 2>&1 | tee log

all: b.gcc

download:
	@mkdir -p $(SRC_DIR); cd $(SRC_DIR); \
	rm -f fail-list; \
	for source in $(SRCS); do \
		url=$${source#*::}; \
		exname=$${source%%::*}; \
		filename=`basename $$url`; \
		if [ $$url != $$exname ]; then filename=$$exname-$$filename; fi; \
		if [ ! -e $$filename ]; then wget -P . --no-check-certificate $$url; \
			if [ $$url != $$exname ]; then mv `basename $$url` $$filename; fi; \
			if [ ! -e $$filename ]; then echo $$filename >> fail-list; fi; \
		fi; \
	done; \
	if [ -e fail-list ]; then \
		echo "=== Download FAILED ==="; \
		cat fail-list; \
		echo "======================="; \
		rm -f fail-list; \
	else \
		echo "Download completed successfully."; \
	fi

##############################################################################

b.%:
	if [ ! -d $*?* ]; then tar xf ${SRC_DIR}/$**; fi
	cd $*?*; \
		./configure --target=${TARGET} --prefix=${PREFIX} --disable-nls --disable-werror; \
		$(MAKE); $(MAKE) install
	touch $@

git-clone:
	repo=$(REPO); repo=`basename $${repo#*/} .git`; echo $$repo; \
	if [ ! -d $$repo-* ]; then \
		git clone $(REPO) $$repo-build; \
		cd $$repo-*; \
		git reset --hard $(REV); \
	fi

##############################################################################

b.binutils:
	if [ ! -d binutils-* ]; then tar xf ${SRC_DIR}/binutils-*.tar.*; fi
	cd binutils-*; mkdir -p build; cd build; \
	../configure --target=${TARGET} --prefix=${PREFIX} --disable-nls --disable-werror; \
	$(MAKE); $(MAKE) install
	touch $@

b.gcc-1-cfg:
	cd gcc-*; mkdir -p build-stage1; cd build-stage1; \
	../configure --target=${TARGET} --prefix=${PREFIX} \
		--enable-languages=c \
		--without-headers \
		--with-newlib \
		--disable-shared \
		--disable-threads \
		--disable-libssp \
		--disable-libgomp \
		--disable-libmudflap \
		--disable-nls \
		--disable-werror CXXFLAGS="${CXXFLAGS}" CFLAGS="${CFLAGS}"
	touch $@

b.gcc-1: b.gcc-1-cfg
	cd gcc-*; mkdir -p build-stage1; cd build-stage1; \
	$(MAKE) STAGE1_CXXFLAGS="${CXXFLAGS}" all-gcc all-target-libgcc; \
	$(MAKE) install-gcc install-target-libgcc
	touch $@

b.gcc-2-cfg:
	cd gcc-*; mkdir -p build-final && cd build-final; \
	../configure --target=${TARGET} --prefix=${PREFIX} \
		--enable-languages=c,c++ \
		--with-newlib \
		--with-headers=${PREFIX}/${TARGET}/include \
		--disable-shared \
		--disable-threads \
		--disable-libssp \
		--disable-libgomp \
		--disable-libmudflap \
		--disable-nls \
		--disable-werror CXXFLAGS="${CXXFLAGS}" CFLAGS="${CFLAGS}"
	touch $@

b.gcc-2: b.gcc-2-cfg
	cd gcc-*; mkdir -p build-final && cd build-final; \
	$(MAKE) STAGE1_CXXFLAGS="${CXXFLAGS}"; $(MAKE) install
	touch $@

b.newlib:
	if [ ! -d newlib-* ]; then \
		tar xf ${SRC_DIR}/newlib-*.tar.*; \
		cd newlib-*; \
		patch -p1 < ../newlib.patch; \
	fi
	cd newlib-*; \
	export CFLAGS="${CFLAGS} -D_LDBL_EQ_DBL -D__IEEE_LITTLE_ENDIAN -D__mn10300__"; mkdir -p build; cd build; \
	../configure --target=${TARGET} --prefix=${PREFIX} \
		--disable-newlib-supplied-syscalls \
		--enable-newlib-reent-small \
		--disable-nls; \
	$(MAKE); $(MAKE) install
	touch $@

b.gcc: b.binutils
	if [ ! -d gcc-* ]; then \
		tar xf ${SRC_DIR}/gcc-*.tar.*; \
		cd gcc-*; \
		patch -p1 < ../gcc.patch; \
		contrib/download_prerequisites; \
	fi
	$(MAKE) b.gcc-1
	$(MAKE) b.newlib
	$(MAKE) b.gcc-2
	touch $@

##############################################################################

makepatch:
	rm -f gcc-5.5.0/gcc/config/mn10300/*.orig
	-diff -ruN org_gcc-5.5.0/gcc/config/mn10300 gcc-5.5.0/gcc/config/mn10300 > gcc.patch
	rm -f newlib-2.2.0.20150423/missing.orig
	-diff -ruN org_newlib-2.2.0.20150423/missing newlib-2.2.0.20150423/missing > newlib.patch

##############################################################################

clean:
	rm -rf b.* log gcc-*/build-* binutils-*/build newlib-*/build
