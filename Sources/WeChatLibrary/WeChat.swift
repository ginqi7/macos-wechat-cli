import AppKit
import ApplicationServices
import Cocoa
import CoreGraphics

public class WeChat {
  var wechatAppElement: AXUIElement? = nil
  var observerElements: [AXUIElement] = []
  var windowElement: AXUIElement? = nil
  var hasUnread: Bool = false
  var totalUnread: Int = 0
  var observer: AXObserver? = nil
  var lastNotificationTime: Date = Date()
  var windowId: CGWindowID? = nil
  var capturer: ImageCapturer? = nil

  // Uses AXPathTarget from Constants.swift and initializes from WeChatConstants.axLocateLinks
  final var locateLinks: [AXPathTarget: [NSAccessibility.Role]] = WeChatConstants.axLocateLinks

  public init() {
  }

  // Helper function: Check and prompt the user to enable accessibility permissions.
  func checkAccessibilityPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

    if !accessEnabled {
      print("--------------------------------------------------------------------")
      print(WeChatConstants.Messages.accessibilityPermissionNeededTitle)
      print(WeChatConstants.Messages.accessibilityPermissionNeededInstructions)
      print("--------------------------------------------------------------------")
      // 尝试打开辅助功能设置面板
      if let url = URL(string: WeChatConstants.accessibilitySettingsURL) {
        NSWorkspace.shared.open(url)
      }
    }
  }

  func getWeChatAppElement() -> AXUIElement? {
    guard
      let wechatApp = NSRunningApplication.runningApplications(
        withBundleIdentifier: WeChatConstants.bundleIdentifier
      ).first
    else {
      return nil
    }
    self.wechatAppElement = AXUIElementCreateApplication(wechatApp.processIdentifier)
    self.windowId = getWindowIDs(for: wechatApp).first
    if let windowId = self.windowId {
      self.capturer = ImageCapturer(for: windowId)
    }
    return self.wechatAppElement
  }

  public func getAppWindow() -> AXUIElement? {
    if let windowElement = self.windowElement {
      return windowElement
    }
    checkAccessibilityPermissions()
    guard let wechatAppElement = getWeChatAppElement() else {
      return nil
    }

    var mainWindow: AXUIElement?
    let windows: CFTypeRef? = wechatAppElement.getAttributeValue(
      attribute: NSAccessibility.Attribute.windows as CFString)
    if let windows = windows as? [AXUIElement] {

      mainWindow = windows.first { element in
        if let title = element.getTitle() {
          return title.starts(with: WeChatConstants.mainWindowTitlePrefix)
        }
        return false
      }
    }
    guard let window = mainWindow else {
      return nil
    }
    window.active()
    self.windowElement = window
    return self.windowElement
  }

  func getWindowIDs(for runningApplication: NSRunningApplication) -> [CGWindowID] {
    // Step 1: Get the process identifier (PID) from the NSRunningApplication
    let pid = runningApplication.processIdentifier

    // Step 2: Retrieve info about all on-screen windows
    let windowList =
      CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []

    // Step 3: Filter windows to those owned by the application's PID
    let appWindows = windowList.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }

    // Step 4: Extract CGWindowID (kCGWindowNumber) from each matching window
    let windowIDs = appWindows.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }

    return windowIDs
  }

  func parseUnreadNum(str: String) -> Int {
    let pattern = WeChatConstants.unreadMessagesPattern
    do {
      let regex = try NSRegularExpression(pattern: pattern)
      let matches = regex.matches(in: str, range: NSRange(str.startIndex..., in: str))

      for match in matches {
        if let range = Range(match.range(at: 1), in: str) {
          return Int(str[range]) ?? 0
        }
      }
    } catch {
      print(String(format: WeChatConstants.Messages.invalidRegexError, error.localizedDescription))
    }
    return 0
  }

  func clickChat() {
    guard let windowElement = getAppWindow() else {
      return
    }
    var buttons = windowElement.findElements(
      withRoleLink: self.locateLinks[.chatButton]!,
      maxDepth: 100
    )
    buttons = filterElements(
      elements: buttons, attribute: .help, value: WeChatConstants.chatButtonHelpText)
    if buttons.count != 1 {
      print(WeChatConstants.Messages.multipleChatButtonsError)
      return
    }
    let button = buttons[0]
    if let desc = button.getDescription() {
      self.hasUnread = desc.contains(WeChatConstants.unreadMessagesSuffix)
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

  public func getChatRowTitle(row: AXUIElement) -> AXUIElement? {
    guard let chatTitleInRow = self.locateLinks[.chatTitleInRow] else {
      return nil
    }
    return row.findElements(
      withRoleLink: chatTitleInRow,
      maxDepth: 100
    ).first
  }

  public func chatRowsToChatInfos(rows: [AXUIElement]) -> [ChatInfo] {
    var result: [ChatInfo] = []
    for row in rows {
      if let index = row.getIndex(),
        let rowTitle = getChatRowTitle(row: row),
        let chatInfo = toChatInfo(element: rowTitle, index: index)
      {
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
    guard let infoStr = element.getTitle() else {
      return nil
    }
    var strs = infoStr.split(separator: WeChatConstants.titleSeparator.first!).map { String($0) }
    let chatInfo: ChatInfo = ChatInfo(title: strs[0], element: element, index: index)
    if strs.contains(WeChatConstants.messageMuteText) {
      strs.removeAll { $0 == WeChatConstants.messageMuteText }
      chatInfo.messageMute = true
    }
    if strs.contains(WeChatConstants.stickTopText) {
      strs.removeAll { $0 == WeChatConstants.stickTopText }
      chatInfo.stick = true
    }
    let match = strs.filter { $0.contains(WeChatConstants.unreadMessagesSuffix) }.first
    if let match = match,
      let firstChar = WeChatConstants.unreadMessagesSuffix.first,
      let index = match.firstIndex(of: firstChar)
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
        withRoleLink: self.locateLinks[.chatInput]!,
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
    timeFormatter.locale = Locale(identifier: WeChatConstants.localeIdentifierZHCN)
    timeFormatter.dateFormat = WeChatConstants.timeFormatHHMM
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
          result.append(self.toMessage(str: title, index: index, date: date, element: cell))
        }
      }
    }
    return result
  }

  public func toMessage(str: String, index: Int, date: String, element: AXUIElement) -> Message {
    let splits = str.split(separator: ":")
    var user = splits[0]
    var message = ""
    if let startIndex = str.index(str.startIndex, offsetBy: user.count + 1, limitedBy: str.endIndex)
    {
      message = String(str[startIndex...])
    }

    if user.hasSuffix(WeChatConstants.userSaidSuffix) {
      user.removeLast(WeChatConstants.userSaidSuffix.count)
    }
    let userName = String(user.trimmingCharacters(in: .whitespaces) as String)
    return Message(
      user: userName, message: message, index: index,
      date: date, element: element, previewable: isPreviewable(message),
      mySentMessage: userName == WeChatConstants.ownerKey)
  }

  func isPreviewable(_ message: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: WeChatConstants.previewablePattern) else {
      return false
    }
    let range = NSRange(message.startIndex..<message.endIndex, in: message)
    return regex.firstMatch(in: message, options: [], range: range) != nil
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
    formatter.dateFormat = WeChatConstants.dateTimeFormatFull
    formatter.timeZone = TimeZone.current
    let dateString = formatter.string(from: currentTime)

    if Int(mySelf.lastNotificationTime.timeIntervalSince1970 * 1000) + 500
      < Int(currentTime.timeIntervalSince1970 * 1000)
    {
      print(
        String(
          format: WeChatConstants.Messages.notificationUpdateMessage, dateString,
          notification as String))
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
      print(String(format: WeChatConstants.Messages.failedToCreateAXObserver, "\(error.rawValue)"))
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
        print(
          String(
            format: WeChatConstants.Messages.failedToAddNotification, "\(notification)",
            "\(addError.rawValue)"))
      } else {
        // print("Registered for \(notification)")
      }
    }

    CFRunLoopAddSource(
      CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(self.observer!), CFRunLoopMode.defaultMode)
  }

  public func captureEmotion(title: String, messageIndex: Int) {

    guard
      let windowElement = getAppWindow()
    else {
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
    let rows = chatViewTable.getVisibleRows()

    let row = rows.first {
      return $0.getIndex() == messageIndex
    }
    guard let row = row,
      let rowlink = locateLinks[.messageInRow],
      let cell = row.findElements(withRoleLink: rowlink).first,
      let capturer = self.capturer,
      let emotion = cell.findElements(withRoleLink: [.image]).first,
      let rect = emotion.frame()
    else {
      return
    }
    capturer.capture(outputName: "WeChat-\(title)-\(messageIndex)", rect: rect)
  }

  public func captureAvatar(title: String, userName: String) {

    if userName == WeChatConstants.ownerKey,
      let appElement = self.getAppWindow(),
      let rowLink = WeChatConstants.axLocateLinks[.avatarButton],
      let avatar = appElement.findElements(withRoleLink: rowLink).first,
      let rect = avatar.frame(),
      let capturer = self.capturer
    {
      capturer.capture(outputName: "Wechat-Me-Avatar", rect: rect)
      return
    }

    guard let chatInfo = show(from: title, onlyVisible: true) else {
      return
    }
    let message = chatInfo.messages.last {
      $0.user == userName
    }

    guard let message = message,
      let rect = message.element.frame(),
      let capturer = self.capturer,
      rect.minX > 0,
      rect.minY > 0
    else {
      return
    }
    capturer.captureUserAvatar(chatTitle: title, userName: userName, x: rect.minX, y: rect.minY)
  }
}
