//
//  RetryPolicyTests.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 19.08.2026.
//

import XCTest
@testable import AsyncPrimitivesKit

struct DummyError: Error, Equatable {
    let code: Int
}

final class RetryPolicyTests: XCTestCase {

    // MARK: - Успех с первой попытки

    func test_succeedsOnFirstAttempt_doesNotRetry() async throws {
        var callCount = 0
        let sleeper = TestSleeper()

        let result = try await withRetry(
            policy: .constant(maxAttempts: 3, delay: 1.0),
            sleeper: sleeper
        ) {
            callCount += 1
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1, "Операция должна выполниться только один раз")
        XCTAssertTrue(sleeper.recordedDelays.isEmpty, "Не должно быть задержек, если сразу успех")
    }

    // MARK: - Успех после нескольких неудач

    func test_succeedsAfterFailures_retriesCorrectNumberOfTimes() async throws {
        var callCount = 0
        let sleeper = TestSleeper()

        let result = try await withRetry(
            policy: .constant(maxAttempts: 5, delay: 1.0),
            sleeper: sleeper
        ) {
            callCount += 1
            if callCount < 3 {
                throw DummyError(code: 500)
            }
            return "recovered"
        }

        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(callCount, 3, "Должно быть 2 неудачи + 1 успешная попытка")
        XCTAssertEqual(sleeper.recordedDelays.count, 2, "Задержка должна быть только между попытками, не после успеха")
    }

    // MARK: - Исчерпание всех попыток

    func test_allAttemptsFail_throwsRetryExhaustedError() async {
        var callCount = 0
        let sleeper = TestSleeper()

        do {
            _ = try await withRetry(
                policy: .constant(maxAttempts: 3, delay: 1.0),
                sleeper: sleeper
            ) {
                callCount += 1
                throw DummyError(code: 503)
            } as String

            XCTFail("Ожидалась ошибка RetryExhaustedError")
        } catch let error as RetryExhaustedError {
            XCTAssertEqual(error.attempts, 3)
            XCTAssertEqual(error.lastError as? DummyError, DummyError(code: 503))
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }

        XCTAssertEqual(callCount, 3, "Должно быть ровно maxAttempts попыток")
        XCTAssertEqual(sleeper.recordedDelays.count, 2, "Задержка между попытками, но не после последней неудачи")
    }

    // MARK: - shouldRetry: false прерывает сразу

    func test_shouldRetryReturnsFalse_stopsImmediately() async {
        var callCount = 0
        let sleeper = TestSleeper()

        let policy = RetryPolicy(
            maxAttempts: 5,
            backoff: .constant(1.0),
            shouldRetry: { error in
                // Например, не ретраим "клиентские" ошибки (аналог 4xx)
                (error as? DummyError)?.code != 400
            }
        )

        do {
            _ = try await withRetry(policy: policy, sleeper: sleeper) {
                callCount += 1
                throw DummyError(code: 400)
            } as String

            XCTFail("Ожидалась исходная ошибка, а не RetryExhaustedError")
        } catch let error as DummyError {
            XCTAssertEqual(error.code, 400)
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }

        XCTAssertEqual(callCount, 1, "Не должно быть повторных попыток для неретраибельной ошибки")
        XCTAssertTrue(sleeper.recordedDelays.isEmpty)
    }

    // MARK: - Отмена Task прерывает retry

    func test_taskCancellation_stopsRetryingImmediately() async throws {
        var callCount = 0
        let sleeper = TestSleeper()

        let task = Task {
            try await withRetry(
                policy: .constant(maxAttempts: 10, delay: 1.0),
                sleeper: sleeper
            ) { () -> String in
                callCount += 1
                throw DummyError(code: 500)
            }
        }

        // Отменяем сразу — до того как retry успеет сделать много попыток
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Ожидалась CancellationError")
        } catch is CancellationError {
            // ok
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    // MARK: - Проверка расчёта exponential backoff

    func test_exponentialBackoff_delaysGrowCorrectly() async throws {
        var callCount = 0
        let sleeper = TestSleeper()

        let policy = RetryPolicy(
            maxAttempts: 4,
            backoff: .exponential(base: 1.0, multiplier: 2.0, jitter: false)
        )

        _ = try? await withRetry(policy: policy, sleeper: sleeper) { () -> String in
            callCount += 1
            throw DummyError(code: 500)
        }

        // Ожидаем задержки: 1.0, 2.0, 4.0 (перед попытками 2, 3, 4)
        XCTAssertEqual(sleeper.recordedDelays, [1.0, 2.0, 4.0])
    }

    // MARK: - Проверка linear backoff

    func test_linearBackoff_delaysGrowCorrectly() async throws {
        let sleeper = TestSleeper()

        let policy = RetryPolicy(
            maxAttempts: 4,
            backoff: .linear(base: 0.5)
        )

        _ = try? await withRetry(policy: policy, sleeper: sleeper) { () -> String in
            throw DummyError(code: 500)
        }

        // Ожидаем: 0.5, 1.0, 1.5
        XCTAssertEqual(sleeper.recordedDelays, [0.5, 1.0, 1.5])
    }
}
