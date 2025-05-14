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
    do {
      let chatInfos = WeChat().listChats(onlyVisible: self.onlyVisible)
      var str = ""
      switch self.format {
      case .json:
        str = toJson(data: chatInfos)
      case .plain:
        var idx = 0
        str = chatInfos.map { info in
          idx = idx + 1
          return "[\(idx)] \(info.toStr())"
        }.joined(separator: "\n")
      }
      print(str)
    } catch let error {
      print(error)
    }
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
    do {
      WeChat().send(to: self.title, message: self.message)
    } catch let error {
      print(error)
    }
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
    help: "Only show visible Chats.")
  var onlyVisible: Bool = false

  func run() {
    do {
      if let chatInfo = WeChat().show(from: self.title, onlyVisible: self.onlyVisible) {
        var str = ""
        switch self.format {
        case .json:
          str = toJson(data: chatInfo)
        case .plain:
          str = chatInfo.messages.map { msg in
            msg.toStr()
          }.joined(separator: "\n")
        }
        print(str)
      }
    } catch let error {
      print(error)
    }
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
    ]
  )

  public init() {}
}
