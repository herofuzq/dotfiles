include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/aerospace_watch: aerospace_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	ln -sfn "$(CURDIR)/aerospace_watch.swift" bin/main.swift
	$(HELPER_COMPILE) aerospace_watch $@ 7 aerospace_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) bin/main.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
