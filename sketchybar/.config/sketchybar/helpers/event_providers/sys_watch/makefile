all: bin/sys_watch

bin/sys_watch: sys_watch.swift makefile | bin
	swiftc -module-cache-path /tmp/sketchybar-swift-module-cache -O $< -o $@

bin:
	mkdir -p bin
