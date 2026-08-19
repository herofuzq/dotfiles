include ../../swift.mk

all: bin/sys_watch

HELPER_COMPILE = ../../helper_compile.sh
MACH_C = ../sketchybar_mach.c
MACH_H = ../sketchybar.h

bin/sys_watch: sys_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) sys_watch $@ 6 sys_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) sys_watch.swift $(MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
