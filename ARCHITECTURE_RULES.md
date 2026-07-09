### Architecture Rules

#### For context

- Currently alot of the codebase is in the process of being refactored so if there are any missalignments keep that in mind.

#### Runtime/Testing Entry

- Main.luau handles whether the environment is testing or not. If the environment is testing, avaliable runtime tests should be loaded from ServerScriptStorage\CompyAgent\Tests. If the environment is not testing the simulation will be loaded in.

- Simulation handles the setup of the environment and loading in of configuration values from ReplicatedStorage\CompyAgent\Config. Agents will be spawned in with the setup of the environment. Simulation responsibilities:
  - Load config.
  - Build the world/environment service.
  - Register spawn points, cover points, objectives, and world-query adapters.
  - Create team blackboards.
  - Spawn and register agents.
  - Start each `AgentRuntime`.
  - Update visualization and metrics.
  - Stop or reset a match.

- Runtime Test setup their own environment in a similar way to simulation and deconstruct their environment on completion

#### Agent Core

- Agents by themselves should be operate without any guidance. AgentController should be the main central script that manages how the agent reacts to the environment. Its responsibilities include:
  - Movement/Pathfinding using NoobPath Package decided by GOAP actions
  - Vision
  - Planning using GOAP
  - Combat decided by GOAP actions
  - Handle visuals of the agent like playing animations
  - Handle using tools like external gun frameworks

#### Blackboard Service

- Blackboard will be a shared memory space for agents of the same team.
- Agents will be able to read and write from the Blackboard
- Will contain information such as:
  - teammate positions
  - teammate death positions
  - assumed enemy location    -- noisy location of where the enemy is
  - confirmed enemy positions

#### EnvironmentService

- Registers world data on setup. Owns shared world data including:
  - Spawn points
  - Cover points
  - Objectives

#### Agent Service

- Main entry point for agent related tasks. Responsibilities include:
  - Registering agent runtimes.
  - Finding agents by id.
  - Listing team agents.
  - Listing enemy agents.
  - Broadcasting events to affected agents.

#### Visualization Service

- Observes state and renders it. Importantly it should not drive behavior.
- Responsible for providing debugging information for agents. For example creating billboardUI ontop of agents to display their goal, action, health, and ammo

#### Metrics Service

Records behavior and performance metrics. It should not control agents