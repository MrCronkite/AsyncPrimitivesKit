//
//  AsyncDebouncer.swift
//  AsyncPrimitivesKit
//
//  Created by Влад Шимченко on 20.08.2026.
//

import Foundation

/// Откладывает выполнение действия до тех пор, пока не пройдёт `interval`
/// секунд без новых вызовов. Каждый новый вызов `call` отменяет
/// предыдущий ожидающий вызов — выполнится только последний.
///
/// Типичный сценарий: debounce поискового запроса по мере ввода текста.
public actor AsyncDebouncer<Value: Sendable> {
    private let interval: TimeInterval
    private let sleeper: Sleeper
    private var pendingTask: Task<Void, Never>?

    public init(interval: TimeInterval, sleeper: Sleeper = RealSleeper()) {
        self.interval = interval
        self.sleeper = sleeper
    }

    /// Регистрирует новый вызов. Отменяет предыдущий ожидающий вызов
    /// (если он ещё не выполнился) и запускает отсчёт заново.
    ///
    /// - Parameters:
    ///   - value: значение, которое будет передано в `action`, если
    ///            вызов "выживет" до конца паузы
    ///   - action: асинхронное действие, выполняемое после `interval`
    ///             секунд тишины
    public func call(_ value: Value, action: @escaping @Sendable (Value) async -> Void) {
        // Отменяем предыдущий ожидающий вызов — он либо ещё спит
        // (тогда просто не проснётся с выполнением), либо уже
        // выполняется (тогда cancel() ни на что не повлияет, это ок,
        // т.к. debounce не должен прерывать уже стартовавшее действие).
        pendingTask?.cancel()

        pendingTask = Task { [interval, sleeper] in
            do {
                try await sleeper.sleep(for: interval)
            } catch {
                // Task.sleep бросает CancellationError при отмене —
                // это ожидаемый путь, просто выходим без выполнения action.
                return
            }

            // Двойная проверка на случай, если отмена произошла
            // ровно в момент пробуждения от сна.
            guard !Task.isCancelled else { return }

            await action(value)
        }
    }

    /// Отменяет текущий ожидающий вызов, если он есть, без замены новым.
    public func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
