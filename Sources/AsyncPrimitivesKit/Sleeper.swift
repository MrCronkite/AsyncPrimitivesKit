//
//  Sleeper.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 19.08.2026.
//

import Foundation

/// Абстракция над механизмом ожидания. Нужна, чтобы в тестах
/// подменить реальную задержку на мгновенную и не ждать секунды.
public protocol Sleeper: Sendable {
    func sleep(for interval: TimeInterval) async throws
}

/// Реальная реализация — используется в продакшене.
public struct RealSleeper: Sleeper {
    public init() {}

    public func sleep(for interval: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}
