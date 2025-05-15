import Foundation
import XCTest

@testable import WeChatLibrary

final class ChatInfoTests: XCTestCase {
  func testToStr() throws {
    let chatInfo1: ChatInfo = ChatInfo(
      title: "user1", element: AXUIElementCreateSystemWide(), index: 0)
    chatInfo1.lastMessage = "Hello World!"
    chatInfo1.lastDate = "13:09"
    let chatInfo2: ChatInfo = ChatInfo(
      title: "user2", element: AXUIElementCreateSystemWide(), index: 1)
    chatInfo2.lastMessage = "ginqi7 is a programmer"
    chatInfo2.lastDate = "13:04"
    let chatInfo3: ChatInfo = ChatInfo(
      title: "user1、user2、user3、user4", element: AXUIElementCreateSystemWide(), index: 2)
    chatInfo3.lastMessage = "[哈哈]"
    chatInfo3.lastDate = "2025/05/10"

    let chatInfo4: ChatInfo = ChatInfo(
      title: "公众号", element: AXUIElementCreateSystemWide(), index: 3)
    chatInfo4.lastMessage = "中国移动10086: [链接] 月度话费账单提醒"
    chatInfo4.lastDate = "12:06"

    let chatInfo5: ChatInfo = ChatInfo(
      title: "群组1", element: AXUIElementCreateSystemWide(), index: 4)
    chatInfo5.lastMessage = "user1: 你好"
    chatInfo5.lastDate = "08:16"

    var chatInfos: [ChatInfo] = []
    chatInfos.append(chatInfo1)
    chatInfos.append(chatInfo2)
    chatInfos.append(chatInfo3)
    chatInfos.append(chatInfo4)
    chatInfos.append(chatInfo5)
    if let content = readFile() {
      for (index, line) in content.split(separator: "\n").enumerated() {
        XCTAssertEqual(String(line), chatInfos[index].toStr())
      }
    }
  }

  func readFile() -> String? {
    let sourceFilePath = #file
    let sourceDir = URL(fileURLWithPath: sourceFilePath).deletingLastPathComponent()
    let dataFileURL = sourceDir.appendingPathComponent("list-chat.data.text")
    do {
      let content = try String(contentsOf: dataFileURL, encoding: .utf8)
      return content
    } catch {
      print("读取文件失败：\(error)")
      return nil
    }
  }
}
