import Foundation
import Translation

@available(iOS 17.4, *)
@objc public class LocalLyricsTranslator: NSObject {
    @objc public static func translate(_ text: String, completion: @escaping (String?) -> Void) {
        Task {
            do {
                let configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: "zh-Hant")
                )
                
                // Retrieve the translation session asynchronously using system APIs
                let translatedText = try await Task.detached {
                    // Initialize the offline translation session and translate text
                    let session = try TranslationSession(configuration: configuration)
                    let response = try await session.translate(text)
                    return response.targetText
                }.value
                
                DispatchQueue.main.async {
                    completion(translatedText)
                }
            } catch {
                DispatchQueue.main.async {
                    print("Translation failed: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
}
