all: bin/bar_height

bin/bar_height: main.swift makefile | bin
	swiftc -module-cache-path /tmp/sketchybar-swift-module-cache -O -o bin/bar_height main.swift

bin:
	mkdir -p bin
