import { expect, test, type Page } from '@playwright/test';

test.describe('MISTAKE-P1 mistake book review flow', () => {
  test.beforeEach(async ({ page }) => {
    await installMistakeMocks(page);
    await loginAsMistakeUser(page);
  });

  test('MISTAKE-P1-01 pending mistake can be reviewed and submitted', async ({ page }) => {
    const submitBodies: unknown[] = [];
    await mockReviewSubmit(page, submitBodies);

    await page.goto('/#/toolkit/mistake-book');
    await waitForFlutter(page);

    await openFirstPendingMistake(page);
    await advanceToRatingStep(page);
    await chooseStrongRecall(page);
    await submitReview(page, submitBodies);

    await expect
      .poll(async () => submitBodies.length, { timeout: 15000 })
      .toBe(1);

    const submitBody = submitBodies[0] as Record<string, unknown>;
    expect(submitBody).toMatchObject({
      note_id: 501,
    });
    expect(typeof submitBody.quality).toBe('number');
    expect(submitBody.quality as number).toBeGreaterThanOrEqual(0);
    expect(submitBody.quality as number).toBeLessThanOrEqual(3);
    expect(JSON.stringify(submitBody)).toContain('review_content');
  });
});

async function loginAsMistakeUser(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('mistake-smoke-token'),
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

async function openFirstPendingMistake(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');

  const x = viewport.width / 2;
  const candidates =
    viewport.width >= 800 ? [156, 184, 216, 248] : [170, 210, 250, 290];
  for (const y of candidates) {
    await page.mouse.click(x, Math.min(y, viewport.height - 96));
    await page.waitForTimeout(700);
    if (await currentRouteIncludes(page, 'ReviewSessionPage')) return;
  }

  // Flutter's Navigator route is not reflected in the hash; a visible step change
  // after pressing the bottom action is the practical signal that the card opened.
  await clickBottomPrimary(page);
  await page.waitForTimeout(500);
}

async function advanceToRatingStep(page: Page) {
  for (let i = 0; i < 4; i += 1) {
    await clickBottomPrimary(page);
    await page.waitForTimeout(500);
  }
}

async function chooseStrongRecall(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');

  const xCandidates =
    viewport.width >= 800
      ? [viewport.width / 2 + 220, viewport.width / 2 + 160, viewport.width / 2]
      : [viewport.width / 2, viewport.width / 2 + 80, viewport.width / 2 - 80];
  const yCandidates =
    viewport.width >= 800
      ? [viewport.height / 2 + 60, viewport.height / 2 + 120, viewport.height / 2]
      : [viewport.height / 2 + 140, viewport.height / 2 + 90, viewport.height / 2 + 40];

  for (const y of yCandidates) {
    for (const x of xCandidates) {
      await page.mouse.click(x, Math.min(y, viewport.height - 112));
      await page.waitForTimeout(250);
    }
  }
}

async function submitReview(page: Page, bodies: unknown[]) {
  for (let i = 0; i < 4; i += 1) {
    await clickBottomPrimary(page);
    await page.waitForTimeout(800);
    if (bodies.length > 0) return;
  }
  throw new Error('Review submit button did not submit a request');
}

async function clickBottomPrimary(page: Page) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');

  const candidates =
    viewport.width >= 800
      ? [
          [viewport.width - 86, viewport.height - 40],
          [viewport.width - 126, viewport.height - 40],
          [viewport.width - 168, viewport.height - 40],
        ]
      : [
          [viewport.width - 74, viewport.height - 38],
          [viewport.width - 118, viewport.height - 38],
          [viewport.width - 160, viewport.height - 38],
        ];

  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(120);
  }
}

async function currentRouteIncludes(page: Page, needle: string): Promise<boolean> {
  return page.evaluate((value) => {
    return window.location.href.includes(value);
  }, needle);
}

async function installMistakeMocks(page: Page) {
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
        username: 'mistake-smoke',
        avatar_base64: null,
      }),
    });
  });

  await page.route('**/api/review/mistakes**', async (route) => {
    const url = new URL(route.request().url());
    const status = url.searchParams.get('status');
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(status === 'reviewed' ? [] : [mistakeJson()]),
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

async function mockReviewSubmit(page: Page, bodies: unknown[]) {
  await page.route('**/api/review/review/submit', async (route) => {
    bodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        note_id: 501,
        mistake_status: 'reviewed',
        sm2_result: {
          interval_days: 3,
          mastery_score: 3,
          ease_factor: 2.6,
        },
        message: 'review submitted',
      }),
    });
  });
}

function mistakeJson() {
  return {
    id: 501,
    notebook_id: 9,
    subject_id: 11,
    title: 'Playwright quadratic mistake',
    content: 'I used the wrong sign when expanding (x - 2)^2.',
    note_type: 'mistake',
    mistake_status: 'pending',
    node_id: 'node-quadratic',
    question_text: 'Expand (x - 2)^2.',
    user_answer: 'x^2 - 4',
    correct_answer: 'x^2 - 4x + 4',
    mistake_category: 'sign',
    review_card_id: 9001,
    mastery_score: 1,
    review_count: 0,
    last_reviewed_at: null,
    created_at: '2026-06-03T08:00:00',
    updated_at: '2026-06-03T08:00:00',
  };
}
