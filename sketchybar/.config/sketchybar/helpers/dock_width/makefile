include ../swift.mk

all: bin/dock_width

bin/dock_width: main.swift makefile ../swift.mk | bin
	$(SKETCHYBAR_SWIFTC) -o $@.new main.swift
	mv -f $@.new $@

bin:
	mkdir -p bin
