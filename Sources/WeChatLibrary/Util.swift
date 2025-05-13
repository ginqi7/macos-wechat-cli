import AppKit
import ApplicationServices
import CoreGraphics

// 辅助函数：尝试描述常见的 CFTypeRef 类型以便打印
func describeCFTypeRef(_ cfValue: CFTypeRef?) -> String {
  guard let value = cfValue else {
    return "[值为 nil]"
  }

  let typeID = CFGetTypeID(value)

  if typeID == CFStringGetTypeID() {
    return "\"\(value as! String)\""
  } else if typeID == CFNumberGetTypeID() {
    return "\(value as! NSNumber)"  // 包括 Int, Float, Double, Bool (0 或 1)
  } else if typeID == CFBooleanGetTypeID() {
    return (value as! CFBoolean) == kCFBooleanTrue ? "true" : "false"
  } else if typeID == CFArrayGetTypeID() {
    guard let arr = value as? [AnyObject] else {  // CFArrayRef 桥接到 [AnyObject]
      return "[CFArray - 无法转换为 [AnyObject]]"
    }
    if arr.isEmpty { return "[] (空数组)" }

    // 尝试更具体地描述数组内容，例如是否为 AXUIElement 数组
    var itemDescriptions: [String] = []
    var isAXUIElementArray = true
    for (index, item) in arr.enumerated() {
      if index < 3 {  // 只显示前几个元素的描述，避免过长输出
        itemDescriptions.append(describeCFTypeRef(item))
      }
      // 检查是否所有元素都是 AXUIElement 类型有点复杂，因为没有直接的 AXUIElementGetTypeID()
      // 我们可以假设，如果 AXUIElementCopyAttributeNames 在这个 item 上成功，它可能是一个 AXUIElement
      var tempNames: CFArray?
      if AXUIElementCopyAttributeNames(item as! AXUIElement, &tempNames) != .success {  // 这里强制转换有风险
        isAXUIElementArray = false
      }
    }
    let ellipsis = arr.count > 3 ? ", ..." : ""
    if isAXUIElementArray {  // 这是一个启发式判断，可能不完全准确
      return "[\(arr.count) AXUIElement(s): \(itemDescriptions.joined(separator: ", "))\(ellipsis)]"
    }
    return "[\(arr.count) 项: \(itemDescriptions.joined(separator: ", "))\(ellipsis)]"

  } else if typeID == CFURLGetTypeID() {
    return "URL: \((value as! URL).absoluteString)"
  } else if typeID == CFDateGetTypeID() {
    return "Date: \(value as! Date)"
  } else if typeID == CFDataGetTypeID() {
    return "[CFData: \(CFDataGetLength(value as! CFData)) 字节]"
  }
  // 尝试检查是否为 AXUIElement (通过查询其角色描述)
  // 注意: value 必须能安全地转换为 AXUIElement 才能调用 AX 函数
  // 这是一个间接的检查方式
  // AXUIElement 本身是一个指针类型，其 CFTypeID 可能不唯一或不公开
  // 我们这里假设如果它是一个对象并且可以获取角色描述，它可能是一个 AXUIElement
  var roleDescCF: CFTypeRef?
  // AXUIElementRef 是一个指针，不能直接用 typeID == AXUIElementGetTypeID() (此函数不存在)
  // 我们可以尝试将其视为 AXUIElement 并获取一个通用属性
  let potentialElement = value as! AXUIElement  // 这是一个有风险的强制转换，仅用于探测
  if AXUIElementCopyAttributeValue(
    potentialElement, kAXRoleDescriptionAttribute as CFString, &roleDescCF) == .success
  {
    if let roleDesc = roleDescCF as? String {
      return "[AXUIElement: \(roleDesc) - 指针: \(value)]"
    } else {
      return "[AXUIElement (无法获取角色描述) - 指针: \(value)]"
    }
  }

  // 对于其他未明确处理的 CFTypeRef 类型
  if let cfDescription = CFCopyDescription(value) {
    return (cfDescription as String)
  }
  return "[未知 CFTypeRef, Swift 类型: \(type(of: value)), TypeID: \(typeID)]"
}

// 主要函数：打印一个 AXUIElement 的所有属性及其值

func printAllAttributes(for element: AXUIElement, elementName: String = "UI元素") {

  print("\n--- 属性列表: \(elementName) (\(element)) ---")

  var attributeNamesCF: CFArray?
  let copyNamesResult = AXUIElementCopyAttributeNames(element, &attributeNamesCF)

  guard copyNamesResult == .success, let attributeNames = attributeNamesCF as? [String] else {
    print("错误：无法获取属性名称列表。错误码: \(copyNamesResult.rawValue)")
    return
  }

  if attributeNames.isEmpty {
    print("此元素没有可列出的属性。")
    print("--- 属性列表结束: \(elementName) ---")
    return
  }

  print("找到 \(attributeNames.count) 个属性:")
  for name in attributeNames.sorted() {  // 按名称排序以便查看
    var valueCF: CFTypeRef?
    var isSettable: DarwinBoolean = false
    var settableString = ""

    // 1. 检查属性是否可写
    let settableResult = AXUIElementIsAttributeSettable(element, name as CFString, &isSettable)
    if settableResult == .success {
      settableString = isSettable.boolValue ? "[可写]" : "[不可写]"
    } else {
      // 如果检查可写性失败，不一定意味着属性不存在或不可读
      // settableString = "[可写性未知 (错误: \(settableResult.rawValue))]"
      // 有些只读属性可能在这里也返回错误，所以我们仍尝试读取它
      settableString = "[可写性检查失败或属性非标准]"
    }

    // 2. 获取属性值
    let valueResult = AXUIElementCopyAttributeValue(element, name as CFString, &valueCF)
    if valueResult == .success {
      let valueDescription = describeCFTypeRef(valueCF)
      print("  - \(name) \(settableString): \(valueDescription)")
    } else {
      // 即使获取值失败，也打印出来，因为 AXUIElementCopyAttributeNames 列出了它
      print("  - \(name) \(settableString): [获取值错误 - 错误码: \(valueResult.rawValue)]")
    }
  }
  print("--- 属性列表结束: \(elementName) ---")
}

func arrayPrintAllAttributes(elements: [AXUIElement]) {
  for element in elements {
    printAllAttributes(for: element)
  }
}
