import SwiftUI

struct ContentView: View {
    @StateObject private var broadcast = BroadcastControllerModel()

    private var broadcastExtensionIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "dev.local.iPadMirrorPad").BroadcastExtension"
    }

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: broadcast.isBroadcasting ? "dot.radiowaves.left.and.right" : "ipad.and.iphone")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
                .foregroundColor(broadcast.isBroadcasting ? .red : .accentColor)

            VStack(spacing: 10) {
                Text("iPad 현재 화면 미러링")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("시작을 누르면 홈 화면과 다른 앱을 포함한 iPad 현재 화면이 Mac 앱에 표시됩니다. 종료를 누르면 화면 공유가 중지됩니다.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 14) {
                BroadcastPickerButton(preferredExtension: broadcastExtensionIdentifier)
                    .frame(width: 360, height: 88)
                    .shadow(color: .red.opacity(0.25), radius: 14, y: 6)
                    .accessibilityLabel("전체 화면 공유 시작")

                Button {
                    broadcast.stopBroadcast()
                } label: {
                    Label("화면 공유 종료", systemImage: "stop.circle.fill")
                        .font(.title2.weight(.semibold))
                        .frame(width: 360, height: 64)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }

            Text(broadcast.status)
                .font(.headline)
                .foregroundStyle(broadcast.isBroadcasting ? .red : .secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text("Mac 앱 사용 순서")
                    .font(.headline)
                Text("1. ‘전체 화면 공유 시작’ 누르기")
                Text("2. 방송 선택창에서 ‘iPad Mirror Broadcast’ 시작")
                Text("3. Mac 앱에서 새로고침 후 iPad 이름 선택")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
    }
}
