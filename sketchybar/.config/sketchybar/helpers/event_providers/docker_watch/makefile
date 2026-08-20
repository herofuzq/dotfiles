include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/docker_watch: docker_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	ln -sfn "$(CURDIR)/docker_watch.swift" bin/main.swift
	$(HELPER_COMPILE) docker_watch $@ 7 docker_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) bin/main.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
