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

    /// Tracks whether the most recent input source change was initiated by this app.
    /// Used to filter out system notifications for programmatic switches, preventing
    /// feedback loops where our own switch triggers `.inputSourceChanged` in IndicatorVM.
    private var _isProgrammaticChange = false

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
                    self._isProgrammaticChange = true
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
                self?._isProgrammaticChange = false
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
            .filter { [weak self] _ in self?._isProgrammaticChange == false }
            .sink { [weak self] _ in self?.inputSourceChangesSubject.send(())
            }
            .store(in: cancelBag)
    }
}
