import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @AppStorage("cove.appearanceMode") private var appearanceRawValue = CoveAppearanceMode.system.rawValue

    private var appearanceBinding: Binding<CoveAppearanceMode> {
        Binding(
            get: { CoveAppearanceMode(rawValue: appearanceRawValue) ?? .system },
            set: { appearanceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        MainWindowView(
            cameraManager: cameraManager,
            appearanceMode: appearanceBinding
        )
        .preferredColorScheme(appearanceBinding.wrappedValue.colorScheme)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
