# GroupSend — Claude Instructions

## Teaching mode

This is a learning project. Tyler is a frontend engineer learning backend development.

**Before writing code:**
- Explain what you're about to build and why
- Cover the design decision and any meaningful alternatives
- Ask Tyler if he wants to attempt it himself first

**While writing code:**
- After creating a file, walk through it and explain non-obvious lines
- Point out where a decision was made and what the tradeoff was

**Pace:**
- Slow down. Understanding matters more than shipping speed.
- If Tyler asks "why did you do X", treat it as the most important question in the conversation.

## Swift / SwiftUI architecture (mobile)

The app targets **iOS 17** and uses modern Swift idioms. Follow these rules when writing or reviewing Swift code:

**State management**
- Use `@State` for local view state. Do not create `ObservableObject` ViewModels — that is the iOS 14 pattern and is superseded by `@Observable` (iOS 17).
- If shared, cross-view state is genuinely needed, use `@Observable` (not `ObservableObject` + `@Published` + `@StateObject`).
- For this project, most screens are self-contained — prefer local `@State` over a ViewModel unless state must cross view boundaries.

**View decomposition**
- When a view file gets large, extract sub-views as `private struct`s in the **same file**, not into separate files. This keeps related layout co-located without polluting the module namespace.
- Only create a new file for a view that is either reused in multiple places or has its own meaningful independent state.
- Do not extract sub-views into separate files just to reduce line count.

**Async logic**
- Keep `Task { }` blocks inside the View. There is no benefit to moving a single async function to a ViewModel when its state is entirely local to one screen.

**No ViewModels for single-screen logic**
- The ViewModel pattern is most justified when: state is shared across views, or logic needs to be unit-tested in isolation. For a self-contained screen, `@State` + private sub-view structs is the idiomatic choice.

## Package installs (mobile)

When a package install fails due to Clerk's peer dep conflict and requires `--legacy-peer-deps`, first check `mobile/node_modules/expo/bundledNativeModules.json` to confirm the Expo SDK 54-expected version before installing. This prevents version drift (e.g. pulling in SDK 55 packages into an SDK 54 project).
