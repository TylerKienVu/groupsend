import SwiftUI

struct ProfileCreationView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var name = ""
    @State private var selectedColorIndex = 3   // defaults to blue (#3DA8FF)
    @State private var isLoading = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Nav ─────────────────────────────────────────────────
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DS.text)
                        .frame(width: 36, height: 36)
                        .background(DS.surface2)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.border, lineWidth: 1))
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Headline ─────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What should we\ncall you?")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(DS.text)
                                .tracking(-0.9)
                            Text("Your crew sees this on the heatmap.")
                                .font(.system(size: 15))
                                .foregroundColor(DS.textDim)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 8)

                        // ── Avatar preview ───────────────────────────────
                        HStack {
                            Spacer()
                            AvatarView(
                                name: name.isEmpty ? "?" : name,
                                hexColor: DS.avatarPaletteHex[selectedColorIndex],
                                size: 104
                            )
                            Spacer()
                        }
                        .padding(.top, 28)

                        // ── Name field ───────────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAME")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(DS.textDim)
                                .tracking(1)
                            TextField("Tyler Chen", text: $name)
                                .font(.system(size: 17))
                                .foregroundColor(DS.text)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(DS.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.rMd)
                                        .stroke(nameFocused ? DS.accent : DS.borderStrong, lineWidth: nameFocused ? 2 : 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.rMd))
                                .focused($nameFocused)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 24)

                        // ── Avatar color picker ──────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AVATAR COLOR")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(DS.textDim)
                                .tracking(1)

                            // 2 rows × 5 columns
                            let rows = [Array(0..<5), Array(5..<10)]
                            VStack(spacing: 12) {
                                ForEach(rows, id: \.first) { row in
                                    HStack(spacing: 12) {
                                        ForEach(row, id: \.self) { i in
                                            colorSwatch(index: i)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                }

                // ── CTA ──────────────────────────────────────────────────
                Button {
                    createProfile()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(name.isEmpty || isLoading ? DS.accent.opacity(0.5) : DS.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(name.isEmpty || isLoading)
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func colorSwatch(index: Int) -> some View {
        let hex = DS.avatarPaletteHex[index]
        let isSelected = index == selectedColorIndex
        ZStack {
            Circle()
                .fill(Color(hex: hex))
                // Selected ring: inset background gap + outer stroke of the color
                .overlay(
                    isSelected
                        ? Circle().stroke(DS.bg, lineWidth: 3)
                        : nil
                )
                .overlay(
                    isSelected
                        ? Circle().stroke(Color(hex: hex), lineWidth: 2).padding(-5)
                        : nil
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#0B0B0F"))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture { selectedColorIndex = index }
    }

    private func createProfile() {
        isLoading = true
        let api = authManager.apiClient()
        let hex = DS.avatarPaletteHex[selectedColorIndex]
        Task {
            do {
                let user: UserProfile = try await api.post(
                    "/users",
                    body: ["name": name, "avatarColor": hex]
                )
                await MainActor.run { authManager.profileCreated(user: user) }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
