include ../swift.mk

all: bin/dock_width

HELPER_COMPILE = ../helper_compile.sh

bin/dock_width: main.swift makefile ../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) dock_width $@ 4 main.swift makefile ../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) -o @OUTPUT@ main.swift

bin:
	mkdir -p bin
