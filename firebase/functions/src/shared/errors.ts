import { randomUUID } from 'node:crypto';
import { logger } from 'firebase-functions/v2';
import { HttpsError } from 'firebase-functions/v2/https';
import type { z } from 'zod';

/**
 * Central error handling for every function. To add an external error tracker
 * (Sentry, Datadog, …) implement [ErrorReporter] and call [setErrorReporter] once
 * in `index.ts`; nothing else in the codebase needs to change.
 */

export interface ErrorReport {
  /** Function that failed, e.g. `inventory.asset.assign`. */
  name: string;
  /** Short reference the user can quote to support; also in the log line. */
  errorId: string;
  /** `error` = our fault, `warning` = expected rejection (bad input, no permission…). */
  severity: 'error' | 'warning';
  /** Original error, with stack. */
  error: unknown;
  /** Safe identifiers only (uid, branch). Never request payloads, tokens or biometrics. */
  context: Record<string, unknown>;
}

export interface ErrorReporter {
  report(report: ErrorReport): void;
}

/** Default: structured Cloud Logging entries (errors also land in Error Reporting). */
export const cloudLoggingReporter: ErrorReporter = {
  report({ name, errorId, severity, error, context }) {
    const code = error instanceof HttpsError ? error.code : 'internal';
    const detail = error instanceof Error ? error.message : String(error);
    const fields = { ...context, function: name, errorId, code };
    if (severity === 'warning') logger.warn(`${name} was rejected (${code}): ${detail}`, fields);
    else logger.error(`${name} failed (${code}): ${detail}`, error, fields);
  },
};

let reporter: ErrorReporter = cloudLoggingReporter;
export const setErrorReporter = (next: ErrorReporter) => {
  reporter = next;
};

// Codes that mean our side failed; the rest are caller mistakes.
const SERVER_CODES = new Set([
  'internal',
  'unknown',
  'data-loss',
  'unavailable',
  'deadline-exceeded',
]);

/** `libraryCopyId` → `Library copy`. */
const humanize = (path: PropertyKey[]) => {
  const words = (path.filter((part) => typeof part === 'string').at(-1) ?? 'details')
    .replace(/Id$/, '')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .toLowerCase();
  return words.charAt(0).toUpperCase() + words.slice(1);
};

/** Turns a zod failure into a message people can act on. */
export function invalidInput(error: z.ZodError): HttpsError {
  const fields = [...new Set(error.issues.map((issue) => humanize(issue.path)))];
  return new HttpsError('invalid-argument', `Please check ${fields.join(', ')} and try again.`, {
    fields,
  });
}

/** Safe to show anyone: no internals, no stack, no ids. */
export const SOMETHING_WENT_WRONG =
  'Something went wrong on our side. Please try again in a moment.';

/**
 * Runs [run], reports every failure through the [ErrorReporter] and rethrows an
 * error whose message is safe to show the user. Unexpected errors become a generic
 * `internal` carrying an `errorId` (also in the log) so support can find them.
 */
export async function logged<R>(
  name: string,
  context: Record<string, unknown>,
  run: () => Promise<R>,
): Promise<R> {
  try {
    return await run();
  } catch (error) {
    const errorId = randomUUID().slice(0, 8);
    const expected = error instanceof HttpsError && !SERVER_CODES.has(error.code);
    reporter.report({ name, errorId, severity: expected ? 'warning' : 'error', error, context });
    if (expected) throw error;
    throw new HttpsError('internal', `${SOMETHING_WENT_WRONG} (Reference: ${errorId})`, {
      errorId,
    });
  }
}
