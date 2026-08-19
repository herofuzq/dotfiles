include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh
MACH_C = ../sketchybar_mach.c
MACH_H = ../sketchybar.h

bin/input_method_watch: input_method_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) input_method_watch $@ 6 input_method_watch.swift $(MACH_C) $(MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) input_method_watch.swift $(MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
