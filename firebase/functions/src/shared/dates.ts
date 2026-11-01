import { z } from 'zod';

const INDIA_OFFSET_MILLISECONDS = 330 * 60 * 1000;
const MILLISECONDS_PER_DAY = 86_400_000;

/** A calendar day as `yyyy-MM-dd`. */
export const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

/** Today's date in India Standard Time as `yyyy-MM-dd`. */
export const todayIST = () => new Date(Date.now() + INDIA_OFFSET_MILLISECONDS).toISOString().slice(0, 10);

const toMilliseconds = (date: string) => Date.parse(`${date}T00:00:00Z`);

export const addDays = (date: string, days: number) => new Date(toMilliseconds(date) + days * MILLISECONDS_PER_DAY).toISOString().slice(0, 10);

/** Whole days from [from] to [to] (negative when [to] is earlier). */
export const daysBetween = (from: string, to: string) => Math.round((toMilliseconds(to) - toMilliseconds(from)) / MILLISECONDS_PER_DAY);

/** Week number since the epoch, so a reminder can repeat weekly with a stable key. */
export const weekOf = (date: string) => Math.floor(toMilliseconds(date) / (7 * MILLISECONDS_PER_DAY));
