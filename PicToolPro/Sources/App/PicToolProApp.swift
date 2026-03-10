import SwiftUI

@main
struct PicToolProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Edit") {
                Button("Undo") {
                    UndoManager().undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Redo") {
                    UndoManager().redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
        }
    }
}
