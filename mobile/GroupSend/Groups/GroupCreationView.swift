import SwiftUI

struct GroupCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var name = ""
    @State private var gymName = ""
    @State private var vibe = ""
    @State private var selectedAccentIdx = 0
    @State private var isLoading = false

    // A curated subset of V-grade colors offered as the group's accent color.
    // This is purely cosmetic — it doesn't encode climbing ability.
    private let accentOptions: [(Color, String)] = [
        (DS.vGrades[3],  "#3CC36A"),
        (DS.vGrades[4],  "#3DA8FF"),
        (DS.vGrades[5],  "#B061FF"),
        (DS.vGrades[6],  "#FF4D6D"),
        (DS.vGrades[9],  "#FF9D2E"),
        (DS.vGrades[10], "#23E0C8"),
        (DS.accent,      "#FF7B3F"),
    ]

    private var canCreate: Bool { !name.isEmpty && !gymName.isEmpty && !isLoading }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Nav ─────────────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DS.text)
                            .frame(width: 36, height: 36)
                            .background(DS.surface2)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DS.border, lineWidth: 1))
                    }
                    Spacer()
                    Text("New crew")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.text)
                    Spacer()
                    Button { createGroup() } label: {
                        Text("Create")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(canCreate ? DS.accent : DS.textMute)
                    }
                    .disabled(!canCreate)
                    .frame(width: 56, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // ── Name ─────────────────────────────────────────
                        fieldBlock(label: "NAME") {
                            TextField("Crimps & Coffee", text: $name)
                                .font(.system(size: 17))
                                .foregroundColor(DS.text)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(DS.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.rMd)
                                        .stroke(DS.borderStrong, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.rMd))
                        }

                        // ── Home gym ──────────────────────────────────────
                        fieldBlock(label: "HOME GYM") {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 16))
                                    .foregroundColor(DS.textDim)
                                TextField("Dogpatch Boulders", text: $gymName)
                                    .font(.system(size: 17))
                                    .foregroundColor(DS.text)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(DS.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.rMd)
                                    .stroke(DS.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.rMd))

                            Text("One gym per group. Members can still log when they climb elsewhere.")
                                .font(.system(size: 12))
                                .foregroundColor(DS.textMute)
                                .padding(.leading, 4)
                                .padding(.top, 6)
                        }

                        // ── Vibe / description ────────────────────────────
                        fieldBlock(label: "VIBE", optional: true) {
                            TextField("Tuesday + Thursday after work…", text: $vibe, axis: .vertical)
                                .font(.system(size: 15))
                                .foregroundColor(vibe.isEmpty ? DS.textDim : DS.text)
                                .lineLimit(3...5)
                                .padding(14)
                                .frame(minHeight: 80, alignment: .topLeading)
                                .background(DS.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.rMd)
                                        .stroke(DS.border, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.rMd))
                        }

                        // ── Accent color picker ───────────────────────────
                        fieldBlock(label: "ACCENT") {
                            HStack(spacing: 8) {
                                ForEach(Array(accentOptions.enumerated()), id: \.offset) { idx, option in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(option.0)
                                            .overlay(
                                                idx == selectedAccentIdx
                                                    ? RoundedRectangle(cornerRadius: 10)
                                                        .stroke(DS.bg, lineWidth: 2.5)
                                                    : nil
                                            )
                                        if idx == selectedAccentIdx {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color(hex: "#0B0B0F"))
                                        }
                                    }
                                    .frame(height: 36)
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture { selectedAccentIdx = idx }
                                }
                            }
                        }

                        // ── Invite link info card ─────────────────────────
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "link")
                                .font(.system(size: 16))
                                .foregroundColor(DS.accent)
                                .frame(width: 32, height: 32)
                                .background(DS.surface3)
                                .clipShape(RoundedRectangle(cornerRadius: 9))

                            Text("After you create the crew, you'll get an invite link to share with your friends.")
                                .font(.system(size: 13))
                                .foregroundColor(DS.textDim)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(DS.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.rLg)
                                .stroke(DS.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // ── Helper for labelled field groups ─────────────────────────────────

    @ViewBuilder
    private func fieldBlock<Content: View>(
        label: String,
        optional: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DS.textDim)
                    .tracking(1)
                if optional {
                    Text("OPTIONAL")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(DS.textMute)
                        .tracking(1)
                }
            }
            content()
        }
    }

    // ── API call ──────────────────────────────────────────────────────────

    private func createGroup() {
        isLoading = true
        let api = authManager.apiClient()
        Task {
            do {
                struct Body: Encodable {
                    let name: String
                    let gymName: String
                    let description: String?
                }
                let _: GroupModel = try await api.post(
                    "/groups",
                    body: Body(name: name, gymName: gymName, description: vibe.isEmpty ? nil : vibe)
                )
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
