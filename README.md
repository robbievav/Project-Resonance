# Project: Resonance

A first-person procedural horror game set in a sprawling, liminal 1990s research facility.

## Core Features
- **Procedural generation** — seed-based floor layouts with 10 room types across 50 floors
- **The Decibel AI** — a blind entity that hunts by sound, scales in difficulty per floor
- **Diegetic UI** — no HUD; health shown via blur, breathing, heartbeat
- **VHS aesthetic** — scanlines, rolling interference, washed-out colors
- **Dynamic audio** — soundtrack fades to silence as danger approaches
- **Atmospheric stealth** — crouch, walk, sprint affect noise levels
- **Hiding system** — duck into lockers, under desks, or behind stalls with a breathing mini-game
- **Lazy floor loading** — only nearby floors stay loaded for performance
- **Floor themes** — deeper floors grow darker and more deteriorated

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
│   ├── DoorSystem.server.lua
│   └── HidingSystem.server.lua
├── client/          → StarterPlayerScripts
│   ├── FirstPersonController.client.lua
│   ├── DiegeticHealth.client.lua
│   ├── FootstepSystem.client.lua
│   ├── AtmosphereController.client.lua
│   ├── DynamicAudio.client.lua
│   └── HidingSystem.client.lua
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
| E (ProximityPrompt) | Interact with doors / Hide |
| Space | Steady breathing (while hiding) |
| E / Backspace | Exit hiding spot |

## Room Types
| Room | Description |
|------|-------------|
| Hallway | Long corridor, flickering fluorescents |
| Office | Desks, filing cabinets, water coolers |
| Maintenance Tunnel | Narrow, dark, pipes along ceiling |
| Observation Deck | Consoles, windows, monitor banks |
| Safe Hub | Well-lit, locked door, cot, med kit |
| Storage Room | Shelves, crates, barrels |
| Laboratory | Lab benches, beakers, glass surfaces |
| Bathroom | Tiled floors, stall partitions, sinks |
| Server Room | Tall racks, blue LEDs, cables |
| Stairwell | Spiral staircase connecting floors |

## Floor Themes
| Floors | Theme | Description |
|--------|-------|-------------|
| 1–10 | Clean Office | Bright lighting, standard colors |
| 11–25 | Deteriorating | Dimmer, muted palette |
| 26–40 | Industrial | Dark, heavy materials, minimal light |
| 41–50 | Abandoned | Near-black, decayed surfaces |