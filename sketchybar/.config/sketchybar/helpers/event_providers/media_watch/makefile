include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh
MACH_C = ../sketchybar_mach.c
MACH_H = ../sketchybar.h

bin/media_watch: media_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) media_watch $@ 6 media_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) media_watch.swift $(MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
