import AppKit
import ApplicationServices
import CoreGraphics

extension AXUIElement {
  func getParentElement() -> AXUIElement? {
    var parent: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(self, kAXParentAttribute as CFString, &parent)
    if result == .success {
      let parent = parent as! AXUIElement
      return parent
    } else {
      print("Failed to get Parent: \(result)")
      return nil
    }
  }

  func getVisibleRows() -> [AXUIElement] {
    var rows: AnyObject?
    let result = AXUIElementCopyAttributeValue(self, kAXVisibleRowsAttribute as CFString, &rows)
    if result == .success {
      return rows as! [AXUIElement]
    }
    return []
  }

  func getAllRows() -> [AXUIElement] {
    var rows: AnyObject?
    let result = AXUIElementCopyAttributeValue(self, kAXRowsAttribute as CFString, &rows)
    if result == .success {
      return rows as! [AXUIElement]
    }
    return []
  }

  func getPid() -> pid_t? {
    var pid: pid_t = 0
    let result = AXUIElementGetPid(self, &pid)
    if result == .success {
      return pid
    } else {
      print("Failed to get PID: \(result)")
      return nil
    }
  }

  func submit() {

    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x24), keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x24), keyDown: false)
    if let pid = self.getPid(), let keyDown = keyDown, let keyUp = keyUp {
      keyDown.postToPid(pid)
      usleep(50_000)
      keyUp.postToPid(pid)
      usleep(50_000)
    }
  }

  // Send the escape key to the app to activate its process, which will expedite subsequent operations.
  func active() {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x35), keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x35), keyDown: false)
    if let pid = self.getPid(), let keyDown = keyDown, let keyUp = keyUp {
      keyDown.postToPid(pid)
      keyUp.postToPid(pid)
    }
  }

  func actions() -> [String] {
    var actionsCF: CFArray?
    let result = AXUIElementCopyActionNames(self, &actionsCF)
    guard result == .success, let actions = actionsCF as? [String] else {
      print("Failed to get Actions: \(result)")
      return []
    }
    return actions
  }

  func press() {
    if self.actions().contains(kAXPressAction as String) {
      AXUIElementPerformAction(self, kAXPressAction as CFString)
    }
  }

  func selected() -> Bool {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(self, kAXSelectedAttribute as CFString, &value)

    if result == .success, let number = value as? NSNumber {
      return number.boolValue
    } else {
      print("Get AXSelected Error:\(result)")
      return false
    }
  }

  func value() -> Any? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(self, kAXValueAttribute as CFString, &value)

    if result == .success {
      return value
    } else {
      print("Get AXValue Error:\(result)")
      return nil
    }
  }

  func write(message: String) {
    let newValue = message as CFString
    let error = AXUIElementSetAttributeValue(self, kAXValueAttribute as CFString, newValue)
    guard error == .success else {
      print("Write Failed：\(error.rawValue)")
      return
    }
  }

  func setSelectedState(selected: Bool) {
    let value = selected as CFBoolean
    let result = AXUIElementSetAttributeValue(self, kAXSelectedAttribute as CFString, value)

    if result != .success {
      print("Set AXSelected Error:\(result)")
    }
  }

  func children(roles: [NSAccessibility.Role] = [])
    -> [AXUIElement]
  {
    var elements: [AXUIElement] = []
    var children: CFTypeRef?

    let childrenResult =
      AXUIElementCopyAttributeValue(
        self, NSAccessibility.Attribute.children.rawValue as CFString, &children)
    if childrenResult == .success,
      let childrenArray = children as? [AXUIElement]
    {
      for child in childrenArray {
        var childrenRole: CFTypeRef?
        if AXUIElementCopyAttributeValue(
          child, NSAccessibility.Attribute.role.rawValue as CFString, &childrenRole) == .success
        {
          let rolesStr = roles.map { $0.rawValue }
          if let role = childrenRole as? String,
            roles.count == 0 || rolesStr.contains(role)
          {
            elements.append(child)
          }
        }
      }
    }
    return elements
  }

  func findElements(
    withRoleLink targetRoleLink: [NSAccessibility.Role],
    depth: Int = 0,
    maxDepth: Int = 5
  ) -> [AXUIElement] {
    var roleLink = targetRoleLink
    var parents = [self]

    while roleLink.count > 0 && depth < maxDepth {
      let role = roleLink.removeFirst()

      var elements: [AXUIElement] = []
      for parent in parents {
        elements.append(contentsOf: parent.children(roles: [role]))
      }
      parents = elements
    }
    return parents
  }

  func getTitle() -> String? {
    var infoRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(
      self, NSAccessibility.Attribute.title as CFString, &infoRef) == .success,
      let infoStr = infoRef as? String
    {
      return infoStr
    }
    return nil
  }

  func getDescription() -> String? {
    var infoRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(
      self, NSAccessibility.Attribute.description as CFString, &infoRef) == .success,
      let infoStr = infoRef as? String
    {
      return infoStr
    }
    return nil
  }

  func printAllAttributes() {
    print("--- 正在检查元素: \(self) ---")

    var attributeNames: CFArray?
    let error = AXUIElementCopyAttributeNames(self, &attributeNames)

    if error == .success, let names = attributeNames as? [String] {
      if names.isEmpty {
        print("元素没有可读的属性名称。")
        return
      }

      print("找到 \(names.count) 个属性名称:")
      for name in names {
        var attributeValue: AnyObject?
        let valueError = AXUIElementCopyAttributeValue(self, name as CFString, &attributeValue)

        if valueError == .success {
          if let value = attributeValue {
            // 尝试打印值的描述，对于复杂类型可能需要进一步处理
            // 对于 AXValueRef 类型，需要特殊处理以获取其内部值
            if CFGetTypeID(value) == AXValueGetTypeID() {
              let axValue = value as! AXValue  // 安全转换，因为我们检查了类型
              var pointValue = CGPoint.zero
              var sizeValue = CGSize.zero
              var rectValue = CGRect.zero
              var rangeValue = CFRange()

              if AXValueGetValue(axValue, .cgPoint, &pointValue) {
                print("  \(name): \(pointValue) (类型: CGPoint)")
              } else if AXValueGetValue(axValue, .cgSize, &sizeValue) {
                print("  \(name): \(sizeValue) (类型: CGSize)")
              } else if AXValueGetValue(axValue, .cgRect, &rectValue) {
                print("  \(name): \(rectValue) (类型: CGRect)")
              } else if AXValueGetValue(axValue, .cfRange, &rangeValue) {
                print("  \(name): \(rangeValue) (类型: CFRange)")
              } else {
                print("  \(name): \(value) (类型: AXValue, 未知内部类型或无法提取)")
              }
            } else {
              print("  \(name): \(value)")
            }
            // Core Foundation 对象在 Swift 中通常会自动管理内存 (ARC 桥接)
            // 但如果是手动创建的，或者从某些 C API 获取且未桥接，则可能需要 CFRelease(value)
          } else {
            print("  \(name): (nil value)")  // 值本身是 nil
          }
        } else {
          print("  \(name): 无法获取值 (错误: \(valueError.rawValue))")
        }
      }
    } else if error == .noValue {
      print("元素没有属性 (AXError.noValue)。")
    } else {
      print("无法获取属性名称 (错误: \(error.rawValue))")
    }
    print("--- 检查元素结束 ---")
  }

  func getIndex() -> Int? {
    var infoRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(
      self, NSAccessibility.Attribute.index as CFString, &infoRef) == .success
    {
      return infoRef as? Int
    }
    return nil
  }

  func getAttributeValue(attribute: CFString) -> CFTypeRef? {
    var attributeValue: CFTypeRef? = nil
    let result = AXUIElementCopyAttributeValue(
      self, attribute, &attributeValue)
    if result == .success {
      return attributeValue
    } else {
      print(
        "Failed to get attribute \(attribute): (Code: \(result.rawValue))"
      )
      return nil
    }
  }

  func getAttributeNames() -> [String] {
    var attributeNames: CFArray?
    let result = AXUIElementCopyAttributeNames(
      self, &attributeNames)
    if result == .success {
      return attributeNames as! [String]
    } else {
      print(
        "Failed to get attributeNames: (Code: \(result.rawValue))"
      )
      return []
    }
  }

  func frame() -> CGRect? {
    guard let frame = getAttributeValue(attribute: "AXFrame" as CFString) else {
      return nil
    }
    // Extract the CGRect value
    var rect: CGRect = .zero
    let success = AXValueGetValue(frame as! AXValue, .cgRect, &rect)
    return success ? rect : nil
  }
}
