import SwiftSignalKit

public enum CameraRollSaveResult: Equatable {
    case saved
    case accessDenied
    case failed
}

// Fetch progress can reach 1 before PhotoKit writes the asset.
public func cameraRollSaveResultSignal(_ save: @escaping (@escaping (CameraRollSaveResult) -> Void) -> Signal<Float, NoError>) -> Signal<CameraRollSaveResult, NoError> {
    return Signal { subscriber in
        return save({ subscriber.putNext($0) }).start(completed: { subscriber.putCompletion() })
    } |> take(1)
}
