import AppKit
import AXSwift
import Carbon
import Combine
import Foundation
import CombineExt

@MainActor
class InputSourceVM: ObservableObject {
    private struct SelectionRequest {
        let inputSource: InputSource
        let app: NSRunningApplication?
        let allowShortcutFallback: Bool
    }

    let preferencesVM: PreferencesVM

    /// Tracks the input source we're programmatically switching to.
    /// Used to filter out system notifications that result from our own TISSelectInputSource
    /// calls, preventing feedback loops in IndicatorVM. Set before the switch, cleared
    /// after the notification is expected to have arrived.
    private var programmaticTarget: InputSource?

    private var cancelBag = CancelBag()

    private let selectInputSourceSubject = PassthroughSubject<SelectionRequest, Never>()

    private let inputSourceChangesSubject = PassthroughSubject<Void, Never>()

    let inputSourceChangesPublisher: AnyPublisher<InputSource, Never>

    init(preferencesVM: PreferencesVM) {
        self.preferencesVM = preferencesVM

        inputSourceChangesPublisher = inputSourceChangesSubject
            .map { _ in InputSource.getCurrentInputSource() }
            .removeDuplicates()
            .eraseToAnyPublisher()

        watchSystemNotification()

        selectInputSourceSubject
            .tap { [weak self] in
                if let self {
                    self.programmaticTarget = $0.inputSource
                    $0.inputSource.select(
                        cJKVFixStrategy: self.preferencesVM.activeCJKVFixStrategy(for: $0.app),
                        allowShortcutFallback: $0.allowShortcutFallback
                    )
                }
            }
            .flatMapLatest({ _ in
                // Multiple checkpoints after switch to ensure the change is detected.
                // CJKV input sources may take longer to settle, so we check at 50ms,
                // 150ms, and 300ms instead of a single 1-second delay.
                Publishers.MergeMany([
                    Just(())
                        .eraseToAnyPublisher(),
                    Timer
                        .delay(seconds: 0.05)
                        .mapToVoid()
                        .eraseToAnyPublisher(),
                    Timer
                        .delay(seconds: 0.15)
                        .mapToVoid()
                        .eraseToAnyPublisher(),
                    Timer
                        .delay(seconds: 0.3)
                        .mapToVoid()
                        .eraseToAnyPublisher()
                ])
                .eraseToAnyPublisher()
            })
            .sink { [weak self] _ in
                self?.inputSourceChangesSubject.send(())
                // Clear target after all checkpoints to stop filtering
                self?.programmaticTarget = nil
            }
            .store(in: cancelBag)
    }

    func select(
        inputSource: InputSource,
        app: NSRunningApplication? = nil,
        allowShortcutFallback: Bool = true
    ) {
        selectInputSourceSubject.send(SelectionRequest(
            inputSource: inputSource,
            app: app,
            allowShortcutFallback: allowShortcutFallback
        ))
    }

    private func watchSystemNotification() {
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String))
            .receive(on: DispatchQueue.main)
            .filter { [weak self] _ in
                // Filter out notifications caused by our own TISSelectInputSource calls.
                // Compare current input source against our target: if they match, the
                // notification is from our programmatic switch and should be ignored.
                guard let target = self?.programmaticTarget else { return true }
                let current = InputSource.getCurrentInputSource()
                return current.persistentIdentifier != target.persistentIdentifier
            }
            .sink { [weak self] _ in self?.inputSourceChangesSubject.send(())
            }
            .store(in: cancelBag)
    }
}
