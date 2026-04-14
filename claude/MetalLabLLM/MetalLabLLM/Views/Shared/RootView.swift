import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadRootView()
        } else {
            IPhoneRootView()
        }
        #else
        MacRootView()
        #endif
    }
}

// MARK: - macOS Root

#if os(macOS)
struct MacRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var creatorSelection: CreatorDestination? = .myLabs
    @State private var userSelection: UserDestination? = .browse

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            if appState.role == .creator {
                CreatorSidebar(selection: $creatorSelection)
            } else {
                UserSidebar(selection: $userSelection)
            }
        } detail: {
            if appState.role == .creator {
                CreatorDetailView(selection: $creatorSelection)
            } else {
                UserDetailView(selection: $userSelection)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                TierBadge()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                RolePicker()
                TierPicker()
            }
        }
    }
}

struct MetalLabCommands: Commands {
    var body: some Commands {
        CommandMenu("Lab") {
            Button("New Lab…") { }.keyboardShortcut("n", modifiers: [.command])
            Button("Export .metalab…") { }.keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}
#endif

// MARK: - iPadOS Root

struct IPadRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var creatorSelection: CreatorDestination? = .myLabs
    @State private var userSelection: UserDestination? = .browse

    var body: some View {
        NavigationSplitView {
            if appState.role == .creator {
                CreatorSidebar(selection: $creatorSelection)
            } else {
                UserSidebar(selection: $userSelection)
            }
        } detail: {
            if appState.role == .creator {
                CreatorDetailView(selection: $creatorSelection)
            } else {
                UserDetailView(selection: $userSelection)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                RolePicker()
                TierPicker()
            }
        }
    }
}

// MARK: - iOS Root

struct IPhoneRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.role == .creator {
            CreatorTabView()
        } else {
            UserTabView()
        }
    }
}
