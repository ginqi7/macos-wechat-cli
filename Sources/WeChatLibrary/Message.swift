import Foundation

public class Message: Encodable {
  private enum EncodingKeys: String, CodingKey {
    case index
    case user
    case message
  }

  var index: Int
  var user: String
  var message: String

  public init(user: String, message: String, index: Int) {
    self.user = user
    self.message = message
    self.index = index
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encode(self.index, forKey: .index)
    try container.encode(self.user, forKey: .user)
    try container.encode(self.message, forKey: .message)
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
