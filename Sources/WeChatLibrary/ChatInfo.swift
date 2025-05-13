import ApplicationServices
import CoreGraphics
import Foundation

/// A description
public class ChatInfo {
  var title: String
  var stick: Bool = false
  var messageMute: Bool = false
  public var lastMessage: String = ""
  var lastDate: String = ""
  var unread: Int = 0
  var element: AXUIElement
  var messages: [String] = []

  public init(title: String, element: AXUIElement) {
    self.title = title
    self.element = element
  }

  public func toString() -> String {
    return "\(self.title) : \(self.lastMessage) \(self.lastDate)"
  }

}
