import Foundation

extension Date {
    /// Returns a short relative string from now to this date.
    /// Examples: "1m", "10m", "1h", "3h", "1d", "28d"
    func relativeStudyString(from referenceDate: Date = Date()) -> String {
        let diff = self.timeIntervalSince(referenceDate)

        if diff < 0 {
            return "now"
        }

        let minutes = Int(diff / 60)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)
        let months = Int(diff / (86400 * 30))

        if months >= 1 {
            return "\(months)mo"
        } else if days >= 1 {
            return "\(days)d"
        } else if hours >= 1 {
            return "\(hours)h"
        } else if minutes >= 1 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}

extension DateFormatter {
    static let lastStudiedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
