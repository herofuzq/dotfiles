include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/aerospace_watch: aerospace_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) aerospace_watch $@ 4 aerospace_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) aerospace_watch.swift -o @OUTPUT@

bin:
	mkdir -p bin
