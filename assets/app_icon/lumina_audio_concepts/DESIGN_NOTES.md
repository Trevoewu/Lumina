# Lumina 音频 App 图标概念

日期：2026-07-23

状态：概念探索。当前 App 图标未被替换。

生成方式：Codex 内置 `image_gen`。

## 共同设计语言

- 品牌语义：`Lumina = 光`，并加入“声音 / 收听”的抽象线索。
- 内容范围：同时覆盖有声书和 Podcast，不绑定任何单一媒介。
- 色彩：深墨绿、Lumina 绿 `#1DB954`、柔和薄荷白。
- 约束：不使用书、麦克风、耳机、播放按钮、文字、3D 或预制圆角。
- 输出：四张 RGB PNG，均为 1024 × 1024。

## 候选方向

1. `01_luminous_pulse.png` — Luminous Pulse / 光脉
   - 发光核心与两层声音波纹。
   - “光 + 收听”的含义最直接，但也最接近通用音频符号。
2. `02_l_wave.png` — L-Wave / 光声 L
   - 将 Lumina 的首字母 L 与单次声波起伏合成一条连续带。
   - 与名称关联最强，缩小后轮廓也最稳定。
3. `03_audio_prism.png` — Audio Prism / 声音棱镜
   - 一束光经过圆形节点后展开为三条平静声波。
   - 概念最具叙事性，适合表达“内容转化为声音”。
4. `04_quiet_beacon.png` — Quiet Beacon / 静默信标
   - 竖直光源、断开的光环和极轻的波形缺口。
   - 图形最安静、最像独立品牌符号。

`overview.png` 的顺序为：左上 01、右上 02、左下 03、右下 04。

`small_size_check.png` 是四个方向缩至 96 px 后的辨识度检查。

## 完整生成提示词

### 01 — Luminous Pulse

```text
Use case: logo-brand
Asset type: production-ready mobile app icon concept for Lumina, an audio app for audiobooks and podcasts
Primary request: create Concept 1, “Luminous Pulse” — a restrained abstract symbol that merges a soft halo of light with two precise audio/broadcast arcs around a small luminous core; it should communicate illumination and listening at once, without depicting a literal book, microphone, headphones, or podcast glyph
Scene/backdrop: full-bleed square deep near-black green background, #08110E to #0F1E19, extremely subtle tonal depth only
Subject: one centered geometric mark: a compact off-white luminous core with two balanced emerald arcs, the negative space should feel calm and premium
Style/medium: clean vector-like brand mark, flat and minimal, editorial, highly polished, original
Composition/framing: centered; strong simple silhouette; generous safe area for iOS and Android icon masks; readable at 48 px; square artwork fills the canvas but do not draw a rounded-square container
Color palette: deep ink green, Lumina emerald #1DB954, pale mint/off-white #EFFFF4; maximum three main colors
Lighting/mood: quiet luminous presence, restrained, no flashy neon
Constraints: no text, no letters, no book, no pages, no microphone, no headphones, no human face, no play button, no equalizer bars, no decorative particles, no watermark, no mockup, no device frame, no bevel, no 3D, no glassmorphism, no pre-rounded corners; avoid excessive glow and gradients; one icon only
```

### 02 — L-Wave

```text
Use case: logo-brand
Asset type: production-ready mobile app icon concept for Lumina, an audio app for audiobooks and podcasts
Primary request: create Concept 2, “L-Wave” — a restrained custom geometric monogram for the name Lumina; form one unmistakable uppercase L from a single thick luminous ribbon, with the short foot of the L gently changing into one subtle audio-wave bend; the overall symbol should suggest both light and sound while remaining primarily a refined L
Scene/backdrop: full-bleed square deep near-black green background, #08110E to #0F1E19, almost flat
Subject: one centered large L-shaped brand mark, drawn as a continuous pale-mint and emerald ribbon with carefully rounded terminals and a single restrained wave inflection, no other symbols
Style/medium: clean vector-like logo mark, Swiss/editorial minimalism, geometric, calm, highly polished, original
Composition/framing: centered; bold silhouette; generous safe area for iOS and Android icon masks; readable at 48 px; square artwork fills the canvas but do not draw a rounded-square container
Color palette: deep ink green, Lumina emerald #1DB954, pale mint/off-white #EFFFF4; maximum three main colors
Lighting/mood: controlled luminous accent, premium and quiet
Constraints: the L must be recognizable without using font text; no written word, no extra letters, no book, no pages, no microphone, no headphones, no radio tower, no human face, no play button, no equalizer bars, no decorative particles, no watermark, no mockup, no device frame, no bevel, no 3D, no glassmorphism, no pre-rounded corners; avoid excessive glow and gradients; one icon only
```

### 03 — Audio Prism

```text
Use case: logo-brand
Asset type: production-ready mobile app icon concept for Lumina, an audio app for audiobooks and podcasts
Primary request: create Concept 3, “Audio Prism” — an abstract light-source mark where one narrow pale beam enters a minimal emerald circular aperture and exits as three calm curved wave bands; it should express Lumina turning content into audible light, without looking like a literal prism diagram or a media play button
Scene/backdrop: full-bleed square deep near-black green background, #08110E to #0F1E19, almost flat
Subject: one compact centered geometric mark built from a small circular aperture, a single straight light beam, and exactly three restrained curved output bands; asymmetrical but perfectly balanced
Style/medium: clean vector-like brand mark, flat, minimal, editorial, refined, highly polished, original
Composition/framing: centered; strong simple silhouette; generous safe area for iOS and Android icon masks; readable at 48 px; square artwork fills the canvas but do not draw a rounded-square container
Color palette: deep ink green, Lumina emerald #1DB954, pale mint/off-white #EFFFF4; maximum three main colors
Lighting/mood: intelligent, serene, quietly luminous
Constraints: no text, no letters, no book, no pages, no microphone, no headphones, no RSS icon, no radio tower, no human face, no triangular play button, no equalizer bars, no rainbow, no decorative particles, no watermark, no mockup, no device frame, no bevel, no 3D, no glassmorphism, no pre-rounded corners; avoid excessive glow and gradients; one icon only
```

小尺寸迭代：

```text
Use case: precise-object-edit
Asset type: mobile app icon refinement
Input images: Image 1: edit target, Lumina “Audio Prism” icon concept
Primary request: improve only small-size legibility of the existing central mark
Changes: enlarge the complete beam-aperture-wave symbol by about 22 percent while keeping it optically centered; make the pale incoming beam, emerald ring, and exactly three outgoing wave bands about 25 percent thicker; shorten the three outgoing bands slightly; round every terminal consistently; keep the asymmetrical concept and spacing calm and balanced
Constraints: preserve the exact deep ink-green background, palette, lighting restraint, flat vector-like style, composition concept, and all other visual decisions; no new elements; no text; no book; no microphone; no headphones; no play button; no mockup; no watermark; no 3D; no pre-rounded corners; one icon only
```

### 04 — Quiet Beacon

```text
Use case: logo-brand
Asset type: production-ready mobile app icon concept for Lumina, an audio app for audiobooks and podcasts
Primary request: create Concept 4, “Quiet Beacon” — a restrained abstract beacon of listening: a vertical pale-mint capsule as the light source, surrounded by one broken emerald halo whose lower opening resolves into a very subtle single waveform notch; the mark should feel like a quiet pool of light and a listening signal, not a literal broadcast logo
Scene/backdrop: full-bleed square deep near-black green background, #08110E to #0F1E19, almost flat
Subject: one centered compact geometric mark, a vertical luminous capsule within a broken circular halo, with only one subtle waveform-shaped interruption; use excellent negative space
Style/medium: clean vector-like brand mark, flat and minimal, modernist/editorial, calm, highly polished, original
Composition/framing: centered; strong simple silhouette; generous safe area for iOS and Android icon masks; readable at 48 px; square artwork fills the canvas but do not draw a rounded-square container
Color palette: deep ink green, Lumina emerald #1DB954, pale mint/off-white #EFFFF4; maximum three main colors
Lighting/mood: serene, warm intelligence, restrained luminosity
Constraints: no text, no letters, no book, no pages, no microphone, no headphones, no RSS icon, no radio tower, no human face, no play button, no equalizer bars, no decorative rays or particles, no watermark, no mockup, no device frame, no bevel, no 3D, no glassmorphism, no pre-rounded corners; avoid excessive glow and gradients; one icon only
```
