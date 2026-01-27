import Foundation

extension Date {
    var dateDescription: String {
        let now = Date()
        let diff = Int(now.timeIntervalSince(self))
        
        if diff < 60 {
            return "just now"
        }
        
        let minutes = diff / 60
        if minutes <= 10 {
            return "1-10 minutes"
        }
        if minutes <= 19 {
            return "15 minutes"
        }
        if minutes < 60 {
            return "30 minutes"
        }
        
        let hours = minutes / 60
        if hours <= 11 {
            return "One-Eleven Hours"
        }
        if hours < 24 {
            return "12+ hours"
        }
        
        let days = hours / 24
        if days < 7 {
            return "1-6 days ago"
        }
        
        let weeks = days / 7
        if days < 28 {
            return "1-3 weeks ago"
        }
        
        let months = days / 30
        if days < 365 {
            return "1-12 months ago"
        }
        
        return "+ 1 year ago"
    }
}
