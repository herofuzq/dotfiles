bin/menus: menus.c makefile | bin
	clang -std=c99 -O3 -F/System/Library/PrivateFrameworks/ -framework Carbon -framework SkyLight $< -o $@.new
	mv -f $@.new $@

bin:
	mkdir -p bin
