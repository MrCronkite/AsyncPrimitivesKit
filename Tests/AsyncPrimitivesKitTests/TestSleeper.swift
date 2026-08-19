//
//  TestSleeper.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 19.08.2026.
//

import Foundation
@testable import AsyncPrimitivesKit

/// Тестовая реализация Sleeper — не ждёт реальное время,
/// а мгновенно возвращается. Записывает все запрошенные задержки,
/// чтобы тест мог проверить, что backoff считается правильно.
final class TestSleeper: Sleeper, @unchecked Sendable {
    private let lock = NSLock()
    private var _recordedDelays: [TimeInterval] = []

    var recordedDelays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return _recordedDelays
    }

    func sleep(for interval: TimeInterval) async throws {
        lock.lock()
        _recordedDelays.append(interval)
        lock.unlock()
        // Не ждём реально — тест выполняется мгновенно.
    }
}
