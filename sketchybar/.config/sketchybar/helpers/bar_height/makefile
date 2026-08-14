include ../swift.mk

all: bin/bar_height

HELPER_COMPILE = ../helper_compile.sh

bin/bar_height: main.swift makefile ../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) bar_height $@ 4 main.swift makefile ../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) -o @OUTPUT@ main.swift

bin:
	mkdir -p bin
