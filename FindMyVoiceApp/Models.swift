import Foundation

struct AppConfig: Codable, Equatable {
    var apiKey: String
    var apiProvider: String
    var openaiModel: String
    var openaiLanguage: String
    var nemoLanguage: String
    var hotkey: String
    var soundStart: String
    var soundStop: String
    var autoPaste: Bool
    var autoCapitalize: Bool
    var autoPunctuate: Bool

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case apiProvider = "api_provider"
        case openaiModel = "openai_model"
        case openaiLanguage = "openai_language"
        case nemoLanguage = "nemo_language"
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
        openaiModel: "whisper-1",
        openaiLanguage: "auto",
        nemoLanguage: "auto",
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
