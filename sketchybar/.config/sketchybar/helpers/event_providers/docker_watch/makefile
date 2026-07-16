include ../../swift.mk

bin/docker_watch: docker_watch.swift makefile ../../swift.mk | bin
	$(SKETCHYBAR_SWIFTC) $< -o $@.new
	mv -f $@.new $@

bin:
	mkdir -p bin
