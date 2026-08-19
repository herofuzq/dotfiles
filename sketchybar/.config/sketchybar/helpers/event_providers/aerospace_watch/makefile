include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh
MACH_C = ../sketchybar_mach.c
MACH_H = ../sketchybar.h

bin/aerospace_watch: aerospace_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) aerospace_watch $@ 6 aerospace_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) aerospace_watch.swift $(MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
