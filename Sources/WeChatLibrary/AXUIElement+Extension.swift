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

  func actions() -> [String] {
    var actionsCF: CFArray?
    let result = AXUIElementCopyActionNames(self, &actionsCF)
    guard result == .success, let actions = actionsCF as? [String] else {
      print("Failed to get Actions: \(result)")
      return []
    }
    return actions
  }

  func click() {
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

}
