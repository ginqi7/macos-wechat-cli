import AppKit
import ApplicationServices
import Cocoa
import CoreGraphics

public enum ChatLocation: String {
  case chatTitle, chatButton, chatInput, chatViewTable, messageInRow,
    chatListTable, chatTitleInRow
}

public class WeChat {
  var wechatAppElement: AXUIElement? = nil
  var windowElement: AXUIElement? = nil
  var hasUnread: Bool = false
  var totalUnread: Int = 0
  var observer: AXObserver? = nil
  var lastNotificationTime: Date = Date()

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

  func getWeChatAppElement() -> AXUIElement? {
    guard
      let wechatApp = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.tencent.xinWeChat"
      ).first
    else {
      return nil
    }
    self.wechatAppElement = AXUIElementCreateApplication(wechatApp.processIdentifier)
    return self.wechatAppElement
  }

  func getAppWindow() -> AXUIElement? {
    if let windowElement = self.windowElement {
      return windowElement
    }
    checkAccessibilityPermissions()

    guard let wechatAppElement = getWeChatAppElement() else {
      return nil
    }

    var mainWindow: AXUIElement?
    let windows: CFTypeRef? = wechatAppElement.getAttributeValue(
      attribute: NSAccessibility.Attribute.windows)
    if let windows = windows as? [AXUIElement] {

      mainWindow = windows.first { element in
        if let title = element.getTitle() {
          return title.starts(with: "微信 (")
        }
        return false
      }
    }
    guard let window = mainWindow else {
      return nil
    }
    self.windowElement = window
    return self.windowElement
  }

  func parseUnreadNum(str: String) -> Int {
    let pattern = "(\\d+)条未读消息"
    do {
      let regex = try NSRegularExpression(pattern: pattern)
      let matches = regex.matches(in: str, range: NSRange(str.startIndex..., in: str))

      for match in matches {
        if let range = Range(match.range(at: 1), in: str) {
          return Int(str[range]) ?? 0
        }
      }
    } catch {
      print("Invalid regex: \(error.localizedDescription)")
    }
    return 0
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
    if buttons.count != 1 {
      print("There are multiple buttons labeled 微信 chats.")
      return
    }
    let button = buttons[0]
    if let desc = button.getDescription() {
      self.hasUnread = desc.contains("条未读消息")
      self.totalUnread = parseUnreadNum(str: desc)
    }
    if let value = button.value(),
      value as! Int == 0  // If the value is 0, the chat button not activate.
    {
      buttons[0].press()
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
        if let num = Int(match[..<index]) {
          if self.totalUnread > 0 && !chatInfo.messageMute {
            chatInfo.unread = num
            self.totalUnread -= num
          }
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
    target.messages = toMessageGroups(elements: rows)
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
  public func toMessageGroups(elements: [AXUIElement]) -> [Message] {
    var result: [Message] = []
    var date: String = ""
    for row in elements {
      if let index = row.getIndex(),
        let cell = row.findElements(
          withRoleLink: self.locateLinks[.messageInRow]!,
          maxDepth: 100
        ).first,
        let title = cell.getTitle()
      {
        if isDate(str: title) {
          date = title
        } else {
          result.append(self.toMessage(str: title, index: index, date: date))
        }
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

  public func previewMessage(title: String, messageIndex: Int, onlyVisible: Bool) {
    guard let windowElement = getAppWindow() else {
      return
    }
    clickChat()
    guard let chatListTable = getChatListTable(windowElement: windowElement) else {
      return
    }
    let visibleRows = chatListTable.getVisibleRows()
    let allRows = chatListTable.getAllRows()

    let _ = locateChat(to: title, visibleRows: visibleRows, allRows: allRows)

    guard let roleLink = self.locateLinks[.chatViewTable],
      let chatViewTable = windowElement.findElements(
        withRoleLink: roleLink,
        maxDepth: 100
      ).first
    else {
      return
    }
    var rows: [AXUIElement] = []
    if onlyVisible {
      rows = chatViewTable.getVisibleRows()
    } else {
      rows = chatViewTable.getAllRows()
    }

    let row = rows.first {
      return $0.getIndex() == messageIndex
    }
    if let row = row,
      let rowlink = locateLinks[.messageInRow],
      let cell = row.findElements(withRoleLink: rowlink).first
    {
      cell.press()
    }
  }

  private func handleAXNotification(
    _ observer: AXObserver,
    _ uiElement: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
  ) {
    guard let refcon = refcon else { return }
    let mySelf = Unmanaged<WeChat>.fromOpaque(refcon).takeUnretainedValue()

    let currentTime = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone.current
    let dateString = formatter.string(from: currentTime)

    if Int(mySelf.lastNotificationTime.timeIntervalSince1970 * 1000) + 500
      < Int(currentTime.timeIntervalSince1970 * 1000)
    {
      print("[Notify] WeChat update at [\(dateString)] for notification: \(notification as String)")
      // You might want to use uiElement as well, depending on the notification
    }
    mySelf.lastNotificationTime = currentTime
  }

  public func startMonitoring() {
    guard let appElement = self.getWeChatAppElement(),
      let pid = appElement.getPid()
    else {
      return
    }
    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    // Use the extracted function as the callback
    let callback: AXObserverCallback = { observer, uiElement, notification, refcon in
      // This outer closure now simply calls the instance method.
      // We still need to get `self` from `refcon` to call the instance method.
      guard let refcon = refcon else { return }
      let wechatInstance = Unmanaged<WeChat>.fromOpaque(refcon).takeUnretainedValue()
      wechatInstance.handleAXNotification(observer, uiElement, notification, refcon)
    }

    var newObserver: AXObserver?
    let error = AXObserverCreate(pid, callback, &newObserver)

    guard error == .success, let actualNewObserver = newObserver else {
      print("Failed to create AXObserver: \(error.rawValue)")
      return
    }
    self.observer = actualNewObserver

    let allNotifications: [NSAccessibility.Notification] = [
      .uiElementDestroyed,
      .titleChanged,
      .valueChanged,
    ]

    for notification in allNotifications {
      let addError = AXObserverAddNotification(
        self.observer!, appElement, notification as CFString, selfPtr)  // 使用 self.observer!
      if addError != .success {
        print("Failed to add notification \(notification): \(addError.rawValue)")
      } else {
        // print("Registered for \(notification)")
      }
    }

    CFRunLoopAddSource(
      CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(self.observer!), CFRunLoopMode.defaultMode)
  }
}
