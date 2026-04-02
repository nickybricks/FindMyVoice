import Foundation

// MARK: - Keyboard Shortcut

struct HotkeyCombo: Codable, Equatable {
    var key: String         // display name from the user's keyboard layout, e.g. "y", "f5"
    var keyCode: Int        // raw Carbon keyCode for RegisterEventHotKey (layout-independent)
    var modifiers: [String] // e.g. ["command", "shift"]

    var isEmpty: Bool { key.isEmpty }

    static let empty = HotkeyCombo(key: "", keyCode: -1, modifiers: [])

    enum CodingKeys: String, CodingKey {
        case key
        case keyCode = "key_code"
        case modifiers
    }

    init(key: String, keyCode: Int, modifiers: [String]) {
        self.key = key
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        keyCode = try c.decodeIfPresent(Int.self, forKey: .keyCode) ?? -1
        modifiers = try c.decode([String].self, forKey: .modifiers)
    }

    /// Modifier symbols for display.
    var displayModifiers: [String] {
        modifiers.compactMap { mod in
            switch mod {
            case "command": return "⌘"
            case "shift":   return "⇧"
            case "option":  return "⌥"
            case "control": return "⌃"
            default:        return nil
            }
        }
    }

    /// Key name for display (uppercased, or symbol for special keys).
    var displayKey: String {
        switch key.lowercased() {
        case "escape": return "Esc"
        case "space":  return "Space"
        case "tab":    return "Tab"
        case "return": return "Return"
        case "delete": return "Delete"
        default:       return key.uppercased()
        }
    }

    /// All display badges in order: modifiers then key.
    var displayBadges: [String] {
        guard !isEmpty else { return [] }
        return displayModifiers + [displayKey]
    }
}

// MARK: - Shortcut Defaults

extension HotkeyCombo {
    static let defaultToggleRecording = HotkeyCombo(key: "f5", keyCode: 96, modifiers: ["command", "shift"])
    static let defaultCancelRecording = HotkeyCombo(key: "escape", keyCode: 53, modifiers: [])
    static let defaultChangeMode      = HotkeyCombo(key: "k", keyCode: 40, modifiers: ["option", "shift"])
}

// MARK: - App Config

struct AppConfig: Codable, Equatable {
    var apiKey: String
    var apiProvider: String
    var openaiModel: String
    var openaiLanguage: String
    var nemoLanguage: String
    var hotkey: String
    var soundStart: String
    var soundStop: String
    var soundMuted: Bool
    var autoPaste: Bool
    var autoCapitalize: Bool
    var autoPunctuate: Bool
    var toggleRecording: HotkeyCombo
    var cancelRecording: HotkeyCombo
    var changeMode: HotkeyCombo
    var pushToTalk: HotkeyCombo
    var mouseShortcut: HotkeyCombo

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case apiProvider = "api_provider"
        case openaiModel = "openai_model"
        case openaiLanguage = "openai_language"
        case nemoLanguage = "nemo_language"
        case hotkey
        case soundStart = "sound_start"
        case soundStop = "sound_stop"
        case soundMuted = "sound_muted"
        case autoPaste = "auto_paste"
        case autoCapitalize = "auto_capitalize"
        case autoPunctuate = "auto_punctuate"
        case toggleRecording = "toggle_recording"
        case cancelRecording = "cancel_recording"
        case changeMode = "change_mode"
        case pushToTalk = "push_to_talk"
        case mouseShortcut = "mouse_shortcut"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apiKey         = try c.decode(String.self, forKey: .apiKey)
        apiProvider    = try c.decode(String.self, forKey: .apiProvider)
        openaiModel    = try c.decode(String.self, forKey: .openaiModel)
        openaiLanguage = try c.decode(String.self, forKey: .openaiLanguage)
        nemoLanguage   = try c.decode(String.self, forKey: .nemoLanguage)
        hotkey         = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? ""
        soundStart     = try c.decode(String.self, forKey: .soundStart)
        soundStop      = try c.decode(String.self, forKey: .soundStop)
        soundMuted     = try c.decodeIfPresent(Bool.self, forKey: .soundMuted) ?? false
        autoPaste      = try c.decode(Bool.self, forKey: .autoPaste)
        autoCapitalize = try c.decode(Bool.self, forKey: .autoCapitalize)
        autoPunctuate  = try c.decode(Bool.self, forKey: .autoPunctuate)
        toggleRecording = try c.decodeIfPresent(HotkeyCombo.self, forKey: .toggleRecording) ?? .defaultToggleRecording
        cancelRecording = try c.decodeIfPresent(HotkeyCombo.self, forKey: .cancelRecording) ?? .defaultCancelRecording
        changeMode      = try c.decodeIfPresent(HotkeyCombo.self, forKey: .changeMode) ?? .defaultChangeMode
        pushToTalk      = try c.decodeIfPresent(HotkeyCombo.self, forKey: .pushToTalk) ?? .empty
        mouseShortcut   = try c.decodeIfPresent(HotkeyCombo.self, forKey: .mouseShortcut) ?? .empty
    }

    init(apiKey: String, apiProvider: String, openaiModel: String, openaiLanguage: String,
         nemoLanguage: String, hotkey: String, soundStart: String, soundStop: String,
         soundMuted: Bool = false, autoPaste: Bool, autoCapitalize: Bool, autoPunctuate: Bool,
         toggleRecording: HotkeyCombo = .defaultToggleRecording,
         cancelRecording: HotkeyCombo = .defaultCancelRecording,
         changeMode: HotkeyCombo = .defaultChangeMode,
         pushToTalk: HotkeyCombo = .empty,
         mouseShortcut: HotkeyCombo = .empty) {
        self.apiKey = apiKey
        self.apiProvider = apiProvider
        self.openaiModel = openaiModel
        self.openaiLanguage = openaiLanguage
        self.nemoLanguage = nemoLanguage
        self.hotkey = hotkey
        self.soundStart = soundStart
        self.soundStop = soundStop
        self.soundMuted = soundMuted
        self.autoPaste = autoPaste
        self.autoCapitalize = autoCapitalize
        self.autoPunctuate = autoPunctuate
        self.toggleRecording = toggleRecording
        self.cancelRecording = cancelRecording
        self.changeMode = changeMode
        self.pushToTalk = pushToTalk
        self.mouseShortcut = mouseShortcut
    }

    static let `default` = AppConfig(
        apiKey: "",
        apiProvider: "openai",
        openaiModel: "whisper-1",
        openaiLanguage: "auto",
        nemoLanguage: "auto",
        hotkey: "",
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

struct NemoStatus: Codable {
    let installed: Bool
}
