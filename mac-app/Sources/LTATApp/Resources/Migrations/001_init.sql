-- Initial schema for LTATApp (MVP)
CREATE TABLE IF NOT EXISTS Project (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    color TEXT,
    active_flag INTEGER DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS Task (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    name TEXT NOT NULL,
    active_flag INTEGER DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(project_id) REFERENCES Project(id)
);

CREATE TABLE IF NOT EXISTS Session (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    task_id TEXT,
    start_at TEXT NOT NULL,
    end_at TEXT,
    status TEXT NOT NULL,
    FOREIGN KEY(project_id) REFERENCES Project(id),
    FOREIGN KEY(task_id) REFERENCES Task(id)
);

CREATE TABLE IF NOT EXISTS Quantum (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    start_at TEXT NOT NULL,
    end_at TEXT,
    is_partial INTEGER DEFAULT 0,
    partial_reason TEXT,
    actual_duration_seconds INTEGER DEFAULT 0,
    activity_percent REAL DEFAULT 0,
    is_active_flag INTEGER DEFAULT 1,
    primary_app TEXT,
    primary_category TEXT,
    switches_count INTEGER DEFAULT 0,
    focus_mode_flag INTEGER DEFAULT 0,
    anomaly_switching_flag INTEGER DEFAULT 0,
    screenshot_id TEXT,
    FOREIGN KEY(session_id) REFERENCES Session(id),
    FOREIGN KEY(screenshot_id) REFERENCES ScreenshotMetadata(id)
);

CREATE TABLE IF NOT EXISTS ActivityAggregate (
    id TEXT PRIMARY KEY,
    quantum_id TEXT NOT NULL,
    keypress_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    scroll_count INTEGER DEFAULT 0,
    mouse_distance_px INTEGER DEFAULT 0,
    FOREIGN KEY(quantum_id) REFERENCES Quantum(id)
);

CREATE TABLE IF NOT EXISTS FocusAggregate (
    id TEXT PRIMARY KEY,
    quantum_id TEXT NOT NULL,
    app_switch_count INTEGER DEFAULT 0,
    primary_app_dwell_ms INTEGER DEFAULT 0,
    category_switch_count INTEGER DEFAULT 0,
    FOREIGN KEY(quantum_id) REFERENCES Quantum(id)
);

CREATE TABLE IF NOT EXISTS ScreenshotMetadata (
    id TEXT PRIMARY KEY,
    quantum_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    width INTEGER,
    height INTEGER,
    format TEXT,
    file_size_bytes INTEGER,
    hash TEXT,
    captured_at TEXT,
    FOREIGN KEY(quantum_id) REFERENCES Quantum(id)
);

CREATE TABLE IF NOT EXISTS SyncQueue (
    id TEXT PRIMARY KEY,
    quantum_id TEXT NOT NULL,
    payload_snapshot TEXT,
    status TEXT DEFAULT 'pending',
    updated_at TEXT NOT NULL,
    FOREIGN KEY(quantum_id) REFERENCES Quantum(id)
);

CREATE TABLE IF NOT EXISTS AuditLog (
    id TEXT PRIMARY KEY,
    ts TEXT NOT NULL,
    level TEXT NOT NULL,
    component TEXT NOT NULL,
    event_type TEXT NOT NULL,
    message TEXT NOT NULL,
    metadata TEXT
);

CREATE INDEX IF NOT EXISTS idx_quantum_session ON Quantum(session_id);
CREATE INDEX IF NOT EXISTS idx_activity_quantum ON ActivityAggregate(quantum_id);
CREATE INDEX IF NOT EXISTS idx_focus_quantum ON FocusAggregate(quantum_id);
CREATE INDEX IF NOT EXISTS idx_screenshot_quantum ON ScreenshotMetadata(quantum_id);
CREATE INDEX IF NOT EXISTS idx_syncqueue_status ON SyncQueue(status);
