import { expect, test, type Page } from '@playwright/test';

test.describe('SUBJECT/DOC/RAG-P1 subject and resource flows', () => {
  test.beforeEach(async ({ page }) => {
    await installSubjectResourceMocks(page);
    await loginAsResourceUser(page);
  });

  test('SUBJECT-P1-01 subject can be created from profile subject manager', async ({ page }) => {
    const createBodies: unknown[] = [];
    await mockSubjectCreate(page, createBodies);

    await page.goto('/#/profile/subjects');
    await waitForFlutter(page);

    await openSubjectCreateSheet(page);
    await fillSubjectForm(page, {
      name: 'Playwright Physics',
      category: 'science',
      description: 'Created by Playwright acceptance test',
    });
    await submitSubjectForm(page, createBodies);

    await expect
      .poll(async () => createBodies.length, { timeout: 15000 })
      .toBe(1);

    expect(createBodies[0]).toMatchObject({
      name: 'Playwright Physics',
      category: 'science',
      description: 'Created by Playwright acceptance test',
    });
    expect(JSON.stringify(createBodies[0])).toContain('color_index');
  });

  test('DOC-P1-01 resource library can read material status and reindex all', async ({ page }) => {
    const reindexAllRequests: string[] = [];
    await mockDocumentActions(page, {
      reindexAllRequests,
    });

    await page.goto('/#/profile/resources/11');
    await waitForFlutter(page);

    await triggerReindexAll(page, reindexAllRequests);
    await expect
      .poll(async () => reindexAllRequests.length, { timeout: 15000 })
      .toBe(1);
    expect(reindexAllRequests[0]).toContain('subject_id=11');
  });
});

async function loginAsResourceUser(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('subject-resource-smoke-token'),
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

async function openSubjectCreateSheet(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  await page.mouse.click(viewport.width - 52, viewport.height - 56);
  await page.waitForTimeout(900);
}

async function fillSubjectForm(
  page: Page,
  values: { name: string; category: string; description: string },
) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');

  const fieldX = viewport.width / 2;
  const centers =
    viewport.width >= 800
      ? [476, 536, 604]
      : [viewport.height - 282, viewport.height - 216, viewport.height - 142];

  await page.mouse.click(fieldX, centers[0]);
  await page.keyboard.type(values.name);
  await page.mouse.click(fieldX, centers[1]);
  await page.keyboard.type(values.category);
  await page.mouse.click(fieldX, centers[2]);
  await page.keyboard.type(values.description);
}

async function submitSubjectForm(page: Page, bodies: unknown[]) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const candidates = [
    [viewport.width / 2, viewport.width >= 800 ? 676 : viewport.height - 48],
    [viewport.width / 2, viewport.height - 48],
    [viewport.width / 2, viewport.height - 68],
    [viewport.width / 2, viewport.height - 92],
  ];
  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(800);
    if (bodies.length > 0) return;
  }
  throw new Error('Subject create form did not submit');
}

async function triggerReindexAll(page: Page, requests: string[]) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const candidates =
    viewport.width >= 800
      ? [
          [viewport.width - 36, 320],
          [viewport.width - 52, 320],
          [viewport.width - 36, 304],
        ]
      : [
          [viewport.width - 36, 320],
          [viewport.width - 52, 320],
          [viewport.width - 36, 350],
        ];

  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(700);
    if (requests.length > 0) return;
  }
  throw new Error('Reindex-all button did not submit');
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

async function installSubjectResourceMocks(page: Page) {
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
        username: 'subject-resource-smoke',
        avatar_base64: null,
      }),
    });
  });

  await page.route('**/api/subjects**', async (route) => {
    if (route.request().method() === 'POST') return route.fallback();
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([subjectJson()]),
    });
  });

  await page.route('**/api/documents/knowledge-base**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        subject_id: 11,
        status: 'ready',
        document_count: 1,
        chunk_count: 8,
        mindmap_ready: true,
        updated_at: '2026-06-04T08:00:00',
      }),
    });
  });

  await page.route('**/api/documents?**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([documentJson()]),
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

async function mockSubjectCreate(page: Page, bodies: unknown[]) {
  await page.route('**/api/subjects', async (route) => {
    if (route.request().method() !== 'POST') return route.fallback();
    bodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(
        subjectJson({
          id: 12,
          name: 'Playwright Physics',
          category: 'science',
          description: 'Created by Playwright acceptance test',
        }),
      ),
    });
  });
}

async function mockDocumentActions(
  page: Page,
  requests: {
    reindexAllRequests: string[];
  },
) {
  await page.route('**/api/documents/reindex-all**', async (route) => {
    requests.reindexAllRequests.push(route.request().url());
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ ok: true }),
    });
  });

}

function subjectJson(overrides: Record<string, unknown> = {}) {
  return {
    id: 11,
    name: 'Playwright Algebra',
    category: 'math',
    description: 'Mock subject for resource tests',
    is_pinned: false,
    is_archived: false,
    color_index: 2,
    created_at: '2026-06-04T08:00:00',
    ...overrides,
  };
}

function documentJson(overrides: Record<string, unknown> = {}) {
  return {
    id: 701,
    filename: 'playwright-algebra.pdf',
    status: 'completed',
    processing_stage: 'indexed',
    progress: 100,
    parser_backend: 'mock-parser',
    chunk_count: 8,
    mindmap_ready: true,
    error: null,
    created_at: '2026-06-04T08:00:00',
    ...overrides,
  };
}
