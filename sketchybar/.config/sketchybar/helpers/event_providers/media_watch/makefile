include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/media_watch: media_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) media_watch $@ 4 media_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) media_watch.swift -o @OUTPUT@

bin:
	mkdir -p bin
