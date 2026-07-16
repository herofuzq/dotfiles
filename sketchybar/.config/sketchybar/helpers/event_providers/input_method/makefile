include ../../swift.mk

bin/input_method_watch: input_method_watch.swift makefile ../../swift.mk | bin
	$(SKETCHYBAR_SWIFTC) $< -o $@.new
	mv -f $@.new $@

bin:
	mkdir -p bin
