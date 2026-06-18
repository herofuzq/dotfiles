all: bin/dock_width

bin/dock_width: main.swift makefile | bin
	swiftc -module-cache-path /tmp/sketchybar-swift-module-cache -O -o bin/dock_width main.swift

bin:
	mkdir -p bin
