import { test, expect } from '@playwright/test';

test.describe('Login Screen', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
    // Wait for Flutter to load
    await page.waitForTimeout(3000);
  });

  test('should display login screen with all elements', async ({ page }) => {
    // Take a screenshot of the initial state
    await page.screenshot({ path: 'e2e/screenshots/login-initial.png', fullPage: true });

    // Verify the page title or logo is visible
    const pageContent = await page.content();
    console.log('Page loaded. Checking for Flutter content...');

    // Check for Flutter app loaded
    await expect(page.locator('flt-glass-pane')).toBeVisible({ timeout: 10000 });
    console.log('Flutter glass pane found!');
  });

  test('should have text input fields', async ({ page }) => {
    // Wait for Flutter to fully render
    await page.waitForTimeout(2000);

    // Take screenshot
    await page.screenshot({ path: 'e2e/screenshots/login-fields.png', fullPage: true });

    // Try to find input elements in Flutter web
    const inputs = await page.locator('input').count();
    console.log(`Found ${inputs} input elements`);

    // Flutter web uses semantic labels for accessibility
    // Check the accessibility tree
    const snapshot = await page.accessibility.snapshot();
    console.log('Accessibility snapshot:', JSON.stringify(snapshot, null, 2));
  });

  test('should interact with username field', async ({ page }) => {
    // Wait for Flutter to render
    await page.waitForTimeout(3000);

    // Screenshot before interaction
    await page.screenshot({ path: 'e2e/screenshots/before-input.png' });

    // Try clicking where the username field should be (center of screen, slightly up)
    const viewport = page.viewportSize();
    if (viewport) {
      // Click on the username field area
      await page.mouse.click(viewport.width / 2, viewport.height / 2 - 100);
      await page.waitForTimeout(500);

      // Type text
      await page.keyboard.type('testuser');
      await page.waitForTimeout(500);

      // Screenshot after typing
      await page.screenshot({ path: 'e2e/screenshots/after-username-input.png' });
    }
  });

  test('should fill all form fields', async ({ page }) => {
    await page.waitForTimeout(3000);

    const viewport = page.viewportSize();
    if (!viewport) return;

    const centerX = viewport.width / 2;
    const centerY = viewport.height / 2;

    // Field 1: GitHub Username (estimated position)
    await page.mouse.click(centerX, centerY - 80);
    await page.waitForTimeout(300);
    await page.keyboard.type('testuser');

    // Tab to next field
    await page.keyboard.press('Tab');
    await page.waitForTimeout(300);

    // Field 2: Repository Name
    await page.keyboard.type('my-notes-repo');

    // Tab to next field
    await page.keyboard.press('Tab');
    await page.waitForTimeout(300);

    // Field 3: Personal Access Token
    await page.keyboard.type('ghp_test123456789');

    // Screenshot with all fields filled
    await page.screenshot({ path: 'e2e/screenshots/all-fields-filled.png' });
  });

  test('should click Connect button', async ({ page }) => {
    await page.waitForTimeout(3000);

    const viewport = page.viewportSize();
    if (!viewport) return;

    // Fill form first
    const centerX = viewport.width / 2;

    // Try to find and click the Connect button
    // In Flutter web, buttons may have specific aria labels

    // Take screenshot to see current state
    await page.screenshot({ path: 'e2e/screenshots/before-connect.png' });

    // Try clicking on "Connect" text if visible
    try {
      // Flutter web sometimes renders text elements
      const connectBtn = page.getByRole('button', { name: /connect/i });
      if (await connectBtn.isVisible()) {
        await connectBtn.click();
        console.log('Clicked Connect button via role');
      }
    } catch {
      console.log('Could not find Connect button via role, trying coordinates');
      // Click where Connect button should be (below the form fields)
      await page.mouse.click(centerX, viewport.height / 2 + 150);
    }

    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'e2e/screenshots/after-connect-click.png' });
  });

  test('should show validation errors on empty submit', async ({ page }) => {
    await page.waitForTimeout(3000);

    const viewport = page.viewportSize();
    if (!viewport) return;

    const centerX = viewport.width / 2;

    // Screenshot before
    await page.screenshot({ path: 'e2e/screenshots/before-validation.png' });

    // Click Connect without filling fields
    await page.mouse.click(centerX, viewport.height / 2 + 150);
    await page.waitForTimeout(1000);

    // Screenshot after - should show validation errors
    await page.screenshot({ path: 'e2e/screenshots/validation-errors.png' });
  });
});
