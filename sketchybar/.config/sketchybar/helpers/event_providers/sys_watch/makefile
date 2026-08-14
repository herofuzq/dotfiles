include ../../swift.mk

all: bin/sys_watch

HELPER_COMPILE = ../../helper_compile.sh

bin/sys_watch: sys_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) sys_watch $@ 4 sys_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) sys_watch.swift -o @OUTPUT@

bin:
	mkdir -p bin
