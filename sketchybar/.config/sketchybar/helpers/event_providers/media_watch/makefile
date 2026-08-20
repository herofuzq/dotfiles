include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/media_watch: media_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	ln -sfn "$(CURDIR)/media_watch.swift" bin/main.swift
	$(HELPER_COMPILE) media_watch $@ 7 media_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) bin/main.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
