bin/docker_watch: docker_watch.swift makefile | bin
	swiftc -module-cache-path /tmp/sketchybar-swift-module-cache -O $< -o $@

bin:
	mkdir -p bin
