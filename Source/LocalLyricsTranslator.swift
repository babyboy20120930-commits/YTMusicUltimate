import Foundation
import Translation

@available(iOS 17.4, *)
@objc public class LocalLyricsTranslator: NSObject {
    @objc public static func translate(_ text: String, completion: @escaping (String?) -> Void) {
        Task {
            let source = Locale.Language(identifier: "en")
            let target = Locale.Language(identifier: "zh-Hant")
            let session = TranslationSession(installedSource: source, target: target)
            
            do {
                let response = try await session.translate(text)
                DispatchQueue.main.async {
                    completion(response.targetText)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
