HELPER_COMPILE = ../../helper_compile.sh

bin/cpu_load: cpu_load.c cpu.h ../sketchybar.h makefile $(HELPER_COMPILE) | bin
	$(HELPER_COMPILE) cpu_load $@ 5 cpu_load.c cpu.h ../sketchybar.h makefile $(HELPER_COMPILE) -- clang -std=c99 -O3 cpu_load.c -o @OUTPUT@

bin:
	mkdir -p bin
