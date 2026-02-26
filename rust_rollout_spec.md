# MPS Rust Rollout Specification

## 1. Current Ruby Implementation Analysis

### 1.1 Design Patterns Currently Used

| Pattern | Implementation | Assessment |
|---------|---------------|------------|
| **Module Namespace** | `module MPS { ... }` | Basic organization, no isolation |
| **Mixins/Traits** | `include Element` | No real interface enforcement |
| **Strategy** | Element classes (Task, Note, etc.) | Implicit, no trait bounds |
| **Factory** | `Engines::MPS.parse_mps_file_to_elments_hash` | Tightly coupled to StringScanner |
| **Registry** | `MPS::Elements.constants` | Runtime reflection (eval), fragile |
| **Configuration Object** | `Config` class | Simple but rigid |

### 1.2 Current Limitations

1. **No Type Safety**: Ruby dynamic typing - no compile-time guarantees
2. **No Plugin Architecture**: Hardcoded element types, cannot add AI agents at runtime
3. **No Event System**: Reminders are passive data only, no active notification mechanism
4. **No Async Support**: Synchronous file I/O blocks everything
5. **No Persistence Abstention**: Hardcoded YAML, cannot swap to SQLite/PostgreSQL
6. **Tight Coupling**: Parser (`Engine::MPS`) directly creates elements with `eval`
7. **No Query System**: Cannot filter/search elements efficiently
8. **No Error Hierarchy**: Catches generic `Exception`, no typed errors
9. **No Testing Infrastructure**: Minimal test coverage
10. **No Serialization Framework**: Cannot export to JSON/CSV/etc.

---

## 2. Rust Architecture Specification

### 2.1 Core Design Patterns

```
┌─────────────────────────────────────────────────────────────────┐
│                        APPLICATION LAYER                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ CLI (Clap)  │  │  REPL REPL  │  │  TUI (Ratratat)        │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
└─────────┼────────────────┼──────────────────────┼───────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER (Core)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    DOMAIN MODEL                           │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────┐  │  │
│  │  │  Task    │ │  Note    │ │ Reminder │ │  Log        │  │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬──────┘  │  │
│  │       └────────────┴────────────┴──────────────┘        │  │
│  │                          ▼                               │  │
│  │               ┌──────────────────┐                        │  │
│  │               │ Element (Trait)  │ ◄─── Super Trait      │  │
│  │               │ - id: Uuid       │                        │  │
│  │               │ - created_at     │                        │  │
│  │               │ - updated_at     │                        │  │
│  │               │ - metadata       │                        │  │
│  │               └──────────────────┘                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 AGGREGATE ROOT                            │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │              MpsFile (Aggregate)                    │ │  │
│  │  │  - id: DateStamp                                    │ │  │
│  │  │  - elements: Vec<Box<dyn Element>>                  │ │  │
│  │  │  - add_element(), remove_element(), query()        │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION SERVICES                         │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐  │
│  │ Parser Service │  │ Query Service  │  │ Export Service  │  │
│  └───────┬────────┘  └───────┬────────┘  └────────┬─────────┘  │
└──────────┼───────────────────┼─────────────────────┼───────────┘
           │                   │                     │
           ▼                   ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                         │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │ File Storage │  │   SQLite     │  │  AI Agent Plugin     │  │
│  │  (YAML/JSON) │  │  Repository  │  │  System (Plugin)     │  │
│  └──────────────┘  └──────────────┘  └───────────────────────┘  │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │ Notification │  │  Scheduler   │  │  Pluggable AI         │  │
│  │  Service     │  │  (Async)     │  │  Bridge               │  │
│  └──────────────┘  └──────────────┘  └───────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Architectural Patterns Used

| Pattern | Where Applied | Rationale |
|---------|--------------|-----------|
| **Domain-Driven Design** | Domain layer | Clear bounded contexts |
| **Aggregate Root** | `MpsFile` | Ensures consistency |
| **Trait Objects** | `Element` trait | Polymorphism for elements |
| **Repository Pattern** | `MpsRepository` trait | Storage abstraction |
| **Service Layer** | Parser, Query, Export | Business logic isolation |
| **Plugin Architecture** | AI Agent system | Extensibility |
| **Event Sourcing** | Notification system | Audit trail |
| **CQRS** | Query vs Command | Separation of concerns |
| **Builder Pattern** | Element creation | Fluent API |
| **Result/Either** | Error handling | Explicit error types |

---

## 3. Core Domain Model (Rust)

### 3.1 Element Trait (Super Trait)

```rust
/// Core trait all MPS elements must implement
pub trait Element: Send + Sync {
    fn id(&self) -> Uuid;
    fn element_type(&self) -> ElementType;
    fn body(&self) -> &str;
    fn tags(&self) -> &[String];
    fn metadata(&self) -> &ElementMetadata;
    fn created_at(&self) -> DateTime<Utc>;
    fn updated_at(&self) -> DateTime<Utc>;
    
    fn with_body(mut self: Box<Self>, body: String) -> Box<dyn Element>;
    fn with_tags(mut self: Box<Self>, tags: Vec<String>) -> Box<dyn Element>;
    fn with_metadata(mut self: Box<Self>, metadata: ElementMetadata) -> Box<dyn Element>;
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum ElementType {
    Task,
    Note,
    Reminder,
    Log,
    Mps,        // Nested MPS block
    Custom(String), // For plugin elements
}

#[derive(Clone, Debug, Default)]
pub struct ElementMetadata {
    pub priority: Option<Priority>,
    pub due_date: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub custom: HashMap<String, String>,
}
```

### 3.2 Concrete Element Types

```rust
// ╔═══════════════════════════════════════════════════════════════╗
// ║                     CONCRETE ELEMENTS                         ║
// ╚═══════════════════════════════════════════════════════════════╝

/// Task element - represents actionable items
pub struct Task {
    id: Uuid,
    body: String,
    tags: Vec<String>,
    metadata: ElementMetadata,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl Task {
    pub fn new(body: impl Into<String>) -> Self { ... }
    pub fn with_priority(mut self, priority: Priority) -> Self { ... }
    pub fn is_completed(&self) -> bool { ... }
    pub fn mark_completed(&mut self) { ... }
}

/// Note element - free-form information
pub struct Note {
    id: Uuid,
    body: String,
    tags: Vec<String>,
    metadata: ElementMetadata,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

/// Reminder element - time-based notification trigger
pub struct Reminder {
    id: Uuid,
    body: String,
    tags: Vec<String>,
    metadata: ElementMetadata,
    trigger_at: DateTime<Utc>,      // When to trigger
    repeat: Option<RepeatPattern>,   // Recurrence rule
    notification_channel: Channel,   // How to notify
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug)]
pub enum RepeatPattern {
    Daily,
    Weekly(DayOfWeek),
    Monthly(DayOfMonth),
    Custom(CronExpression),
}

/// Log element - time tracking
pub struct Log {
    id: Uuid,
    body: String,
    tags: Vec<String>,
    metadata: ElementMetadata,
    start_time: DateTime<Utc>,
    end_time: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl Log {
    pub fn start(body: impl Into<String>) -> Self { ... }
    pub fn stop(&mut self) { ... }
    pub fn duration(&self) -> Duration { ... }
}
```

### 3.3 Aggregate Root - MpsFile

```rust
/// MpsFile - Aggregate Root for daily MPS entries
pub struct MpsFile {
    id: MpsFileId,
    date: NaiveDate,
    elements: Vec<Box<dyn Element>>,
    version: u64,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl MpsFile {
    pub fn new(date: NaiveDate) -> Self { ... }
    
    // Command methods (mutating)
    pub fn add_element(&mut self, element: Box<dyn Element>) -> Result<(), MpsError> { ... }
    pub fn remove_element(&mut self, id: Uuid) -> Result<Box<dyn Element>, MpsError> { ... }
    pub fn update_element(&mut self, element: Box<dyn Element>) -> Result<(), MpsError> { ... }
    
    // Query methods (immutable)
    pub fn get_element(&self, id: Uuid) -> Option<&dyn Element> { ... }
    pub fn query(&self, filter: &ElementFilter) -> Vec<&dyn Element> { ... }
    pub fn tasks(&self) -> Vec<&Task> { ... }
    pub fn reminders(&self) -> Vec<&Reminder> { ... }
    pub fn logs(&self) -> Vec<&Log> { ... }
    
    // Serialization
    pub fn to_json(&self) -> String { ... }
    pub fn to_yaml(&self) -> String { ... }
    pub fn to_markdown(&self) -> String { ... }
    pub fn to_plain_text(&self) -> String { ... }
}

#[derive(Clone, Debug)]
pub struct MpsFileId(pub String); // Format: "YYYYMMDD.timestamp.mps"
```

---

## 4. Plugin Architecture for AI Agents

### 4.1 Plugin System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     PLUGIN SYSTEM ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     │
│   │  AI Agent   │     │ Notification│     │   Custom    │     │
│   │  Plugin A   │     │  Plugin B   │     │  Plugin C   │     │
│   └──────┬──────┘     └──────┬──────┘     └──────┬──────┘     │
│          │                    │                    │           │
│          └────────────────────┼────────────────────┘           │
│                               ▼                                 │
│                    ┌──────────────────┐                         │
│                    │  Plugin Manager  │                         │
│                    │  (PluginRegistry)│                         │
│                    └────────┬─────────┘                         │
│                             │                                   │
│                             ▼                                   │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                  PLUGIN TRAIT                            │  │
│   │  trait Plugin: Send + Sync {                            │  │
│   │      fn name(&self) -> &str;                            │  │
│   │      fn version(&self) -> &str;                         │  │
│   │      fn initialize(&self, ctx: &PluginContext)          │  │
│   │      fn on_event(&self, event: &PluginEvent)            │  │
│   │      fn capabilities(&self) -> PluginCapabilities;     │  │
│   │  }                                                      │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Plugin Trait Definition

```rust
/// Core plugin trait - all AI agents implement this
pub trait Plugin: Send + Sync {
    /// Unique plugin identifier
    fn name(&self) -> &str;
    
    /// Semantic version
    fn version(&self) -> &str;
    
    /// Human-readable description
    fn description(&self) -> &str;
    
    /// Initialize plugin with configuration
    fn initialize(&self, ctx: &PluginContext) -> Result<(), PluginError>;
    
    /// Handle events from MPS system
    fn on_event(&self, event: &PluginEvent) -> PluginResponse;
    
    /// Capabilities this plugin provides
    fn capabilities(&self) -> PluginCapabilities;
    
    /// Shutdown hook
    fn shutdown(&self) -> Result<(), PluginError>;
}

#[derive(Clone, Debug, Default)]
pub struct PluginCapabilities {
    pub ai_enabled: bool,
    pub notifications: bool,
    pub scheduled_tasks: bool,
    pub custom_elements: bool,
    pub export_formats: Vec<String>,
}

pub enum PluginEvent {
    ElementCreated { element: Box<dyn Element>, file: &MpsFile },
    ElementUpdated { element: Box<dyn Element>, file: &MpsFile },
    ElementDeleted { element_id: Uuid, file: &MpsFile },
    ReminderTriggered { reminder: &Reminder },
    TaskCompleted { task: &Task },
    LogStarted { log: &Log },
    LogEnded { log: &Log, duration: Duration },
}

pub enum PluginResponse {
    None,
    Action(PluginAction),
    Notification(PluginNotification),
    ModifiedElement(Box<dyn Element>),
    Error(String),
}
```

### 4.3 AI Agent Plugin Example

```rust
/// Example: AI Smart Reminder Agent
pub struct SmartReminderAgent {
    config: SmartReminderConfig,
    model: Option<Box<dyn LlmModel>>,
}

impl SmartReminderAgent {
    pub fn new(config: SmartReminderConfig) -> Self { ... }
    
    /// Analyze reminder and suggest optimal timing
    pub fn suggest_timing(&self, reminder: &Reminder) -> DateTime<Utc> { ... }
    
    /// Generate smart follow-up tasks
    pub fn suggest_followups(&self, completed_task: &Task) -> Vec<Task> { ... }
    
    /// Context-aware notification messages
    pub fn generate_message(&self, reminder: &Reminder, context: &MpsFile) -> String { ... }
}

/// AI LLM trait for model abstraction
pub trait LlmModel: Send + Sync {
    fn complete(&self, prompt: &str) -> Result<String, LlmError>;
    fn chat(&self, messages: &[ChatMessage]) -> Result<ChatMessage, LlmError>;
    fn embed(&self, text: &str) -> Result<Vec<f32>, EmbeddingError>;
}
```

---

## 5. Event & Notification System

### 5.1 Event Bus

```rust
/// Async event bus for inter-component communication
pub struct EventBus {
    subscribers: Arc<RwLock<HashMap<EventType, Vec<Subscription>>>>,
    runtime: Runtime,
}

impl EventBus {
    pub fn new() -> Self { ... }
    
    pub fn subscribe<F>(&mut self, event_type: EventType, handler: F) 
    where 
        F: Fn(Box<dyn Event>) -> Pin<Box<dyn Future<Output=()> + Send>> + Send + Sync + 'static
    { ... }
    
    pub async fn publish(&self, event: Box<dyn Event>) { ... }
}

pub trait Event: Send + Debug {
    fn event_type(&self) -> EventType;
    fn timestamp(&self) -> DateTime<Utc>;
    fn source(&self) -> EventSource;
}

pub enum EventType {
    ElementCreated,
    ElementUpdated,
    ElementDeleted,
    ReminderFired,
    TaskCompleted,
    LogStarted,
    LogEnded,
    ScheduleTriggered,
    PluginEvent(String),
}
```

### 5.2 Notification Channels

```rust
/// Pluggable notification backends
pub trait NotificationChannel: Send + Sync {
    fn send(&self, notification: &Notification) -> Result<(), NotificationError>;
    fn capabilities(&self) -> ChannelCapabilities;
}

pub struct Notification {
    pub id: Uuid,
    pub title: String,
    pub body: String,
    pub urgency: Urgency,
    pub channel: ChannelType,
    pub actions: Vec<Action>,
    pub scheduled_for: Option<DateTime<Utc>>,
}

pub enum ChannelType {
    Desktop,      // libnotify/dunst
    Email,        // SMTP
    Slack,        // Slack API
    Telegram,     // Bot API
    Webhook,      // HTTP POST
    Console,      // stdout
}

pub enum Urgency {
    Low,
    Normal,
    Critical,
}
```

---

## 6. Repository & Storage Abstraction

### 6.1 Repository Trait

```rust
pub trait MpsRepository: Send + Sync {
    async fn save(&self, file: &MpsFile) -> Result<(), RepositoryError>;
    async fn load(&self, id: &MpsFileId) -> Result<MpsFile, RepositoryError>;
    async fn delete(&self, id: &MpsFileId) -> Result<(), RepositoryError>;
    async fn list(&self, range: DateRange) -> Result<Vec<MpsFileId>, RepositoryError>;
    async fn search(&self, query: &SearchQuery) -> Result<Vec<SearchResult>, RepositoryError>;
}

pub trait SearchIndex: Send + Sync {
    fn index(&self, file: &MpsFile) -> Result<(), IndexError>;
    fn search(&self, query: &SearchQuery) -> Result<Vec<SearchResult>, IndexError>;
    fn reindex(&self) -> Result<(), IndexError>;
}
```

### 6.2 Storage Implementations

```rust
// File-based storage (YAML/JSON)
pub struct FileSystemRepository {
    base_path: PathBuf,
    format: StorageFormat,
}

// SQLite with full-text search
pub struct SqliteRepository {
    connection: SqliteConnection,
}

// PostgreSQL for multi-device sync
pub struct PostgresRepository {
    pool: PgPool,
}
```

---

## 7. Query & Filter System

### 7.1 Query DSL

```rust
/// Fluent query builder
pub struct MpsQuery {
    filters: Vec<Box<dyn QueryFilter>>,
    sort: SortOption,
    limit: Option<usize>,
    offset: usize,
}

impl MpsQuery {
    pub fn new() -> Self { ... }
    
    pub fn for_date(mut self, date: NaiveDate) -> Self { ... }
    pub fn for_date_range(mut self, start: NaiveDate, end: NaiveDate) -> Self { ... }
    
    pub fn with_type(mut self, element_type: ElementType) -> Self { ... }
    pub fn with_tag(mut self, tag: impl Into<String>) -> Self { ... }
    pub fn with_tags(mut self, tags: Vec<String>) -> Self { ... }
    
    pub fn with_priority(mut self, priority: Priority) -> Self { ... }
    pub fn is_completed(mut self) -> Self { ... }
    pub fn is_pending(mut self) -> Self { ... }
    
    pub fn has_due_date(mut self) -> Self { ... }
    pub fn due_before(mut self, date: DateTime<Utc>) -> Self { ... }
    pub fn due_after(mut self, date: DateTime<Utc>) -> Self { ... }
    
    pub fn sort_by(mut self, sort: SortOption) -> Self { ... }
    pub fn limit(mut self, n: usize) -> Self { ... }
    pub fn offset(mut self, n: usize) -> Self { ... }
    
    pub fn execute(&self, repo: &dyn MpsRepository) -> Result<Vec<Box<dyn Element>>, QueryError> { ... }
}
```

---

## 8. CLI & Interface Layer

### 8.1 Command Structure (using Clap)

```rust
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "mps")]
#[command(about = "MPS - Personal Productivity Manager", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
    
    #[arg(short, long, global = true)]
    pub config: Option<PathBuf>,
    
    #[arg(short, long, global = true, action = clap::ArgAction::Count)]
    pub verbose: u8,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Open MPS file in editor
    Open {
        /// Date expression (today, yesterday, YYYYMMDD, "2 days ago")
        #[arg(default_value = "today")]
        date: String,
        
        /// Open in specified editor
        #[arg(short, long)]
        editor: Option<String>,
    },
    
    /// Create new element
    New {
        /// Element type (task, note, reminder, log)
        #[arg(value_enum)]
        element_type: ElementTypeCli,
        
        /// Element body/content
        body: String,
        
        /// Tags (comma-separated)
        #[arg(short, long, value_delimiter = ',')]
        tags: Vec<String>,
        
        /// Date to add element to
        #[arg(short, long)]
        date: Option<String>,
    },
    
    /// List/search elements
    List {
        /// Filter by type
        #[arg(short, long)]
        r#type: Option<ElementTypeCli>,
        
        /// Filter by tag
        #[arg(short, long)]
        tag: Option<String>,
        
        /// Show completed tasks
        #[arg(long)]
        all: bool,
        
        /// Date range
        #[arg(short, long)]
        range: Option<String>,
    },
    
    /// Git operations
    Git {
        #[arg(last = true)]
        args: Vec<String>,
    },
    
    /// AI Agent commands
    Agent {
        #[command(subcommand)]
        subcommand: AgentCommands,
    },
    
    /// Export data
    Export {
        /// Output format (json, yaml, markdown, csv)
        #[arg(short, long)]
        format: ExportFormat,
        
        /// Output file
        #[arg(short, long)]
        output: Option<PathBuf>,
        
        /// Date range
        #[arg(short, long)]
        range: Option<String>,
    },
    
    /// Server mode (for remote access/API)
    Serve {
        #[arg(short, long, default_value = "127.0.0.1:3030")]
        address: String,
    },
}
```

---

## 9. Error Handling

### 9.1 Error Types

```rust
#[derive(Error, Debug)]
pub enum MpsError {
    #[error("Element not found: {0}")]
    ElementNotFound(Uuid),
    
    #[error("File not found: {0}")]
    FileNotFound(MpsFileId),
    
    #[error("Parse error: {0}")]
    ParseError(String),
    
    #[error("Storage error: {0}")]
    StorageError(String),
    
    #[error("Configuration error: {0}")]
    ConfigError(String),
    
    #[error("Plugin error: {0}")]
    PluginError(String),
    
    #[error("Validation error: {0}")]
    ValidationError(String),
}
```

---

## 10. Project Structure

```
mps/
├── Cargo.toml
├── rust-toolchain.toml
├── .env.example
├── README.md
├── CHANGELOG.md
│
├── src/
│   ├── main.rs                    # Entry point
│   ├── lib.rs                     # Library root
│   │
│   ├── domain/                    # Domain Layer (innermost)
│   │   ├── mod.rs
│   │   ├── element.rs             # Element trait
│   │   ├── task.rs
│   │   ├── note.rs
│   │   ├── reminder.rs
│   │   ├── log.rs
│   │   ├── mps_file.rs            # Aggregate root
│   │   ├── errors.rs              # Domain errors
│   │   └── value_objects/         # Value objects
│   │       ├── mod.rs
│   │       ├── mps_file_id.rs
│   │       ├── priority.rs
│   │       └── date_stamp.rs
│   │
│   ├── application/              # Application Services
│   │   ├── mod.rs
│   │   ├── parser.rs              # Text file parser
│   │   ├── query_service.rs       # Query execution
│   │   ├── command_service.rs     # Commands (CQRS write)
│   │   ├── export_service.rs       # Export to various formats
│   │   └── scheduler.rs           # Reminder scheduler
│   │
│   ├── infrastructure/           # Infrastructure Layer
│   │   ├── mod.rs
│   │   ├── repository/
│   │   │   ├── mod.rs
│   │   │   ├── repository.rs      # Repository trait
│   │   │   ├── file_system.rs
│   │   │   ├── sqlite.rs
│   │   │   └── search_index.rs
│   │   ├── storage/
│   │   │   ├── mod.rs
│   │   │   └── yaml.rs
│   │   ├── notification/
│   │   │   ├── mod.rs
│   │   │   ├── notifier.rs
│   │   │   └── channels/
│   │   │       ├── mod.rs
│   │   │       ├── desktop.rs
│   │   │       ├── email.rs
│   │   │       └── slack.rs
│   │   └── plugins/
│   │       ├── mod.rs
│   │       ├── plugin.rs           # Plugin trait
│   │       ├── manager.rs          # Plugin registry
│   │       └── ai/
│   │           ├── mod.rs
│   │           ├── llm.rs           # LLM trait
│   │           └── smart_reminder.rs
│   │
│   ├── interface/                 # Interface Adapters
│   │   ├── mod.rs
│   │   ├── cli/
│   │   │   ├── mod.rs
│   │   │   ├── commands.rs
│   │   │   └── parser.rs          # CLI arg parsing
│   │   ├── tui/
│   │   │   └── mod.rs              # Terminal UI
│   │   └── api/
│   │       ├── mod.rs
│   │       └── server.rs           # HTTP API server
│   │
│   └── common/                   # Shared utilities
│       ├── mod.rs
│       ├── config.rs
│       ├── logging.rs
│       ├── date_utils.rs
│       └── extensions.rs
│
├── tests/
│   ├── integration/
│   │   └── mod.rs
│   ├── domain/
│   │   ├── mod.rs
│   │   └── element_tests.rs
│   └── fixtures/
│       └── mod.rs
│
├── examples/
│   ├── basic_usage.rs
│   ├── plugin_example.rs
│   └── export_example.rs
│
└── docs/
    ├── architecture.md
    ├── plugin_development.md
    └── api_reference.md
```

---

## 11. Dependencies (Cargo.toml)

```toml
[package]
name = "mps"
version = "0.1.0"
edition = "2024"

[dependencies]
# Async runtime
tokio = { version = "1", features = ["full"] }

# CLI
clap = { version = "4", features = ["derive", "env"] }
clap_complete = "4"

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
toml = "0.8"

# Database
rusqlite = { version = "0.31", features = ["bundled"] }
sqlx = { version = "0.7", features = ["runtime-tokio", "sqlite", "postgres"] }

# Date/Time
chrono = { version = "0.4", features = ["serde"] }
chrono-tz = "0.8"

# UUID
uuid = { version = "1", features = ["v4", "serde", "fast-rng"] }

# Logging
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
tracing-appender = "0.2"

# Error handling
thiserror = "1"
anyhow = "1"

# Async notifications
tokio-sync = "0.3"

# Editor integration
tui-editor = "0.2"

# HTTP server (for API)
axum = "0.6"
tower = "0.4"

# Regex
regex = "1"
fancy-regex = "0.11"

# Fuzzy search
fuzzy-matcher = "0.3"

# Async trait support
async-trait = "0.1"

# Conditional compilation
cfg-if = "1"

[dev-dependencies]
tokio-test = "0.4"
mockall = "0.11"
proptest = "1"
criterion = "0.5"

[features]
default = ["sqlite"]
sqlite = ["rusqlite"]
postgres = ["sqlx/postgres"]
```

---

## 12. Implementation Phases

### Phase 1: Core Domain (Weeks 1-2)
- [ ] Define Element trait and value objects
- [ ] Implement Task, Note, Reminder, Log types
- [ ] Implement MpsFile aggregate
- [ ] Implement basic error types
- [ ] Unit tests for domain

### Phase 2: Storage & Parser (Weeks 3-4)
- [ ] FileSystem repository implementation
- [ ] Text parser for .mps files
- [ ] YAML/JSON serialization
- [ ] Search index implementation

### Phase 3: Query System (Week 5)
- [ ] MpsQuery builder
- [ ] Filter implementations
- [ ] SQLite repository

### Phase 4: Event System (Week 6)
- [ ] EventBus implementation
- [ ] Scheduler for reminders
- [ ] Notification channels

### Phase 5: Plugin Architecture (Weeks 7-8)
- [ ] Plugin trait and manager
- [ ] Plugin registry
- [ ] AI agent plugin skeleton

### Phase 6: Interface Layer (Weeks 9-10)
- [ ] CLI commands implementation
- [ ] TUI (optional)
- [ ] HTTP API server

### Phase 7: Polish (Week 11-12)
- [ ] Integration tests
- [ ] Performance optimization
- [ ] Documentation
- [ ] Release

---

## 13. Summary

This specification provides a production-grade Rust implementation with:

| Feature | Ruby Implementation | Rust Implementation |
|---------|--------------------|--------------------|
| Type Safety | None (dynamic) | Full (static) |
| Concurrency | GIL-limited | True parallelism |
| Error Handling | Exceptions | Result/Either types |
| Extensibility | eval() reflection | Plugin trait system |
| AI Integration | None | Pluggable LLM interface |
| Notifications | None | Async event bus |
| Storage | YAML only | Pluggable backends |
| Query | None | Full query DSL |
| Testing | Minimal | Property-based |

The architecture enables future AI agent integration through a well-defined plugin system, event bus, and async capabilities.
