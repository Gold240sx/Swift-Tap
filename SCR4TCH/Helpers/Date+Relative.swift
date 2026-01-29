import Foundation

extension Date {
    var dateDescription: String {
        return TimeAgoFormatter.timeAgoFormatter(from: self)
    }
}
