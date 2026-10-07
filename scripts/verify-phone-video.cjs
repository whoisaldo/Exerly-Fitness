// Exercise the delivered MP4 through the landing page's real browser controls.
/* global document, innerWidth */
const { chromium, expect } = require('@playwright/test');
const fs = require('node:fs/promises');
const path = require('node:path');

async function main() {
  const destination = path.resolve('brag-output/verification');
  await fs.mkdir(destination, { recursive: true });
  const browser = await chromium.launch({ channel: 'chrome' });
  const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3305';
  const results = [];
  try {
    for (const profile of [
      { name: 'desktop', viewport: { width: 1440, height: 1100 }, reducedMotion: 'no-preference' },
      {
        name: 'mobile',
        viewport: { width: 390, height: 844 },
        reducedMotion: 'reduce',
        isMobile: true,
        hasTouch: true,
      },
    ]) {
      const context = await browser.newContext(profile);
      const dimensions =
        profile.name === 'mobile' ? { width: 1080, height: 1920 } : { width: 1920, height: 1080 };
      const page = await context.newPage();
      const errors = [];
      const mediaRequests = [];
      page.on('pageerror', (error) => errors.push(error.message));
      page.on('request', (request) => {
        if (request.url().endsWith('.mp4')) mediaRequests.push(request.url());
      });
      await page.goto(baseURL);
      const section = page.getByRole('region', { name: 'Exerly product demo' });
      const play = page.getByRole('button', { name: 'Play iPhone logging video, 21 seconds' });
      await play.scrollIntoViewIfNeeded();
      await expect(play.locator('img')).toBeVisible();
      await expect
        .poll(() => play.locator('img').evaluate((img) => img.complete && img.naturalWidth))
        .toBe(dimensions.width);
      await expect(page.locator('video')).toHaveCount(0);
      expect(mediaRequests).toHaveLength(0);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
        true
      );
      await section.screenshot({ path: path.join(destination, `${profile.name}-poster.png`) });
      if (profile.name === 'desktop') {
        await play.focus();
        await page.keyboard.press('Enter');
      } else await play.tap();
      const video = section.locator('video');
      await expect
        .poll(() => video.evaluate((v) => v.currentTime), { timeout: 20000 })
        .toBeGreaterThan(0.2);
      const state = await video.evaluate((v) => {
        v.pause();
        v.currentTime = 19.5;
        v.textTracks[0].mode = 'hidden';
        return {
          duration: v.duration,
          controls: v.controls,
          inline: v.playsInline,
          width: v.videoWidth,
          height: v.videoHeight,
        };
      });
      expect(state.duration).toBeCloseTo(21, 1);
      expect(state).toMatchObject({ controls: true, inline: true, ...dimensions });
      await expect.poll(() => video.evaluate((v) => !v.seeking)).toBe(true);
      await expect
        .poll(() => video.evaluate((v) => v.textTracks[0].cues?.length || 0))
        .toBeGreaterThan(3);
      await section.screenshot({ path: path.join(destination, `${profile.name}-playback.png`) });
      await video.evaluate((v) => {
        v.currentTime = 20.5;
        return v.play();
      });
      await expect.poll(() => video.evaluate((v) => v.ended), { timeout: 8000 }).toBe(true);
      await expect(section.getByText('Video credits', { exact: true })).toHaveCount(0);
      expect(errors).toEqual([]);
      results.push({
        profile: profile.name,
        ...state,
        initialVideoRequests: 0,
        playback: 'passed',
        seek: 'passed',
        captions: 'passed',
        ended: 'passed',
        pageErrors: errors,
      });
      await context.close();
    }
    const page = await browser.newPage();
    await page.route('**/media/exerly-phone-logging.mp4', (route) => route.abort());
    await page.goto(baseURL);
    await page.getByRole('button', { name: 'Play iPhone logging video, 21 seconds' }).click();
    await expect(page.getByRole('status')).toContainText('The video could not load.');
    await expect(page.getByRole('link', { name: 'Open the video directly' })).toHaveAttribute(
      'href',
      '/media/exerly-phone-logging.mp4'
    );
    results.push({ profile: 'network failure', fallback: 'passed' });
    await fs.writeFile(
      path.join(destination, 'browser-results.json'),
      JSON.stringify(results, null, 2) + '\n'
    );
    console.log(JSON.stringify(results, null, 2));
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
