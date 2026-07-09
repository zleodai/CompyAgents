export type AgentConfig = {
	MaxHealth: number,
	MaxAmmo: number,
	ThinkInterval: number,
	VisionInterval: number,
	BlackboardUpdateInterval: number,
	InfoBar: boolean,
	DebugRaycast: boolean,
	DebugTracers: boolean,
	DebugLog: boolean,
	WalkSpeed: number,
	ModelFolderName: string,
	RootPartSize: Vector3,
	HeadSize: Vector3,
	HeadOffset: Vector3,
	HipHeight: number,
	DebugTransparency: number,
}

export type CombatConfig = {
	Range: number,
	Damage: number,
	ReloadTime: number,
	ShotCooldown: number,
	RequiredAimDot: number,
	TurnRateRadiansPerSecond: number,
}

export type NoobPathAgentParams = {
	AgentRadius: number,
	AgentHeight: number,
	AgentCanJump: boolean,
	AgentCanClimb: boolean,
	WaypointSpacing: number,
	Costs: { [string]: number },
	PathSettings: {
		SupportPartialPath: boolean,
	},
}

export type NoobPathConfig = {
	Enabled: boolean,
	Precise: boolean,
	Timeout: boolean,
	Visualize: boolean,
	AgentParams: NoobPathAgentParams,
}

export type SimulationConfig = {
	DemoAgentsPerTeam: number,
	TargetAgentsPerTeam: number,
	UseStudioLevel: boolean,
	UseConfigSpawnsFallback: boolean,
	SpawnTag: string,
	CoverTag: string,
	ObjectiveTag: string,
	HumanoidTag: string,
	VisualizationInterval: number,
	MetricsInterval: number,
}

export type TeamConfig = {
	Color: Color3,
	SpawnOrigin: Vector3,
	SpawnSpacing: number,
	Forward: Vector3,
}

export type TestConfig = {
	Enabled: boolean,
	Verbose: boolean,
	FailFast: boolean,
}

export type Config = {
	Agent: AgentConfig,
	Combat: CombatConfig,
	NoobPath: NoobPathConfig,
	Simulation: SimulationConfig,
	Teams: { [string]: TeamConfig },
	Tests: TestConfig,
}

export type FactValue = boolean | number | string
export type FactMap = { [string]: FactValue }

export type GOAPActionContext = {
	dt: number,
	now: number,
}

export type GOAPAction = {
	id: string,
	cost: number?,
	preconditions: FactMap,
	effects: FactMap,
	start: ((AgentController, GOAPActionContext) -> ())?,
	update: ((AgentController, GOAPActionContext) -> ())?,
	check: ((AgentController, GOAPActionContext) -> boolean)?,
	finish: ((AgentController, GOAPActionContext) -> ())?,
}

export type GOAPGoal = {
	id: string,
	priority: number,
	facts: FactMap,
}

export type GOAPGoalDefinition = {
	id: string,
	check: (AgentState, BlackboardStore, FactMap) -> boolean,
	priority: (AgentState, BlackboardStore, FactMap) -> number,
	facts: (AgentState, BlackboardStore, FactMap) -> FactMap,
}

export type PlannerOptions = {
	MaxExpansions: number?,
	MaxPlanDepth: number?,
}

export type PlannerNode = {
	facts: FactMap,
	plan: { GOAPAction },
	cost: number,
}

export type PlanResult = {
	success: boolean,
	actions: { GOAPAction }?,
	cost: number?,
	expansions: number,
	reason: string?,
}

export type PerceptionContact = {
	agentId: string,
	position: Vector3,
	confidence: number,
	lastSeenAt: number,
}

export type AgentState = {
	id: string,
	teamId: string,
	alive: boolean,
	health: number,
	ammo: number,
	position: Vector3,
	facing: Vector3,
	model: Model?,
	humanoid: Humanoid?,
	rootPart: BasePart?,
	head: BasePart?,
	currentGoal: string?,
	currentActionId: string?,
	currentPlan: { GOAPAction }?,
	currentActionIndex: number,
	actionStarted: boolean,
	actionStartedAt: number,
	needsPlan: boolean,
	replanReason: string,
	visibleEnemies: { PerceptionContact },
	knownEnemies: { [string]: PerceptionContact },
	inCover: boolean,
	destination: Vector3?,
	moving: boolean,
	arrived: boolean,
	targetId: string?,
	toReload: boolean,
	reloadEndTime: number,
	reloading: boolean,
	shotCompleted: boolean,
	lastShotAt: number,
	lastShotOrigin: Vector3?,
	lastShotTarget: Vector3?,
	lastRaycastAt: number,
	lastRaycastOrigin: Vector3?,
	lastRaycastEnd: Vector3?,
	debugGoal: string,
	debugAction: string,
	inDepthDebugUIActive: boolean,
	inDepthDebugUIText: string,
}

export type AgentEvent = {
	kind: string,
	at: number?,
	amount: number?,
	attackerId: string?,
	agentId: string?,
	targetId: string?,
	position: Vector3?,
	reason: string?,
}

export type EnemySighting = {
	agentId: string,
	position: Vector3,
	confidence: number,
	confirmed: boolean,
	lastSeenAt: number,
}

export type TeammatePosition = {
	agentId: string,
	position: Vector3,
	updatedAt: number,
}

export type TeammateDeath = {
	agentId: string,
	position: Vector3,
	updatedAt: number,
}

export type ReservationRecord = {
	resourceId: string,
	ownerId: string,
	expiresAt: number,
}

export type IntentRecord = {
	ownerId: string,
	intent: IntentData,
	updatedAt: number,
	expiresAt: number,
}

export type IntentData = {
	kind: string,
	data: { [string]: FactValue },
}

export type BlackboardStore = {
	teamId: string,
	teammatePositions: { [string]: TeammatePosition },
	teammateDeaths: { [string]: TeammateDeath },
	assumedEnemyLocations: { [string]: EnemySighting },
	confirmedEnemyPositions: { [string]: EnemySighting },
	enemySightings: { [string]: EnemySighting },
	intents: { [string]: IntentRecord },
	reservations: { [string]: ReservationRecord },
	RecordTeammatePosition: (BlackboardStore, string, Vector3, number) -> (),
	RecordTeammateDeath: (BlackboardStore, string, Vector3, number) -> (),
	RecordEnemySighting: (BlackboardStore, string, Vector3, number, boolean, number) -> (),
	GetBestEnemySighting: (BlackboardStore) -> EnemySighting?,
	Reserve: (BlackboardStore, string, string, number, number) -> boolean,
	ReleaseReservation: (BlackboardStore, string, string) -> (),
	PublishIntent: (BlackboardStore, string, IntentData, number, number) -> (),
	Cleanup: (BlackboardStore, number) -> (),
}

export type SpawnPoint = {
	name: string,
	teamId: string?,
	cframe: CFrame,
	position: Vector3,
	facing: Vector3,
	spawnOrder: number,
	spawnRadius: number,
}

export type CoverPoint = {
	name: string,
	teamId: string?,
	position: Vector3,
}

export type ObjectivePoint = {
	name: string,
	teamId: string?,
	position: Vector3,
}

export type EnvironmentService = {
	config: Config,
	spawnPoints: { SpawnPoint },
	coverPoints: { CoverPoint },
	objectives: { ObjectivePoint },
	Refresh: (EnvironmentService) -> (),
	GetSpawnCFrame: (EnvironmentService, string, number) -> CFrame,
	GetNearestCover: (EnvironmentService, Vector3, string) -> Vector3?,
	ClampDestination: (EnvironmentService, Vector3) -> Vector3,
	RaycastLineOfSight: (EnvironmentService, Vector3, Vector3, { Instance }?) -> (boolean, Vector3),
	HasLineOfSight: (EnvironmentService, Vector3, Vector3, { Instance }?) -> boolean,
}

export type AgentService = {
	runtimes: { [string]: AgentRuntime },
	runtimeOrder: { AgentRuntime },
	activeInDepthDebugAgentId: string?,
	inDepthDebugTextRemote: RemoteFunction?,
	inDepthDebugActiveRemote: RemoteEvent?,
	inDepthDebugActiveConnection: RBXScriptConnection?,
	Register: (AgentService, AgentRuntime) -> (),
	GetRuntime: (AgentService, string) -> AgentRuntime?,
	GetState: (AgentService, string) -> AgentState?,
	GetAllRuntimes: (AgentService) -> { AgentRuntime },
	GetTeamStates: (AgentService, string) -> { AgentState },
	GetEnemyStates: (AgentService, string) -> { AgentState },
	BroadcastToTeam: (AgentService, string, AgentEvent) -> (),
	SetInDepthDebugUIActive: (AgentService, string, boolean) -> (),
	GetInDepthDebugUIText: (AgentService, string) -> string,
	BindDebugRemotes: (AgentService) -> (),
	UnbindDebugRemotes: (AgentService) -> (),
}

export type AgentModelFactory = {
	config: Config,
	Create: (AgentModelFactory, AgentState, CFrame) -> Model,
}

export type AgentModelStore = {
	config: Config,
	factory: AgentModelFactory,
	models: { [string]: Model },
	CreateForAgent: (AgentModelStore, AgentState, CFrame) -> Model,
	GetModel: (AgentModelStore, string) -> Model?,
	HideModel: (AgentModelStore, string) -> (),
	DestroyAll: (AgentModelStore) -> (),
}

export type AgentMailbox = {
	events: { AgentEvent },
	Push: (AgentMailbox, AgentEvent) -> (),
	Drain: (AgentMailbox) -> { AgentEvent },
}

export type AgentMemory = {
	knownEnemies: { [string]: PerceptionContact },
	RememberEnemy: (AgentMemory, string, Vector3, number, number) -> (),
	GetBestKnownEnemy: (AgentMemory) -> PerceptionContact?,
}

export type BlackboardClient = {
	state: AgentState,
	blackboard: BlackboardStore,
	PublishPosition: (BlackboardClient, number) -> (),
	PublishDeath: (BlackboardClient, number) -> (),
	PublishEnemySighting: (BlackboardClient, string, Vector3, number, boolean, number) -> (),
	PublishIntent: (BlackboardClient, string, { [string]: FactValue }, number) -> (),
	Reserve: (BlackboardClient, string, number, number) -> boolean,
	Cleanup: (BlackboardClient, number) -> (),
}

export type VisionController = {
	runtime: AgentRuntime,
	state: AgentState,
	config: Config,
	environment: EnvironmentService,
	agentService: AgentService,
	memory: AgentMemory,
	blackboardClient: BlackboardClient,
	nextSenseAt: number,
	Sense: (VisionController, number) -> (),
	Tick: (VisionController, number) -> (),
}

export type NoobPathAgent = {
	Timeout: boolean,
	Speed: number,
	Visualize: boolean,
	Run: (NoobPathAgent, Vector3) -> (),
	Stop: (NoobPathAgent) -> (),
	Destroy: (NoobPathAgent) -> (),
	Reached: RBXScriptSignal,
	Trapped: RBXScriptSignal,
	Error: RBXScriptSignal,
}

export type MovementController = {
	runtime: AgentRuntime,
	state: AgentState,
	config: Config,
	pathAgent: NoobPathAgent?,
	lastDestination: Vector3?,
	connections: { RBXScriptConnection },
	SetDestination: (MovementController, Vector3) -> (),
	Stop: (MovementController) -> (),
	Tick: (MovementController, number) -> (),
	Destroy: (MovementController) -> (),
}

export type CombatController = {
	runtime: AgentRuntime,
	state: AgentState,
	config: Config,
	environment: EnvironmentService,
	agentService: AgentService,
	ShootAtTarget: (CombatController, string) -> (),
	StopShooting: (CombatController) -> (),
	Tick: (CombatController, number) -> (),
}

export type PlannerController = {
	runtime: AgentRuntime,
	state: AgentState,
	blackboard: BlackboardStore,
	environment: EnvironmentService,
	controller: AgentController,
	ClearPlan: (PlannerController) -> (),
	RequestReplan: (PlannerController, string) -> (),
	Replan: (PlannerController, number) -> boolean,
	GetCurrentAction: (PlannerController) -> GOAPAction?,
	Advance: (PlannerController, number) -> (),
	Tick: (PlannerController, number, number) -> (),
}

export type AgentController = {
	runtime: AgentRuntime,
	state: AgentState,
	config: Config,
	blackboard: BlackboardStore,
	environment: EnvironmentService,
	memory: AgentMemory,
	movement: MovementController,
	combat: CombatController,
	planner: PlannerController?,
	RequestPlan: (AgentController, string) -> (),
	ClearPlan: (AgentController) -> (),
	Kill: (AgentController) -> (),
	Reload: (AgentController) -> (),
	MoveTo: (AgentController, Vector3) -> (),
	StopMovement: (AgentController) -> (),
	MoveForAction: (AgentController, string) -> (),
	LookAtPosition: (AgentController, Vector3, number) -> (),
	ShootAtTarget: (AgentController, string) -> (),
	StopShooting: (AgentController) -> (),
	SetInCover: (AgentController, boolean) -> (),
	GetBestVisibleEnemy: (AgentController) -> PerceptionContact?,
	GetBestKnownEnemyPosition: (AgentController) -> Vector3?,
	HasReachedDestination: (AgentController) -> boolean,
	HasCompletedShot: (AgentController) -> boolean,
	HasCompletedReload: (AgentController) -> boolean,
	GetActionElapsed: (AgentController, number) -> number,
}

export type AgentRuntimeDeps = {
	config: Config,
	state: AgentState,
	blackboard: BlackboardStore,
	environment: EnvironmentService,
	agentService: AgentService,
	modelStore: AgentModelStore,
}

export type AgentRuntime = {
	config: Config,
	state: AgentState,
	blackboard: BlackboardStore,
	environment: EnvironmentService,
	agentService: AgentService,
	modelStore: AgentModelStore,
	mailbox: AgentMailbox,
	memory: AgentMemory,
	blackboardClient: BlackboardClient,
	movement: MovementController,
	combat: CombatController,
	controller: AgentController,
	planner: PlannerController,
	vision: VisionController,
	running: boolean,
	thread: thread?,
	Start: (AgentRuntime) -> (),
	Stop: (AgentRuntime) -> (),
	PushEvent: (AgentRuntime, AgentEvent) -> (),
	RequestReplan: (AgentRuntime, string) -> (),
	TakeDamage: (AgentRuntime, number, string) -> (),
	Kill: (AgentRuntime) -> (),
	TickBehavior: (AgentRuntime, number, number) -> (),
}

export type VisualizationService = {
	config: Config,
	agentService: AgentService,
	running: boolean,
	thread: thread?,
	debugFolder: Folder?,
	raycastLines: { [string]: BasePart },
	tracerLines: { [string]: BasePart },
	Start: (VisualizationService) -> (),
	Stop: (VisualizationService) -> (),
}

export type MetricsSample = {
	totalAgents: number,
	aliveAgents: number,
	sampledAt: number,
}

export type MetricsService = {
	config: Config,
	agentService: AgentService,
	running: boolean,
	thread: thread?,
	heartbeatConnection: RBXScriptConnection?,
	frameSamples: { number },
	frameSampleIndex: number,
	frameSampleTotal: number,
	averageFrameMS: number,
	lastSample: MetricsSample,
	Start: (MetricsService) -> (),
	Stop: (MetricsService) -> (),
	GetAverageFrameMS: (MetricsService) -> number,
}

export type Simulation = {
	config: Config,
	started: boolean,
	blackboards: { [string]: BlackboardStore },
	runtimes: { AgentRuntime },
	environment: EnvironmentService,
	agentService: AgentService,
	modelStore: AgentModelStore,
	visualization: VisualizationService,
	metrics: MetricsService,
	debugAverageFrameMSRemote: RemoteFunction?,
	Start: (Simulation) -> (),
	Stop: (Simulation) -> (),
}

export type TestValue = boolean | number | string | nil

export type TestContext = {
	Assert: (boolean, string) -> (),
	AssertEqual: (TestValue, TestValue, string) -> (),
}

export type TestCase = {
	name: string,
	run: (TestContext) -> (),
}

export type TestSummary = {
	total: number,
	failed: number,
}

return {}
