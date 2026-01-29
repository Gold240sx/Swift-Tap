import Foundation
import SwiftUI
import Combine

/// Manages undo/redo history for text content
class ContentUndoManager: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private(set) var currentContent: String = ""
    private var maxHistorySize: Int = 50
    
    /// Initialize with initial content
    init(initialContent: String = "") {
        currentContent = initialContent
        undoStack.append(initialContent)
    }
    
    /// Record a new state (call this before making changes)
    func recordState(_ content: String) {
        // Only record if content actually changed
        guard content != currentContent else { return }
        
        // Add current state to undo stack
        undoStack.append(currentContent)
        
        // Limit stack size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        // Clear redo stack when new change is made
        redoStack.removeAll()
        
        // Update current content
        currentContent = content
        
        updateCanUndoRedo()
    }
    
    /// Undo the last change
    func undo() -> String? {
        guard !undoStack.isEmpty else { return nil }
        
        // Move current to redo stack
        redoStack.append(currentContent)
        
        // Pop from undo stack
        let previousState = undoStack.removeLast()
        currentContent = previousState
        
        updateCanUndoRedo()
        
        return previousState
    }
    
    /// Redo the last undone change
    func redo() -> String? {
        guard !redoStack.isEmpty else { return nil }
        
        // Move current to undo stack
        undoStack.append(currentContent)
        
        // Pop from redo stack
        let nextState = redoStack.removeLast()
        currentContent = nextState
        
        updateCanUndoRedo()
        
        return nextState
    }
    
    /// Update the current content without recording (for external updates)
    func updateCurrentContent(_ content: String) {
        currentContent = content
        updateCanUndoRedo()
    }
    
    /// Clear all history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        currentContent = ""
        updateCanUndoRedo()
    }
    
    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
