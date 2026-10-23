import UIKit

/// Local presentation preference; never uploads a cover or changes Telegram stories.
struct WegramMomentsCoverStore {
    private let file: URL
    init(accountPath: String) {
        self.file = URL(fileURLWithPath: accountPath, isDirectory: true).appendingPathComponent("wegram-moments-cover.jpg")
    }
    func load() -> UIImage? {
        UIImage(contentsOfFile: self.file.path)
    }
    func save(_ data: Data) throws {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try data.write(to: self.file, options: .atomic)
    }
    func reset() throws {
        do { try FileManager.default.removeItem(at: self.file) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { }
    }
}
