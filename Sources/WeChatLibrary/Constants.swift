import ApplicationServices  // For NSAccessibility.Role
import Cocoa
import CoreGraphics
import Foundation

// Enum for identifying specific UI element paths/targets
public enum AXPathTarget: String {
  case chatTitle, chatButton, chatInput, chatViewTable, messageInRow,
    chatListTable, chatTitleInRow, avatarButton
}

public struct WeChatConstants {
  // Bundle Identifiers
  public static let bundleIdentifier = "com.tencent.xinWeChat"

  // Window Titles
  public static let mainWindowTitlePrefix = "微信 ("

  // Regex Patterns
  public static let unreadMessagesPattern = "(\\d+)条未读消息"

  // Regex Patterns
  public static let titleSeparator = ","

  // UI Element Identifiers (Accessibility & Text)
  public static let chatButtonHelpText = "微信"
  public static let messageMuteText = "消息免打扰"
  public static let stickTopText = "置顶"
  public static let unreadMessagesSuffix = "条未读消息"
  public static let userSaidSuffix = "说"  // e.g., "User说:"

  // Date/Time Formats & Locale
  public static let timeFormatHHMM = "HH:mm"
  public static let dateTimeFormatFull = "yyyy-MM-dd HH:mm:ss"
  public static let localeIdentifierZHCN = "zh_CN"

  public static let ownerKey = "我"

  // URLs
  public static let accessibilitySettingsURL =
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

  // Console Messages & Prompts
  public struct Messages {
    public static let accessibilityPermissionNeededTitle = "重要: 辅助功能权限未启用!"
    public static let accessibilityPermissionNeededInstructions = """
      请前往: 系统设置 > 隐私与安全性 > 辅助功能
      然后点击 '+'，将此应用添加到列表中并启用它。
      """
    public static let multipleChatButtonsError = "There are multiple buttons labeled 微信 chats."
    public static let invalidRegexError = "Invalid regex: %@"  // %@ for localizedDescription
    public static let notificationUpdateMessage =
      "[Notify] WeChat update at [%@] for notification: %@"
    public static let failedToCreateAXObserver = "Failed to create AXObserver: %@"
    public static let failedToAddNotification = "Failed to add notification %@: %@"
    public static let failedToGetAttribute = "Failed to get attribute %@: (Code: %@)"
  }

  // AX Path Locators
  public static let axLocateLinks: [AXPathTarget: [NSAccessibility.Role]] = [
    .chatListTable: [.splitGroup, .scrollArea, .table],
    .chatTitleInRow: [.cell, .row],
    .chatTitle: [.cell, .row],  // Note: Same as chatTitleInRow, kept for consistency with original
    .chatButton: [.radioButton],
    .chatInput: [.splitGroup, .splitGroup, .scrollArea, .textArea],
    .chatViewTable: [.splitGroup, .splitGroup, .scrollArea, .table],
    .messageInRow: [.cell, .unknown],
    .avatarButton: [.button],
  ]
}
