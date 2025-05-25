import ApplicationServices
import Foundation

public class Message: Encodable {
  private enum EncodingKeys: String, CodingKey {
    case index
    case user
    case message
    case date
  }

  var index: Int
  var user: String
  var message: String
  var element: AXUIElement
  public var date: String

  public init(user: String, message: String, index: Int, date: String, element: AXUIElement) {
    self.user = user
    self.message = message
    self.index = index
    self.date = date
    self.element = element
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encode(self.index, forKey: .index)
    try container.encode(self.user, forKey: .user)
    try container.encode(self.message, forKey: .message)
    try container.encode(self.date, forKey: .date)
  }

  public func toJson() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(self)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

  public func toStr() -> String {
    return "\(self.user) > \(self.message)"
  }
}
