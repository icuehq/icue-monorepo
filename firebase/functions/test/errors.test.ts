import { HttpsError } from 'firebase-functions/v2/https';
import { afterEach, describe, expect, it } from 'vitest';
import { z } from 'zod';
import {
  cloudLoggingReporter,
  invalidInput,
  logged,
  setErrorReporter,
  type ErrorReport,
} from '../src/shared/errors';

const reports: ErrorReport[] = [];
setErrorReporter({ report: (report) => reports.push(report) });
afterEach(() => (reports.length = 0));

describe('logged', () => {
  it('reports expected rejections as warnings and rethrows them untouched', async () => {
    const original = new HttpsError('permission-denied', 'You do not have permission to do this.');
    await expect(logged('fn', { uid: '1' }, () => Promise.reject(original))).rejects.toBe(original);
    expect(reports).toMatchObject([{ severity: 'warning', name: 'fn', context: { uid: '1' } }]);
  });

  it('hides unexpected errors behind a friendly message with a matching reference', async () => {
    const error = await logged('fn', {}, () => Promise.reject(new Error('db exploded'))).catch(
      (e) => e,
    );
    expect(error).toBeInstanceOf(HttpsError);
    expect(error.code).toBe('internal');
    expect(error.message).not.toContain('exploded');
    expect(error.message).toContain(reports[0].errorId);
    expect(reports[0]).toMatchObject({ severity: 'error' });
  });

  it('treats server-side HttpsErrors as our fault', async () => {
    await logged('fn', {}, () => Promise.reject(new HttpsError('unavailable', 'x'))).catch(
      () => {},
    );
    expect(reports[0].severity).toBe('error');
  });
});

describe('invalidInput', () => {
  it('names the fields in plain words', () => {
    const result = z.object({ itemId: z.string(), expiryDate: z.string() }).safeParse({});
    expect(invalidInput(result.error!).message).toBe(
      'Please check Item, Expiry date and try again.',
    );
  });
});

it('exports the default reporter for tests and wrappers', () =>
  expect(cloudLoggingReporter.report).toBeTypeOf('function'));
