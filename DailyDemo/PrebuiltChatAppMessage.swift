import Foundation

public struct PrebuiltChatAppMessage: Codable {
    public static let notificationIdentifier: String = "prebuilt-chat-app-message"

    public let message: String
    public let senderName: String

    public init(
        message: String,
        senderName: String
    ) {
        self.senderName = senderName
        self.message = message
    }
}

enum Command: Codable, CaseIterable {
    case foo
    case bar
    case baz
}

extension PrebuiltChatAppMessage {
    var embeddedCommand: Command? {
        guard let messageData = Data(base64Encoded: message) else { return nil }
        return try? JSONDecoder().decode(Command.self, from: messageData)
    }
}
