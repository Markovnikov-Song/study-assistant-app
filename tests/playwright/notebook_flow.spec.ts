import { expect, test, type Page } from '@playwright/test';

test.describe('NOTE-P1 notebook detail flow', () => {
  test.beforeEach(async ({ page }) => {
    await installNotebookMocks(page);
    await loginAsNotebookUser(page);
  });

  test('NOTE-P1-01 note detail can polish and import to RAG', async ({ page }) => {
    const updateBodies: unknown[] = [];
    const polishBodies: unknown[] = [];
    const importBodies: unknown[] = [];
    await mockNoteDetail(page, updateBodies);
    await mockPolishNote(page, polishBodies);
    await mockImportToRag(page, importBodies);

    await page.goto('/#/toolkit/notebooks/3/notes/5');
    await waitForFlutter(page);

    await tapPolishAction(page, polishBodies);
    await expect
      .poll(async () => polishBodies.length, { timeout: 15000 })
      .toBe(1);
    expect(updateBodies.length).toBeGreaterThanOrEqual(1);

    await dismissPolishDialog(page);
    await tapImportAction(page, importBodies);
    await expect
      .poll(async () => importBodies.length, { timeout: 15000 })
      .toBe(1);
    expect(updateBodies.length).toBeGreaterThanOrEqual(2);
  });
});

async function loginAsNotebookUser(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('notebook-smoke-token'),
    );
    window.localStorage.setItem(
      'flutter.onboarding.calculus_demo.seen.v1',
      JSON.stringify(true),
    );
  });
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

async function tapPolishAction(page: Page, bodies: unknown[]) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const y = 28;
  const candidates =
    viewport.width >= 800
      ? [viewport.width - 150, viewport.width - 132, viewport.width - 116]
      : [viewport.width - 154, viewport.width - 136, viewport.width - 118];
  for (const x of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(800);
    if (bodies.length > 0) return;
  }
  throw new Error('Polish action did not request /polish');
}

async function dismissPolishDialog(page: Page) {
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);
  const viewport = page.viewportSize();
  if (!viewport) return;
  await page.mouse.click(viewport.width / 2 - 80, viewport.height / 2 + 70);
  await page.waitForTimeout(500);
}

async function tapImportAction(page: Page, bodies: unknown[]) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const y = 28;
  const candidates =
    viewport.width >= 800
      ? [viewport.width - 102, viewport.width - 84, viewport.width - 66]
      : [viewport.width - 108, viewport.width - 90, viewport.width - 72];
  for (const x of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(800);
    if (bodies.length > 0) return;
  }
  throw new Error('Import action did not request /import-to-rag');
}

async function installNotebookMocks(page: Page) {
  await page.route('**/api/**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ ok: true, items: [], data: [] }),
    });
  });

  await page.route('**/api/users/me', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        user_id: 1,
        username: 'notebook-smoke',
        avatar_base64: null,
      }),
    });
  });
}

async function mockNoteDetail(page: Page, updateBodies: unknown[]) {
  await page.route('**/api/notes/5', async (route) => {
    const request = route.request();
    if (request.method() === 'PATCH') {
      updateBodies.push(request.postDataJSON());
    }
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(noteJson({ imported_to_doc_id: null })),
    });
  });
}

async function mockPolishNote(page: Page, bodies: unknown[]) {
  await page.route('**/api/notes/5/polish', async (route) => {
    bodies.push(route.request().postDataJSON() ?? {});
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        polished_content:
          '# Polished Note\n\nThis is a polished explanation for Playwright.',
      }),
    });
  });
}

async function mockImportToRag(page: Page, bodies: unknown[]) {
  await page.route('**/api/notes/5/import-to-rag', async (route) => {
    bodies.push(route.request().postDataJSON() ?? {});
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ doc_id: 77 }),
    });
  });
}

function noteJson(overrides: Record<string, unknown> = {}) {
  return {
    id: 5,
    notebook_id: 3,
    subject_id: 11,
    source_session_id: null,
    source_message_id: null,
    role: 'assistant',
    original_content: '# Playwright Note\n\nOriginal note content.',
    title: 'Playwright Note',
    outline: ['Original point'],
    imported_to_doc_id: null,
    sources: [],
    created_at: '2026-06-03T08:00:00',
    updated_at: '2026-06-03T08:00:00',
    note_type: 'general',
    mistake_status: null,
    ...overrides,
  };
}
