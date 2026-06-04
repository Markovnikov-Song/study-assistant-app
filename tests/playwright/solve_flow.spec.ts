import { expect, test, type Page } from '@playwright/test';

test.describe('SA-P0 solve assistant flow', () => {
  test.beforeEach(async ({ page }) => {
    await installSolveMocks(page);
    await loginAsSmokeUser(page);
  });

  test('SA-P0-01 solve page renders without fatal browser errors', async ({ page }) => {
    const errors: string[] = [];
    const failedRequests: string[] = [];

    page.on('pageerror', (error) => errors.push(error.message));
    page.on('console', (message) => {
      if (message.type() === 'error') errors.push(message.text());
    });
    page.on('requestfailed', (request) => {
      const url = request.url();
      if (!url.includes('/api/')) failedRequests.push(url);
    });

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    await expect(page).toHaveURL(/#\/toolkit\/solve$/);

    const bodyBox = await page.locator('body').boundingBox();
    expect(bodyBox?.width ?? 0).toBeGreaterThan(300);
    expect(bodyBox?.height ?? 0).toBeGreaterThan(300);

    const nonWhitePixels = await countNonWhitePixels(page);
    expect(nonWhitePixels).toBeGreaterThan(500);

    const pageText = await readFlutterHostText(page);
    if (pageText.length > 0) {
      expect(pageText).toContain('瑙ｉ鍔╂墜');
    }

    expect(errors).toEqual([]);
    expect(failedRequests).toEqual([]);
  });

  test('SA-P0-02 text problem submits and renders streamed solution', async ({ page }) => {
    const dispatchBodies: unknown[] = [];
    await mockSolveDispatch(page, dispatchBodies);

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    const problem = 'Solve x + 2 = 5';
    await typeIntoBottomInput(page, problem);
    await tapSendButton(page);

    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(1);

    await page.waitForTimeout(1200);
    const answerPixels = await countNonWhitePixels(page, {
      x: 0,
      y: 90,
      width: 360,
      height: 180,
    });
    expect(answerPixels).toBeGreaterThan(2500);

    expect(dispatchBodies).toHaveLength(1);
    expect(dispatchBodies[0]).toMatchObject({
      text: problem,
      supplement_text: problem,
      images: [],
      session_id: null,
    });
  });

  test('SA-P0-03 streamed solution can be saved to notebook', async ({ page }) => {
    const dispatchBodies: unknown[] = [];
    const noteBodies: unknown[] = [];
    await mockSolveDispatch(page, dispatchBodies);
    await mockCreateNotes(page, noteBodies);

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    await typeIntoBottomInput(page, 'Solve x + 2 = 5');
    await tapSendButton(page);
    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(1);
    await page.waitForTimeout(1200);

    await tapSaveToNotebookAction(page);
    await confirmCenteredDialog(page);

    await expect
      .poll(async () => noteBodies.length, { timeout: 15000 })
      .toBe(1);

    expect(noteBodies[0]).toMatchObject({
      notes: [
        {
          notebook_id: 3,
          role: 'assistant',
          sources: { type: 'solve', message_index: 1 },
        },
      ],
    });
    expect(JSON.stringify(noteBodies[0])).toContain('x = 3');
  });

  test('SA-P0-04 streamed solution can be saved to mistakes', async ({ page }) => {
    const dispatchBodies: unknown[] = [];
    const mistakeBodies: unknown[] = [];
    const legacyMistakeBodies: unknown[] = [];
    await mockSolveDispatch(page, dispatchBodies);
    await mockCreateMistakeFromPractice(page, mistakeBodies);
    await mockLegacyMistakeEndpoint(page, legacyMistakeBodies);

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    const problem = 'Solve x + 2 = 5';
    await typeIntoBottomInput(page, problem);
    await tapSendButton(page);
    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(1);
    await page.waitForTimeout(1200);

    await tapSaveToMistakesAction(page);
    await confirmMistakeDialog(page);

    await expect
      .poll(async () => mistakeBodies.length, { timeout: 15000 })
      .toBe(1);

    expect(legacyMistakeBodies).toHaveLength(0);
    expect(mistakeBodies[0]).toMatchObject({
      subject_id: 11,
      mistake_category: 'complete',
    });
    expect(JSON.stringify(mistakeBodies[0])).toContain(problem);
    expect(JSON.stringify(mistakeBodies[0])).toContain('x = 3');
  });

  test('SA-P0-05 notebook and mistake save states stay independent', async ({ page }) => {
    await runDualSaveFlow(page, 'notebook-first');
    await page.reload();
    await waitForFlutter(page);
    await runDualSaveFlow(page, 'mistake-first');
  });

  test('SA-P0-07 history session restores and follow-up reuses session id', async ({ page }) => {
    const dispatchBodies: unknown[] = [];
    await mockSolveHistory(page);
    await mockSolveDispatch(page, dispatchBodies);

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    await openHistorySheet(page);
    await selectFirstHistorySession(page);
    await page.waitForTimeout(1200);

    await typeIntoBottomInput(page, 'Why is x equal to 3?');
    await tapSendButton(page);

    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(1);
    expect(dispatchBodies[0]).toMatchObject({
      session_id: 777,
      text: 'Why is x equal to 3?',
      supplement_text: 'Why is x equal to 3?',
    });
    expect(JSON.stringify(dispatchBodies[0])).toContain('Solve x + 2 = 5');
    expect(JSON.stringify(dispatchBodies[0])).toContain('x = 3');
  });

  test('SA-P0-08 solve error still allows another solve request', async ({ page }) => {
    const dispatchBodies: unknown[] = [];
    await mockSolveDispatchSequence(page, dispatchBodies, ['error', 'success']);

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    await typeIntoBottomInput(page, 'Bad photo problem');
    await tapSendButton(page);
    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(1);
    await page.waitForTimeout(1000);

    await typeIntoBottomInput(page, 'Solve x + 2 = 5');
    await tapSendButton(page);

    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(2);
    expect(dispatchBodies[1]).toMatchObject({
      text: 'Solve x + 2 = 5',
      supplement_text: 'Solve x + 2 = 5',
    });
  });

  test('SA-P0-08 notebook save failure does not mark result as saved', async ({ page }) => {
    const dispatchBodies: unknown[] = [];
    const noteBodies: unknown[] = [];
    await mockSolveDispatch(page, dispatchBodies);
    await mockCreateNotesFailure(page, noteBodies);

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    await typeIntoBottomInput(page, 'Solve x + 2 = 5');
    await tapSendButton(page);
    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(1);
    await page.waitForTimeout(1200);

    await tapSaveToNotebookAction(page);
    await confirmCenteredDialog(page);
    await expect
      .poll(async () => noteBodies.length, { timeout: 15000 })
      .toBe(1);

    await tapSaveToNotebookAction(page);
    await confirmCenteredDialog(page);
    await expect
      .poll(async () => noteBodies.length, { timeout: 15000 })
      .toBe(2);
  });

  test('SA-P0-08 mistake save failure does not mark result as saved', async ({ page }) => {
    const dispatchBodies: unknown[] = [];
    const mistakeBodies: unknown[] = [];
    const legacyMistakeBodies: unknown[] = [];
    await mockSolveDispatch(page, dispatchBodies);
    await mockCreateMistakeFromPracticeFailure(page, mistakeBodies);
    await mockLegacyMistakeEndpoint(page, legacyMistakeBodies);

    await page.goto('/#/toolkit/solve');
    await waitForFlutter(page);

    await typeIntoBottomInput(page, 'Solve x + 2 = 5');
    await tapSendButton(page);
    await expect
      .poll(async () => dispatchBodies.length, { timeout: 15000 })
      .toBe(1);
    await page.waitForTimeout(1200);

    await tapSaveToMistakesAction(page);
    await confirmMistakeDialog(page);
    await expect
      .poll(async () => mistakeBodies.length, { timeout: 15000 })
      .toBe(1);

    await tapSaveToMistakesAction(page, false);
    await confirmMistakeDialog(page);
    await expect
      .poll(async () => mistakeBodies.length, { timeout: 15000 })
      .toBe(2);
    expect(legacyMistakeBodies).toHaveLength(0);
  });
});

async function runDualSaveFlow(
  page: Page,
  order: 'notebook-first' | 'mistake-first',
) {
  const dispatchBodies: unknown[] = [];
  const noteBodies: unknown[] = [];
  const mistakeBodies: unknown[] = [];
  const legacyMistakeBodies: unknown[] = [];

  await mockSolveDispatch(page, dispatchBodies);
  await mockCreateNotes(page, noteBodies);
  await mockCreateMistakeFromPractice(page, mistakeBodies);
  await mockLegacyMistakeEndpoint(page, legacyMistakeBodies);

  await page.goto('/#/toolkit/solve');
  await waitForFlutter(page);

  await typeIntoBottomInput(page, 'Solve x + 2 = 5');
  await tapSendButton(page);
  await expect
    .poll(async () => dispatchBodies.length, { timeout: 15000 })
    .toBe(1);
  await page.waitForTimeout(1200);

  if (order === 'notebook-first') {
    await tapSaveToNotebookAction(page);
    await confirmCenteredDialog(page);
    await expect
      .poll(async () => noteBodies.length, { timeout: 15000 })
      .toBe(1);

    await tapSaveToMistakesAction(page);
    await confirmMistakeDialog(page);
    await expect
      .poll(async () => mistakeBodies.length, { timeout: 15000 })
      .toBe(1);
  } else {
    await tapSaveToMistakesAction(page);
    await confirmMistakeDialog(page);
    await expect
      .poll(async () => mistakeBodies.length, { timeout: 15000 })
      .toBe(1);

    await tapSaveToNotebookAction(page);
    await confirmCenteredDialog(page);
    await expect
      .poll(async () => noteBodies.length, { timeout: 15000 })
      .toBe(1);
  }

  expect(legacyMistakeBodies).toHaveLength(0);
}

async function loginAsSmokeUser(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('smoke-token'),
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
  await page.waitForTimeout(1200);
}

async function readFlutterHostText(page: Page): Promise<string> {
  return page.evaluate(() => {
    const host =
      document.querySelector('flt-glass-pane') ||
      document.querySelector('flutter-view') ||
      document.body;
    return host.textContent?.trim() ?? '';
  });
}

async function typeIntoBottomInput(page: Page, text: string) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width / 2, viewport.height - 28);
  await page.keyboard.type(text);
}

async function tapSendButton(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width - 28, viewport.height - 28);
}

async function openHistorySheet(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.waitForTimeout(1500);
  const candidates = [
    [viewport.width - 136, 28],
    [viewport.width - 124, 28],
    [viewport.width - 112, 28],
    [viewport.width - 104, 28],
    [viewport.width - 96, 28],
    [viewport.width - 136, 42],
    [viewport.width - 124, 42],
    [viewport.width - 112, 38],
    [viewport.width - 104, 42],
    [viewport.width - 96, 38],
  ];
  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(700);
    if (await isModalScrimVisible(page)) return;
  }
  throw new Error('History button did not open history sheet');
}

async function isModalScrimVisible(page: Page): Promise<boolean> {
  const viewport = page.viewportSize();
  if (!viewport) return false;
  const darkPixels = await countNonWhitePixels(page, {
    x: 20,
    y: viewport.height * 0.2,
    width: 1,
    height: 1,
  });
  return darkPixels > 0;
}

async function selectFirstHistorySession(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const detailRequest = page.waitForRequest(
    (request) => request.url().includes('/api/solve/sessions/777'),
    { timeout: 5000 },
  );
  const x = viewport.width >= 800 ? viewport.width / 2 + 292 : viewport.width - 30;
  const y = viewport.width >= 800 ? viewport.height * 0.475 : viewport.height * 0.455;
  await page.mouse.click(x, y);
  await detailRequest;
}

async function tapSaveToNotebookAction(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const x = viewport.width >= 800 ? 98 : 95;
  const y = viewport.width >= 800 ? 222 : 222;
  await page.mouse.click(x, y);
}

async function tapSaveToMistakesAction(page: Page, waitForSubjects = true) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const candidates =
    viewport.width >= 800
      ? [
          [186, 216],
          [210, 216],
          [238, 216],
          [186, 222],
          [210, 222],
          [238, 222],
          [186, 232],
          [210, 232],
          [238, 232],
        ]
      : [
          [188, 216],
          [220, 216],
          [248, 216],
          [188, 222],
          [220, 222],
          [248, 222],
          [188, 232],
          [220, 232],
          [248, 232],
        ];

  for (const [x, y] of candidates) {
    if (!waitForSubjects) {
      await page.mouse.click(x, y);
      await page.waitForTimeout(700);
      return;
    }

    const subjectRequest = page
      .waitForRequest((request) => request.url().includes('/api/subjects'), {
        timeout: 700,
      })
      .catch(() => null);
    await page.mouse.click(x, y);
    if (await subjectRequest) return;
  }
  throw new Error('Save-to-mistakes action did not request subjects');
}

async function confirmCenteredDialog(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.waitForTimeout(600);
  await page.mouse.click(viewport.width - 96, viewport.height / 2 + 54);
}

async function confirmMistakeDialog(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.waitForTimeout(600);
  const candidates =
    viewport.width >= 800
      ? [
          [viewport.width / 2 + 78, viewport.height / 2 + 98],
        ]
      : [
          [viewport.width / 2 + 78, viewport.height / 2 + 74],
          [viewport.width / 2 + 88, viewport.height / 2 + 74],
          [viewport.width / 2 + 78, viewport.height / 2 + 96],
          [viewport.width / 2 + 88, viewport.height / 2 + 96],
          [viewport.width / 2 + 78, viewport.height / 2 + 118],
        ];
  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(300);
  }
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

async function installSolveMocks(page: Page) {
  await page.route('**/api/**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ ok: true }),
    });
  });

  await page.route('**/api/users/me', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        user_id: 1,
        username: 'smoke',
        avatar_base64: null,
      }),
    });
  });

  await page.route('**/api/subjects**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([
        {
          id: 11,
          name: '娴嬭瘯鏁板',
          category: '鏁板',
          description: '',
          is_pinned: false,
          is_archived: false,
          color_index: 2,
          created_at: '2026-06-01T00:00:00',
        },
      ]),
    });
  });

  await page.route('**/api/notebooks**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([
        {
          id: 3,
          name: '绗旇',
          is_system: true,
          is_pinned: false,
          is_archived: false,
          sort_order: 2,
          created_at: '2026-06-01T00:00:00',
        },
      ]),
    });
  });

  await page.route('**/api/solve/sessions**', async (route) => {
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

}

async function mockSolveDispatch(page: Page, dispatchBodies: unknown[]) {
  await page.route('**/api/cas/dispatch', async (route) => {
    dispatchBodies.push(route.request().postDataJSON());
    const events = [
      { content: '## Idea\n' },
      { content: 'Move terms: x = 5 - 2.\n' },
      { content: 'So x = 3.' },
      { content: '[DONE]', session_id: 501 },
    ];

    await route.fulfill({
      status: 200,
      contentType: 'text/event-stream; charset=utf-8',
      body: events.map((event) => `data: ${JSON.stringify(event)}\n\n`).join(''),
    });
  });
}
async function mockSolveDispatchSequence(
  page: Page,
  dispatchBodies: unknown[],
  sequence: Array<'error' | 'success'>,
) {
  let index = 0;
  await page.route('**/api/cas/dispatch', async (route) => {
    dispatchBodies.push(route.request().postDataJSON());
    const mode = sequence[Math.min(index, sequence.length - 1)];
    index += 1;

    if (mode === 'error') {
      await route.fulfill({
        status: 200,
        contentType: 'text/event-stream; charset=utf-8',
        body: `data: ${JSON.stringify({
          content: '[ERROR]',
          error: 'OCR failed for smoke test',
        })}\n\n`,
      });
      return;
    }

    const events = [
      { content: '## Idea\n' },
      { content: 'Move terms: x = 5 - 2.\n' },
      { content: 'So x = 3.' },
      { content: '[DONE]', session_id: 501 },
    ];
    await route.fulfill({
      status: 200,
      contentType: 'text/event-stream; charset=utf-8',
      body: events.map((event) => `data: ${JSON.stringify(event)}\n\n`).join(''),
    });
  });
}
async function mockSolveHistory(page: Page) {
  await page.route('**/api/solve/sessions', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([
        {
          id: 777,
          title: '鍘嗗彶瑙ｉ璁板綍',
          created_at: '2026-06-02T08:00:00',
          thumbnail: null,
        },
      ]),
    });
  });

  await page.route('**/api/solve/sessions/777', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([
        {
          id: 1,
          role: 'user',
          content: 'Solve x + 2 = 5',
          sources: null,
          created_at: '2026-06-02T08:00:00',
        },
        {
          id: 2,
          role: 'assistant',
          content: 'Move terms: x = 5 - 2. So x = 3.',
          sources: null,
          created_at: '2026-06-02T08:00:01',
        },
      ]),
    });
  });
}

async function mockCreateNotes(page: Page, noteBodies: unknown[]) {
  await page.route('**/api/notes', async (route) => {
    noteBodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 201,
      contentType: 'application/json',
      body: JSON.stringify([
        {
          id: 700,
          notebook_id: 3,
          role: 'assistant',
          title: '瑙ｉ璁板綍',
          original_content: 'Move terms: x = 5 - 2. So x = 3.',
          created_at: '2026-06-01T00:00:00',
          updated_at: '2026-06-01T00:00:00',
        },
      ]),
    });
  });
}

async function mockCreateNotesFailure(page: Page, noteBodies: unknown[]) {
  await page.route('**/api/notes', async (route) => {
    noteBodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ detail: 'note save failed for smoke test' }),
    });
  });
}

async function mockCreateMistakeFromPractice(
  page: Page,
  mistakeBodies: unknown[],
) {
  await page.route('**/api/review/mistakes/from-practice', async (route) => {
    const body = route.request().postDataJSON();
    mistakeBodies.push(body);
    await route.fulfill({
      status: 201,
      contentType: 'application/json',
      body: JSON.stringify({
        id: 800,
        notebook_id: 4,
        subject_id: body.subject_id,
        title: body.title ?? '瑙ｉ閿欓',
        content: body.content ?? '',
        note_type: 'mistake',
        mistake_status: 'pending',
        question_text: body.question_text,
        mistake_category: body.mistake_category,
        review_card_id: 900,
        mastery_score: 0,
        review_count: 0,
        created_at: '2026-06-01T00:00:00',
        updated_at: '2026-06-01T00:00:00',
      }),
    });
  });
}

async function mockCreateMistakeFromPracticeFailure(
  page: Page,
  mistakeBodies: unknown[],
) {
  await page.route('**/api/review/mistakes/from-practice', async (route) => {
    mistakeBodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ detail: 'mistake save failed for smoke test' }),
    });
  });
}

async function mockLegacyMistakeEndpoint(
  page: Page,
  legacyMistakeBodies: unknown[],
) {
  await page.route('**/api/review/mistakes', async (route) => {
    legacyMistakeBodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ detail: 'legacy mistake endpoint should not be used' }),
    });
  });
}



