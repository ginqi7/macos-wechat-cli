import AppKit
import ApplicationServices
import CoreGraphics

public enum ChatLocation: String {
  case chatTitle, chatButton, chatInput, chatViewTable, messageInRow,
    chatListTable, chatTitleInRow
}

public class WeChat {
  var windowElement: AXUIElement?

  final var locateLinks: [ChatLocation: [NSAccessibility.Role]] = [
    .chatListTable: [.splitGroup, .scrollArea, .table],
    .chatTitleInRow: [.cell, .row],
    .chatTitle: [.cell, .row],
    .chatButton: [.radioButton],
    .chatInput: [.splitGroup, .splitGroup, .scrollArea, .textArea],
    .chatViewTable: [.splitGroup, .splitGroup, .scrollArea, .table],
    .messageInRow: [.cell, .unknown],
  ]

  public init() {
  }

  // Helper function: Check and prompt the user to enable accessibility permissions.
  func checkAccessibilityPermissions() {
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
  }

  func getAppWindow() -> AXUIElement? {
    if let windowElement = self.windowElement {
      return windowElement
    }
    checkAccessibilityPermissions()
    guard
      let wechatApp = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.tencent.xinWeChat"
      ).first
    else {
      return nil
    }
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
    self.windowElement = unsafeBitCast(window, to: AXUIElement.self)
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
    if buttons.count == 1,
      let value = buttons[0].value(),
      value as! Int == 0  // If the value is 0, the chat button not activate.
    {
      buttons[0].click()
    }
  }

  public func getChatListTable(windowElement: AXUIElement) -> AXUIElement? {
    if let roleLink = self.locateLinks[.chatListTable],
      let table = windowElement.findElements(
        withRoleLink: roleLink,
        maxDepth: 100
      ).first
    {
      return table
    }
    return nil
  }

  public func getChatRowTitle(row: AXUIElement) -> [AXUIElement] {
    if let chatTitleInRow = self.locateLinks[.chatTitleInRow] {
      return row.findElements(
        withRoleLink: chatTitleInRow,
        maxDepth: 100
      )
    }
    return []
  }

  public func chatRowsToChatInfos(rows: [AXUIElement]) -> [ChatInfo] {
    var result: [ChatInfo] = []
    var chatTitles: [AXUIElement] = []
    var indexList: [Int] = []
    for row in rows {
      if let index = row.getIndex() {
        indexList.append(index)
      }
      chatTitles.append(contentsOf: getChatRowTitle(row: row))
    }

    for (idx, chatTitle) in chatTitles.enumerated() {
      if let chatInfo = toChatInfo(element: chatTitle, index: indexList[idx]) {
        result.append(chatInfo)
      }
    }
    return result
  }

  public func listChats(onlyVisible: Bool = false) -> [ChatInfo] {
    guard let windowElement = getAppWindow() else {
      return []
    }
    clickChat()
    guard let chatListTable = getChatListTable(windowElement: windowElement) else {
      return []
    }

    var rows: [AXUIElement] = []
    if onlyVisible {
      rows = chatListTable.getVisibleRows()
    } else {
      rows = chatListTable.getAllRows()
    }
    return chatRowsToChatInfos(rows: rows)
  }

  func toChatInfo(element: AXUIElement, index: Int) -> ChatInfo? {
    var infoRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(
      element, NSAccessibility.Attribute.title as CFString, &infoRef) == .success,
      let infoStr = infoRef as? String
    {
      var strs = infoStr.split(separator: ",").map { String($0) }
      let chatInfo: ChatInfo = ChatInfo(title: strs[0], element: element, index: index)
      if strs.contains("消息免打扰") {
        strs.removeAll { $0 == "消息免打扰" }
        chatInfo.messageMute = true
      }
      if strs.contains("置顶") {
        strs.removeAll { $0 == "置顶" }
        chatInfo.stick = true
      }
      let match = strs.filter { $0.contains("条未读消息") }.first
      if let match = match,
        let index = match.firstIndex(of: "条")
      {
        strs.removeAll { $0 == match }
        if let num = Int(match[..<index]),
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

  public func send(to: String, message: String) {
    guard let windowElement = getAppWindow() else {
      return
    }
    clickChat()
    guard let chatListTable = getChatListTable(windowElement: windowElement) else {
      return
    }

    let visibleRows = chatListTable.getVisibleRows()
    let allRows = chatListTable.getAllRows()

    let chat = locateChat(to: to, visibleRows: visibleRows, allRows: allRows)

    if let chat = chat {
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

  public func locateChat(to: String, visibleRows: [AXUIElement], allRows: [AXUIElement])
    -> ChatInfo?
  {
    // Find Selected Chat
    var selectedChat = getSelectedChat(rows: visibleRows)
    if selectedChat == nil {
      selectedChat = getSelectedChat(rows: allRows)
    }

    // Verify if the selected chat is your target.
    var target: ChatInfo? = nil

    if let selectedChat = selectedChat,
      selectedChat.title == to
    {
      target = selectedChat
    }

    if target == nil {
      // If selected chat is not target, search it.
      var chats = chatRowsToChatInfos(rows: visibleRows)
      var chat = chats.first { $0.title == to }
      if chat == nil {
        chats = chatRowsToChatInfos(rows: allRows)
      }
      chat = chats.first { $0.title == to }

      if let chat = chat,
        let selectElement = chat.element.getParentElement()?.getParentElement()
      {
        selectElement.setSelectedState(selected: true)
        target = chat
      }
    }
    return target
  }

  public func show(from: String, onlyVisible: Bool = false) -> ChatInfo? {
    guard let windowElement = getAppWindow() else {
      return nil
    }
    clickChat()
    guard let chatListTable = getChatListTable(windowElement: windowElement) else {
      return nil
    }

    let visibleRows = chatListTable.getVisibleRows()
    let allRows = chatListTable.getAllRows()

    let target = locateChat(to: from, visibleRows: visibleRows, allRows: allRows)
    guard let target = target else {
      return target
    }

    // Show target Messages.
    var messages: [AXUIElement] = []
    guard let roleLink = self.locateLinks[.chatViewTable],
      let chatViewTable = windowElement.findElements(
        withRoleLink: roleLink,
        maxDepth: 100
      ).first
    else {
      return target
    }
    var rows: [AXUIElement] = []
    if onlyVisible {
      rows = chatViewTable.getVisibleRows()
    } else {
      rows = chatViewTable.getAllRows()
    }
    var indexList: [Int] = []
    for row in rows {
      if let index = row.getIndex() {
        indexList.append(index)
      }
      messages.append(
        contentsOf: row.findElements(
          withRoleLink: self.locateLinks[.messageInRow]!,
          maxDepth: 100
        ))
    }
    target.messages = toMessageGroups(elements: messages, indexList: indexList)
    return target
  }

  func isTimeFormat(_ string: String) -> Bool {
    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale(identifier: "zh_CN")
    timeFormatter.dateFormat = "HH:mm"
    // 使用严格模式，提高格式匹配准确性
    timeFormatter.isLenient = false

    return timeFormatter.date(from: string) != nil
  }

  public func isDate(str: String) -> Bool {
    let splits = str.split(separator: " ")
    if splits.count <= 2,
      let date = splits.last,
      isTimeFormat(String(date))
    {
      return true
    }
    return false
  }
  public func toMessageGroups(elements: [AXUIElement], indexList: [Int]) -> [Message] {
    var result: [Message] = []
    var date: String = ""
    var indices = indexList
    for element in elements {
      guard let title = element.getTitle() else {
        continue
      }
      if isDate(str: title) {
        date = title
      } else {
        result.append(self.toMessage(str: title, index: indices.removeFirst(), date: date))
      }
    }
    return result
  }

  public func toMessage(str: String, index: Int, date: String) -> Message {
    let splits = str.split(separator: ":")
    var user = splits[0]
    var message = ""
    if let startIndex = str.index(str.startIndex, offsetBy: user.count + 1, limitedBy: str.endIndex)
    {
      message = String(str[startIndex...])
    }

    if user.last == "说" {
      user.removeLast()
    }
    return Message(
      user: String(user.trimmingCharacters(in: .whitespaces)), message: message, index: index,
      date: date)
  }

  public func getSelectedChat(rows: [AXUIElement]) -> ChatInfo? {
    let row = rows.first { $0.selected() }
    if let row = row,
      let title = row.findElements(
        withRoleLink: self.locateLinks[.chatTitle]!,
        maxDepth: 100
      ).first
    {
      return toChatInfo(element: title, index: row.getIndex()!)
    }
    return nil
  }
}
