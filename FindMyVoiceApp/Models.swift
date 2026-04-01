import Foundation

struct AppConfig: Codable, Equatable {
    var apiKey: String
    var apiProvider: String
    var apiBaseUrl: String
    var model: String
    var language: String
    var hotkey: String
    var soundStart: String
    var soundStop: String
    var autoPaste: Bool
    var autoCapitalize: Bool
    var autoPunctuate: Bool

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case apiProvider = "api_provider"
        case apiBaseUrl = "api_base_url"
        case model
        case language
        case hotkey
        case soundStart = "sound_start"
        case soundStop = "sound_stop"
        case autoPaste = "auto_paste"
        case autoCapitalize = "auto_capitalize"
        case autoPunctuate = "auto_punctuate"
    }

    static let `default` = AppConfig(
        apiKey: "",
        apiProvider: "openai",
        apiBaseUrl: "https://api.openai.com/v1",
        model: "whisper-1",
        language: "en",
        hotkey: "f1",
        soundStart: "Tink",
        soundStop: "Pop",
        autoPaste: true,
        autoCapitalize: true,
        autoPunctuate: true
    )
}

struct BackendStatus: Codable {
    let recording: Bool
}
