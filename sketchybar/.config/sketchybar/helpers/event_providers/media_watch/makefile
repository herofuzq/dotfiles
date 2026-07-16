include ../../swift.mk

bin/media_watch: media_watch.swift makefile ../../swift.mk | bin
	$(SKETCHYBAR_SWIFTC) $< -o $@.new
	mv -f $@.new $@

bin:
	mkdir -p bin
