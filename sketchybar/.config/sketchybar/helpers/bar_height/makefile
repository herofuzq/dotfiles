include ../swift.mk

all: bin/bar_height

bin/bar_height: main.swift makefile ../swift.mk | bin
	$(SKETCHYBAR_SWIFTC) -o $@.new main.swift
	mv -f $@.new $@

bin:
	mkdir -p bin
