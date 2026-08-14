include ../../swift.mk

HELPER_COMPILE = ../../helper_compile.sh

bin/input_method_watch: input_method_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) input_method_watch $@ 4 input_method_watch.swift makefile ../../swift.mk $(HELPER_COMPILE) -- $(SKETCHYBAR_SWIFTC) input_method_watch.swift -o @OUTPUT@

bin:
	mkdir -p bin
