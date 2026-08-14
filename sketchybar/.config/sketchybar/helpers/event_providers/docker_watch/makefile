include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/docker_watch: docker_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) docker_watch $@ 4 docker_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) docker_watch.swift -o @OUTPUT@

bin:
	mkdir -p bin
