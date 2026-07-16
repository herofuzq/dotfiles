include ../../swift.mk

bin/aerospace_watch: aerospace_watch.swift makefile ../../swift.mk | bin
	$(SKETCHYBAR_SWIFTC) $< -o $@.new
	mv -f $@.new $@

bin:
	mkdir -p bin
