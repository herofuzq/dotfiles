bin/cpu_load: cpu_load.c cpu.h ../sketchybar.h makefile | bin
	clang -std=c99 -O3 $< -o $@.new
	mv -f $@.new $@

bin:
	mkdir -p bin
