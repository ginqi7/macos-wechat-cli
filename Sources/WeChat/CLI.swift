import ArgumentParser
import Foundation
import WeChatLibrary

public enum OutputFormat: String, ExpressibleByArgument {
  case json, plain
}

public enum Version: String, ExpressibleByArgument {
  case v38, v40
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

  @Option(
    name: .shortAndLong,
    help: "WeChat Version: 3.8 or 4.0")
  var version: Version = .v38

  func run() {
    let chatInfos = WeChat(version: self.version.rawValue).listChats(onlyVisible: self.onlyVisible)
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

  @Option(
    name: .shortAndLong,
    help: "WeChat Version: 3.8 or 4.0")
  var version: Version = .v38

  func run() {
    WeChat(version: self.version.rawValue).send(to: self.title, message: self.message)
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

  @Option(
    name: .shortAndLong,
    help: "WeChat Version: 3.8 or 4.0")
  var version: Version = .v38

  func run() {
    if let chatInfo = WeChat(version: self.version.rawValue).show(
      from: self.title, onlyVisible: self.onlyVisible)
    {
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

  @Option(
    name: .shortAndLong,
    help: "WeChat Version: 3.8 or 4.0")
  var version: Version = .v38

  func run() {
    WeChat(version: self.version.rawValue).previewMessage(
      title: self.title,
      messageIndex: self.index, onlyVisible: self.onlyVisible)
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
    ]
  )

  public init() {}
}
