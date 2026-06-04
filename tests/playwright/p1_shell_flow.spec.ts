import { expect, test, type Page } from '@playwright/test';

const shellRoutes = [
  { id: 'SHELL-P1-01', path: '/#/', name: 'chat shell tab' },
  { id: 'SHELL-P1-01', path: '/#/course-space', name: 'course-space shell tab' },
  { id: 'SHELL-P1-01', path: '/#/toolkit', name: 'toolkit shell tab' },
  { id: 'SHELL-P1-01', path: '/#/profile', name: 'profile shell tab' },
];

const featureEntryRoutes = [
  { id: 'ENTRY-P1-01', path: '/#/toolkit/calendar', name: 'calendar entry' },
  { id: 'ENTRY-P1-02', path: '/#/toolkit/mistake-book', name: 'mistake book entry' },
  { id: 'ENTRY-P1-03', path: '/#/toolkit/notebooks', name: 'notebooks entry' },
  { id: 'ENTRY-P1-04', path: '/#/toolkit/quiz?topic=Algebra&count=2', name: 'quiz entry' },
  { id: 'ENTRY-P1-05', path: '/#/toolkit/practice', name: 'practice entry' },
  { id: 'ENTRY-P1-06', path: '/#/toolkit/review', name: 'legacy review compatibility entry' },
  { id: 'ENTRY-P1-07', path: '/#/workshop', name: 'software workshop entry' },
];

test.describe('P1 app shell and feature entries', () => {
  test.beforeEach(async ({ page }) => {
    await installP1ApiMocks(page);
  });

  test('AUTH-P1-01 protected routes redirect anonymous users to login', async ({ page }) => {
    await page.goto('/#/toolkit/calendar');
    await waitForFlutter(page);

    await expect(page).toHaveURL(/#\/login$/);
    await assertPageIsUsable(page);
  });

  for (const route of shellRoutes) {
    test(`${route.id} ${route.name} renders for authenticated users`, async ({ page }) => {
      await loginAsP1User(page);
      await assertRouteRenders(page, route.path);
    });
  }

  for (const route of featureEntryRoutes) {
    test(`${route.id} ${route.name} renders for authenticated users`, async ({ page }) => {
      await loginAsP1User(page);
      await assertRouteRenders(page, route.path);
    });
  }
});

async function assertRouteRenders(page: Page, path: string) {
  const errors = collectFatalBrowserErrors(page);

  await page.goto(path);
  await waitForFlutter(page);

  await expect(page).not.toHaveURL(/#\/login$/);
  await assertPageIsUsable(page);
  expect(errors()).toEqual([]);
}

async function assertPageIsUsable(page: Page) {
  const bodyBox = await page.locator('body').boundingBox();
  expect(bodyBox?.width ?? 0).toBeGreaterThan(300);
  expect(bodyBox?.height ?? 0).toBeGreaterThan(300);
  const screenshot = await page.screenshot({ fullPage: false });
  expect(screenshot.length).toBeGreaterThan(1000);
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

async function loginAsP1User(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('p1-smoke-token'),
    );
    window.localStorage.setItem(
      'flutter.onboarding.calculus_demo.seen.v1',
      JSON.stringify(true),
    );
  });
}

async function installP1ApiMocks(page: Page) {
  await page.route('**/api/users/me', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        user_id: 1,
        username: 'p1-smoke',
        avatar_base64: null,
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

  await page.route('**/api/mini-apps**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
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
