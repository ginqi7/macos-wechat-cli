import ArgumentParser
import Foundation
import WeChatLibrary

private struct ListChats: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "List WeChat Chats")

  func run() {
    do {
      let chatInfos = WeChat().listAllChats()
      for chatInfo in chatInfos {
        print(chatInfo.toString())
      }
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

  func run() {
    do {
      WeChat().show(from: self.title)
    } catch let error {
      print(error)
    }
  }
}

public struct CLI: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "org-reminders",
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
