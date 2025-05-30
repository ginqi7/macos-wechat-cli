import ScreenCaptureKit

public enum CaptureType: String {
  case emotion, userAvatar, meAvatar
}

public class ImageCapturer {

  private var directory: URL?
  private let identifier: CGWindowID

  public init(for windowIdentifier: CGWindowID, _ directory: URL? = nil) {
    self.identifier = windowIdentifier
    self.directory = directory
  }

  func resolvePath(_ path: String) -> String {
    let expandedPath: String
    if path.hasPrefix("~") {
      expandedPath = (path as NSString).expandingTildeInPath
    } else {
      expandedPath = path
    }
    let url = URL(fileURLWithPath: expandedPath).standardized
    return url.path
  }

  func getAbsolutePath(of filename: String) -> String {
    let currentDir = FileManager.default.currentDirectoryPath
    let currentDirURL = URL(fileURLWithPath: currentDir)
    let fileURL = URL(fileURLWithPath: resolvePath(filename), relativeTo: currentDirURL)
    return fileURL.path
  }

  public func setDirectory(directory: String?) {
    if let directory = directory {
      let path = getAbsolutePath(of: directory)
      self.directory = URL(
        fileURLWithPath: path,
        isDirectory: true
      )
      var isDirectory: ObjCBool = true
      if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
        print("Directory \(path) does not exist.")
        return
      }

    }
  }

  func getOutputFileURL(name: String, ext: String) -> URL? {
    let fileName = name + ext
    guard
      var outputURL = self.self.directory
        ?? Optional(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    else { return nil }
    outputURL.appendPathComponent(fileName)

    return outputURL
  }

  public func savePng(outputName: String, rect: CGRect) {
    do {
      guard let image = windowImage(rect: rect) else {
        print("Error: No window image")
        exit(1)
      }
      guard let url = getOutputFileURL(name: outputName, ext: ".png") else {
        print("Error: could craft URL to screenshot")
        exit(1)
      }
      guard let data = image.pngData(compressionFactor: 1) else {
        print("Error: No png data")
        exit(1)
      }
      try data.write(to: url)
      print("Save to: \((url.path as NSString).abbreviatingWithTildeInPath)")
      exit(0)
    } catch {
      print("Error: \(error.localizedDescription)")
      exit(1)
    }
  }

  private func windowImage(rect: CGRect) -> CGImage? {
    return CGWindowListCreateImage(
      rect,
      CGWindowListOption.optionIncludingWindow,
      self.identifier,
      CGWindowImageOption.bestResolution)
  }

  public func capture(outputName: String, rect: CGRect) {
    savePng(outputName: outputName, rect: rect)
  }

  public func captureUserAvatar(chatTitle: String, userName: String, x: Double, y: Double) {
    let rect = CGRect(x: x + 20.0, y: y + 10.5, width: 32.0, height: 32.0)
    let outputName = "wechat-\(chatTitle)-\(userName)"
    savePng(outputName: outputName, rect: rect)
  }

  public func captureMessage(chatTitle: String, messageIndex: Int, rect: CGRect) {
    let outputName = "wechat-\(chatTitle)-\(messageIndex)"
    savePng(outputName: outputName, rect: rect)
  }

  public func captureMeAvatar(rect: CGRect) {
    let outputName = "wechat-Me-Avatar"
    savePng(outputName: outputName, rect: rect)
  }

}

extension CGImage {
  func pngData(compressionFactor: Float) -> Data? {
    NSBitmapImageRep(cgImage: self).representation(
      using: .png, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: compressionFactor]
    )
  }
}
