# Project: Resonance

A first-person procedural horror game set in a sprawling, liminal 1990s research facility.

## Core Features
- **Procedural generation** — seed-based floor layouts with 6 room types
- **The Decibel AI** — a blind entity that hunts by sound
- **Diegetic UI** — no HUD; health shown via blur, breathing, heartbeat
- **VHS aesthetic** — scanlines, rolling interference, washed-out colors
- **Dynamic audio** — soundtrack fades to silence as danger approaches
- **Atmospheric stealth** — crouch, walk, sprint affect noise levels

## Tech Stack
- **Roblox Studio** + **Rojo** for syncing
- Luau (Roblox Lua)

## Project Structure
```
src/
├── server/          → ServerScriptService
│   ├── MapGenerator.server.lua
│   ├── SoundEmitter.server.lua
│   ├── DecibelAI.server.lua
│   └── DoorSystem.server.lua
├── client/          → StarterPlayerScripts
│   ├── FirstPersonController.client.lua
│   ├── DiegeticHealth.client.lua
│   ├── FootstepSystem.client.lua
│   ├── AtmosphereController.client.lua
│   └── DynamicAudio.client.lua
└── shared/          → ReplicatedStorage.Shared
    ├── Config.lua
    └── RoomTemplates.lua
```

## Getting Started
1. Install [Rojo](https://rojo.space/) (v7.4+)
2. Run `rojo serve` in this directory
3. Open Roblox Studio → Plugins → Rojo → Connect
4. Press Play to test

## Controls
| Key | Action |
|-----|--------|
| WASD | Move |
| Shift | Sprint (loud) |
| Ctrl/C | Crouch (quiet) |
| E (ProximityPrompt) | Interact with doors |