import AppKit
import ApplicationServices
import CoreGraphics

public enum ChatLocation: String {
  case chatList, chatButton, chatInput, chatMessages
}

public class WeChat {
  var windowElement: AXUIElement?

  final var locateLinks: [ChatLocation: [NSAccessibility.Role]] = [
    .chatList: [.splitGroup, .scrollArea, .table, .row, .cell, .row],
    .chatButton: [.radioButton],
    .chatInput: [.splitGroup, .splitGroup, .scrollArea, .textArea],
    .chatMessages: [.splitGroup, .splitGroup, .scrollArea, .table, .row, .cell, .unknown],
  ]

  public init() {
  }

  // 辅助函数：检查并引导用户开启辅助功能权限
  func checkAccessibilityPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

    if !accessEnabled {
      print("--------------------------------------------------------------------")
      print("重要: 辅助功能权限未启用!")
      print("请前往: 系统设置 > 隐私与安全性 > 辅助功能")
      print("然后点击 '+'，将此应用添加到列表中并启用它。")
      print("--------------------------------------------------------------------")
      // 尝试打开辅助功能设置面板
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
      {
        NSWorkspace.shared.open(url)
      }
    }
    return accessEnabled
  }

  func getAppWindow() -> AXUIElement? {
    if let windowElement = self.windowElement {
      return windowElement
    }
    checkAccessibilityPermissions()
    let wechatApp = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.tencent.xinWeChat"
    ).first!
    let wechatAppElement = AXUIElementCreateApplication(wechatApp.processIdentifier)
    var mainWindow: CFTypeRef?
    var windowResult = AXUIElementCopyAttributeValue(
      wechatAppElement, NSAccessibility.Attribute.focusedWindow.rawValue as CFString, &mainWindow)
    if windowResult != .success || mainWindow == nil {
      windowResult = AXUIElementCopyAttributeValue(
        wechatAppElement, NSAccessibility.Attribute.mainWindow.rawValue as CFString, &mainWindow)
    }
    guard windowResult == .success, let window = mainWindow else {
      print("无法获取 WeChat 的窗口。错误: \(windowResult.rawValue)")
      return nil
    }
    self.windowElement = window as! AXUIElement  // 实际应做更安全的转换
    return self.windowElement
  }

  func clickChat() {
    guard let windowElement = getAppWindow() else {
      return
    }
    var buttons = windowElement.findElements(
      withRoleLink: self.locateLinks[.chatButton]!,  //[.radioButton],
      maxDepth: 100
    )
    buttons = filterElements(
      elements: buttons, attribute: .help, value: "微信")
    if buttons.count == 1 {
      let button = buttons[0]
      if let value = button.value(),
        value as! Int == 0
      {
        button.click()
      }
    }
  }

  public func listAllChats() -> [ChatInfo] {
    guard let windowElement = getAppWindow() else {
      return []
    }
    clickChat()
    let rows = windowElement.findElements(
      withRoleLink: self.locateLinks[.chatList]!,  // [.splitGroup, .scrollArea, .table, .row, .cell, .row],
      maxDepth: 100
    )
    // let rows: [AXUIElement] = []
    return rows.map {
      toChatInfo(element: $0)!
    }
  }

  func toChatInfo(element: AXUIElement) -> ChatInfo? {

    var infoRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(
      element, NSAccessibility.Attribute.title as CFString, &infoRef) == .success,
      let infoStr = infoRef as? String
    {
      var strs = infoStr.split(separator: ",").map { String($0) }
      let chatInfo: ChatInfo = ChatInfo(title: strs[0], element: element)
      if strs.contains("消息免打扰") {
        strs.removeAll { $0 == "消息免打扰" }
        chatInfo.messageMute = true
      }
      if strs.contains("置顶") {
        strs.removeAll { $0 == "置顶" }
        chatInfo.stick = true
      }
      if let match = strs.filter { $0.contains("条未读消息") }.first {
        strs.removeAll { $0 == match }
        if let num = Int(match.substring(to: match.firstIndex(of: "条")!)),
          num > 1
        {
          chatInfo.unread = num
        }
      }
      if strs.count >= 2 {
        chatInfo.lastMessage = strs[1]
      }

      if strs.count >= 3 {
        chatInfo.lastDate = strs[2]
      }
      return chatInfo
    }
    return nil
  }

  func filterElements(elements: [AXUIElement], chidrenCount: Int)
    -> [AXUIElement]
  {
    var results: [AXUIElement] = []
    for element in elements {
      var children: CFTypeRef?
      if AXUIElementCopyAttributeValue(
        element, NSAccessibility.Attribute.children as CFString, &children) == .success,
        (children as? [AnyObject])?.count == chidrenCount
      {
        results.append(element)
      }
    }
    return results
  }

  func filterElements(elements: [AXUIElement], attribute: NSAccessibility.Attribute, value: String)
    -> [AXUIElement]
  {
    var results: [AXUIElement] = []
    for element in elements {
      var attributeValue: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, attribute as CFString, &attributeValue) == .success,
        attributeValue as? String == value
      {
        results.append(element)
      }
    }
    return results
  }

  func locateChat(chat: String) {
  }

  public func send(to: String, message: String) {
    guard let windowElement = getAppWindow() else {
      return
    }
    let chats = listAllChats()
    if let chat = chats.first { $0.title == to } {
      let selectElement = chat.element.getParentElement()!.getParentElement()!
      if !selectElement.selected() {
        selectElement.setSelectedState(selected: true)
      }
      let textArea = windowElement.findElements(
        withRoleLink: self.locateLinks[.chatInput]!,  // [.splitGroup, .splitGroup, .scrollArea, .textArea],
        maxDepth: 100
      )
      textArea[0].write(message: message)
      textArea[0].submit()
    }
  }
  public func show(from: String) {
    guard let windowElement = getAppWindow() else {
      return
    }
    let chats = listAllChats()
    if let chat = chats.first { $0.title == from } {
      let selectElement = chat.element.getParentElement()!.getParentElement()!
      if !selectElement.selected() {
        selectElement.setSelectedState(selected: true)
      }
      let messages = windowElement.findElements(
        withRoleLink: self.locateLinks[.chatMessages]!,  // [.splitGroup, .splitGroup, .scrollArea, .table, .row, .cell, .unknown],
        maxDepth: 100
      )
      chat.messages = messages.map { $0.getTitle() }.filter { $0 != nil }.map { $0! }
      for message in chat.messages {
        print(message)
      }
    }
  }
}
