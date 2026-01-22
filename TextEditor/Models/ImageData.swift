//
//  ImageData.swift
//  TextEditor
//
//  Created by Assistant
//

import Foundation
import SwiftData

@Model
class ImageData {
    var id: UUID
    var urlString: String
    var width: Double?
    var height: Double?
    var altText: String?
    var isFullWidth: Bool
    var offsetX: Double
    var offsetY: Double
    /// Zoom scale for the image (1.0 = fit, >1.0 = zoomed in)
    var scale: Double

    init(id: UUID = UUID(), urlString: String, width: Double? = nil, height: Double? = nil, altText: String? = nil, isFullWidth: Bool = false, offsetX: Double = 0, offsetY: Double = 0, scale: Double = 1.0) {
        self.id = id
        self.urlString = urlString
        self.width = width
        self.height = height
        self.altText = altText
        self.isFullWidth = isFullWidth
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
    }
}
