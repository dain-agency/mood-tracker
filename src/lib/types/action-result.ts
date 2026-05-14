/**
 * Standard return type for all server actions.
 * Every action returns this shape — no exceptions.
 *
 * Usage:
 *   async function createResident(input: CreateResidentInput): Promise<ActionResult<Resident>>
 */

export type ActionResult<T = void> = 
  | { success: true; data: T }
  | { success: false; error: string; fieldErrors?: Record<string, string[]> };

/**
 * Helper to create success results.
 */
export function success<T>(data: T): ActionResult<T> {
  return { success: true, data };
}

/**
 * Helper to create error results.
 */
export function failure(error: string, fieldErrors?: Record<string, string[]>): ActionResult<never> {
  return { success: false, error, fieldErrors };
}

/**
 * Type guard: narrow ActionResult to success case.
 */
export function isSuccess<T>(result: ActionResult<T>): result is { success: true; data: T } {
  return result.success === true;
}