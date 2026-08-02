# CompyAgent Repository Guidance

## Scope and sources of truth

The Obsidian vault for this repository is `C:\Users\Leo\Documents\files\Obsiddy\CompyAgent`.

Use the live repository and the current documents linked below as the architecture baseline. Do not revive superseded controller/runtime scaffolds or the vault file `Depricated/Agent Architecture (DEPRICATED).canvas`.

When source and documentation disagree, inspect current call sites and runtime behavior before editing. Update the canonical document in the same task so the disagreement does not remain.

## Current architecture

- `Src/Server/Core/Simulation.luau` is the server composition and lifecycle owner. It uses and starts the module-global DebugService, AgentService, and EnvironmentService singletons, selects Agent teams and spawn placement, starts Agents, and shuts services down before caller-owned Agent/model teardown.
- `Src/Server/Agents/Agent.luau` owns one Agent's runtime state, controller reference, sensing outputs, inventory, planner module, cadence, and Heartbeat. It passes AgentService to VisionSensor; VisionSensor requires EnvironmentService directly. Module-global service singletons are allowed where they do not create require cycles.
- `Src/Server/Services/AgentService.luau` is a module-global singleton that requires shared Config directly. It constructs Agents, owns server-lifetime Agent ID generation, and maintains the live-Agent registry and cached-position broad phase. It owns registration indexes, retained team IDs, lifecycle listeners, and filtering registrations by team-ID equality. FOV filtering, raycasts, allegiance decisions beyond same/different team IDs, Agent destruction, and controller/model destruction belong to callers.
- `Src/Server/Services/EnvironmentService.luau` is a module-global singleton and the registry for Studio-authored spawn points, cover points, objectives, rooms, and doors. It requires shared Config directly and owns typed registry queries, room occupancy caching, and registered-instance listeners. Agent templates, Agent construction, spawn selection, and arbitrary Agent line-of-sight do not belong there.
- `Src/Server/Services/DebugService.luau` is a module-global singleton that requires shared Config and AgentService directly. It owns the in-depth debug remotes, selection state, and its Heartbeat listener; Simulation owns its Start/End lifecycle.
- `Src/Server/Integrations/Spearhead/SPHAgentFactory.luau` is the character/controller construction boundary. `Src/Server/Integrations/Spearhead/SPHController.luau` owns Spearhead movement, stance, animation, weapon, and combat control for that character.
- `Src/Server/GOAP/GOAPPlanner.luau`, `Src/Server/GOAP/Actions`, and `Src/Server/GOAP/Goals` form the GOAP layer. Keep action instances per Agent and keep service/world dependencies explicit through the Agent runtime.
- Internal server requires should start from `ServerScriptService.CompyAgent`. Shared requires should start from `ReplicatedStorage.CompyAgent`.

## Source-to-document map

| Repository source | Authoritative document | Maintenance rule |
| --- | --- | --- |
| `Src/Server/Core/Simulation.luau` | [Simulation.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/Simulation.md) | Keep service lifecycle order, spawn selection, Agent creation/startup, rollback, restart, and teardown semantics synchronized. |
| `Src/Server/Agents/Agent.luau` | [Agent.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/Agent.md) | Whenever the constructor, public API, AgentSharedData flow, dependency injection, team ownership, cadence, lifecycle, failure behavior, or disposal semantics change, update this document in the same task. |
| `Src/Server/Agents/Sensors/VisionSensor.luau` | [VisionSensor.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/VisionSensor.md) | Keep constructor dependencies, sensing outputs, noise, raycasts, filtering, failure behavior, and Agent cadence integration synchronized. |
| `Src/Server/Services/AgentService.luau` | [AgentService.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/AgentService.md) | Whenever the service is edited or refactored, update this usage document in the same task. Document every public method plus `Start`, `Update`, and `End`, including singleton ownership, server-lifetime ID generation, cadence, listener cleanup, and disposal semantics. |
| `Src/Server/Services/EnvironmentService.luau` | [EnvironmentService.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/EnvironmentService.md) | Whenever the service is edited or refactored, update this usage document in the same task. Document every public method plus `Start`, `Update`, and `End`, including singleton ownership, registry ownership, dynamic-instance listeners, cleanup, and disposal semantics. |
| `Src/Server/Services/DebugService.luau` | [DebugService.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/DebugService.md) | Whenever the service is edited or refactored, update this usage document in the same task. Document singleton/config ownership, every public method, remote callback ownership, restart behavior, and disposal semantics. |
| `Src/Server/Integrations/Spearhead/SPHAgentFactory.luau` | [SPHAgentFactory.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/SPHAgentFactory.md) | This is the actual construction factory represented by the user's “SPHControllerFactory” wording. Whenever its public API, configuration, template/team flow, ownership, rollback, or lifecycle behavior changes, update this document in the same task. |
| `Src/Server/Integrations/Spearhead/SPHController.luau` | [SPHController.md](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Docs/SPHController.md) | Whenever its public API, configuration, ownership rule, animation behavior, or lifecycle behavior changes, update this document in the same task. Never invent missing Spearhead animations. |
| `Src/Server/GOAP/GOAPPlanner.luau`, `Src/Server/GOAP/Actions`, and `Src/Server/GOAP/Goals` | [Architecture.canvas](C:/Users/Leo/Documents/files/Obsiddy/CompyAgent/Architecture.canvas) | Use this as the current GOAP design reference. Keep it synchronized when facts, actions, goals, planner relationships, or ownership materially change. |

`Src/Server/Agents/Agent.luau` and `Src/Server/Agents/Sensors/VisionSensor.luau` participate in both service integrations. Agent receives AgentService through construction; VisionSensor receives that reference from Agent and requires EnvironmentService directly.

## Repository practices

- Preserve unrelated uncommitted work. Never revert, overwrite, reformat, or delete changes outside the task.
- Keep construction-only types local. Share a type only when multiple modules genuinely consume the same runtime contract.
- Keep the project server-side, data-first, decentralized, and AI-vs-AI unless the user explicitly changes scope.
- Prefer semantic Studio registries, tags, attributes, and typed records over hardcoded map logic.
- Keep movement/path failure ownership in `SPHController`; higher-level Agent/GOAP code requests movement and reacts to the result.
- Use Roblox Studio MCP for hierarchy inspection, instance/property inspection, Luau diagnostics, playtesting, console output, and viewport screenshots when Studio verification is required.
- Run validation proportionate to the change. The normal baseline is `selene Src`, `rojo sourcemap default.project.json`, and `rojo build default.project.json -o <temporary-output>.rbxlx`, plus relevant Roblox-native Studio tests.

## NoobPath package preservation

A source copy of NoobPath is stored in the repository. Running `wally install` can remove `Packages/NoobPath`. If that happens and the package is absent, restore it from the repository copy without changing its behavior.
