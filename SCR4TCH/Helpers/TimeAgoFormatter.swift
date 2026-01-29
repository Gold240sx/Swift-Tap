//
//  TimeAgoFormatter.swift
//  HoverMenubar_UI
//
//  Created by Michael Martell on 7/4/25.
//

import Foundation

struct TimeAgoFormatter {
    static func timeAgoFormatter(from date: Date, shortFormat: Bool = false, language: SupportedLanguage? = nil) -> String {
        let language = language ?? LanguageManager.shared.currentLanguage
        let locale = Locale(identifier: language.rawValue)
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        let minutes = timeInterval / 60
        let hours = timeInterval / 3600
        let days = timeInterval / 86400
        let weeks = days / 7
        let months = days / 30.44 // Average days in a month
        let years = days / 365.25 // Average days in a year
        
        // Helper function to get localized strings
        func localized(_ key: String) -> String {
            return LanguageManager.shared.translate(key)
        }
        
        if shortFormat {
            // Short format without "ago" - e.g., "45min", "3yrs"
            switch timeInterval {
            case 0..<180: // Less than 3 minutes
                return localized("time_now")
                
            case 180..<1800: // 3 to 30 minutes
                let minutesAgo = Int(floor(minutes))
                return "\(minutesAgo)\(localized("time_min_short"))"
                
            case 1800..<3600: // 30 minutes to 1 hour
                let roundedMinutes = Int(ceil(minutes / 5.0) * 5.0)
                if roundedMinutes >= 60 {
                    return "1\(localized("time_hr_short"))"
                }
                return "\(roundedMinutes)\(localized("time_min_short"))"
                
            case 3600..<86400: // 1 hour to 1 day
                let hoursAgo = Int(floor(hours))
                return hoursAgo == 1 ? "1\(localized("time_hr_short"))" : "\(hoursAgo)\(localized("time_hrs_short"))"
                
            case 86400..<259200: // 1 to 3 days
                let daysAgo = Int(floor(days))
                return daysAgo == 1 ? "1\(localized("time_day_short"))" : "\(daysAgo)\(localized("time_days_short"))"
                
            case 259200..<604800: // 3 days to 1 week - show day of week
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.dateFormat = "EEEE"
                return formatter.string(from: date)
                
            case 604800..<2629746: // 1 week to 1 month
                let weeksAgo = Int(floor(weeks))
                return weeksAgo == 1 ? "1\(localized("time_wk_short"))" : "\(weeksAgo)\(localized("time_wks_short"))"
                
            case 2629746..<31556952: // 1 month to 1 year
                let monthsAgo = Int(floor(months))
                return monthsAgo == 1 ? "1\(localized("time_mo_short"))" : "\(monthsAgo)\(localized("time_mos_short"))"
                
            default: // 1+ years
                let yearsAgo = Int(floor(years))
                return yearsAgo == 1 ? "1\(localized("time_yr_short"))" : "\(yearsAgo)\(localized("time_yrs_short"))"
            }
        } else {
            // Original format with "ago"
            switch timeInterval {
            case 0..<180: // Less than 3 minutes
                return localized("time_now")
                
            case 180..<1800: // 3 to 30 minutes
                let minutesAgo = Int(floor(minutes))
                return minutesAgo == 1 ? 
                    "\(minutesAgo) \(localized("time_minute")) \(localized("time_ago"))" : 
                    "\(minutesAgo) \(localized("time_minutes")) \(localized("time_ago"))"
                
            case 1800..<3600: // 30 minutes to 1 hour
                let roundedMinutes = Int(ceil(minutes / 5.0) * 5.0)
                if roundedMinutes >= 60 {
                    return "1 \(localized("time_hour")) \(localized("time_ago"))"
                }
                return roundedMinutes == 1 ? 
                    "\(roundedMinutes) \(localized("time_minute")) \(localized("time_ago"))" : 
                    "\(roundedMinutes) \(localized("time_minutes")) \(localized("time_ago"))"
                
            case 3600..<86400: // 1 hour to 1 day
                let hoursAgo = Int(floor(hours))
                return hoursAgo == 1 ? 
                    "\(hoursAgo) \(localized("time_hour")) \(localized("time_ago"))" : 
                    "\(hoursAgo) \(localized("time_hours")) \(localized("time_ago"))"
                
            case 86400..<259200: // 1 to 3 days
                let daysAgo = Int(floor(days))
                return daysAgo == 1 ? 
                    "\(daysAgo) \(localized("time_day")) \(localized("time_ago"))" : 
                    "\(daysAgo) \(localized("time_days")) \(localized("time_ago"))"
                
            case 259200..<604800: // 3 days to 1 week - show day of week
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.dateFormat = "EEEE"
                return formatter.string(from: date)
                
            case 604800..<2629746: // 1 week to 1 month
                let weeksAgo = Int(floor(weeks))
                return weeksAgo == 1 ? 
                    "\(weeksAgo) \(localized("time_week")) \(localized("time_ago"))" : 
                    "\(weeksAgo) \(localized("time_weeks")) \(localized("time_ago"))"
                
            case 2629746..<31556952: // 1 month to 1 year
                let monthsAgo = Int(floor(months))
                return monthsAgo == 1 ? 
                    "\(monthsAgo) \(localized("time_month")) \(localized("time_ago"))" : 
                    "\(monthsAgo) \(localized("time_months")) \(localized("time_ago"))"
                
            default: // 1+ years
                let yearsAgo = Int(floor(years))
                return yearsAgo == 1 ? 
                    "\(localized("time_over")) (1) \(localized("time_year")) \(localized("time_ago"))" : 
                    "\(localized("time_over")) (\(yearsAgo)) \(localized("time_years")) \(localized("time_ago"))"
            }
        }
    }
    
    // Helper function to format dates according to locale
    static func formatDate(_ date: Date, format: String, language: SupportedLanguage? = nil) -> String {
        let language = language ?? LanguageManager.shared.currentLanguage
        let locale = Locale(identifier: language.rawValue)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}