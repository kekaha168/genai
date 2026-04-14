import SwiftUI

// MARK: - Empty State

struct EmptyStateView: View {
    let vm: InspectorViewModel
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Background grid
            GeometryReader { geo in
                Canvas { ctx, size in
                    let spacing: CGFloat = 32
                    ctx.opacity = 0.04
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                    ctx.stroke(path, with: .foreground, lineWidth: 0.5)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon cluster
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulse ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .fill(.blue.opacity(0.05))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulse ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.3), value: pulse)

                    Image(systemName: "cpu.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.blue)
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers)
                }
                .padding(.bottom, 32)

                Text("Core ML Inspector")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Load any .mlmodel or .mlpackage\nto inspect its structure and parameters.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    Button {
                        vm.showFilePicker = true
                    } label: {
                        Label("Choose Model File", systemImage: "folder")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        vm.loadSampleModel()
                    } label: {
                        Label("Load Sample (DiceDetector)", systemImage: "die.face.5")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 36)
                .padding(.horizontal, 32)

                Spacer()

                // Feature pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(featurePills, id: \.0) { icon, label in
                            FeaturePill(icon: icon, label: label)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        .onAppear { pulse = true }
    }

    let featurePills: [(String, String)] = [
        ("arrow.down.circle", "Inputs & Outputs"),
        ("square.3.layers.3d", "Layer Structure"),
        ("brain.head.profile", "ANE Routing"),
        ("tag", "Metadata"),
        ("cpu", "Compute Plan"),
    ]
}

struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .foregroundStyle(.secondary)
    }
}

// MARK: - Loading

struct LoadingView: View {
    let message: String
    @State private var rotation = 0.0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.blue.opacity(0.15), lineWidth: 3)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
            }

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .onAppear { rotation = 360 }
        .navigationTitle("Loading")
    }
}

// MARK: - Error

struct ErrorView: View {
    let message: String
    let vm: InspectorViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Failed to load model")
                .font(.title3.bold())

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                vm.state = .empty
            }
            .buttonStyle(.bordered)
        }
        .navigationTitle("Error")
    }
}
