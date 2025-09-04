## 🍎 FujiMoji for macOS

Type any emoji, text snippet, or media by name from anywhere on your Mac. FujiMoji is a lightweight menu bar app that listens for your trigger key, shows fast suggestions, and pastes the selected result directly into the active text field.

![FujiMoji demo](FujiMoji/Assets.xcassets/fujimoji-demo.gif)

### 📱 Download
- [Website](https://fujimoji.app)
- [Direct Download](https://github.com/RickLiu1203/FujiMoji/releases/download/v1.0/FujiMoji.dmg)

### ✨ Features
- **Type-by-name**: Enter tags between your capture keys to insert results, e.g. `3/heart/` → ❤️❤️❤️.
- **Smart suggestions**: Popup appears after 2+ characters with arrow-key navigation and Tab/Enter to confirm.
- **Custom content**: Map your own text snippets and media (images, GIFs) to tags.
- **Skin tones**: Pick a default skin tone.
- **Configurable keys**: Choose your start/end capture keys (defaults: `/` and `/`).
- **Privacy-first**: Runs fully locally. Requires macOS Input Monitoring to observe keystrokes.

### 🖱️ How It Works
- Configure and customize everything in the menu bar!
- Start typing in any app. Enter your chosen start key, the tag, then your end key (or tab/enter).
  - Example: `/pizza/`, `2/fire/`, `/smile/`
- After 2+ characters, a suggestion popup appears. Navigate with arrow keys, confirm with Tab or Enter, or finish by typing your end key. Esc and Space cancels.
- Place digits immediately before the start key to repeat the result: `3/party/`.
- You can set custom emojis, texts, and media through the menu. Adding favourites will move them to the top of the suggestions popup.
- You can set multi-line custom text by pressing Shift+Enter when in the editor text input.
- If replacement was unsuccessful, it is probably caused by application lag. Try again and it almost always will work!

### 🔑 Permissions (Input Monitoring)
FujiMoji needs Input Monitoring and Accessibility to detect your capture keys and typed tags.
- System Settings → Privacy & Security → Accessibility → enable FujiMoji → relaunch
- System Settings → Privacy & Security → Input Monitoring → enable FujiMoji → relaunch
- Or use the in-app prompts: `Open Settings` and `Relaunch App`

### 🛠️ Customization
- `Set Emojis` (⌘E): Manage emoji-to-tag mappings and aliases.
- `Set Custom Text` (⌘T): Map your own text snippets to tags.
- `Set Custom Media` (⌘M): Map images/GIFs to tags and paste them inline.
- `Show Suggestions`: Toggle suggestions popup visibility.
- `Start/End Capture Key`: Change your trigger keys.
- `Skin Tone`: Pick the default.

### 🧰 Build From Source
- **Requirements**: macOS 14.0+, Xcode 16+
- Open `FujiMoji.xcodeproj` in Xcode
- Select the `FujiMoji` scheme and Run
- The app lives in the menu bar

### 📦 Data & Files
- Default emoji/tag data is bundled under `FujiMoji/Defaults/` (e.g., `default.json`, `emoji_array.json`, `variant_emojis.json`).
- User edits are saved to your Documents as `user_emoji_mappings.json` and loaded automatically on launch.

### 📄 License
This project is licensed under the MIT License.

### 👨‍💻 Author
@RickLiu1203

---

<div>
  <p>Made with 💜 by Rick Liu</p>
</div>
