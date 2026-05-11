#include "cpu.h"
#include "../sketchybar.h"
#include <string.h>
#include <sys/sysctl.h>

struct mem_info {
  int app_pct;
  int wired_pct;
  int compressed_pct;
  int free_pct;
};

static void get_mem_info(struct mem_info* mem) {
  mach_port_t host = mach_host_self();
  vm_size_t page_size;
  host_page_size(host, &page_size);

  vm_statistics64_data_t vm_stat;
  mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
  if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm_stat, &count) != KERN_SUCCESS) {
    memset(mem, 0, sizeof(*mem));
    return;
  }

  uint64_t mem_total;
  size_t len = sizeof(mem_total);
  sysctlbyname("hw.memsize", &mem_total, &len, NULL, 0);

  uint64_t total_pages = mem_total / page_size;

  uint64_t app_pages = (uint64_t)vm_stat.active_count;
  uint64_t wired_pages = vm_stat.wire_count;
  uint64_t compressed_pages = vm_stat.compressor_page_count;
  uint64_t free_pages = (uint64_t)vm_stat.free_count + vm_stat.inactive_count + vm_stat.speculative_count;

  mem->app_pct = (int)((double)app_pages / (double)total_pages * 100.0);
  mem->wired_pct = (int)((double)wired_pages / (double)total_pages * 100.0);
  mem->compressed_pct = (int)((double)compressed_pages / (double)total_pages * 100.0);
  mem->free_pct = (int)((double)free_pages / (double)total_pages * 100.0);
}

int main(int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);
  struct cpu cpu;
  cpu_init(&cpu);

  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  char trigger_message[512];
  for (;;) {
    cpu_update(&cpu);

    struct mem_info mem;
    get_mem_info(&mem);

    snprintf(trigger_message,
             512,
             "--trigger '%s' "
             "user_load='%d' sys_load='%02d' total_load='%02d' "
             "mem_used='%d' "
             "mem_app='%d' mem_wired='%d' mem_compressed='%d' mem_free='%d'",
             argv[1],
             cpu.user_load,
             cpu.sys_load,
             cpu.total_load,
             mem.app_pct + mem.wired_pct + mem.compressed_pct,
             mem.app_pct,
             mem.wired_pct,
             mem.compressed_pct,
             mem.free_pct);

    sketchybar(trigger_message);
    usleep(update_freq * 1000000);
  }
  return 0;
}
