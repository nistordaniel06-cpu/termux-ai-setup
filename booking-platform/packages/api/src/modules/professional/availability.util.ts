export type Interval = { start: Date; end: Date };

/**
 * All times in this module are treated as UTC wall-clock ("HH:mm" on a given
 * calendar day). Phase 1 deliberately does not do per-business timezone
 * conversion — see docs/ARCHITECTURE.md.
 */
export function combineDateAndTime(date: Date, hhmm: string): Date {
  const [hours, minutes] = hhmm.split(":").map(Number);
  const combined = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), hours, minutes, 0, 0)
  );
  return combined;
}

/** Subtracts `blocked` intervals from `windows`, returning the remaining open intervals. */
export function subtractIntervals(windows: Interval[], blocked: Interval[]): Interval[] {
  let result = windows;
  for (const block of blocked) {
    const next: Interval[] = [];
    for (const window of result) {
      if (block.end <= window.start || block.start >= window.end) {
        next.push(window);
        continue;
      }
      if (block.start > window.start) {
        next.push({ start: window.start, end: new Date(Math.min(block.start.getTime(), window.end.getTime())) });
      }
      if (block.end < window.end) {
        next.push({ start: new Date(Math.max(block.end.getTime(), window.start.getTime())), end: window.end });
      }
    }
    result = next.filter((w) => w.start < w.end);
  }
  return result;
}

/** Candidate slot start times, stepped every `granularityMinutes`, fully contained in a window. */
export function generateCandidateSlots(
  windows: Interval[],
  durationMinutes: number,
  granularityMinutes = 15
): Date[] {
  const slots: Date[] = [];
  const stepMs = granularityMinutes * 60_000;
  const durationMs = durationMinutes * 60_000;

  for (const window of windows) {
    for (let t = window.start.getTime(); t + durationMs <= window.end.getTime(); t += stepMs) {
      slots.push(new Date(t));
    }
  }
  return slots;
}

export function overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
  return aStart < bEnd && bStart < aEnd;
}
