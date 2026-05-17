/**
 * Heartbeat HTTP client for the dain-os Monitoring Hub ingest.
 *
 * Copied verbatim from `packages/monitoring-client/src/index.ts` in the
 * dain-os monorepo (see docs/monitoring/heartbeat-integration.md there).
 * Kept as a single file with zero transitive deps so it works on any
 * Node 18+ runtime, including Vercel functions.
 */

export type HeartbeatStatus =
  | 'started'
  | 'completed'
  | 'failed'
  | 'timeout';

export interface SendHeartbeatOptions {
  /** Absolute URL to /api/v1/monitoring/external-crons/heartbeat. */
  endpoint: string;
  /** Value of MONITORING_HEARTBEAT_SECRET on the receiver. */
  secret: string;
  provider: string;
  projectRef: string;
  externalId: string;
  status: HeartbeatStatus;
  startedAt: Date;
  finishedAt?: Date | null;
  durationMs?: number | null;
  returnMessage?: string | null;
  externalRunId?: string | null;
  projectName?: string;
  displayName?: string;
  scheduleExpression?: string;
  scheduleTimezone?: string | null;
  commandOrPath?: string | null;
  rawPayload?: Record<string, unknown>;
  /** Override the global fetch (for tests). */
  fetchImpl?: typeof fetch;
  /** Optional timeout in ms. Default: 5000. */
  timeoutMs?: number;
}

export interface HeartbeatResponse {
  sourceId: string;
  runId: string | null;
}

interface ApiEnvelope<T> {
  success: boolean;
  data?: T;
  error?: { code?: string; message?: string };
}

const DEFAULT_TIMEOUT_MS = 5_000;

export async function sendHeartbeat(
  opts: SendHeartbeatOptions,
): Promise<HeartbeatResponse> {
  const fetchImpl = opts.fetchImpl ?? globalThis.fetch;
  if (!fetchImpl) {
    throw new Error('sendHeartbeat: no fetch implementation available');
  }

  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    opts.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  );

  try {
    const body: Record<string, unknown> = {
      provider: opts.provider,
      projectRef: opts.projectRef,
      externalId: opts.externalId,
      status: opts.status,
      startedAt: opts.startedAt.toISOString(),
    };
    if (opts.finishedAt !== undefined && opts.finishedAt !== null) {
      body.finishedAt = opts.finishedAt.toISOString();
    }
    if (opts.durationMs !== undefined && opts.durationMs !== null) {
      body.durationMs = opts.durationMs;
    }
    if (opts.returnMessage !== undefined && opts.returnMessage !== null) {
      body.returnMessage = opts.returnMessage;
    }
    if (opts.externalRunId !== undefined && opts.externalRunId !== null) {
      body.externalRunId = opts.externalRunId;
    }
    if (opts.projectName !== undefined) body.projectName = opts.projectName;
    if (opts.displayName !== undefined) body.displayName = opts.displayName;
    if (opts.scheduleExpression !== undefined) {
      body.scheduleExpression = opts.scheduleExpression;
    }
    if (opts.scheduleTimezone !== undefined && opts.scheduleTimezone !== null) {
      body.scheduleTimezone = opts.scheduleTimezone;
    }
    if (opts.commandOrPath !== undefined && opts.commandOrPath !== null) {
      body.commandOrPath = opts.commandOrPath;
    }
    if (opts.rawPayload !== undefined) body.rawPayload = opts.rawPayload;

    const response = await fetchImpl(opts.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${opts.secret}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    if (!response.ok) {
      const text = await safeReadText(response);
      throw new Error(
        `sendHeartbeat: ${response.status} ${response.statusText}${text ? ` — ${text}` : ''}`,
      );
    }

    const envelope = (await response.json()) as ApiEnvelope<HeartbeatResponse>;
    if (!envelope.success || !envelope.data) {
      throw new Error(
        `sendHeartbeat: unexpected response shape${envelope.error?.message ? ` — ${envelope.error.message}` : ''}`,
      );
    }
    return envelope.data;
  } finally {
    clearTimeout(timeout);
  }
}

async function safeReadText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch {
    return '';
  }
}

export interface WrapHeartbeatOptions
  extends Omit<
    SendHeartbeatOptions,
    'status' | 'startedAt' | 'finishedAt' | 'durationMs' | 'returnMessage'
  > {
  /**
   * Called when a heartbeat fails. The wrapped fn is unaffected — its
   * result/throw flows out of wrapWithHeartbeat regardless.
   * Default: no-op. `externalRunId` is inherited from SendHeartbeatOptions
   * and threaded through every emitted heartbeat automatically.
   */
  onError?: (phase: 'started' | 'completed' | 'failed', err: unknown) => void;
}

/**
 * Wrap an async function with start + finish heartbeats.
 *
 * Always returns or throws what `fn` does — heartbeat failures are caught
 * and routed to `onError`. This keeps monitoring opt-in: if the receiver is
 * down, the cron still runs to completion.
 */
export async function wrapWithHeartbeat<T>(
  opts: WrapHeartbeatOptions,
  fn: () => Promise<T>,
): Promise<T> {
  const startedAt = new Date();
  const onError = opts.onError ?? noopOnError;

  await safeBeat(onError, 'started', () =>
    sendHeartbeat({
      ...opts,
      status: 'started',
      startedAt,
    }),
  );

  try {
    const result = await fn();
    const finishedAt = new Date();
    await safeBeat(onError, 'completed', () =>
      sendHeartbeat({
        ...opts,
        status: 'completed',
        startedAt,
        finishedAt,
        durationMs: finishedAt.getTime() - startedAt.getTime(),
      }),
    );
    return result;
  } catch (err) {
    const finishedAt = new Date();
    const message = err instanceof Error ? err.message : String(err);
    await safeBeat(onError, 'failed', () =>
      sendHeartbeat({
        ...opts,
        status: 'failed',
        startedAt,
        finishedAt,
        durationMs: finishedAt.getTime() - startedAt.getTime(),
        returnMessage: message.slice(0, 2000),
      }),
    );
    throw err;
  }
}

function noopOnError(): void {
  /* default: swallow heartbeat errors */
}

async function safeBeat(
  onError: NonNullable<WrapHeartbeatOptions['onError']>,
  phase: 'started' | 'completed' | 'failed',
  fn: () => Promise<unknown>,
): Promise<void> {
  try {
    await fn();
  } catch (err) {
    onError(phase, err);
  }
}
