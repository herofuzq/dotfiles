HELPER_COMPILE = ../helper_compile.sh

bin/menus: menus.c makefile $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) menus $@ 3 menus.c makefile $(HELPER_COMPILE) -- clang -std=c99 -O3 -F/System/Library/PrivateFrameworks/ -framework Carbon -framework SkyLight menus.c -o @OUTPUT@

bin:
	mkdir -p bin
