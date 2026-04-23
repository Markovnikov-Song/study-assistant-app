-- Migration 007: 添加学习日历相关表
-- calendar_routines: 重复例程定义
-- calendar_events:   单次学习事件（含例程生成的实例）
-- study_sessions:    实际学习时长记录（番茄钟累计）

-- ── calendar_routines ────────────────────────────────────────────────────────
-- 必须先于 calendar_events 创建，因为 calendar_events 有 routine_id FK

CREATE TABLE IF NOT EXISTS calendar_routines (
    id               SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title            VARCHAR(50) NOT NULL,
    repeat_type      VARCHAR(10) NOT NULL
                         CHECK (repeat_type IN ('daily', 'weekly', 'monthly')),
    day_of_week      SMALLINT CHECK (day_of_week BETWEEN 1 AND 7),  -- weekly 时使用，1=周一
    start_time       TIME NOT NULL,
    duration_minutes SMALLINT NOT NULL CHECK (duration_minutes BETWEEN 15 AND 480),
    subject_id       INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    color            VARCHAR(7) NOT NULL DEFAULT '#6366F1',
    start_date       DATE NOT NULL,
    end_date         DATE,                    -- NULL 表示无限期
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendar_routines_user
    ON calendar_routines (user_id, is_active);

-- ── calendar_events ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS calendar_events (
    id                      SERIAL PRIMARY KEY,
    user_id                 INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title                   VARCHAR(50) NOT NULL,
    event_date              DATE NOT NULL,
    start_time              TIME NOT NULL,
    duration_minutes        SMALLINT NOT NULL CHECK (duration_minutes BETWEEN 15 AND 480),
    actual_duration_minutes SMALLINT,         -- 实际学习时长，番茄钟累计写入
    subject_id              INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    color                   VARCHAR(7) NOT NULL DEFAULT '#6366F1',
    notes                   VARCHAR(200),
    is_completed            BOOLEAN NOT NULL DEFAULT FALSE,
    is_countdown            BOOLEAN NOT NULL DEFAULT FALSE,  -- 考试/重要日期倒计时
    priority                VARCHAR(10) NOT NULL DEFAULT 'medium'
                                CHECK (priority IN ('high', 'medium', 'low')),
    source                  VARCHAR(50) NOT NULL DEFAULT 'manual',  -- manual/study-planner/agent
    routine_id              INTEGER REFERENCES calendar_routines(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 主查询索引：按用户 + 日期范围查询
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_date
    ON calendar_events (user_id, event_date);

-- 倒计时专用索引（部分索引，只索引 is_countdown=TRUE 的行）
CREATE INDEX IF NOT EXISTS idx_calendar_events_countdown
    ON calendar_events (user_id, event_date)
    WHERE is_countdown = TRUE;

-- ── study_sessions ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS study_sessions (
    id               SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id         INTEGER REFERENCES calendar_events(id) ON DELETE SET NULL,
    subject_id       INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ NOT NULL,
    duration_minutes SMALLINT NOT NULL,       -- 实际时长（含不足 25 分钟的记录）
    pomodoro_count   SMALLINT NOT NULL DEFAULT 0,  -- 完成的完整番茄钟数
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 统计查询索引：按用户 + 时间范围聚合
CREATE INDEX IF NOT EXISTS idx_study_sessions_user_time
    ON study_sessions (user_id, started_at);

-- 按事件查询索引（部分索引，只索引有关联事件的行）
CREATE INDEX IF NOT EXISTS idx_study_sessions_event
    ON study_sessions (event_id)
    WHERE event_id IS NOT NULL;
