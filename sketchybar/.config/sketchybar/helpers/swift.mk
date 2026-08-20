# The rolling CLT can briefly ship a compiler newer than its default SDK.
# MacOSX 15.4 is compatible with the helper APIs and current compiler; callers
# may override SKETCHYBAR_SWIFT_SDK after the default toolchain catches up.
SKETCHYBAR_SWIFT_SDK ?= $(if $(wildcard /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk),/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk,$(shell xcrun --sdk macosx --show-sdk-path))
SKETCHYBAR_SWIFTC = swiftc -sdk "$(SKETCHYBAR_SWIFT_SDK)" -module-cache-path /tmp/sketchybar-swift-module-cache -O
# Multi-file Swift helpers may only put top-level statements in main.swift.
# Watcher recipes symlink the real source to bin/main.swift (gitignored).
SKETCHYBAR_MACH_SWIFT = ../sketchybar_mach.swift
SKETCHYBAR_MACH_C = ../sketchybar_mach.c
SKETCHYBAR_MACH_H = ../sketchybar.h
