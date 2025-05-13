import ApplicationServices
import CoreGraphics
import Foundation

/// A description
public class ChatInfo: Encodable {
  private enum EncodingKeys: String, CodingKey {

    case title
    case stick
    case messageMute
    case lastMessage
    case lastDate
    case unread
    case messages
  }

  var title: String
  var stick: Bool = false
  var messageMute: Bool = false
  var lastMessage: String = ""
  var lastDate: String = ""
  var unread: Int = 0
  var element: AXUIElement
  public var messages: [MessageGroup] = []

  public init(title: String, element: AXUIElement) {
    self.title = title
    self.element = element
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encode(self.title, forKey: .title)
    try container.encode(self.stick, forKey: .stick)
    try container.encode(self.messageMute, forKey: .messageMute)
    try container.encode(self.lastMessage, forKey: .lastMessage)
    try container.encode(self.lastDate, forKey: .lastDate)
    try container.encode(self.unread, forKey: .unread)
    try container.encode(self.messages, forKey: .messages)
  }

  public func toStr() -> String {
    return "\(self.title) > \(self.lastMessage) (\(self.lastDate))"
  }

}
