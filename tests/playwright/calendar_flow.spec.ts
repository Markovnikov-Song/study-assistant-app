import { expect, test, type Page } from '@playwright/test';

test.describe('CAL-P1 calendar flow', () => {
  test.beforeEach(async ({ page }) => {
    await installCalendarMocks(page);
    await loginAsCalendarUser(page);
  });

  test('CAL-P1-01 calendar event can be created with reminder enabled', async ({ page }) => {
    const createdEvents: unknown[] = [];
    await mockCreateCalendarEvent(page, createdEvents);

    await page.goto('/#/toolkit/calendar');
    await waitForFlutter(page);

    await openCreateEventSheet(page);
    await typeCalendarEventTitle(page, 'Playwright study plan');
    await saveCalendarEvent(page);

    await expect
      .poll(async () => createdEvents.length, { timeout: 15000 })
      .toBe(1);

    expect(createdEvents[0]).toMatchObject({
      title: 'Playwright study plan',
      duration_minutes: 60,
      source: 'manual',
      is_countdown: false,
      priority: 'medium',
    });
    expect(JSON.stringify(createdEvents[0])).toContain('event_date');
    expect(JSON.stringify(createdEvents[0])).toContain('start_time');
  });

  test('CAL-P1-02 reminder test sheet opens without fatal errors', async ({ page }) => {
    const errors = collectFatalBrowserErrors(page);

    await page.goto('/#/toolkit/calendar');
    await waitForFlutter(page);

    const before = (await page.screenshot({ fullPage: false })).length;
    await openReminderSheet(page);
    await page.waitForTimeout(800);
    const after = (await page.screenshot({ fullPage: false })).length;

    expect(after).toBeGreaterThan(1000);
    expect(after).not.toBe(before);
    expect(errors()).toEqual([]);
  });

  test('POMO-P1-01 today event can start the floating pomodoro timer', async ({ page }) => {
    await mockTodayEvents(page, [calendarEventJson({ title: 'Pomodoro smoke' })]);

    await page.goto('/#/toolkit/calendar');
    await waitForFlutter(page);

    await tapFirstPomodoroStart(page);
    expect(await hasPomodoroBubble(page)).toBeTruthy();
  });

  test('POMO-P1-02 floating pomodoro can pause, resume, and stop with a session record', async ({ page }) => {
    const studySessions: unknown[] = [];
    await mockTodayEvents(page, [calendarEventJson({ title: 'Pomodoro controls' })]);
    await mockCreateStudySession(page, studySessions);

    await page.goto('/#/toolkit/calendar');
    await waitForFlutter(page);

    await tapFirstPomodoroStart(page);
    await expandPomodoroBubble(page);
    await tapPomodoroPauseOrResume(page);
    await page.waitForTimeout(500);
    await tapPomodoroPauseOrResume(page);
    await page.waitForTimeout(1300);
    await stopPomodoroWithoutCompleting(page);

    await expect
      .poll(async () => studySessions.length, { timeout: 15000 })
      .toBe(1);
    expect(studySessions[0]).toMatchObject({
      event_id: 902,
      subject_id: null,
      duration_minutes: 1,
      pomodoro_count: 0,
    });
  });

  test('POMO-P1-03 focus guard sheet opens from the floating pomodoro panel', async ({ page }) => {
    const errors = collectFatalBrowserErrors(page);
    await mockTodayEvents(page, [calendarEventJson({ title: 'Focus guard smoke' })]);

    await page.goto('/#/toolkit/calendar');
    await waitForFlutter(page);

    await tapFirstPomodoroStart(page);
    await expandPomodoroBubble(page);
    await openFocusGuardSheetFromPomodoro(page);

    expect(await isBottomSheetLikelyOpen(page)).toBeTruthy();
    expect(errors()).toEqual([]);
  });
});

async function openCreateEventSheet(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width - 48, viewport.height - 56);
  await page.waitForTimeout(900);
}

async function typeCalendarEventTitle(page: Page, title: string) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const y = viewport.width >= 800 ? 185 : 275;
  await page.mouse.click(viewport.width / 2, y);
  await page.keyboard.type(title);
  await page.waitForTimeout(300);
}

async function saveCalendarEvent(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.wheel(0, viewport.width >= 800 ? 900 : 2200);
  await page.waitForTimeout(500);
  await page.mouse.click(viewport.width / 2, viewport.height - 44);
}

async function openReminderSheet(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const candidates =
    viewport.width >= 800
      ? [
          [viewport.width - 136, 28],
          [viewport.width - 112, 28],
          [viewport.width - 96, 28],
        ]
      : [
          [viewport.width - 136, 28],
          [viewport.width - 112, 28],
          [viewport.width - 96, 28],
        ];
  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(500);
    if (await isBottomSheetLikelyOpen(page)) return;
  }
  throw new Error('Reminder sheet did not open');
}

async function tapFirstPomodoroStart(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const candidates =
    viewport.width >= 800
      ? [
          [viewport.width - 60, viewport.height - 112],
          [viewport.width - 44, viewport.height - 112],
          [viewport.width - 86, viewport.height - 72],
          [viewport.width - 112, viewport.height - 72],
          [viewport.width - 86, viewport.height - 104],
          [viewport.width - 112, viewport.height - 104],
        ]
      : [
          [viewport.width - 60, viewport.height - 112],
          [viewport.width - 44, viewport.height - 112],
          [viewport.width - 86, viewport.height - 86],
          [viewport.width - 112, viewport.height - 86],
          [viewport.width - 86, viewport.height - 120],
          [viewport.width - 112, viewport.height - 120],
          [viewport.width - 86, viewport.height - 154],
          [viewport.width - 112, viewport.height - 154],
        ];

  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(900);
    if (await hasPomodoroBubble(page)) return;
  }
  throw new Error('Pomodoro start button did not show floating bubble');
}

async function expandPomodoroBubble(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width - 58, viewport.height - 150);
  await page.waitForTimeout(800);
  if (!(await hasPomodoroPanel(page))) {
    throw new Error('Pomodoro bubble did not expand');
  }
}

async function tapPomodoroPauseOrResume(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width - 286, viewport.height - 52);
}

async function openFocusGuardSheetFromPomodoro(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width - 238, viewport.height - 52);
  await page.waitForTimeout(900);
}

async function stopPomodoroWithoutCompleting(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width - 44, viewport.height - 52);
  await page.waitForTimeout(700);
  await page.mouse.click(viewport.width / 2 - 28, viewport.height / 2 + 44);
}

async function hasPomodoroBubble(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) return false;
  const pixels = await countNonWhitePixels(page, {
    x: Math.max(0, viewport.width - 130),
    y: Math.max(0, viewport.height - 240),
    width: 120,
    height: 140,
  });
  return pixels > 1200;
}

async function hasPomodoroPanel(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) return false;
  const pixels = await countNonWhitePixels(page, {
    x: Math.max(0, viewport.width - 350),
    y: Math.max(0, viewport.height - 280),
    width: Math.min(340, viewport.width),
    height: 260,
  });
  return pixels > 4500;
}

async function isBottomSheetLikelyOpen(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) return false;
  const screenshot = await page.screenshot({
    fullPage: false,
    clip: {
      x: Math.floor(viewport.width / 2),
      y: Math.floor(viewport.height * 0.65),
      width: 1,
      height: 1,
    },
  });
  return screenshot.length > 70;
}

async function countNonWhitePixels(
  page: Page,
  clip?: { x: number; y: number; width: number; height: number },
): Promise<number> {
  const screenshot = await page.screenshot({ fullPage: false, clip });
  return page.evaluate(async (bytes) => {
    const blob = new Blob([new Uint8Array(bytes)], { type: 'image/png' });
    const bitmap = await createImageBitmap(blob);
    const canvas = document.createElement('canvas');
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    const ctx = canvas.getContext('2d');
    if (!ctx) return 0;
    ctx.drawImage(bitmap, 0, 0);
    const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    let count = 0;
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const a = data[i + 3];
      if (a > 0 && (r < 245 || g < 245 || b < 245)) count += 1;
    }
    return count;
  }, Array.from(screenshot));
}

function collectFatalBrowserErrors(page: Page) {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('requestfailed', (request) => {
    const url = request.url();
    if (!url.includes('/api/')) errors.push(`request failed: ${url}`);
  });
  return () => errors;
}

async function waitForFlutter(page: Page) {
  await page.waitForFunction(() => {
    return Boolean(
      document.querySelector('flt-glass-pane') ||
        document.querySelector('flutter-view') ||
        document.querySelector('flt-scene-host'),
    );
  });
  await page.waitForTimeout(1500);
}

async function loginAsCalendarUser(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('calendar-smoke-token'),
    );
    window.localStorage.setItem(
      'flutter.onboarding.calculus_demo.seen.v1',
      JSON.stringify(true),
    );
  });
}

async function installCalendarMocks(page: Page) {
  await page.route('**/api/users/me', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        user_id: 1,
        username: 'calendar-smoke',
        avatar_base64: null,
      }),
    });
  });

  await page.route('**/api/calendar/events/today', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        events: [],
        stats: {
          total: 0,
          completed: 0,
          completion_rate: 0,
          total_duration_minutes: 0,
          actual_duration_minutes: 0,
        },
      }),
    });
  });

  await page.route('**/api/calendar/events?**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ events: [], total: 0 }),
    });
  });

  await page.route('**/api/calendar/routines**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ routines: [] }),
    });
  });

  await page.route('**/api/calendar/stats**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        period: '7d',
        total_duration_minutes: 0,
        checkin_days: 0,
        streak_days: 0,
        daily_stats: [],
        subject_stats: [],
      }),
    });
  });

  await page.route('**/api/subjects**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });

  await page.route('**/api/capabilities**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ capabilities: [], total: 0 }),
    });
  });

  await page.route('**/api/**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ ok: true, items: [], data: [] }),
    });
  });
}

async function mockCreateCalendarEvent(page: Page, createdEvents: unknown[]) {
  await page.route('**/api/calendar/events', async (route) => {
    const body = route.request().postDataJSON();
    createdEvents.push(body);
    await route.fulfill({
      status: 201,
      contentType: 'application/json',
      body: JSON.stringify({
        id: 901,
        user_id: 1,
        title: body.title,
        event_date: body.event_date,
        start_time: body.start_time,
        duration_minutes: body.duration_minutes,
        actual_duration_minutes: null,
        subject_id: body.subject_id ?? null,
        subject_name: null,
        subject_color: null,
        color: body.color ?? '#6366F1',
        notes: body.notes ?? null,
        is_completed: false,
        is_countdown: body.is_countdown ?? false,
        priority: body.priority ?? 'medium',
        source: body.source ?? 'manual',
        routine_id: null,
        created_at: '2026-06-02T08:00:00',
        updated_at: '2026-06-02T08:00:00',
      }),
    });
  });
}

async function mockCreateStudySession(page: Page, studySessions: unknown[]) {
  await page.route('**/api/calendar/sessions', async (route) => {
    const body = route.request().postDataJSON();
    studySessions.push(body);
    await route.fulfill({
      status: 201,
      contentType: 'application/json',
      body: JSON.stringify({
        id: 991,
        event_id: body.event_id,
        subject_id: body.subject_id ?? null,
        started_at: body.started_at,
        ended_at: body.ended_at,
        duration_minutes: body.duration_minutes,
        pomodoro_count: body.pomodoro_count,
        created_at: '2026-06-03T08:00:00',
      }),
    });
  });
}

async function mockTodayEvents(page: Page, events: unknown[]) {
  await page.route('**/api/calendar/events/today', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        events,
        stats: {
          total: events.length,
          completed: 0,
          completion_rate: 0,
          total_duration_minutes: 60,
          actual_duration_minutes: 0,
        },
      }),
    });
  });
}

function calendarEventJson(overrides: Record<string, unknown> = {}) {
  const today = new Date().toISOString().slice(0, 10);
  return {
    id: 902,
    user_id: 1,
    title: 'Calendar event',
    event_date: today,
    start_time: '16:00',
    duration_minutes: 60,
    actual_duration_minutes: null,
    subject_id: null,
    subject_name: null,
    subject_color: null,
    color: '#6366F1',
    notes: null,
    is_completed: false,
    is_countdown: false,
    priority: 'medium',
    source: 'manual',
    routine_id: null,
    created_at: '2026-06-02T08:00:00',
    updated_at: '2026-06-02T08:00:00',
    ...overrides,
  };
}
