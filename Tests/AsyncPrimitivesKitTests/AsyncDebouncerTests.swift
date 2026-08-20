//
//  AsyncDebouncerTests.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 20.08.2026.
//

import XCTest
@testable import AsyncPrimitivesKit

final class AsyncDebouncerTests: XCTestCase {

    // MARK: - Одиночный вызов выполняется

    func test_singleCall_executesAfterInterval() async throws {
        let sleeper = TestSleeper()
        let debouncer = AsyncDebouncer<String>(interval: 0.3, sleeper: sleeper)
        let collector = ValueCollector<String>()

        await debouncer.call("query") { value in
            await collector.add(value)
        }

        // Даём Task внутри actor'а шанс выполниться
        try await Task.sleep(nanoseconds: 50_000_000)

        let values = await collector.values
        XCTAssertEqual(values, ["query"])
    }

    // MARK: - Быстрые повторные вызовы — выполняется только последний

    func test_rapidCalls_onlyLastOneExecutes() async throws {
        let sleeper = TestSleeper()
        let debouncer = AsyncDebouncer<String>(interval: 0.3, sleeper: sleeper)
        let collector = ValueCollector<String>()

        await debouncer.call("a") { await collector.add($0) }
        await debouncer.call("ab") { await collector.add($0) }
        await debouncer.call("abc") { await collector.add($0) }

        try await Task.sleep(nanoseconds: 50_000_000)

        let values = await collector.values
        XCTAssertEqual(values, ["abc"], "Должно выполниться только последнее значение")
    }

    // MARK: - Явная отмена

    func test_explicitCancel_preventsExecution() async throws {
        let sleeper = TestSleeper()
        let debouncer = AsyncDebouncer<String>(interval: 0.3, sleeper: sleeper)
        let collector = ValueCollector<String>()

        await debouncer.call("query") { await collector.add($0) }
        await debouncer.cancel()

        try await Task.sleep(nanoseconds: 50_000_000)

        let values = await collector.values
        XCTAssertTrue(values.isEmpty, "Отменённый вызов не должен выполниться")
    }
}

/// Вспомогательный actor для сбора значений из конкурентного кода в тестах.
actor ValueCollector<T: Sendable> {
    private(set) var values: [T] = []

    func add(_ value: T) {
        values.append(value)
    }
}
