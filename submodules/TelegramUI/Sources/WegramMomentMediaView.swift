import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TinyThumbnail

// Feed previews observe the existing cache; opening the original viewer owns fetching and read receipts.
final class WegramMomentMediaView: UIImageView {
    private let disposable = MetaDisposable()
    private var generation = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentMode = .scaleAspectFill
        self.clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { self.disposable.dispose() }
    func reset() {
        self.generation += 1
        self.disposable.set(nil)
        self.image = nil
    }
    func update(context: AccountContext, media: EngineMedia?, protected: Bool) {
        self.reset()
        let generation = self.generation
        guard !protected, let media else { return }
        let resource: EngineMediaResource?
        let tiny: Data?
        switch media {
        case let .image(image):
            resource = largestImageRepresentation(image.representations).map { EngineMediaResource($0.resource) }
            tiny = image.immediateThumbnailData
        case let .file(file):
            resource = file.previewRepresentations.first.map { EngineMediaResource($0.resource) }
            tiny = file.immediateThumbnailData
        default: return
        }
        if let data = tiny.flatMap(decodeTinyThumbnail) { self.image = UIImage(data: data) }
        if let resource {
            self.disposable.set((context.engine.resources.data(resource: resource)
            |> map { data -> UIImage? in
                guard data.isComplete else { return nil }
                return UIImage(contentsOfFile: data.path)
            } |> deliverOnMainQueue).startStrict(next: { [weak self] image in
                if let self, self.generation == generation, let image { self.image = image }
            }))
        }
    }
}
