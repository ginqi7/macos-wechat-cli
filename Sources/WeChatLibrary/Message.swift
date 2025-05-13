import Foundation

public class Message: Encodable {
  private enum EncodingKeys: String, CodingKey {
    case user
    case message
  }

  var user: String
  var message: String

  public init(user: String, message: String) {
    self.user = user
    self.message = message
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
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
