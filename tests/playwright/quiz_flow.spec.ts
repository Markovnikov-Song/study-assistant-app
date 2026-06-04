import { expect, test, type Page } from '@playwright/test';

test.describe('QUIZ-P1 quiz generation flow', () => {
  test.beforeEach(async ({ page }) => {
    await installQuizMocks(page);
    await loginAsQuizUser(page);
  });

  test('QUIZ-P1-01 custom quiz selects a subject and requests generated questions', async ({ page }) => {
    const errors = collectFatalBrowserErrors(page);
    const customQuizBodies: unknown[] = [];
    await mockCustomQuiz(page, customQuizBodies);

    await page.goto('/#/toolkit/quiz?topic=Algebra&count=1');
    await waitForFlutter(page);

    await selectFirstSubject(page);
    await triggerCustomQuizGeneration(page, customQuizBodies);

    await expect
      .poll(async () => customQuizBodies.length, { timeout: 15000 })
      .toBe(1);

    expect(customQuizBodies[0]).toMatchObject({
      subject_id: 11,
      source_mode: 'material',
      topic: 'Algebra',
      use_broad: false,
    });
    expect(JSON.stringify(customQuizBodies[0])).toContain('question_types');
    expect(JSON.stringify(customQuizBodies[0])).toContain('type_counts');
    expect(JSON.stringify(customQuizBodies[0])).toContain('difficulty');

    await page.waitForTimeout(900);
    const nonWhitePixels = await countNonWhitePixels(page);
    expect(nonWhitePixels).toBeGreaterThan(5000);

    const pageText = await readFlutterHostText(page);
    if (pageText.length > 0) {
      expect(pageText).toContain('Playwright');
    }
    expect(errors()).toEqual([]);
  });
});

async function loginAsQuizUser(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('quiz-smoke-token'),
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

async function readFlutterHostText(page: Page): Promise<string> {
  return page.evaluate(() => {
    const host =
      document.querySelector('flt-glass-pane') ||
      document.querySelector('flutter-view') ||
      document.body;
    return host.textContent?.trim() ?? '';
  });
}

async function selectFirstSubject(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');

  const x = viewport.width / 2;
  const candidateYs =
    viewport.width >= 800
      ? [viewport.height / 2 + 60, viewport.height / 2 + 95, viewport.height / 2 + 130]
      : [viewport.height / 2 + 40, viewport.height / 2 + 80, viewport.height / 2 + 120];

  for (const y of candidateYs) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(800);
    if (await hasRequestedPastExams(page)) return;
  }
}

async function hasRequestedPastExams(page: Page): Promise<boolean> {
  return page.evaluate(() => {
    const entries = performance.getEntriesByType('resource');
    return entries.some((entry) => entry.name.includes('/api/past-exams'));
  });
}

async function triggerCustomQuizGeneration(page: Page, bodies: unknown[]) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');

  const positions =
    viewport.width >= 800
      ? [
          [viewport.width * 0.33, viewport.height - 120],
          [viewport.width * 0.33, viewport.height - 84],
          [viewport.width * 0.33, viewport.height - 52],
          [viewport.width * 0.5, viewport.height - 84],
        ]
      : [
          [viewport.width / 2, viewport.height - 96],
          [viewport.width / 2, viewport.height - 64],
          [viewport.width / 2, viewport.height - 42],
        ];

  for (let attempt = 0; attempt < 4; attempt += 1) {
    for (const [x, y] of positions) {
      await page.mouse.click(x, y);
      await page.waitForTimeout(700);
      if (bodies.length > 0) return;
    }
    await page.mouse.wheel(0, 650);
    await page.waitForTimeout(500);
  }
  throw new Error('Custom quiz generate button did not submit a request');
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

async function installQuizMocks(page: Page) {
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
        username: 'quiz-smoke',
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
          name: 'Playwright Algebra',
          category: 'math',
          description: 'Mock subject for quiz flow',
          is_pinned: false,
          is_archived: false,
          color_index: 2,
          created_at: '2026-06-03T08:00:00',
        },
      ]),
    });
  });

  await page.route('**/api/past-exams**', async (route) => {
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

async function mockCustomQuiz(page: Page, bodies: unknown[]) {
  await page.route('**/api/exam/custom', async (route) => {
    const request = route.request();
    bodies.push(request.postDataJSON());
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        result:
          '# Playwright Generated Quiz\n\n1. If x + 2 = 5, what is x?\n\nAnswer: x = 3',
      }),
    });
  });
}
