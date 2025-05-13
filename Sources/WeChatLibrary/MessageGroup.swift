import Foundation

public class MessageGroup: Encodable {
  private enum EncodingKeys: String, CodingKey {
    case date
    case messages
  }

  var date: String
  var messages: [Message]

  public init(date: String, messages: [Message]) {
    self.date = date
    self.messages = messages
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encode(self.date, forKey: .date)
    try container.encode(self.messages, forKey: .messages)
  }

  public func toJson() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(self)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

  public func toStr() -> String {
    let dateStr = "---------- \(self.date) ----------"
    let messagesStr = self.messages.map { $0.toStr() }.joined(separator: "\n")
    return "\(dateStr)\n\(messagesStr)"
  }
}
