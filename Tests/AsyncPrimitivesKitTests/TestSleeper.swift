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
actor TestSleeper: Sleeper {
    private(set) var recordedDelays: [TimeInterval] = []

    func sleep(for interval: TimeInterval) async throws {
        recordedDelays.append(interval)
    }
}
