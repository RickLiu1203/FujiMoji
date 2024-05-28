import SwiftUI

struct SettingsView: View {
    @AppStorage("spaceToggle") private var spaceToggle: Bool = true

    var body: some View {
        Form {
            Section() {
                HStack {
                    Text("Replace text after pressing space")
                    Spacer()
                    Toggle("Replace text after pressing space", isOn: $spaceToggle)
                        .labelsHidden()
                }
                .toggleStyle(.switch)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
