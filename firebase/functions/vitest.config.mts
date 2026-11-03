import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    setupFiles: ['test/setup.ts'],
    fileParallelism: false, // emulator tests share one Firestore
  },
});
