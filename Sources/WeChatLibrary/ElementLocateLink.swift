import AppKit
import ApplicationServices
import CoreGraphics

public enum ChatLocation: String {
  case chatTitle, chatButton, chatInput, chatViewTable, messageInRow,
    chatListTable, chatTitleInRow
}

public class ElementLocateLink {
  var version: String

  final var locateLinks: [String: [ChatLocation: [NSAccessibility.Role]]] = [
    "v38": [
      .chatListTable: [.splitGroup, .scrollArea, .table],
      .chatTitleInRow: [.cell, .row],
      .chatTitle: [.cell, .row],
      .chatButton: [.radioButton],
      .chatInput: [.splitGroup, .splitGroup, .scrollArea, .textArea],
      .chatViewTable: [.splitGroup, .splitGroup, .scrollArea, .table],
      .messageInRow: [.cell, .unknown],
    ],
    "v40": [
      .chatListTable: [.splitGroup, .scrollArea, .table],
      .chatTitleInRow: [.cell, .row],
      .chatTitle: [.cell, .row],
      .chatButton: [.group, .button],
      .chatInput: [.splitGroup, .splitGroup, .scrollArea, .textArea],
      .chatViewTable: [.splitGroup, .splitGroup, .scrollArea, .table],
      .messageInRow: [.cell, .unknown],
    ],
  ]

  public init(version: String) {
    self.version = version
  }

  public func getLocateLink(key: ChatLocation) -> [NSAccessibility.Role] {

    if let locateLinks = locateLinks[self.version],
      let locateLink = locateLinks[key]
    {
      return locateLink
    }
    return []
  }

  public func findElements(parent: AXUIElement, location: ChatLocation) -> [AXUIElement] {
    let elements = parent.findElements(
      withRoleLink: getLocateLink(key: location),
      maxDepth: 100
    )
    if elements.count == 0 {
      print("Error: there no elements in \(location)")
    }
    return elements
  }

  public func findElement(parent: AXUIElement, location: ChatLocation) -> AXUIElement? {
    let elements = parent.findElements(
      withRoleLink: getLocateLink(key: location),
      maxDepth: 100
    )
    if elements.count == 0 {
      print("Error: there no elements in \(location)")
    }
    return elements.first
  }
}
