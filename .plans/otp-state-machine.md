# Plan: OTP State Machine + Loading Feedback

Source: `/Users/tylervu/Downloads/GroupSend_extracted/design_handoff_otp_loading/`
Target: `mobile/GroupSend/Auth/OtpView.swift` + `mobile/GroupSend/Core/DesignSystem.swift`

Link to designs: https://api.anthropic.com/v1/design/h/cN7PvHALRhzB213ajbnDQA?open_file=index.html

---

## Context

The existing `OtpView.swift` is a static screen — cells show digits, verify is called silently,
and errors drop a plain red text block below. The design handoff replaces this with a 4-state
component that gives users real-time feedback at every step of verification.

Nothing outside these two files changes.

---

## Architecture decision: no ViewModel

State is local to one screen and shared nowhere else. A ViewModel would add indirection
without benefit. The idiomatic iOS 17 approach for a self-contained screen is `@State` +
private sub-view structs in the same file.

To manage the file's size without scattering layout across multiple files, we extract
`OTPDigitCell` and `OTPCaptionRow` as `private struct`s at the bottom of `OtpView.swift`.
They are `private` so they don't appear in the module namespace; they live in the same file
so the state machine logic stays co-located.

---

## Files to change

| File                                       | Type of change                                       |
| ------------------------------------------ | ---------------------------------------------------- |
| `mobile/GroupSend/Core/DesignSystem.swift` | Add two semantic color aliases                       |
| `mobile/GroupSend/Auth/OtpView.swift`      | Rewrite: add state machine, private sub-view structs |

---

## File layout of OtpView.swift after the change

```
OtpView.swift
  ├── OTPState                (private enum)
  ├── ShakeEffect             (private GeometryEffect struct)
  ├── OtpView                 (the screen — state, body, async logic)
  ├── OTPDigitCell            (private View struct — one cell, all 4 visual states)
  └── OTPCaptionRow           (private View struct — caption + subline, all 4 states)
```

---

## Step 1 — Add semantic colors to DesignSystem.swift

Add below the `accent`/`accentInk` block:

```swift
static let success = Color(hex: "#3CC36A") // V3 green — verification OK
static let error   = Color(hex: "#FF4D6D") // V6 red   — verification failed
```

These values already exist in `vGrades` (indices 3 and 6). We're adding semantic names
so auth code says `DS.success`/`DS.error` rather than reaching into a grade-difficulty array.

---

## Step 2 — OTPState enum

Private enum at the top of OtpView.swift:

```swift
private enum OTPState { case entering, verifying, success, error }
```

Single source of truth. Every visual — cell color, caption content, animation — is derived
from this value. No separate `isLoading: Bool` or `errorMessage: String?`.

---

## Step 3 — ShakeEffect geometry effect

Private struct just below the enum:

```swift
private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = animatableData - animatableData.rounded(.down)
        let x = sin(t * .pi * 6) * 6 * max(0, 1 - t)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
```

> **Why:** `animatableData` increments (0→1, 1→2, …) so SwiftUI produces a fresh animation each retry.
> The envelope `max(0, 1 - animatableData)` collapses to 0 for any value ≥ 1, silently killing the shake on retry 2+.
> Using the fractional part `t = animatableData - floor(animatableData)` keeps the domain in [0, 1) on every retry.

SwiftUI animates `animatableData` from 0 → 1 via `.linear(duration: 0.5)`.
`effectValue` is called each frame, computing a horizontal offset that traces a
decaying sine wave (~3 oscillations, amplitude 6pt, fades to 0). Applied to the
digit row `HStack` via `.modifier(ShakeEffect(animatableData: shakeAmount))`.

---

## Step 4 — OtpView: @State properties

Remove `isLoading`, `errorMessage`, and `focusedIndex`. Replace with:

```swift
@State private var digits: [String] = Array(repeating: "", count: 6)
@State private var otpState: OTPState = .entering
@FocusState private var keyboardActive: Bool

// Animation drivers
@State private var isPulsing = false            // arms the pulse animation; flips true on verifying, false on exit
@State private var shakeAmount: CGFloat = 0    // drives error shake (0 → 1 per attempt)
@State private var successScale: CGFloat = 0.6 // drives success badge spring
@State private var successOpacity: Double = 0

@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

`@FocusState` and `@Environment` must live on the View — they can't move to a ViewModel.
`isPulsing` flips to `true` once when entering verifying; `.repeatForever` drives the animation from there. Flips to `false` when state exits verifying, snapping cells to rest via `.linear(duration: 0)`.
`shakeAmount` increments (not resets) so each retry produces a fresh animation naturally.

---

## Step 5 — OtpView: computed helpers

```swift
private var code: String { digits.joined() }
private var activeIndex: Int { digits.firstIndex(of: "") ?? 5 }
```

`activeIndex` is the first empty slot — the cell that shows the focus ring and caret.

---

## Step 6 — OtpView: body

The body is a `ZStack` with `DS.bg` + a `VStack`. Seven sections:

1. **Nav bar** — same visual as today; navigation pop via OS swipe (NavigationStack handles it)
2. **Copy block** — heading + "Sent to [phone]" subtitle (unchanged)
3. **Digit row** — `HStack` of 6 `OTPDigitCell` instances, wrapped in `.modifier(ShakeEffect(...))`:

```swift
HStack(spacing: 10) {
    ForEach(0..<6, id: \.self) { i in
        OTPDigitCell(
            digit: digits[i],
            index: i,
            activeIndex: activeIndex,
            otpState: otpState,
            isPulsing: isPulsing,
            reduceMotion: reduceMotion,
            onTap: { keyboardActive = true }
        )
    }
}
.modifier(ShakeEffect(animatableData: shakeAmount))
```
4. **Caption + subline** — `OTPCaptionRow` instance
5. **Spacer**
6. **Hidden TextField** — keyboard capture; binding blocks input in non-entering states:

```swift
TextField("", text: Binding(
    get: { code },
    set: { newValue in
        guard otpState == .entering else { return }
        let filtered = newValue.filter(\.isNumber)
        var newDigits = Array(repeating: "", count: 6)
        for (i, ch) in filtered.prefix(6).enumerated() {
            newDigits[i] = String(ch)
        }
        digits = newDigits
    }
))
.keyboardType(.numberPad)
.focused($keyboardActive)
.opacity(0)
.frame(width: 1, height: 1)
```

Modifiers on the body ZStack:

```swift
.navigationBarHidden(true)
.onAppear { keyboardActive = true }
.onChange(of: code) { _, newCode in
    if newCode.count == 6, otpState == .entering { startVerifying() }
}
.onChange(of: otpState) { _, newState in handleStateChange(newState) }
```

---

## Step 7 — OtpView: handleStateChange(\_:)

```swift
private func handleStateChange(_ state: OTPState) {
    switch state {
    case .entering:
        successScale = 0.6
        successOpacity = 0

    case .verifying:
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isPulsing = true
        }

    case .success:
        isPulsing = false
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            successScale = 1
            successOpacity = 1
        }

    case .error:
        isPulsing = false
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.5)) { shakeAmount += 1 }
    }
}
```

---

## Step 8 — OtpView: startVerifying()

```swift
private func startVerifying() {
    let capturedCode = code
    otpState = .verifying

    Task {
        do {
            try await clerkSignIn.verifyCode(capturedCode)
            guard let token = try await Clerk.shared.session?.getToken() else {
                throw URLError(.userAuthenticationRequired)
            }
            let profile = try await APIClient(token: token).getMe()

            await MainActor.run { otpState = .success }
            try? await Task.sleep(for: .milliseconds(600))  // best-effort hold; sign-in runs even if Task is cancelled
            await MainActor.run {
                authManager.signIn(token: token, hasProfile: profile != nil)
                if let profile { authManager.userLoaded(profile) }
            }

        } catch {
            if Clerk.shared.session != nil {
                try? await Clerk.shared.auth.signOut()
            }
            await MainActor.run { otpState = .error }
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                digits = Array(repeating: "", count: 6)
                otpState = .entering
                keyboardActive = true
            }
        }
    }
}
```

450ms error wait: the shake is 0.5s; we wait 450ms so the transition back to `entering`
overlaps the tail of the shake rather than waiting a full extra second after it ends.

---

## Step 9 — OTPDigitCell (private struct)

Receives everything it needs as init params — no state of its own.

```swift
private struct OTPDigitCell: View {
    let digit: String
    let index: Int
    let activeIndex: Int
    let otpState: OTPState
    let isPulsing: Bool
    let reduceMotion: Bool
    let onTap: () -> Void
}
```

Body is a `ZStack`:

- `RoundedRectangle` fill — `cellFill` computed var
- `RoundedRectangle` stroke — `cellBorder`/`cellBorderWidth` computed vars
- Content: orange caret (`Rectangle 2×24pt`) when `digit.isEmpty && index == activeIndex && otpState == .entering`, otherwise `Text(digit)` in `cellTextColor`

Modifiers on the ZStack:

```swift
.frame(width: 48, height: 60)
.shadow(color: cellShadow, radius: 8)
.offset(y: otpState == .verifying && isPulsing ? -3 : 0)
.animation(
    !reduceMotion && otpState == .verifying
        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(index) * 0.18)
        : .linear(duration: 0),
    value: isPulsing
)
.contentShape(Rectangle())
.onTapGesture(perform: onTap)
```

**Computed vars (on the struct, not the parent view):**

`cellFill`:

- `.success` → `DS.success.opacity(0.10)`
- `.error` → `DS.error.opacity(0.08)`
- default → `DS.surface`

`cellBorder`:

- `.entering` → `DS.accent` if active, `DS.borderStrong` if filled, `DS.border` if empty
- `.verifying` → `DS.accent` when `isPulsing`, else `DS.borderStrong`
- `.success` → `DS.success`
- `.error` → `DS.error`

`cellBorderWidth`:

- `.entering` and `index == activeIndex` → `2`
- everything else → `1`

`cellShadow`:

- `.entering` active → `DS.accent.opacity(0.2)`
- `.verifying` → `DS.accent.opacity(0.33)` when isPulsing, else `.clear`
- `.success` → `DS.success.opacity(0.33)`
- `.error` → `DS.error.opacity(0.4)`

`cellTextColor`:

- `.error` → `DS.error`
- default → `DS.text`

**How the pulse stagger works (React analogy):**
When `isPulsing` flips `false → true`, `.animation(value: isPulsing)` fires on each cell.
Each cell has a different `.delay(Double(index) * 0.18)`, so cell 0 starts at 0ms, cell 1 at
180ms, cell 5 at 900ms. The `.repeatForever(autoreverses: true)` then cycles each cell forever,
offset from its neighbors in time. The result is a left-to-right wave.

When `isPulsing` resets to `false` (state leaves verifying), the `.animation` modifier reads
`otpState != .verifying` and uses `.linear(duration: 0)` — the cells snap to offset 0 instantly.

---

## Step 10 — OTPCaptionRow (private struct)

```swift
private struct OTPCaptionRow: View {
    let otpState: OTPState
    let isPulsing: Bool
    let successScale: CGFloat
    let successOpacity: Double
    let reduceMotion: Bool
}
```

Body: a `VStack(spacing: 8)` containing:

1. **Caption HStack** — `frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)`

Use a `@ViewBuilder` computed var `captionContent` with a `switch` over `otpState` for exhaustiveness:

```swift
@ViewBuilder
private var captionContent: some View {
    switch otpState {
    case .entering:
        Text("Didn't get it?").foregroundColor(DS.textDim)
        Text("Resend in 0:42").foregroundColor(DS.accent).fontWeight(.medium)

    case .verifying:
        Text("Verifying").foregroundColor(DS.text)
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(DS.accent).frame(width: 4, height: 4)
                    .offset(y: isPulsing ? -2 : 0)
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18),
                        value: isPulsing
                    )
            }
        }

    case .success:
        ZStack {
            Circle().fill(DS.success).frame(width: 18, height: 18)
            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                .foregroundColor(DS.bg)
        }
        .scaleEffect(successScale).opacity(successOpacity)
        Text("Verified").foregroundColor(DS.success).fontWeight(.medium)

    case .error:
        Text("That code didn't match.").foregroundColor(DS.error).fontWeight(.medium)
        Spacer()
        Text("Resend").foregroundColor(DS.accent).fontWeight(.medium)
    }
}
```

> **Why switch over if blocks:** `OTPState` is a sealed enum. A `switch` is exhaustiveness-checked — adding a 5th case without updating this view is a compile error, not a silent blank render.

2. **Subline** — shown only in verifying state, no transition needed:

```swift
if otpState == .verifying {
    Text("Checking with carrier")
        .font(.system(size: 13))
        .foregroundColor(DS.textMute)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

Add `.accessibilityLiveRegion(.polite)` to the caption HStack so VoiceOver announces
state changes without the user having to navigate to the element.

`minHeight: 22` on the caption HStack prevents layout shifts — all state content fits in
22pt, so nothing below it jumps when the state changes.

---

## State transition diagram

```
                  ┌─────────────────────────────────────┐
                  │                                     │
                  ▼                                     │
            [entering]                                  │
         (default, on load)                             │
                  │                                     │
                  │  6th digit entered                  │
                  ▼                                     │
           [verifying]                                  │
         (API call in flight)                           │
                  │                                     │
        ┌─────────┴────────────┐                        │
        │ API ok               │ API error              │
        ▼                      ▼                        │
    [success]              [error]                      │
   (600ms hold)          (shake plays)                  │
        │                      │                        │
        │ authManager.signIn   │ 450ms wait             │
        ▼                      ▼                        │
  ContentView               [entering] ────────────────┘
  switches screen        (digits cleared,
                          keyboard refocused)
```

---

## What is not touched

- `PhoneEntryView.swift`
- `ProfileCreationView.swift`
- `AuthManager.swift`
- `APIClient.swift`
- `ContentView.swift`

---

## Test checklist (manual, in simulator)

- [ ] Screen opens with keyboard up, cell 0 has orange ring + caret
- [ ] Typing shifts orange ring + caret to next empty cell
- [ ] 6th digit fires verifying: cells pulse L→R in wave, caption shows "Verifying" + dots, "Checking with carrier" appears below
- [ ] Success path: cells go green, badge pops in, "Verified" appears, 600ms hold, ProfileCreationView slides in
- [ ] Error path: row shakes once, cells go red with red digits, "That code didn't match." + "Resend" appear, code clears, orange ring returns to cell 0
- [ ] Reduced motion: bad code → no shake, cells go red instantly; good code → no pulse/pop, cells go green instantly
