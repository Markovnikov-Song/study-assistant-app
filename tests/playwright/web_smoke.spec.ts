import { expect, test, type Page } from '@playwright/test';

const routes = [
  { path: '/', name: 'root' },
  { path: '/login', name: 'login' },
  {
    path: '/toolkit/memory-drill?topic=Vocabulary&count=3&content_type=vocabulary',
    name: 'memory drill',
    auth: true,
  },
  {
    path: '/toolkit/quiz?topic=Algebra&count=2',
    name: 'quiz',
    auth: true,
  },
  { path: '/toolkit/calendar', name: 'calendar', auth: true },
];

test.beforeEach(async ({ page }) => {
  await installApiMocks(page);
});

for (const route of routes) {
  test(`${route.name} route renders without fatal browser errors`, async ({ page }) => {
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

    if (route.auth) {
      await page.addInitScript(() => {
        window.localStorage.setItem('flutter.access_token', 'smoke-token');
      });
    }

    await page.goto(route.path);
    await waitForFlutter(page);

    const bodyBox = await page.locator('body').boundingBox();
    expect(bodyBox?.width ?? 0).toBeGreaterThan(300);
    expect(bodyBox?.height ?? 0).toBeGreaterThan(300);
    expect(errors).toEqual([]);
    expect(failedRequests).toEqual([]);
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

async function installApiMocks(page: Page) {
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
      body: JSON.stringify({ ok: true, items: [] }),
    });
  });
}
