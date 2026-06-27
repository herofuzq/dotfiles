#include "cpu.h"
#include <math.h>
#include "../sketchybar.h"

int main(int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  struct cpu cpu;
  cpu_init(&cpu);

  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  char trigger_message[512];
  for (;;) {
    cpu_update(&cpu);

    snprintf(trigger_message,
             512,
             "--trigger '%s' "
             "user_load='%d' sys_load='%02d' total_load='%02d'",
             argv[1],
             cpu.user_load,
             cpu.sys_load,
             cpu.total_load);

    sketchybar(trigger_message);
    // isfinite 拦 NaN/inf:NaN 让所有比较返 false,会跳过 usleep 形成死循环;
    // inf 会让 usleep 参数溢出 (uint32_t 微秒约 4294s 上限)。
    if (isfinite(update_freq) && update_freq > 0.0f && update_freq < 3600.0f)
      usleep(update_freq * 1000000);
  }
  return 0;
}
