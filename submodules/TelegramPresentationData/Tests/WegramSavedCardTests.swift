import XCTest
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import Postbox
import ChatPresentationInterfaceState

final class WegramSavedCardTests: XCTestCase {
    func testChatMediaScopeSurvivesQueryAndResultsButClearsOnDomainChange() {
        let media = ChatSearchData(query: "hello").withUpdatedMediaTags(.photoOrVideo)
        XCTAssertEqual(media.withUpdatedQuery("world").mediaTags, .photoOrVideo)
        XCTAssertEqual(media.withUpdatedResultsState(nil).mediaTags, .photoOrVideo)
        XCTAssertEqual(media.withUpdatedDomainSuggestionContext(.none).mediaTags, .photoOrVideo)
        XCTAssertNil(media.withUpdatedDomain(.everything).mediaTags)
        XCTAssertNil(media.withUpdatedDomain(.members).mediaTags)
        XCTAssertNil(media.withUpdatedMediaTags(nil).mediaTags)
        XCTAssertNotEqual(media, media.withUpdatedMediaTags(.file))
        XCTAssertNil(ChatSearchData(mediaTags: []).mediaTags)
        XCTAssertNil(ChatSearchData(domain: .members, mediaTags: .file).mediaTags)
    }

    func testChatCategoriesUseActualTagScopesAndIgnoreHiddenActions() {
        let view = WegramChatSearchCategoriesView()
        var scopes: [EngineMessage.Tags?] = []
        view.selectedCategory = { scopes.append($0) }
        for button in view.buttons { button.sendActions(for: .touchUpInside) }
        XCTAssertEqual(scopes, [nil, .photoOrVideo, .file, .webPage, .music, .voiceOrInstantVideo])
        view.isHidden = true
        view.buttons[1].sendActions(for: .touchUpInside)
        XCTAssertEqual(scopes.count, 6)
    }

    func testFavoriteCategoriesUseOriginalMediaTagsAndVoiceExcludesRoundVideo() {
        XCTAssertNil(WegramSavedAttachmentCategory.all.tags)
        XCTAssertEqual(WegramSavedAttachmentCategory.links.tags, .webPage)
        XCTAssertEqual(WegramSavedAttachmentCategory.files.tags, .file)
        XCTAssertEqual(WegramSavedAttachmentCategory.media.tags, .photoOrVideo)
        XCTAssertEqual(WegramSavedAttachmentCategory.music.tags, .music)
        XCTAssertEqual(WegramSavedAttachmentCategory.voice.tags, .voice)
        XCTAssertNotEqual(WegramSavedAttachmentCategory.voice.tags, .voiceOrInstantVideo)
    }

    func testCategoryButtonsSelectCurrentCategoryAndIgnoreRepeatedOrInactiveActions() {
        let view = WegramSavedAttachmentCategoriesView()
        var selected: [WegramSavedAttachmentCategory] = []
        view.selectedCategory = { [weak view] category in
            selected.append(category)
            view?.update(selected: category, chinese: true, dark: false, fontSize: 17)
        }
        view.update(selected: .all, chinese: true, dark: false, fontSize: 17)
        view.buttons[0].sendActions(for: .touchUpInside)
        view.buttons[1].sendActions(for: .touchUpInside)
        view.buttons[1].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [.links])
        XCTAssertTrue(view.buttons[1].accessibilityTraits.contains(.selected))
        XCTAssertFalse(view.buttons[0].accessibilityTraits.contains(.selected))
        view.isHidden = true
        view.buttons[2].sendActions(for: .touchUpInside)
        view.isHidden = false
        view.alpha = 0
        view.buttons[2].sendActions(for: .touchUpInside)
        view.alpha = 1
        view.buttons[2].isEnabled = false
        view.buttons[2].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [.links])
        view.buttons[2].isEnabled = true
        view.buttons[2].sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [.links, .files])
    }

    func testCategoriesKeepSixLargeTargetsInsideSurfaceAcrossFontsAndThemes() throws {
        let view = WegramSavedAttachmentCategoriesView()
        for chinese in [true, false] {
            for dark in [false, true] {
                for font: CGFloat in [17, 26] {
                    for width: CGFloat in [250, 402, 874] {
                        view.update(selected: .media, chinese: chinese, dark: dark, fontSize: font)
                        view.frame = CGRect(x: 0, y: 0, width: width, height: view.preferredHeight(width: width))
                        view.layoutIfNeeded()
                        for (index, button) in view.buttons.enumerated() {
                            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                            XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
                            XCTAssertLessThanOrEqual(button.frame.maxX, width - 16 + 0.01)
                            XCTAssertLessThanOrEqual(button.frame.maxY, view.bounds.height - 20)
                            XCTAssertEqual(button.currentTitle, WegramSavedAttachmentCategory.allCases[index].title(chinese: chinese))
                            XCTAssertEqual(button.accessibilityTraits.contains(.selected), index == 3)
                        }
                        if chinese, !dark, font == 17, width == 402, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                            let format = UIGraphicsImageRendererFormat(); format.scale = 3
                            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("saved-categories.png"))
                        }
                    }
                }
            }
        }
    }

    func testCardsKeepContentSourceAndDateInsideSeparateRoundedSurface() throws {
        for dark in [false, true] {
            for font: CGFloat in [17, 26] {
                for width: CGFloat in [250, 402, 874] {
                    for thumbnail in [false, true] {
                        let view = WegramSavedAttachmentCardView()
                        view.update(title: "第四节课：发音技巧和长文本标题", subtitle: "第一行说明。第二行说明。内容继续时应当截断并保持来源日期可见。", source: "原始来源群聊", date: "今天", hasThumbnail: thumbnail, dark: dark, fontSize: font)
                        view.frame = CGRect(x: 0, y: 0, width: width, height: view.preferredHeight(width: width))
                        view.layoutIfNeeded()
                        XCTAssertEqual(view.card.frame.minX, 8)
                        XCTAssertEqual(view.card.frame.maxX, width - 8)
                        XCTAssertEqual(view.card.frame.maxY, view.bounds.height - 8)
                        XCTAssertEqual(view.card.layer.cornerRadius, 4)
                        XCTAssertLessThanOrEqual(view.subtitle.frame.maxY, view.metadata.frame.minY)
                        XCTAssertLessThanOrEqual(view.title.frame.maxY, view.subtitle.frame.minY)
                        XCTAssertLessThanOrEqual(view.metadata.frame.maxY, view.card.bounds.height - 18)
                        XCTAssertGreaterThanOrEqual(view.bounds.height, 44)
                        for text in [view.title, view.subtitle, view.metadata, view.dateLabel] {
                            XCTAssertGreaterThanOrEqual(text.frame.minX, 18)
                            XCTAssertLessThanOrEqual(text.frame.maxX, view.card.bounds.width - 18)
                        }
                        if thumbnail {
                            XCTAssertEqual(view.thumbnailHost.frame.size, CGSize(width: 56, height: 56))
                            XCTAssertLessThanOrEqual(view.thumbnailHost.frame.maxX, view.title.frame.minX)
                            XCTAssertLessThanOrEqual(view.thumbnailHost.frame.maxY, view.metadata.frame.minY)
                        }
                        XCTAssertEqual(view.metadata.text, "原始来源群聊")
                        XCTAssertEqual(view.dateLabel.text, "今天")
                        XCTAssertLessThanOrEqual(view.metadata.frame.maxX, view.dateLabel.frame.minX)
                        XCTAssertTrue(view.accessibilityTraits.contains(.button))
                        XCTAssertEqual(view.thumbnailHost.isHidden, !thumbnail)
                        if width == 402, font == 17, !thumbnail, let output = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] {
                            let format = UIGraphicsImageRendererFormat(); format.scale = 3
                            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { view.layer.render(in: $0.cgContext) }
                            try image.pngData()?.write(to: URL(fileURLWithPath: output).appendingPathComponent("saved-card-\(dark ? "dark" : "light").png"))
                        }
                    }
                }
            }
        }
    }

    func testLongSourceCannotTruncateDateAndMissingSourceLeavesNoGap() {
        let view = WegramSavedAttachmentCardView()
        for source in [String(repeating: "很长的真实来源名称", count: 20), ""] {
            view.update(title: "收藏", subtitle: "", source: source, date: "2025年12月20日", hasThumbnail: false, dark: false, fontSize: 26)
            view.frame = CGRect(x: 0, y: 0, width: 250, height: view.preferredHeight(width: 250))
            view.layoutIfNeeded()
            XCTAssertGreaterThan(view.dateLabel.frame.width, 0)
            XCTAssertEqual(view.dateLabel.frame.width, ceil(view.dateLabel.intrinsicContentSize.width))
            XCTAssertLessThanOrEqual(view.dateLabel.frame.maxX, view.card.bounds.width - 18)
            XCTAssertLessThanOrEqual(view.metadata.frame.maxX, view.dateLabel.frame.minX)
            if source.isEmpty { XCTAssertEqual(view.dateLabel.frame.minX, 18) }
        }
    }

    func testDateUsingAllAvailableWidthDoesNotAddAnEmptySourceGap() {
        let view = WegramSavedAttachmentCardView()
        view.update(title: "收藏", subtitle: "", source: "来源", date: "2025年12月20日", hasThumbnail: false, dark: false, fontSize: 36)
        view.frame = CGRect(x: 0, y: 0, width: 180, height: view.preferredHeight(width: 180))
        view.layoutIfNeeded()
        XCTAssertEqual(view.metadata.frame.width, 0)
        XCTAssertEqual(view.dateLabel.frame.minX, 18)
        XCTAssertLessThanOrEqual(view.dateLabel.frame.maxX, view.card.bounds.width - 18)
    }

    func testReusedCardInvokesCurrentSelectionAndIgnoresInactiveControls() {
        let view = WegramSavedAttachmentCardView()
        var ids: [Int] = []
        view.pressed = { ids.append(1) }
        view.sendActions(for: .touchUpInside)
        view.pressed = { ids.append(2) }
        view.sendActions(for: .touchUpInside)
        view.isHighlighted = true
        view.update(title: "当前收藏", subtitle: "", source: "", date: "", hasThumbnail: false, dark: true, fontSize: 17)
        XCTAssertEqual(view.card.backgroundColor, UIColor(rgb: 0x393939))
        view.isHighlighted = false
        XCTAssertEqual(view.card.backgroundColor, UIColor(rgb: 0x2c2c2c))
        view.isEnabled = false
        view.sendActions(for: .touchUpInside)
        view.isEnabled = true; view.alpha = 0
        view.sendActions(for: .touchUpInside)
        view.alpha = 1; view.isHidden = true
        view.sendActions(for: .touchUpInside)
        XCTAssertEqual(ids, [1, 2])
    }

    func testForwardedSignatureIsNotReplacedByCollectorsName() {
        let user = TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(1)), accessHash: nil, firstName: "收藏者", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
        let info = EngineMessage.ForwardInfo(author: nil, source: nil, sourceMessageId: nil, date: 1, authorSignature: "原始隐私署名", psaType: nil, flags: [])
        XCTAssertEqual(wegramSavedAttachmentSource(forwardInfo: info, author: .user(user)), "原始隐私署名")
        XCTAssertEqual(wegramSavedAttachmentSource(forwardInfo: nil, author: .user(user)), "收藏者")
        let unknown = EngineMessage.ForwardInfo(author: nil, source: nil, sourceMessageId: nil, date: 1, authorSignature: nil, psaType: nil, flags: [])
        XCTAssertEqual(wegramSavedAttachmentSource(forwardInfo: unknown, author: .user(user)), "", "Unknown forwarded origin must not be attributed to the collector")
    }

    func testSearchHighlightsActualUTF16MatchesAndClearsWhenQueryChanges() throws {
        let view = WegramSavedAttachmentCardView()
        let text = "📍巨鹿路，巨鹿花园 ROAD road"
        func update(_ query: String, dark: Bool = false) {
            view.update(title: text, subtitle: "ROAD road", source: "巨鹿来源", date: "今天", hasThumbnail: false, dark: dark, fontSize: 17, query: query)
        }
        update("巨鹿")
        let green = UIColor(rgb: 0x07c160)
        let title = try XCTUnwrap(view.title.attributedText)
        XCTAssertEqual(title.string, text)
        let original = text as NSString
        let first = original.range(of: "巨鹿")
        let second = original.range(of: "巨鹿", range: NSRange(location: NSMaxRange(first), length: original.length - NSMaxRange(first)))
        for range in [first, second] {
            XCTAssertEqual(title.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor, green)
            XCTAssertEqual((title.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont)?.pointSize, 16)
        }
        XCTAssertEqual(view.metadata.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, green)
        update("road", dark: true)
        let subtitle = try XCTUnwrap(view.subtitle.attributedText)
        XCTAssertEqual(subtitle.string, "ROAD road")
        for location in [0, 5] { XCTAssertEqual(subtitle.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor, green) }
        for query in ["", " \n ", "不存在"] {
            update(query)
            for label in [view.title, view.subtitle, view.metadata] {
                var containsGreen = false
                label.attributedText?.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: label.attributedText?.length ?? 0)) { color, _, _ in
                    if (color as? UIColor)?.isEqual(green) == true { containsGreen = true }
                }
                XCTAssertFalse(containsGreen)
            }
        }
    }

    func testSearchSnippetShowsDistantMatchWithoutCuttingEmojiAndKeepsFullAccessibilityText() {
        let full = String(repeating: "前文👨‍👩‍👧‍👦", count: 40) + "目标词" + String(repeating: "后文🇨🇳", count: 40)
        let snippet = wegramSavedAttachmentSearchSnippet(full, query: "目标词")
        XCTAssertTrue(snippet.hasPrefix("…"))
        XCTAssertTrue(snippet.hasSuffix("…"))
        XCTAssertTrue(snippet.contains("目标词"))
        XCTAssertFalse(snippet.contains("�"))
        XCTAssertEqual(wegramSavedAttachmentSearchSnippet("短文 Road", query: "road"), "短文 Road")
        XCTAssertEqual(wegramSavedAttachmentSearchSnippet(full, query: nil), full)
        XCTAssertEqual(wegramSavedAttachmentSearchSnippet(full, query: "不存在"), full)
        let view = WegramSavedAttachmentCardView()
        view.update(title: "标题", subtitle: full, source: "来源", date: "今天", hasThumbnail: false, dark: false, fontSize: 17, query: "目标词")
        XCTAssertEqual(view.subtitle.text, snippet)
        XCTAssertTrue(view.accessibilityLabel?.contains(full) == true)
        XCTAssertLessThan(snippet.count, full.count)
    }

    func testSpoilerPlaceholderDoesNotRevealOrHighlightHiddenContentAndDateStaysNeutral() {
        let view = WegramSavedAttachmentCardView()
        view.update(title: "[剧透内容]", subtitle: "", source: "今天来源", date: "今天", hasThumbnail: false, dark: false, fontSize: 17, query: "剧透", highlightContent: false)
        XCTAssertEqual(view.title.text, "[剧透内容]")
        XCTAssertEqual(view.title.attributedText?.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, UIColor(rgb: 0x181818))
        view.update(title: "原文", subtitle: "", source: "今天来源", date: "今天", hasThumbnail: false, dark: false, fontSize: 17, query: "今天")
        XCTAssertEqual(view.metadata.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor(rgb: 0x07c160))
        XCTAssertEqual(view.dateLabel.textColor, UIColor(rgb: 0xb2b2b2))
    }

    func testRichTextSpoilersAreDetectedInOriginalAttributedPreviewBeforePlainTextProjection() {
        let peer = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(10))
        let data = defaultPresentationData()
        for hidden in [false, true] {
            let text: RichText = hidden ? .textSpoiler(text: .plain("隐藏关键词")) : .plain("普通关键词")
            let page = InstantPage(blocks: [.paragraph(.concat([.plain("前文"), text, .plain("后文")]))], media: [:], isComplete: true, rtl: false, url: "", views: nil)
            let message = EngineMessage(stableId: 1, stableVersion: 0, id: EngineMessage.Id(peerId: peer, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [RichTextMessageAttribute(instantPage: page, fullInstantPage: nil)], media: [], peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            let preview = descriptionStringForMessage(contentSettings: .default, message: message, strings: data.strings, nameDisplayOrder: data.nameDisplayOrder, dateTimeFormat: data.dateTimeFormat, accountPeerId: peer).0
            XCTAssertTrue(preview.string.contains(hidden ? "隐藏关键词" : "普通关键词"))
            XCTAssertEqual(wegramSavedAttachmentHasHiddenText(message, preview: preview), hidden)
        }
    }

    private func documentFile(name: String?, size: Int64?, attributes: [TelegramMediaFileAttribute] = []) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: MediaId(namespace: 0, id: 40), partialReference: nil, resource: LocalFileMediaResource(fileId: 40), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/octet-stream", size: size, attributes: (name.map { [.FileName(fileName: $0)] } ?? []) + attributes, alternativeRepresentations: [])
    }

    func testDocumentCardUsesActualFileNameSizeAndExistingColoredTypeArtwork() throws {
        let strings = defaultPresentationStrings
        let pdf = try XCTUnwrap(WegramSavedAttachmentDocument(file: self.documentFile(name: "实际文件.PdF", size: 1536), caption: "文件附言", captionIsHidden: false, strings: strings, decimalSeparator: "."))
        XCTAssertEqual(pdf.title, "实际文件.PdF")
        XCTAssertEqual(pdf.subtitle, "PDF " + strings.FileSize_KB("1.5").string + "\n文件附言")
        XCTAssertEqual(pdf.icon.renderingMode, .alwaysOriginal)
        XCTAssertEqual(pdf.icon.size, CGSize(width: 44, height: 44))
        let doc = try XCTUnwrap(WegramSavedAttachmentDocument(file: self.documentFile(name: "报告.docx", size: 0), caption: "", captionIsHidden: false, strings: strings, decimalSeparator: "."))
        XCTAssertEqual(doc.title, "报告.docx")
        XCTAssertNotEqual(pdf.icon.pngData(), doc.icon.pngData())
        let view = WegramSavedAttachmentCardView()
        for item in [pdf, doc] {
            view.update(title: item.title, subtitle: item.subtitle, source: "来源", date: "今天", hasThumbnail: true, dark: false, fontSize: 26, query: "报告")
            view.frame = CGRect(x: 0, y: 0, width: 250, height: view.preferredHeight(width: 250))
            view.layoutIfNeeded()
            XCTAssertEqual(view.title.text, item.title)
            XCTAssertTrue(view.accessibilityLabel?.contains(item.subtitle) == true)
            XCTAssertLessThanOrEqual(view.subtitle.frame.maxY, view.metadata.frame.minY)
        }
    }

    func testDocumentWithoutKnownSizeDoesNotInventZeroBytesAndCaptionSpoilerStaysHidden() throws {
        let strings = defaultPresentationStrings
        for size: Int64? in [nil, -1] {
            let unknown = try XCTUnwrap(WegramSavedAttachmentDocument(file: self.documentFile(name: nil, size: size), caption: "", captionIsHidden: false, strings: strings, decimalSeparator: "."))
            XCTAssertEqual(unknown.title, strings.Message_File)
            XCTAssertEqual(unknown.subtitle, "")
        }
        let zero = try XCTUnwrap(WegramSavedAttachmentDocument(file: self.documentFile(name: "empty", size: 0), caption: "", captionIsHidden: false, strings: strings, decimalSeparator: "."))
        XCTAssertEqual(zero.subtitle, strings.FileSize_B("0").string)
        let hidden = try XCTUnwrap(WegramSavedAttachmentDocument(file: self.documentFile(name: "公开文件名.pdf", size: 1536), caption: "不能展示的附言", captionIsHidden: true, strings: strings, decimalSeparator: "."))
        XCTAssertEqual(hidden.title, "公开文件名.pdf")
        XCTAssertFalse(hidden.subtitle.contains("不能展示"))
        XCTAssertTrue(hidden.subtitle.contains("[Spoiler]"))
    }

    func testVoiceMusicVideoAndAnimationsKeepTheirExistingMediaCards() {
        let attributes: [[TelegramMediaFileAttribute]] = [
            [.Audio(isVoice: true, duration: 1, title: nil, performer: nil, waveform: nil)],
            [.Audio(isVoice: false, duration: 1, title: "歌名", performer: nil, waveform: nil)],
            [.Animated],
            [.Video(duration: 1, size: PixelDimensions(width: 640, height: 480), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)],
            [.Video(duration: 1, size: PixelDimensions(width: 640, height: 480), flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil)]
        ]
        for attributes in attributes {
            XCTAssertNil(WegramSavedAttachmentDocument(file: self.documentFile(name: "媒体.pdf", size: 100, attributes: attributes), caption: "", captionIsHidden: false, strings: defaultPresentationStrings, decimalSeparator: "."))
        }
    }

    private func location(latitude: Double = 31.2, longitude: Double = 121.4, venue: MapVenue? = nil, address: MapGeoAddress? = nil, timeout: Int32? = nil) -> TelegramMediaMap {
        return TelegramMediaMap(latitude: latitude, longitude: longitude, heading: nil, accuracyRadius: nil, venue: venue, address: address, liveBroadcastingTimeout: timeout)
    }

    func testSavedLocationUsesActualVenueAddressAndPreservesComment() throws {
        let venue = MapVenue(title: "真实办公园", address: "实际街道678号", provider: nil, id: nil, type: nil)
        let location = try XCTUnwrap(WegramSavedAttachmentLocation(map: self.location(venue: venue), caption: "我添加的地点说明", captionIsHidden: false, strings: defaultPresentationStrings))
        XCTAssertEqual(location.title, venue.title)
        XCTAssertEqual(location.subtitle, "实际街道678号\n我添加的地点说明")
        let view = WegramSavedAttachmentCardView()
        for dark in [false, true] {
            view.update(title: location.title, subtitle: location.subtitle, source: "原始来源", date: "昨天", hasThumbnail: true, dark: dark, fontSize: 26, query: "办公")
            view.frame = CGRect(x: 0, y: 0, width: 250, height: view.preferredHeight(width: 250))
            view.layoutIfNeeded()
            XCTAssertEqual(view.title.text, "真实办公园")
            XCTAssertTrue(view.accessibilityLabel?.contains("实际街道678号\n我添加的地点说明") == true)
            XCTAssertLessThanOrEqual(view.subtitle.frame.maxY, view.metadata.frame.minY)
        }
    }

    func testSavedLocationMissingVenueUsesRealAddressOrCoordinatesWithoutInventingPlace() throws {
        let address = MapGeoAddress(country: "CN", state: "上海", city: "", street: "真实路")
        let located = try XCTUnwrap(WegramSavedAttachmentLocation(map: self.location(address: address), caption: "", captionIsHidden: false, strings: defaultPresentationStrings))
        XCTAssertEqual(located.title, defaultPresentationStrings.Message_Location)
        XCTAssertEqual(located.subtitle, "上海 真实路")
        let coordinates = try XCTUnwrap(WegramSavedAttachmentLocation(map: self.location(latitude: -12.34567, longitude: 76.54321), caption: " \n", captionIsHidden: false, strings: defaultPresentationStrings))
        XCTAssertEqual(coordinates.subtitle, "-12.34567, 76.54321")
        XCTAssertNil(WegramSavedAttachmentLocation(map: self.location(), caption: "隐藏地点说明", captionIsHidden: true, strings: defaultPresentationStrings))
        for map in [self.location(latitude: .nan), self.location(longitude: 181), self.location(timeout: 3600), self.location(timeout: 0)] {
            XCTAssertNil(WegramSavedAttachmentLocation(map: map, caption: "", captionIsHidden: false, strings: defaultPresentationStrings))
        }
    }

    private func webpage(title: String? = "实际文章标题", summary: String? = "实际文章摘要", type: String? = "article", image: TelegramMediaImage? = nil, url: String = "https://example.com/article") -> TelegramMediaWebpage {
        let content = TelegramMediaWebpageLoadedContent(url: url, displayUrl: "example.com/article", hash: 0, type: type, websiteName: "网站", title: title, text: summary, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: image, file: nil, story: nil, attributes: [], instantPage: nil)
        return TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 41), content: .Loaded(content))
    }

    func testSavedLinkUsesActualArticleTitleSummaryAndOriginalCover() throws {
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 42), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let webpage = self.webpage(image: image)
        for caption in ["https://example.com/article", " \nhttps://example.com/article\n", "example.com/article"] {
            let link = try XCTUnwrap(WegramSavedAttachmentLink(webpage: webpage, caption: caption, captionIsHidden: false))
            XCTAssertEqual(link.title, "实际文章标题")
            XCTAssertEqual(link.subtitle, "实际文章摘要")
            XCTAssertTrue(link.image === image)
        }
        let commented = try XCTUnwrap(WegramSavedAttachmentLink(webpage: webpage, caption: "保留我的附言 https://example.com/article", captionIsHidden: false))
        XCTAssertEqual(commented.subtitle, "保留我的附言 https://example.com/article\n实际文章摘要")
    }

    func testSavedLinkKeepsPendingSpecialAndHiddenContentOnExistingPath() {
        let pending = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 41), content: .Pending(0, "https://example.com/article"))
        XCTAssertNil(WegramSavedAttachmentLink(webpage: pending, caption: "原始文字", captionIsHidden: false))
        XCTAssertNil(WegramSavedAttachmentLink(webpage: self.webpage(), caption: "隐藏附言", captionIsHidden: true))
        for type in ["photo", "video", "telegram_channel"] {
            XCTAssertNil(WegramSavedAttachmentLink(webpage: self.webpage(type: type), caption: "", captionIsHidden: false))
        }
        XCTAssertNil(WegramSavedAttachmentLink(webpage: self.webpage(url: "https://t.me/example"), caption: "", captionIsHidden: false))
        XCTAssertNil(WegramSavedAttachmentLink(webpage: self.webpage(title: nil, summary: nil), caption: "", captionIsHidden: false))
    }

    func testSavedLinkFallbackDoesNotDuplicateSummaryAndReusedCardClearsCover() throws {
        let link = try XCTUnwrap(WegramSavedAttachmentLink(webpage: self.webpage(title: " \n", summary: "只有真实摘要"), caption: "", captionIsHidden: false))
        XCTAssertEqual(link.title, "只有真实摘要")
        XCTAssertEqual(link.subtitle, "")
        XCTAssertNil(link.image)
        let view = WegramSavedAttachmentCardView()
        for thumbnail in [true, false] {
            view.update(title: link.title, subtitle: link.subtitle, source: "真实收藏来源", date: "今天", hasThumbnail: thumbnail, dark: false, fontSize: 26, query: "真实")
            view.frame = CGRect(x: 0, y: 0, width: 250, height: view.preferredHeight(width: 250))
            view.layoutIfNeeded()
            XCTAssertEqual(view.thumbnailHost.isHidden, !thumbnail)
            XCTAssertEqual(view.title.frame.minX, thumbnail ? 86 : 18)
            XCTAssertTrue(view.accessibilityLabel?.contains("只有真实摘要") == true)
            XCTAssertLessThanOrEqual(view.title.frame.maxY, view.metadata.frame.minY)
        }
    }

    func testSavedDateUsesLocalCalendarBoundariesIncludingYearAndDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        func label(_ value: Date, now: Date, chinese: Bool = true) -> String {
            return wegramSavedAttachmentDate(timestamp: Int32(value.timeIntervalSince1970), now: now, calendar: calendar, chinese: chinese)
        }
        XCTAssertEqual(label(date(2026, 3, 8, 23), now: date(2026, 3, 9, 0)), "昨天")
        XCTAssertEqual(label(date(2026, 3, 9, 0), now: date(2026, 3, 9, 23)), "今天")
        XCTAssertEqual(label(date(2025, 12, 31, 23), now: date(2026, 1, 1, 0)), "昨天")
        XCTAssertEqual(label(date(2025, 12, 20), now: date(2026, 1, 1)), "2025年12月20日")
        XCTAssertEqual(label(date(2026, 1, 1), now: date(2026, 1, 12)), "1月1日")
        XCTAssertEqual(label(date(2026, 3, 6), now: date(2026, 3, 9)), "星期五")
        XCTAssertEqual(label(date(2026, 3, 9), now: date(2026, 3, 9), chinese: false), "Today")
    }
}
