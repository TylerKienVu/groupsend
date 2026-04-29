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

## Package installs (mobile)

When a package install fails due to Clerk's peer dep conflict and requires `--legacy-peer-deps`, first check `mobile/node_modules/expo/bundledNativeModules.json` to confirm the Expo SDK 54-expected version before installing. This prevents version drift (e.g. pulling in SDK 55 packages into an SDK 54 project).
