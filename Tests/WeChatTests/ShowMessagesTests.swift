import Accessibility
import ApplicationServices
import Foundation
import XCTest

@testable import WeChatLibrary

final class ShowMessagesTests: XCTestCase {
  func testToStr() throws {
    let message1 = Message(
      user: "我", message: "I created a WeChat CLI tool.", index: 0, date: "",
      element: AXUIElementCreateApplication(1))
    let message2 = Message(
      user: "user1", message: "Looks good.", index: 1, date: "",
      element: AXUIElementCreateApplication(1))
    let message3 = Message(
      user: "user1", message: "发送了一个图片", index: 2, date: "11:55",
      element: AXUIElementCreateApplication(1))
    let message4 = Message(
      user: "user1", message: "This marks a new beginning.", index: 3, date: "12:12",
      element: AXUIElementCreateApplication(1))
    let message5 = Message(
      user: "user1", message: "发送了一个图片", index: 4, date: "12:12",
      element: AXUIElementCreateApplication(1))
    let message6 = Message(
      user: "user1", message: "哈哈", index: 5, date: "12:12",
      element: AXUIElementCreateApplication(1))
    let message7 = Message(
      user: "我", message: "哈哈", index: 6, date: "12:12", element: AXUIElementCreateApplication(1))

    var messages: [Message] = []
    messages.append(message1)
    messages.append(message2)
    messages.append(message3)
    messages.append(message4)
    messages.append(message5)
    messages.append(message6)
    messages.append(message7)
    let chatInfo = ChatInfo(title: "user1", element: AXUIElementCreateApplication(1), index: 0)
    chatInfo.messages = messages
    if let content = readFile() {
      XCTAssertEqual(content, chatInfo.messagesToStr())
    }
  }

  func readFile() -> String? {
    let sourceFilePath = #file
    let sourceDir = URL(fileURLWithPath: sourceFilePath).deletingLastPathComponent()
    let dataFileURL = sourceDir.appendingPathComponent("show.data.text")
    do {
      let content = try String(contentsOf: dataFileURL, encoding: .utf8)
      return content
    } catch {
      print("读取文件失败：\(error)")
      return nil
    }
  }
}
