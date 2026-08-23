//
//  AsyncRateLimiterTests.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 23.08.2026.
//

import XCTest
@testable import AsyncPrimitivesKit

final class AsyncRateLimiterTests: XCTestCase {

    // MARK: - Всплеск в пределах capacity выполняется без ожидания

    func test_burstWithinCapacity_executesImmediately() async throws {
        let limiter = AsyncRateLimiter(capacity: 3, refillRate: 1)
        let counter = Counter()

        let start = DispatchTime.now()

        for _ in 0..<3 {
            try await limiter.withPermit { () -> Void in
                await counter.increment()
            }
        }

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000

        let total = await counter.value
        XCTAssertEqual(total, 3)
        XCTAssertLessThan(elapsed, 0.1, "3 операции в пределах capacity не должны ждать")
    }

    // MARK: - Превышение capacity вызывает ожидание

    func test_exceedingCapacity_waitsForRefill() async throws {
        let limiter = AsyncRateLimiter(capacity: 2, refillRate: 10)
        let counter = Counter()

        let start = DispatchTime.now()

        for _ in 0..<3 {
            try await limiter.withPermit { () -> Void in
                await counter.increment()
            }
        }

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000

        let total = await counter.value
        XCTAssertEqual(total, 3)
        XCTAssertGreaterThanOrEqual(elapsed, 0.09, "3-я операция должна была подождать пополнения токена")
    }

    // MARK: - Все операции в итоге выполняются под нагрузкой

    func test_manyOperations_allEventuallyComplete() async throws {
        let limiter = AsyncRateLimiter(capacity: 5, refillRate: 20)
        let counter = Counter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<15 {
                group.addTask {
                    try await limiter.withPermit { () -> Void in
                        await counter.increment()
                    }
                }
            }
            try await group.waitForAll()
        }

        let total = await counter.value
        XCTAssertEqual(total, 15)
    }
}
