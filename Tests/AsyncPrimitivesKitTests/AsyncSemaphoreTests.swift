//
//  AsyncSemaphoreTests.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 23.08.2026.
//

import XCTest
@testable import AsyncPrimitivesKit

final class AsyncSemaphoreTests: XCTestCase {

    // MARK: - Не превышает лимит одновременных операций

    func test_limitsConcurrentExecution() async throws {
        let semaphore = AsyncSemaphore(limit: 2)
        let tracker = ConcurrencyTracker()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await semaphore.withPermit {
                        await tracker.enter()
                        try await Task.sleep(nanoseconds: 20_000_000) // 20ms — имитация работы
                        await tracker.exit()
                    }
                }
            }
            try await group.waitForAll()
        }

        let maxObserved = await tracker.maxConcurrent
        XCTAssertLessThanOrEqual(maxObserved, 2, "Не должно быть больше 2 одновременных выполнений")
    }

    // MARK: - Все операции в итоге выполняются

    func test_allOperationsEventuallyComplete() async throws {
        let semaphore = AsyncSemaphore(limit: 3)
        let counter = Counter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await semaphore.withPermit { () -> Void in
                        await counter.increment()
                    }
                }
            }
            try await group.waitForAll()
        }

        let total = await counter.value
        XCTAssertEqual(total, 20, "Все 20 операций должны выполниться, просто не одновременно")
    }

    // MARK: - Слот освобождается даже при ошибке внутри operation

    func test_releasesPermitEvenOnError() async throws {
        let semaphore = AsyncSemaphore(limit: 1)

        // Первый вызов бросает ошибку
        do {
            try await semaphore.withPermit { () -> Void in
                throw DummyError(code: 1)
            }
        } catch {
            // ожидаемо
        }

        // Даём время фоновому release() выполниться
        try await Task.sleep(nanoseconds: 50_000_000)

        // Если слот не освободился — этот вызов зависнет и тест упадёт по таймауту
        let flag = Flag()
        try await semaphore.withPermit { () -> Void in
            await flag.set(true)
        }

        let executed = await flag.value
        XCTAssertTrue(executed, "Слот должен освободиться после ошибки в предыдущей операции")
    }
}

/// Вспомогательный actor для отслеживания максимального числа
/// одновременно выполняющихся операций в тесте.
actor ConcurrencyTracker {
    private var current = 0
    private(set) var maxConcurrent = 0

    func enter() {
        current += 1
        maxConcurrent = max(maxConcurrent, current)
    }

    func exit() {
        current -= 1
    }
}

/// Простой изолированный флаг для проверки, что замыкание было вызвано.
actor Flag {
    private(set) var value = false

    func set(_ newValue: Bool) {
        value = newValue
    }
}
