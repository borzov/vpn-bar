import Foundation
import AppKit
import os.log
import AudioToolbox

/// Типы звуковой обратной связи.
enum SoundFeedback {
    case connectionSuccess
    case disconnection
    
    var systemSoundID: SystemSoundID {
        switch self {
        case .connectionSuccess:
            return 1000 // Glass
        case .disconnection:
            return 1003 // Pop
        }
    }
}

/// Управляет звуковой обратной связью для VPN-операций.
@MainActor
final class SoundFeedbackManager {
    static let shared = SoundFeedbackManager()
    
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "SoundFeedback")
    private var isEnabled: Bool {
        SettingsManager.shared.soundFeedbackEnabled
    }
    
    private init() {}
    
    /// Воспроизводит звук для указанного типа обратной связи.
    /// - Parameter feedback: Тип звуковой обратной связи.
    func play(_ feedback: SoundFeedback) {
        guard isEnabled else {
            logger.debug("Sound feedback is disabled")
            return
        }
        
        AudioServicesPlaySystemSound(feedback.systemSoundID)
        
        logger.debug("Playing sound feedback: \(String(describing: feedback))")
    }
}

