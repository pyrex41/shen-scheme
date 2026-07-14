ifeq ($(OS), Windows_NT)
	os = windows
	m ?= ta6nt
else ifeq ($(shell uname -s), Darwin)
	os = macOS
	uname_m := $(shell uname -m)
	ifeq ($(uname_m), arm64)
		m ?= tarm64osx
	else
		m ?= ta6osx
	endif
else
	os = linux
	uname_m := $(shell uname -m)
	ifeq ($(uname_m), aarch64)
		m ?= tarm64le
	else ifeq ($(uname_m), riscv64)
		m ?= trv64le
	else
		m ?= ta6le
	endif
endif

ifeq ($(os), windows)
	S = \\\\
	objext = .obj
	arext = .lib
	binext = .exe
	archiveext = .zip
	cskernelname = csv1030mt
	lz4dirname = lz4mts$(S)lib
	lz4libname = liblz4
	zlibdirname = zlibmts
	zliblibname = zlib
	compress = 7z a -tzip
	uncompress = 7z x
	uncompressToFlag = -o
else
	S = /
	objext = .o
	arext = .a
	binext =
	archiveext = .tar.gz
	cskernelname = libkernel
	lz4dirname = lz4$(S)lib
	lz4libname = liblz4
	zlibdirname = zlib
	zliblibname = libz
	compress = tar cvzf
	uncompress = tar xzf
	uncompressToFlag = -C
endif

ifeq ($(os), linux)
	linkerflags = -lm -ldl -lpthread -luuid
endif

shenversion ?= 41.2
csversion ?= 10.3.0

# Kernel sourcing -- see KERNEL-PROVENANCE.md.
# The kernel proper is Mark Tarver's S41.2 "2026-07-11 refresh": the SAME 41.2
# version number but a RESTRUCTURED kernel (15 KLambda files; no dict.kl,
# init.kl, stlib.kl, compiler.kl or extension-*.kl). Its standard library ships
# separately as lazy .shen sources under Lib/StLib, so stlib.kl and the
# command-line launcher (extension-launcher.kl) are taken from the community
# shen-sources 41.2 release to preserve the standard library and REPL front end.
tarver_zip_url ?= https://www.shenlanguage.org/Download/S41.2.zip
tarver_zip_sha256 ?= 51becbfd60fa8c93c3f8ae5b20b948eaa84c4b1d14ad2f5d2a056002a53ee836
build_dir ?= _build
chez_build_dir ?= $(build_dir)$(S)chez
csdir ?= $(chez_build_dir)$(S)csv$(csversion)
cslicense = $(csdir)$(S)LICENSE
cscopyright = $(csdir)$(S)NOTICE
csbootpath = $(csdir)$(S)$(m)$(S)boot$(S)$(m)
psboot = .$(S)$(csbootpath)$(S)petite.boot
csboot = .$(S)$(csbootpath)$(S)scheme.boot
cskernelname ?= libkernel
cskernel = $(csbootpath)$(S)$(cskernelname)$(arext)
zlibdir = $(csdir)$(S)$(m)$(S)$(zlibdirname)
zlib = $(zlibdir)$(S)$(zliblibname)$(arext)
lz4dir = $(csdir)$(S)$(m)$(S)$(lz4dirname)
lz4 = $(lz4dir)$(S)$(lz4libname)$(arext)
csbinpath = $(csdir)$(S)$(m)$(S)bin$(S)$(m)
scmexe = $(csbinpath)$(S)scheme
klsources_dir ?= kl
compiled_dir ?= compiled
exe ?= $(build_dir)/bin/shen-scheme$(binext)
prefix ?= /usr/local
home_path ?= "$(prefix)/lib/shen-scheme"
bootfile = $(build_dir)/lib/shen-scheme/shen.boot

precompiled_dir = $(build_dir)$(S)shen-scheme-v0.26-src

git_tag ?= $(shell git tag -l --contains HEAD 2> /dev/null)
ifeq ("$(git_tag)","")
	git_tag = $(shell git rev-parse --short HEAD 2> /dev/null)
endif
archive_name = shen-scheme-$(git_tag)-src

ifneq ($(uname_m), aarch64)
ifneq ($(uname_m), riscv64)
	CFLAGS += -m64
endif
endif

.DEFAULT: all
.PHONY: all
all: $(exe) $(bootfile)

$(csdir):
	echo "Downloading and uncompressing Chez..."
	mkdir -p $(chez_build_dir)
	cd $(chez_build_dir); curl -LO 'https://github.com/cisco/ChezScheme/releases/download/v$(csversion)/csv$(csversion).tar.gz'; tar xzf csv$(csversion).tar.gz; rm csv$(csversion).tar.gz

$(cskernel): $(csdir)
	echo "Building Chez..."
ifeq ($(os), windows)
	cmd.exe /C 'cd $(csdir) && build.bat ta6nt'
else
	cd $(csdir) && ./configure --threads --disable-curses --disable-iconv --disable-x11 && make
endif

.PHONY: chez_kernel
chez_kernel: $(cskernel)

$(zlib): $(cskernel)

$(lz4): $(cskernel)

$(exe): $(zlib) $(lz4) $(cskernel) main$(objext)
	mkdir -p $(build_dir)/bin
ifeq ($(os), windows)
	cmd.exe /C '$(csdir)$(S)c$(S)vs.bat amd64 && link.exe /out:$(exe) /machine:X64 /incremental:no /release /nologo $(zlib) $(lz4) $(cskernel) main$(objext) /DEFAULTLIB:rpcrt4.lib /DEFAULTLIB:User32.lib /DEFAULTLIB:Advapi32.lib /DEFAULTLIB:Ole32.lib'
else
	$(CC) -o $@ main.o -L$(csbootpath) -lkernel -L$(zlibdir) -L$(lz4dir) -llz4 -lz $(linkerflags)
endif

%$(objext): %.c
ifeq ($(os), windows)
	cmd.exe /C '$(csdir)$(S)c$(S)vs.bat amd64 && cl.exe /c /nologo /W3 /D_CRT_SECURE_NO_WARNINGS /I.$(S)$(csbootpath) /I.$(S)lib /MT /Fo$@ $<'
else
	$(CC) -c -o $@ $< -I$(csbootpath) -I./lib -Wall -Wextra -pedantic $(CFLAGS)
endif

$(bootfile): $(psboot) $(csboot) shen-scheme.scm src/* $(compiled_dir)/*.scm
	mkdir -p $(build_dir)/lib/shen-scheme
	echo '(make-boot-file "$(bootfile)" (list)  "$(psboot)" "$(csboot)" "shen-scheme.scm")' | "$(scmexe)" -q -b "$(psboot)" -b "$(csboot)"

.PHONY: fetch-kernel
fetch-kernel:
	rm -f $(klsources_dir)/dict.kl $(klsources_dir)/init.kl \
	      $(klsources_dir)/extension-features.kl \
	      $(klsources_dir)/extension-expand-dynamic.kl \
	      $(klsources_dir)/extension-programmable-pattern-matching.kl
	rm -f $(klsources_dir)/stlib.kl
	# (1) Community shen-sources 41.2: keep ONLY the command-line launcher
	#     (extension-launcher.kl). stlib.kl is NO LONGER taken from here -- the
	#     standard library is now generated from Tarver's Lib/StLib sources by
	#     `make gen-stlib` (see below).
	curl -LO 'https://github.com/Shen-Language/shen-sources/releases/download/shen-$(shenversion)/ShenOSKernel-$(shenversion).tar.gz'
	tar xzf ShenOSKernel-$(shenversion).tar.gz
	cp ShenOSKernel-$(shenversion)/klambda/extension-launcher.kl $(klsources_dir)/
	# (2) Tarver S41.2 (2026-07-11 refresh): the 15 kernel KLambda files (which
	#     overwrite the community core/sys/...) AND the Lib/StLib .shen sources
	#     (left in S41.2-refresh/ for `make gen-stlib`). The zip's sha256 covers
	#     both.
	curl -LO '$(tarver_zip_url)'
	( command -v sha256sum >/dev/null 2>&1 && echo '$(tarver_zip_sha256)  S41.2.zip' | sha256sum -c - ) || \
	  echo '$(tarver_zip_sha256)  S41.2.zip' | shasum -a 256 -c -
	rm -rf S41.2-refresh && mkdir S41.2-refresh
	cd S41.2-refresh && unzip -q ../S41.2.zip
	cp S41.2-refresh/S41/KLambda/*.kl $(klsources_dir)/

# Generate kl/stlib.kl from Tarver's Lib/StLib .shen sources (see
# scripts/gen-stlib.shen and KERNEL-PROVENANCE.md). Requires a bootstrap Shen
# ($(SHEN), e.g. an existing shen-scheme). Build order from scratch:
#   make fetch-kernel && make SHEN=shen-scheme gen-stlib && make precompile && make
# gen-stlib builds a throwaway kernel-only stage-1 boot (no standard library, so
# registering Tarver's StLib macros can't collide with an existing one), then
# runs the generator on it. The subsequent `make precompile && make` rebuild the
# real image with the generated kl/stlib.kl.
.PHONY: gen-stlib
gen-stlib:
	$(SHEN) script scripts/do-build-stage1.shen > /dev/null
	: > $(compiled_dir)/stlib.scm
	$(MAKE) $(exe) $(bootfile)
	./$(exe) script scripts/gen-stlib.shen
	# discard the throwaway stage-1 artifacts so the real build rebuilds cleanly
	rm -f $(compiled_dir)/stlib.scm shen-scheme.scm $(bootfile) $(exe)

.PHONY: fetch-prebuilt
fetch-prebuilt:
	mkdir -p $(build_dir)
	curl -LO 'https://github.com/tizoc/shen-scheme/releases/download/v0.26/shen-scheme-v0.26-$(os)-bin$(archiveext)'
	$(uncompress) shen-scheme-v0.26-$(os)-bin$(archiveext) $(uncompressToFlag)$(build_dir)

.PHONY: precompile-with-prebuilt
precompile-with-prebuilt:
	$(build_dir)$(S)shen-scheme-v0.26-$(os)-bin$(S)bin$(S)shen-scheme$(binext) script scripts/do-build.shen > /dev/null

$(precompiled_dir):
	mkdir -p $(build_dir)
	curl -LO 'https://github.com/tizoc/shen-scheme/releases/download/v0.26/shen-scheme-v0.26-src.tar.gz'
	tar xzf shen-scheme-v0.26-src.tar.gz -C $(build_dir)
	rm -f $(precompiled_dir)$(S)Makefile
	cp Makefile $(precompiled_dir)$(S)Makefile

.PHONY: precompile
precompile:
	$(SHEN) script scripts/do-build.shen > /dev/null

.PHONY: build-precompiled
build-precompiled: $(precompiled_dir) $(cskernel)
	mkdir -p $(precompiled_dir)$(S)_build
	cp -a $(chez_build_dir) $(precompiled_dir)$(S)$(chez_build_dir)
	cd $(precompiled_dir); make csversion=$(csversion)

.PHONY: test-shen
test-shen: $(exe) $(bootfile)
	./$(exe) script scripts/run-shen-tests.shen

.PHONY: test-compiler
test-compiler: $(exe) $(bootfile)
	./$(exe) script scripts/run-compiler-tests.shen

.PHONY: test
test: test-shen test-compiler

.PHONY: run
run: $(exe) $(bootfile)
	./$(exe)

.PHONY: install
install: $(exe) $(bootfile)
	mkdir -p $(DESTDIR)$(prefix)/bin
	mkdir -p $(DESTDIR)$(home_path)
	install -m 0755 $(exe) $(DESTDIR)$(prefix)/bin
	install -m 0644 $(bootfile) $(DESTDIR)$(home_path)/

.PHONY: source-release
source-release:
	mkdir -p _dist
	git archive --format=tar --prefix="$(archive_name)/" $(git_tag) | (cd _dist && tar xf -)
	cp $(compiled_dir)/*.scm "_dist/$(archive_name)/compiled/"
	cp shen-scheme.scm "_dist/$(archive_name)/shen-scheme.scm"
	rm -rf "_dist/$(archive_name)/".git*
	rm "_dist/$(archive_name)/"*/.gitignore
	cd _dist; tar cvzf "$(archive_name).tar.gz" "$(archive_name)/";	rm -rf "$(archive_name)/"
	echo "Generated tarball for tag $(git_tag) as _dist/$(archive_name).tar.gz"

.PHONY: binary-release
binary-release: $(exe) $(bootfile)
	mkdir -p "_dist/shen-scheme-$(git_tag)-$(os)-bin"
	mkdir -p "_dist/shen-scheme-$(git_tag)-$(os)-bin/bin"
	mkdir -p "_dist/shen-scheme-$(git_tag)-$(os)-bin/lib/shen-scheme"
	mkdir -p "_dist/shen-scheme-$(git_tag)-$(os)-bin/chez-legal"
	cp $(exe) "_dist/shen-scheme-$(git_tag)-$(os)-bin/bin"
	cp $(bootfile) "_dist/shen-scheme-$(git_tag)-$(os)-bin/lib/shen-scheme"
	cp README.md "_dist/shen-scheme-$(git_tag)-$(os)-bin/README.txt"
	cp LICENSE "_dist/shen-scheme-$(git_tag)-$(os)-bin/LICENSE.txt"
	cp $(cslicense) "_dist/shen-scheme-$(git_tag)-$(os)-bin/chez-legal/LICENSE.txt"
	cp $(cscopyright) "_dist/shen-scheme-$(git_tag)-$(os)-bin/chez-legal/NOTICE.txt"
	cd _dist; $(compress) "shen-scheme-$(git_tag)-$(os)-bin$(archiveext)" "shen-scheme-$(git_tag)-$(os)-bin"; rm -rf "shen-scheme-$(git_tag)-$(os)-bin"

.PHONY: clean
clean:
	rm -f $(exe) $(bootfile) *.o *.obj
