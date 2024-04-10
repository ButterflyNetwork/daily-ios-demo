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
