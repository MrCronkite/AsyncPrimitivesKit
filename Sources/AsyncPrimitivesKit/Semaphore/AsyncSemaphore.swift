//
//  AsyncSemaphore.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 23.08.2026.
//

import Foundation

/// Ограничивает число одновременно выполняющихся операций.
///
/// В отличие от `DispatchSemaphore`, не блокирует поток — приостанавливает
/// (suspends) вызывающий `Task`, пока не освободится слот.
public actor AsyncSemaphore {
    private let limit: Int
    private var availablePermits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// - Parameter limit: максимальное число одновременных операций.
    public init(limit: Int) {
        precondition(limit > 0, "limit должен быть больше 0")
        self.limit = limit
        self.availablePermits = limit
    }

    /// Забирает слот, приостанавливая Task, если все слоты заняты.
    /// Возвращается, как только слот становится доступен.
    public func acquire() async {
        if availablePermits > 0 {
            availablePermits -= 1
            return
        }

        // Слотов нет — встаём в очередь и ждём, пока release()
        // не возобновит именно нас через continuation.
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Освобождает слот. Если есть ожидающие в очереди — передаёт
    /// слот следующему по очереди (FIFO), а не увеличивает счётчик.
    public func release() async {
        if waiters.isEmpty {
            availablePermits += 1
        } else {
            // Передаём слот напрямую первому ожидающему,
            // не трогая availablePermits — слот "переходит из рук в руки".
            let next = waiters.removeFirst()
            next.resume()
        }
    }

    /// Выполняет `operation`, автоматически забирая слот перед выполнением
    /// и освобождая его после — даже если `operation` бросит ошибку.
    public func withPermit<T: Sendable>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        await acquire()
        defer { Task { await self.release() } }
        return try await operation()
    }
}
