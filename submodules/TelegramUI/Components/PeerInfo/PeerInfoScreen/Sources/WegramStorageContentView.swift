import UIKit
import TelegramCore

struct WegramStorageSummary {
    let categories: [StorageUsageStats.CategoryKey: Int64]
    let cacheBytes: Int64
    let mediaBytes: Int64
    let otherBytes: Int64
    let fractions: [Double]?
    var usageFraction: Double? { self.fractions?.first }
    var clearCategories: [StorageUsageStats.CategoryKey] { self.categories.filter { $0.value > 0 }.map(\.key) }

    init(stats: AllStorageUsageStats) {
        let categories = stats.totalStats.categories.mapValues { max(0, $0.size) }
        self.categories = categories
        func sum(_ values: [Int64]) -> Int64 {
            values.reduce(0) { result, value in
                let (sum, overflow) = result.addingReportingOverflow(value)
                return overflow ? Int64.max : sum
            }
        }
        self.cacheBytes = sum(Array(self.categories.values))
        self.mediaBytes = sum([.photos, .videos, .files, .music].compactMap { categories[$0] })
        self.otherBytes = max(0, self.cacheBytes - self.mediaBytes)
        let capacity = max(0, stats.deviceAvailableSpace)
        let free = min(capacity, max(0, stats.deviceFreeSpace))
        let used = capacity - free
        if capacity > 0 && self.cacheBytes <= used {
            self.fractions = [Double(self.cacheBytes) / Double(capacity), Double(used - self.cacheBytes) / Double(capacity), Double(free) / Double(capacity)]
        } else { self.fractions = nil }
    }
}

final class WegramStorageActionButton: UIButton {
    let fill = UIView()
    var primary = false
    var dark = false
    var fontSize: CGFloat = 17
    override var isEnabled: Bool { didSet { self.updateFill() } }
    init() {
        super.init(frame: .zero)
        self.insertSubview(self.fill, at: 0)
        self.fill.isUserInteractionEnabled = false
        self.fill.layer.cornerRadius = 5
        self.titleLabel?.textAlignment = .center
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func updateFill() {
        self.accessibilityTraits = self.isEnabled ? .button : [.button, .notEnabled]
        let green = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
        self.fill.backgroundColor = !self.isEnabled ? UIColor(white: self.dark ? 0.2 : 0.9, alpha: 1) : (self.primary ? green : UIColor(white: self.dark ? 0.18 : 0.95, alpha: 1))
        self.setTitleColor(!self.isEnabled ? .gray : (self.primary ? .white : green), for: .normal)
        self.titleLabel?.font = .systemFont(ofSize: self.fontSize, weight: .medium)
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.fill.frame = CGRect(x: 0, y: 6, width: self.bounds.width, height: max(0, self.bounds.height - 12))
        self.titleLabel?.frame = self.bounds
    }
}

final class WegramStorageBlock: UIView {
    let title = UILabel()
    let size = UILabel()
    let explanation = UILabel()
    let button = WegramStorageActionButton()
    init() {
        super.init(frame: .zero)
        for view in [self.title, self.size, self.explanation, self.button] { self.addSubview(view) }
        self.title.numberOfLines = 0
        self.explanation.numberOfLines = 0
        self.size.adjustsFontSizeToFitWidth = true
        self.size.minimumScaleFactor = 0.5
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func layout(width: CGFloat) -> CGFloat {
        let buttonHeight = max(44, self.button.fontSize + 24)
        let buttonWidth = max(64, self.button.intrinsicContentSize.width + 24)
        let titleWidth = max(1, width - 48 - (self.button.isHidden ? 0 : buttonWidth + 16))
        let titleHeight = self.title.sizeThatFits(CGSize(width: titleWidth, height: .greatestFiniteMagnitude)).height
        self.title.frame = CGRect(x: 24, y: 18, width: titleWidth, height: titleHeight)
        self.button.frame = CGRect(x: width - 24 - buttonWidth, y: 12, width: buttonWidth, height: buttonHeight)
        self.size.frame = CGRect(x: 24, y: self.title.frame.maxY + 12, width: titleWidth, height: self.size.font.lineHeight)
        let textHeight = self.explanation.sizeThatFits(CGSize(width: max(1, width - 48), height: .greatestFiniteMagnitude)).height
        self.explanation.frame = CGRect(x: 24, y: max(self.size.frame.maxY, self.button.isHidden ? 0 : self.button.frame.maxY) + 12, width: max(0, width - 48), height: textHeight)
        return self.explanation.frame.maxY + 20
    }
}

final class WegramStorageContentView: UIScrollView {
    let chart = UIView()
    let segments = [UIView(), UIView(), UIView()]
    let legends = [UILabel(), UILabel(), UILabel()]
    let heading = UILabel()
    let total = UILabel()
    let proportion = UILabel()
    let blocks = [WegramStorageBlock(), WegramStorageBlock(), WegramStorageBlock()]
    private let dividers = [UIView(), UIView(), UIView()]
    let activity = UIActivityIndicatorView(style: .medium)
    let progress = UIProgressView(progressViewStyle: .default)
    private(set) var summary: WegramStorageSummary?
    private var chinese = true
    var formatBytes: (Int64) -> String = { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    var clear: (() -> Void)?
    var manage: (() -> Void)?
    var busy = false { didSet { self.updateState() } }

    init() {
        super.init(frame: .zero)
        self.contentInsetAdjustmentBehavior = .never
        self.alwaysBounceVertical = true
        self.chart.layer.cornerRadius = 2
        self.chart.clipsToBounds = true
        self.chart.isAccessibilityElement = true
        for segment in self.segments { self.chart.addSubview(segment) }
        for view in [self.chart, self.heading, self.total, self.proportion, self.activity, self.progress] { self.addSubview(view) }
        for label in self.legends { self.addSubview(label); label.numberOfLines = 0 }
        for block in self.blocks { self.addSubview(block) }
        for divider in self.dividers { self.addSubview(divider) }
        self.heading.numberOfLines = 0
        self.total.adjustsFontSizeToFitWidth = true
        self.total.minimumScaleFactor = 0.5
        self.proportion.numberOfLines = 0
        self.blocks[0].button.primary = true
        self.blocks[0].button.accessibilityIdentifier = "Wegram.Storage.ClearCache"
        self.blocks[1].button.accessibilityIdentifier = "Wegram.Storage.ManageMedia"
        self.blocks[2].button.isHidden = true
        self.blocks[0].button.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.busy, (self.summary?.cacheBytes ?? 0) > 0 else { return }
            self.clear?()
        }), for: .touchUpInside)
        self.blocks[1].button.addAction(UIAction(handler: { [weak self] _ in
            guard let self, !self.busy, self.summary != nil else { return }
            self.manage?()
        }), for: .touchUpInside)
        self.update(dark: false, fontSize: 17, chinese: true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(summary: WegramStorageSummary?) { self.summary = summary; self.updateState() }
    func setProgress(_ value: Float?) {
        self.progress.isHidden = !self.busy || value == nil || !(value?.isFinite ?? false)
        if let value, value.isFinite { self.progress.progress = min(1, max(0, value)) }
    }
    func update(dark: Bool, fontSize: CGFloat, chinese: Bool) {
        self.chinese = chinese
        let text = UIColor(white: dark ? 0.82 : 0.1, alpha: 1)
        let secondary = UIColor(white: dark ? 0.45 : 0.5, alpha: 1)
        self.backgroundColor = UIColor(white: dark ? 0.1 : 1, alpha: 1)
        self.chart.backgroundColor = UIColor(white: dark ? 0.2 : 0.9, alpha: 1)
        self.progress.progressTintColor = UIColor(red: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
        self.progress.trackTintColor = self.chart.backgroundColor
        let colors = [UIColor(red: 0.3, green: 0.72, blue: 0.4, alpha: 1), UIColor(red: 0.98, green: 0.78, blue: 0.25, alpha: 1), UIColor(white: dark ? 0.3 : 0.9, alpha: 1)]
        let names = chinese ? ["本账号缓存", "其他已用空间", "手机可用空间"] : ["Account Cache", "Other Used Space", "Available Space"]
        for index in 0..<3 {
            self.segments[index].backgroundColor = colors[index]
            let legend = NSMutableAttributedString(string: "■ " + names[index], attributes: [.foregroundColor: secondary, .font: UIFont.systemFont(ofSize: max(13, fontSize * 14 / 17))])
            legend.addAttribute(.foregroundColor, value: colors[index], range: NSRange(location: 0, length: 1))
            self.legends[index].attributedText = legend
            self.legends[index].font = .systemFont(ofSize: max(13, fontSize * 14 / 17))
        }
        for divider in self.dividers { divider.backgroundColor = UIColor(white: dark ? 0.07 : 237 / 255, alpha: 1) }
        self.heading.text = chinese ? "本账号已用缓存" : "Cache Used by This Account"
        self.heading.font = .systemFont(ofSize: fontSize)
        self.heading.textColor = text
        self.total.font = .systemFont(ofSize: fontSize * 46 / 17, weight: .medium)
        self.total.textColor = text
        self.proportion.font = .systemFont(ofSize: max(13, fontSize * 14 / 17))
        self.proportion.textColor = secondary
        let titles = chinese ? ["缓存", "聊天媒体", "其他缓存"] : ["Cache", "Chat Media", "Other Cache"]
        let descriptions = chinese ? ["清理本账号的本地媒体缓存，确认后开始。保留规则与自动下载在右上角“更多”中调整。", "包含在上方缓存中。可按聊天或媒体类型选择清理照片、视频、文件与音乐。", "包含在上方缓存中，包括头像、贴纸、动态及其他缓存。此处不统计程序文件、消息数据库或其他账号。"] : ["Clear this account’s local media cache after confirmation. Retention and automatic download settings are under More (top right).", "Included in the cache above. Manage photos, videos, files and music by chat or media type.", "Included in the cache above: avatars, stickers, stories and other cache. App files, the message database and other accounts are not measured here."]
        for index in 0..<3 {
            let block = self.blocks[index]
            block.title.text = titles[index]
            block.title.font = .systemFont(ofSize: fontSize)
            block.title.textColor = text
            block.size.font = .systemFont(ofSize: fontSize * 26 / 17, weight: .medium)
            block.size.textColor = text
            block.explanation.text = descriptions[index]
            block.explanation.font = .systemFont(ofSize: max(13, fontSize * 14 / 17))
            block.explanation.textColor = secondary
            block.button.dark = dark
            block.button.fontSize = fontSize
        }
        self.blocks[0].button.setTitle(chinese ? "清理" : "Clear", for: .normal)
        self.blocks[1].button.setTitle(chinese ? "管理" : "Manage", for: .normal)
        self.updateState()
    }
    private func updateState() {
        self.total.text = self.summary.map { self.formatBytes($0.cacheBytes) } ?? "—"
        let bytes = [self.summary?.cacheBytes, self.summary?.mediaBytes, self.summary?.otherBytes]
        for index in 0..<3 { self.blocks[index].size.text = bytes[index].map(self.formatBytes) ?? "—" }
        if let fraction = self.summary?.usageFraction {
            let value = fraction > 0 && fraction < 0.001 ? "<0.1" : String(format: "%.1f", fraction * 100)
            self.proportion.text = self.chinese ? "占手机 \(value)% 存储空间" : "Uses \(value)% of device storage"
        } else { self.proportion.text = self.chinese ? "容量占比暂不可用" : "Storage proportion unavailable" }
        self.chart.accessibilityLabel = self.chinese ? "手机存储空间" : "Device Storage"
        self.chart.accessibilityValue = self.proportion.text
        self.blocks[0].button.isEnabled = !self.busy && (self.summary?.cacheBytes ?? 0) > 0
        self.blocks[1].button.isEnabled = !self.busy && self.summary != nil
        for block in self.blocks { block.button.updateFill() }
        if self.summary == nil || self.busy { self.activity.startAnimating() } else { self.activity.stopAnimating() }
        if !self.busy { self.progress.isHidden = true }
        self.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let textWidth = max(1, width - 48)
        self.chart.frame = CGRect(x: 24, y: 24, width: textWidth, height: 16)
        var x: CGFloat = 0
        for index in 0..<3 {
            let segmentWidth = CGFloat(self.summary?.fractions?[index] ?? 0) * self.chart.bounds.width
            self.segments[index].frame = CGRect(x: x, y: 0, width: segmentWidth, height: 16)
            x += segmentWidth
        }
        var y = self.chart.frame.maxY + 8
        var legendX: CGFloat = 24
        var lineHeight: CGFloat = 0
        for (index, legend) in self.legends.enumerated() {
            let size = legend.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
            if legendX > 24 && (index == 2 || legendX + size.width > width - 24) {
                y += lineHeight + 8
                legendX = 24
                lineHeight = 0
            }
            legend.frame = CGRect(x: legendX, y: y, width: min(textWidth, size.width), height: size.height)
            legendX = legend.frame.maxX + 12
            lineHeight = max(lineHeight, size.height)
        }
        y += lineHeight + 24
        let headingHeight = self.heading.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
        self.heading.frame = CGRect(x: 24, y: y, width: textWidth, height: headingHeight)
        self.total.frame = CGRect(x: 24, y: self.heading.frame.maxY + 12, width: textWidth, height: self.total.font.lineHeight)
        let proportionHeight = self.proportion.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
        self.proportion.frame = CGRect(x: 24, y: self.total.frame.maxY + 12, width: textWidth, height: proportionHeight)
        self.activity.center = CGPoint(x: width - 36, y: self.heading.frame.midY)
        self.progress.frame = CGRect(x: 24, y: self.proportion.frame.maxY + 12, width: textWidth, height: 3)
        y = self.proportion.frame.maxY + 36
        for (index, block) in self.blocks.enumerated() {
            self.dividers[index].frame = CGRect(x: 0, y: y - 8, width: width, height: 8)
            let height = block.layout(width: width)
            block.frame = CGRect(x: 0, y: y, width: width, height: height)
            y = block.frame.maxY + 8
        }
        self.contentSize = CGSize(width: width, height: y + 16)
    }
}
