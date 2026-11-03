import Foundation
import WidgetKit

@objc public final class WidgetReloader: NSObject {
    /// Reloads the week and month widgets; they share one snapshot.
    @objc public static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
