include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/input_method_watch: input_method_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) | bin
	ln -sfn "$(CURDIR)/input_method_watch.swift" bin/main.swift
	$(HELPER_COMPILE) input_method_watch $@ 7 input_method_watch.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) $(SKETCHYBAR_MACH_H) makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) bin/main.swift $(SKETCHYBAR_MACH_SWIFT) $(SKETCHYBAR_MACH_C) -o @OUTPUT@

bin:
	mkdir -p bin
