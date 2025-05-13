# MacOS WeChat CLI

A simple CLI for interacting with OS X WeChat.

## Usage:


```
OVERVIEW: A CLI tool for Sending / Receving WeChat Message.

USAGE: org-reminders <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  list-chats              List WeChat Chats
  send                    Set WeChat Message.
  show                    Show WeChat Messages.

  See 'org-reminders help <subcommand>' for detailed help.
```

#### Show all chats

```
$ wechat list-chats
77 : Hello 13:31
```

#### Show messages on a specific chat

```
$ wechat show 77
77说:Hello
我说:Hi

```

#### Send a message to a chat

```
$ wechat send 77 "Hello World"
```

#### See help for more examples

```
$ wechat --help
$ wechat show -h
```

## Installation:

#### With [Homebrew](http://brew.sh/)

```
$ brew install ginqi7/formulae/wechat-cli
```

#### From GitHub releases

Download the latest release from
[here](https://github.com/ginqi7/wechat-cli/releases)

```
$ tar -zxvf wechat.tar.gz
$ mv wechat /usr/local/bin
$ rm wechat.tar.gz
```

#### Building manually

This requires a recent Xcode installation.

```
$ cd wechat-cli
$ make build-release
$ cp .build/apple/Products/Release/wechat /usr/local/bin/wechat
```
