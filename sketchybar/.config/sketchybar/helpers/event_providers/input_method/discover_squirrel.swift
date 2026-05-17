#!/usr/bin/env swift

/// Squirrel 通知发现脚本
/// 运行此脚本，然后在鼠须管中按 Shift 切换中/英文模式，
/// 脚本会打印出 Squirrel 发出的所有 DistributedNotification 的名称及 userInfo。
///
/// 用法:
///   swift discover_squirrel.swift
///
/// 观察输出，找到类似 "SquirrelNotificationName" 或包含 "Squirrel" 的通知名，
/// 确认其 userInfo 中是否包含 mode/action 相关字段。

import Foundation

print("🔍 开始监听分布式通知...")
print("   请按 Shift 切换鼠须管中/英文模式 3-5 次")
print("   (按 Ctrl+C 退出)\n")

let center = DistributedNotificationCenter.default()

let observer = center.addObserver(
    forName: nil,
    object: nil,
    queue: .main
) { notification in
    let name = notification.name.rawValue

    // 只关心 Squirrel 相关的通知
    guard name.lowercased().contains("squirrel") ||
          name.lowercased().contains("rime") ||
          name.lowercased().contains("inputmethod") else {
        return
    }

    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)]")
    print("  Notification: \(name)")
    if let userInfo = notification.userInfo {
        print("  UserInfo: \(userInfo)")
    } else {
        print("  UserInfo: (nil)")
    }
    print("")
}

// 保活 30 秒
RunLoop.main.run(until: Date(timeIntervalSinceNow: 30))
print("⏰ 30 秒已到，脚本退出。")
