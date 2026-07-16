include ../../swift.mk

all: bin/sys_watch

bin/sys_watch: sys_watch.swift makefile ../../swift.mk | bin
	$(SKETCHYBAR_SWIFTC) $< -o $@.new
	mv -f $@.new $@

bin:
	mkdir -p bin
