# MacOS WeChat CLI

A simple CLI for interacting with OS X WeChat.

## Usage:


```
OVERVIEW: A CLI tool for Sending / Receving WeChat Message.

USAGE: wechat <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  list-chats              List WeChat Chats
  send                    Set WeChat Message.
  show                    Show WeChat Messages.

  See 'wechat help <subcommand>' for detailed help.
```

### List WeChat Chats

#### Example

```
$ wechat list-chats
[0] user1 > Hello World! (13:09)
[1] user2 > ginqi7 is a programmer (13:04)
[2] user1、user2、user3、user4 > [哈哈] (2025/05/10)
[3] 公众号 > 中国移动10086: [链接] 月度话费账单提醒 (12:06)
[4] 群组1 > user1: 你好 (08:16)
```

#### More Options
```
OVERVIEW: List WeChat Chats

USAGE: wechat list-chats [--format <format>] [--only-visible <only-visible>]

OPTIONS:
  -f, --format <format>   format, either of 'plain' or 'json' (default: plain)
  -o, --only-visible <only-visible>
                          Only show visible Chats. (default: false)
  -h, --help              Show help information.
```

### Show messages on a specific chat
#### Example
```
$ wechat show user1
----------------------------------------
我 > I created a WeChat CLI tool.
user1 > Looks good.
-----------------11:55-----------------
user1 > 发送了一个图片
-----------------12:12-----------------
user1 > This marks a new beginning.
user1 > 发送了一个图片
user1 > 哈哈
我 > 哈哈
```

#### More Options
```
OVERVIEW: Show WeChat Messages.

USAGE: wechat show <title> [--format <format>] [--only-visible <only-visible>]

ARGUMENTS:
  <title>                 Chat title

OPTIONS:
  -f, --format <format>   format, either of 'plain' or 'json' (default: plain)
  -o, --only-visible <only-visible>
                          Only show visible messages. (default: false)
  -h, --help              Show help information.
```

### Send a message to a chat

```
$ wechat send user1 "Hello World"
```

### See help for more examples

```
$ wechat --help
$ wechat show -h
```

## Installation:

### With [Homebrew](http://brew.sh/)

```
$ brew install ginqi7/formulae/wechat-cli
```

### From GitHub releases

Download the latest release from
[here](https://github.com/ginqi7/wechat-cli/releases)

```
$ tar -zxvf wechat.tar.gz
$ mv wechat /usr/local/bin
$ rm wechat.tar.gz
```

### Building manually

This requires a recent Xcode installation.

```
$ cd wechat-cli
$ make build-release
$ cp .build/apple/Products/Release/wechat /usr/local/bin/wechat
```
