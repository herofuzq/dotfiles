all: bin/refresh_rate

bin/refresh_rate: main.swift makefile | bin
	swiftc -module-cache-path /tmp/sketchybar-swift-module-cache -O -o bin/refresh_rate main.swift

bin:
	mkdir -p bin
