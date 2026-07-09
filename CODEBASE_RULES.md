# CompyAgent Codebase Rules

These are the project and collaboration rules assigned during this Codex session for the CompyAgent research project.

## Collaboration Style

- Communicate directly, pragmatically, and with concrete technical reasoning.
- Keep updates concise while work is in progress.
- Prioritize planning unless implementation is explicitly requested.
- Respect the current scope and do not make file edits unless Leo asks for implementation or artifact creation.
- When asked for a review, lead with risks, bugs, behavioral regressions, missing tests, and archiectural missalignments before summaries.

## Project Scope

- CompyAgent is a Roblox/Luau research project focused on coordinated GOAP agents.
- The target demo is AI-vs-AI squad behavior, ideally scaling toward 20v20.
- No player controls are needed for the current scope.
- Humanoid models are to be used to represent the agents.
- The July 16 demo target is visible GOAP behavior, not ApproximateQ or MARL.
- ApproximateQ, MARL, or learned squad/subgoal assignment should remain stretch work after the GOAP 
plus blackboard baseline is stable.

## Style Guides

KEEP CODE SIMPLE AND READABLE
DO NOT WRITE EXTRA CODE WHEN UNNECESSARY

- Prefer absolute root requires in modules:

```[luau]
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)
```

- Do not use relative requires such as `require(script.Parent...)`.
- Do not define local type aliases like `type Agent = Types.Agent` outside `Types.luau`.
- Do not define redundant types like `type AgentId = number` or `type TeamId = string`
- Types should use Luau types and use type annotations

- Example of a Data Module:

```[luau]
local RifleData = {
    [Enums.Rifles.AK47] = {
        shotCooldown = 0.1,
        shotDamage = 20,
        ammoInMagazine = 30,
        reloadTime = 2.5,
        aimDownSightsTime = 0.2,
        accuracy = 0.7,
        inaccuracyDeviation = 20,
    },
    [Enums.Rifles.AK12] = {
        shotCooldown = 0.1,
        shotDamage = 20,
        ammoInMagazine = 30,
        reloadTime = 2,
        aimDownSightsTime = 0.1,
        accuracy = 0.8,
        inaccuracyDeviation = 20,
    },
}
export RifleData
```

- Example of an Enum:

```[luau]
Enums.Rifles = {
    AK47 = 1,
    [1] = "AK47",
    AK12 = 2,
    [2] = "AK12",
}
```

- Example of a Constructor:

```[luau]
function PathSystem.new(deps: Types.SystemDependencies): Types.PathSystem
    local self = setmetatable({}, PathSystem)
    self.config = deps.config
    self.agentStore = deps.agentStore
    self.worldQuery = deps.adapters.worldQuery
    self.pathProvider = deps.adapters.pathProvider
    self.movementDriver = deps.adapters.movementDriver
    self.queue = deps.queues.Pathing
    return self
end
```

## Repository Conventions

- The current workspace is `C:\Users\Leo\RobloxGameDev\CompyAgent`.
- Roblox server code lives under `Src\Server` and maps to `ServerScriptService\CompyAgent` through Rojo.
- Roblox replicated code lives under `Src\Shared` and maps to `ReplicatedStorage\CompyAgent` through Rojo.

- Types belong in Types.luau Src\Server\Core\Types.luau
- Data Modules belong in Src\Server\Data
- Enums belong in Src\Server\Core\Enums.luau
- Tests belong in Src\Server\Tests in a folder module
- Configs belong in Src\Shared\Config in a folder module

Example of a folder module:

```text
Config/
├── AgentConfig.luau/
├── TestConfig.luau/
├── SimulationConfig.luau/
├── TeamConfig.luau/
├── NoobPath.luau/
├── init.luau/
```

init.luau:

```[luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Config = {
    require(CompySharedScripts.Config.AgentConfig),
    require(CompySharedScripts.Config.TestConfig),
    require(CompySharedScripts.Config.SimulationConfig),
    require(CompySharedScripts.Config.TeamConfig),
    require(CompySharedScripts.Config.NoobPath),
}

return Config
```

## Test Rules

- Runtime tests should have custom configuration files that can be loaded in when that test is being ran
- Runtime tests should have proper construction and destructors to initalize and cleanup their testing environment.
- Keep in mind time cannot be sped up for runtime tests

## Validation Rules

- Prefer `rg` or `rg --files` for code search.
- Server-side CompyAgent work should be checked with Selene and Rojo when relevant.
- Remove temporary Rojo build artifacts after validation unless Leo asks to keep them.

## Figma and UML Rules

- The UML board is `CompyUML`.
- Use FigJam sections to keep generated diagrams grouped and tidy.
- Prefer editable FigJam shapes and connectors over a flat image export for UML diagrams.
- Follow the styling guide in the `Building blocks` section found in the UML board `CompyUML` when adding to or reading from the board
