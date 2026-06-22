# PRODUCT.md — DigDug

## Register
Product. DigDug is a native macOS SwiftUI app: a floating, always-on-top chat panel that talks to a local Ollama model. Design serves the task (ask, read, copy), it does not sell.

## Users & Purpose
A developer (the author) who keeps DigDug floating over VS Code and other apps. They summon it, ask a question, read a markdown/code answer, copy from it, and dismiss. Speed and readability of model output (especially code blocks) are the whole job.

## Brand & Personality
Three words: focused, premium, confident. The "dig" theme (excavation, unearthing answers) is carried by the icon and accent, not by decoration. Reference bar: Raycast, Linear, the macOS-native feel of well-built menu-bar tools.

## Anti-references
- Generic SwiftUI default chrome (plain TextField + Send button, flat gray bubbles).
- ChatGPT/Discord clones.
- Toy-like rounded everything with no hierarchy.

## Strategic design principles
- Output legibility first: large, comfortable body text; code blocks that read like an editor.
- One accent, used for the user's voice + primary action + active state only.
- Native macOS materials and vibrancy; respect light/dark.
- Compact chrome, generous content. The panel is small; every pixel serves the conversation.
- Safety is reviewed in context: multi-file plans show exact mappings and reasons in one dense native sheet, followed by a compact completion or rollback report.
