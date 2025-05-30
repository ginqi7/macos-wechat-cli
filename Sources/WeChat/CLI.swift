import ArgumentParser
import Foundation
import WeChatLibrary

public enum OutputFormat: String, ExpressibleByArgument {
  case json, plain
}

public func toJson(data: Encodable) -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let encoded = try! encoder.encode(data)
  return String(data: encoded, encoding: .utf8) ?? ""
}

private struct ListChats: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "List WeChat Chats")

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  @Option(
    name: .shortAndLong,
    help: "Only show visible Chats.")
  var onlyVisible: Bool = false

  func run() {
    let chatInfos = WeChat().listChats(onlyVisible: self.onlyVisible)
    var str = ""
    switch self.format {
    case .json:
      str = toJson(data: chatInfos)
    case .plain:
      str = chatInfos.map {
        $0.toStr()
      }.joined(separator: "\n")
    }
    print(str)
  }
}

private struct Send: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Set WeChat Message.")
  @Argument(
    help: "Chat title")
  var title: String

  @Argument(
    help: "Chat Message")
  var message: String

  func run() {
    WeChat().send(to: self.title, message: self.message)
  }
}

private struct Show: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show WeChat Messages.")
  @Argument(
    help: "Chat title")
  var title: String
  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain
  @Option(
    name: .shortAndLong,
    help: "Only show visible messages.")
  var onlyVisible: Bool = false

  func run() {
    if let chatInfo = WeChat().show(from: self.title, onlyVisible: self.onlyVisible) {
      var str = ""
      switch self.format {
      case .json:
        str = toJson(data: chatInfo)
      case .plain:
        str = chatInfo.messagesToStr()
      }
      print(str)
    }
  }
}

private struct Preview: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Preview the Link or the Image")
  @Argument(
    help: "Chat Title")
  var title: String
  @Argument(
    help: "Message Index")
  var index: Int
  @Option(
    name: .shortAndLong,
    help: "Only show visible messages.")
  var onlyVisible: Bool = false

  func run() {
    WeChat().previewMessage(
      title: self.title,
      messageIndex: self.index, onlyVisible: self.onlyVisible)
  }
}

private struct Notify: ParsableCommand {
  private var weChatMonitor: WeChat
  static let configuration = CommandConfiguration(
    abstract: "Preview the Link or the Image")

  init() {
    self.weChatMonitor = WeChat()
  }

  init(from decoder: Decoder) throws {
    self.init()
  }

  func run() throws {
    weChatMonitor.startMonitoring()
    RunLoop.current.run()
  }
}

private struct CaptureEmotion: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Capture Emotion in Chat.")
  @Argument(
    help: "Chat Title")
  var title: String
  @Argument(
    help: "Message Index")
  var index: Int
  @Option(
    name: .shortAndLong,
    help: "The output directory")
  var directory: String

  func run() throws {
    WeChat().captureEmotion(
      title: self.title,
      messageIndex: self.index,
      outputDirectory: self.directory
    )
  }
}

private struct CaptureAvatar: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Capture Avatar in Chat.")
  @Argument(
    help: "Chat Title")
  var title: String
  @Argument(
    help: "User Name")
  var userName: String
  @Option(
    name: .shortAndLong,
    help: "The output directory")
  var directory: String

  func run() throws {
    WeChat().captureAvatar(
      title: self.title,
      userName: self.userName,
      outputDirectory: self.directory
    )
  }
}

public struct CLI: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "wechat",
    abstract:
      "A CLI tool for Sending / Receving WeChat Message.",
    subcommands: [
      ListChats.self,
      Send.self,
      Show.self,
      Preview.self,
      Notify.self,
      CaptureEmotion.self,
      CaptureAvatar.self,
    ]
  )

  public init() {}
}
