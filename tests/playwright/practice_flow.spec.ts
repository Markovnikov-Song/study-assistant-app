import { expect, test, type Page } from '@playwright/test';

test.describe('PRACTICE-P1 practice execution flow', () => {
  test.beforeEach(async ({ page }) => {
    await installPracticeMocks(page);
    await loginAsPracticeUser(page);
  });

  test('PRACTICE-P1-01 subject practice generates questions and submits an answer', async ({ page }) => {
    const generateBodies: unknown[] = [];
    const submitBodies: unknown[] = [];
    await mockGenerateQuiz(page, generateBodies);
    await mockSubmitAnswer(page, submitBodies);

    await page.goto('/#/toolkit/practice');
    await waitForFlutter(page);

    await openFirstSubjectPractice(page, generateBodies);
    await expect
      .poll(async () => generateBodies.length, { timeout: 15000 })
      .toBe(1);

    expect(generateBodies[0]).toMatchObject({
      node_id: 'subject-11',
      node_title: 'Playwright Algebra',
      question_count: 3,
    });

    await answerFirstQuestionIncorrectly(page, submitBodies);
    await expect
      .poll(async () => submitBodies.length, { timeout: 15000 })
      .toBe(1);

    expect(submitBodies[0]).toMatchObject({
      question_id: 'practice-q1',
      user_answer: 'B',
      node_id: 'subject-11',
      node_title: 'Playwright Algebra',
      question_type: 'choice',
      subject_id: 11,
    });
  });
});

async function loginAsPracticeUser(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem(
      'flutter.access_token',
      JSON.stringify('practice-smoke-token'),
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

async function openFirstSubjectPractice(page: Page, bodies: unknown[]) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');
  const x = viewport.width / 2;
  const candidates =
    viewport.width >= 800
      ? [360, 410, 460, 510]
      : [420, 450, 480, 510, 540];

  for (const y of candidates) {
    await page.mouse.click(x, Math.min(y, viewport.height - 80));
    await page.waitForTimeout(800);
    if (bodies.length > 0) return;
  }
  throw new Error('Subject practice did not request generated questions');
}

async function answerFirstQuestionIncorrectly(page: Page, bodies: unknown[]) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('Missing viewport size');

  const optionX = viewport.width / 2;
  const optionCandidates =
    viewport.width >= 800 ? [366, 372, 382] : [410, 445, 480, 515];
  for (const y of optionCandidates) {
    await page.mouse.click(optionX, Math.min(y, viewport.height - 180));
    await page.waitForTimeout(250);
  }

  const submitCandidates =
    viewport.width >= 800 ? [440, 448, 456] : [540, 580, 620, 660];
  for (const y of submitCandidates) {
    await page.mouse.click(optionX, y);
    await page.waitForTimeout(700);
    if (bodies.length > 0) return;
  }
  throw new Error('Practice answer was not submitted');
}

async function installPracticeMocks(page: Page) {
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
        username: 'practice-smoke',
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
          description: 'Mock subject for practice flow',
          is_pinned: false,
          is_archived: false,
          color_index: 2,
          created_at: '2026-06-03T08:00:00',
        },
      ]),
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

async function mockGenerateQuiz(page: Page, bodies: unknown[]) {
  await page.route('**/api/quiz/generate', async (route) => {
    bodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        total_count: 1,
        questions: [
          {
            id: 'practice-q1',
            type: 'choice',
            difficulty: 'L1',
            difficulty_label: '基础',
            question: 'If x + 2 = 5, what is x?',
            options: [
              { key: 'A', content: '3', is_correct: true },
              { key: 'B', content: '4', is_correct: false },
            ],
            correct_answer: 'A',
            explanation: 'Subtract 2 from both sides.',
            source_node_id: 'subject-11',
            source_node_title: 'Playwright Algebra',
            knowledge_zone: 'current',
          },
        ],
        boundary_info: {},
        message: 'ok',
      }),
    });
  });
}

async function mockSubmitAnswer(page: Page, bodies: unknown[]) {
  await page.route('**/api/quiz/submit-answer', async (route) => {
    bodies.push(route.request().postDataJSON());
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        question_id: 'practice-q1',
        user_answer: 'B',
        correct: false,
        correct_answer: 'A',
        message: '答错了，已尝试加入错题本',
        added_to_mistake_book: true,
        review_card_id: 900,
      }),
    });
  });
}
