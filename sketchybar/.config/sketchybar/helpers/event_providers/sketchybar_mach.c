#include "sketchybar.h"

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

// Pack argv the same way SketchyBar's CLI does, then send it on the official
// Mach bootstrap port. Callers must not spawn a `sketchybar` process just to
// deliver --trigger / --set. Returns false when the message cannot be sent.
bool sketchybar_send_args(int argc, const char *const *argv) {
	if (argc <= 0 || argv == NULL) {
		return false;
	}

	size_t total = 1;
	for (int i = 0; i < argc; i++) {
		if (argv[i] == NULL) {
			return false;
		}
		total += strlen(argv[i]) + 1;
	}

	char *formatted = malloc(total);
	if (formatted == NULL) {
		return false;
	}

	size_t caret = 0;
	for (int i = 0; i < argc; i++) {
		size_t n = strlen(argv[i]);
		memcpy(formatted + caret, argv[i], n);
		caret += n;
		formatted[caret++] = '\0';
	}
	formatted[caret] = '\0';

	uint32_t length = (uint32_t)(caret + 1);
	if (!g_mach_port) {
		g_mach_port = mach_get_bs_port();
	}
	bool ok = mach_send_message(g_mach_port, formatted, length);
	if (!ok) {
		g_mach_port = mach_get_bs_port();
		ok = mach_send_message(g_mach_port, formatted, length);
		if (!ok) {
			fprintf(stderr, "sketchybar: mach message send failed, will retry\n");
		}
	}
	free(formatted);
	return ok;
}
