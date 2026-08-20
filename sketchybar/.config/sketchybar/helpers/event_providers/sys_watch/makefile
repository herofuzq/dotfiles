include ../../swift.mk

all: bin/sys_watch

HELPER_COMPILE = ../../helper_compile.sh

bin/sys_watch: sys_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	ln -sfn "$(CURDIR)/sys_watch.swift" bin/main.swift
	$(HELPER_COMPILE) sys_watch $@ 7 sys_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) bin/main.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
