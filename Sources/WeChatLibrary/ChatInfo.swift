import ApplicationServices
import CoreGraphics
import Foundation

/// A description
public class ChatInfo: Encodable {
  private enum EncodingKeys: String, CodingKey {
    case index
    case title
    case stick
    case messageMute
    case lastMessage
    case lastDate
    case unread
    case messages
  }

  var index: Int
  var title: String
  var stick: Bool = false
  var messageMute: Bool = false
  var lastMessage: String = ""
  var lastDate: String = ""
  var unread: Int = 0
  var element: AXUIElement
  public var messages: [Message] = []

  public init(title: String, element: AXUIElement, index: Int) {
    self.title = title
    self.element = element
    self.index = index
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
    try container.encode(self.index, forKey: .index)
  }

  public func toStr() -> String {
    return "[\(self.index)] \(self.title) > \(self.lastMessage) (\(self.lastDate))"
  }

  public func messagesToStr() -> String {
    var date = ""
    var str = ""
    str += self.formatDate(date: date)
    for message in self.messages {
      if message.date != date {
        date = message.date
        str += self.formatDate(date: date)
      }
      str += message.toStr() + "\n"
    }
    return str
  }

  func formatDate(date: String) -> String {
    let width = 40
    let half = (width - date.count) / 2
    let seperator = String(repeating: "-", count: half)
    return seperator + date + seperator + "\n"

  }
}
