# IOSRaiderIO

A SwiftUI app for iPhone and iPad that shows what talents the best World of Warcraft Mythic+ players use.

Pick a class and spec, and the app loads the top players of that spec from the
[Raider.IO](https://raider.io) leaderboard. It then reads each player's talents and builds a
"popular build" from how often each talent is picked.

## Features

- **Classes**: every class and spec, with the top players of the current Mythic+ season by region (World, EU, US, KR, TW).
- **Popular build**: talent pick rates across the top players, drawn on the full talent tree.
- **Player details**: a player's current talents, M+ score and best keys.
- **Favorites**: saved players, kept between launches.
- **Settings**: leaderboard region, dark mode, language (English, Čeština, Русский).
- Liquid Glass look on iOS 26+, with a material fallback on iOS 17–25.

## Data sources

No API keys are needed.

- Raider.IO public API: season data, spec leaderboards, character profiles.
- Raidbots static data: full talent trees (`talents.json`).

Requests are limited to 3 at a time. After an HTTP 429 the app backs off and retries.

## Project layout

```
IOSRaiderIO/
├── IOSRaiderIO/
│   ├── Models/           Decodable API models and app types
│   ├── Networking/       RaiderIOClient protocol, live client, request limiter, errors
│   ├── Store/            BuildStore (the single @Observable model), favorites, pick-rate aggregation
│   ├── Views/            Screens and reusable components
│   ├── Resources/        classes.json (class/spec catalog)
│   ├── PreviewFixtures/  Saved API responses for #Preview and tests (excluded from Release builds)
│   └── Localizable.xcstrings
└── MyAppTests/           Swift Testing unit tests (decoding, BuildStore, pick rates)
```

## Requirements

- Xcode 27 or later (the project uses the Xcode 27 project format)
- iOS / iPadOS 17.0 or later

Open `IOSRaiderIO/IOSRaiderIO.xcodeproj`, choose the **IOSRaiderIO** scheme and run.
Run the tests with ⌘U. They use the JSON fixtures and never touch the network.
