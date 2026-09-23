import API_CONFIG from '../../config';
import { api, ApiError, getSessionScope } from '../../lib/api';
import { operationID } from '../../lib/ids';
import type { SessionUser } from '../../hooks/useSession';
import {
  contentSignature,
  firstIncomplete,
  initialAnswers,
  normalizeContent,
  setupError,
  type RemoteSetupDraft,
  type SetupAnswers,
  type SetupContent,
  type SetupPreview,
  type SetupStatus,
} from './setupTypes';

interface DraftWrite {
  id: string;
  body: SetupContent & { revision: number };
}
interface Submission {
  id: string;
  body: SetupAnswers & { draftRevision: number };
}
interface SavedDraft {
  version: 2;
  accountID: string;
  content: SetupContent;
  baseline: string;
  serverRevision: number | null;
  pending: DraftWrite | null;
  submission: Submission | null;
  updatedAt: number;
}
interface SetupState {
  saved: SavedDraft;
  syncing: boolean;
  submitting: boolean;
  message: string | null;
  error: string | null;
  conflict: RemoteSetupDraft | null;
  preview: (SetupPreview & { signature: string }) | null;
  complete: SetupStatus | null;
  readable: boolean;
}

let branch: { current: string; previous: string | null } | null = null;
function browserBranch() {
  if (!branch) {
    const key = 'exerly.setup.browser-branch';
    branch = { previous: null, current: operationID() };
    try {
      branch.previous = sessionStorage.getItem(key);
      sessionStorage.setItem(key, branch.current);
    } catch {
      /* Local drafts still use separate durable branch records. */
    }
  }
  return branch;
}

export function setupDraftPrefix(accountID: string): string {
  return `exerly.setup.v2:${API_CONFIG.BASE_URL}:${accountID}:`;
}

export class SetupStore {
  private state: SetupState;
  private listeners = new Set<() => void>();
  private syncTask: Promise<boolean> | null = null;
  private timer: number | undefined;
  private stopped = false;
  private abort = new AbortController();
  private defaults: SetupAnswers;
  private prefix: string;
  private key: string;
  readonly repair: boolean;
  readonly steps: number[];

  constructor(
    private accountID: string,
    private scope: string,
    user: SessionUser,
    status: SetupStatus
  ) {
    this.defaults = initialAnswers(user, status.repair_answers);
    this.prefix = setupDraftPrefix(accountID);
    const tab = browserBranch();
    this.key = this.prefix + tab.current;
    const fallback: SetupContent = {
      schema_version: 2,
      last_valid_step: 0,
      answers: this.defaults,
    };
    let saved: SavedDraft = {
      version: 2,
      accountID,
      content: fallback,
      baseline: contentSignature(fallback),
      serverRevision: null,
      pending: null,
      submission: null,
      updatedAt: Date.now(),
    };
    let error: string | null = null;
    try {
      const choices = this.savedDrafts();
      const restored =
        choices.find((row) => row.key === this.key) ??
        choices.find((row) => row.key === this.prefix + tab.previous) ??
        choices[0];
      if (restored) saved = restored.draft;
      const missing = firstIncomplete(saved.content);
      saved = {
        ...saved,
        content: {
          ...saved.content,
          last_valid_step: Math.min(saved.content.last_valid_step, missing),
        },
      };
      localStorage.setItem(this.key, JSON.stringify(saved));
    } catch {
      error =
        'This browser could not open your saved setup. Existing drafts have been kept. Allow site storage and reload to continue.';
    }
    this.repair = status.needs_repair;
    this.steps = this.repair
      ? [0, 1, 2, 3].filter((step) => setupError(saved.content.answers, step)).concat(4)
      : [0, 1, 2, 3, 4];
    if (this.repair && !this.steps.includes(saved.content.last_valid_step))
      saved.content.last_valid_step = this.steps[0];
    this.state = {
      saved,
      syncing: false,
      submitting: false,
      message: null,
      error,
      conflict: null,
      preview: null,
      complete: null,
      readable: !error,
    };
  }

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  getSnapshot = () => this.state;
  private publish(patch: Partial<SetupState>) {
    if (this.stopped) return;
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener();
  }
  private owned() {
    return !this.stopped && getSessionScope() === this.scope;
  }
  private assertOwned() {
    if (!this.owned())
      throw new Error('The signed-in account changed. Reopen setup for this account.');
  }
  private save(patch: Partial<SavedDraft>) {
    this.assertOwned();
    const saved = { ...this.state.saved, ...patch, updatedAt: Date.now() };
    if (this.repair) {
      for (const step of [0, 1, 2, 3]) {
        if (setupError(saved.content.answers, step) && !this.steps.includes(step))
          this.steps.push(step);
      }
      this.steps.sort((a, b) => a - b);
    }
    try {
      localStorage.setItem(this.key, JSON.stringify(saved));
    } catch {
      this.publish({ saved, preview: null });
      throw new Error(
        'This browser could not save your answers. Free some storage before continuing. Your open answers have not been sent.'
      );
    }
    this.publish({ saved });
  }
  private fail(error: unknown) {
    if (!this.owned()) return;
    if (error instanceof Error && error.name === 'AbortError') return;
    this.publish({
      error:
        error instanceof Error
          ? error.message
          : 'Could not sync setup. Your saved answers are still here.',
    });
  }

  private async request<T>(operation: (signal: AbortSignal) => Promise<T>): Promise<T> {
    const source = this.abort.signal;
    const controller = new AbortController();
    let timedOut = false;
    const cancel = () => controller.abort();
    if (source.aborted) cancel();
    source.addEventListener('abort', cancel, { once: true });
    const timer = window.setTimeout(() => {
      timedOut = true;
      cancel();
    }, 15000);
    try {
      return await operation(controller.signal);
    } catch (error) {
      if (timedOut)
        throw new Error(
          'The connection took too long. Your answers are saved. Retry to check their status.'
        );
      throw error;
    } finally {
      window.clearTimeout(timer);
      source.removeEventListener('abort', cancel);
    }
  }

  savedDrafts(): { key: string; draft: SavedDraft }[] {
    const rows: { key: string; draft: SavedDraft }[] = [];
    for (const key of Object.keys(localStorage).filter((key) => key.startsWith(this.prefix))) {
      const draft = JSON.parse(localStorage.getItem(key)!);
      if (
        draft.version !== 2 ||
        draft.accountID !== this.accountID ||
        draft.content?.schema_version !== 2 ||
        !draft.content?.answers ||
        typeof draft.baseline !== 'string' ||
        !(draft.serverRevision === null || Number.isInteger(draft.serverRevision)) ||
        !Number.isInteger(draft.content.last_valid_step) ||
        draft.content.last_valid_step < 0 ||
        draft.content.last_valid_step > 4 ||
        !Number.isFinite(draft.updatedAt) ||
        (draft.pending && (typeof draft.pending.id !== 'string' || !draft.pending.body?.answers)) ||
        (draft.submission && (typeof draft.submission.id !== 'string' || !draft.submission.body))
      )
        throw new Error('Unsupported saved setup');
      normalizeContent(
        { ...draft.content, account_id: this.accountID, revision: draft.serverRevision ?? 0 },
        this.defaults
      );
      rows.push({ key, draft });
    }
    return rows.sort((a, b) => b.draft.updatedAt - a.draft.updatedAt);
  }

  otherDrafts() {
    const seen = new Set([contentSignature(this.state.saved.content)]);
    try {
      return this.savedDrafts().filter(({ key, draft }) => {
        const signature = contentSignature(draft.content);
        if (key === this.key || seen.has(signature)) return false;
        seen.add(signature);
        return true;
      });
    } catch {
      return [];
    }
  }

  resumeDraft(key: string) {
    if (this.state.submitting || this.state.saved.submission) return;
    try {
      const other = this.savedDrafts().find((row) => row.key === key);
      if (!other) return;
      // Keep this branch's acknowledged baseline. Choosing an older set of
      // answers is a new edit which must still compare the current cloud revision.
      const content = { ...other.draft.content };
      content.last_valid_step = Math.min(content.last_valid_step, firstIncomplete(content));
      this.save({ content });
      this.publish({ preview: null, error: null });
      this.schedule();
    } catch (error) {
      this.fail(error);
    }
  }

  edit(patch: Partial<SetupAnswers>) {
    if (!this.state.readable || this.state.submitting || this.state.saved.submission) return;
    try {
      const changes = { ...patch };
      if (patch.nutritionGoal !== undefined) changes.nutritionGoalFollowsFitness = false;
      else if (
        patch.goal !== undefined &&
        this.state.saved.content.answers.nutritionGoalFollowsFitness === true
      )
        changes.nutritionGoal =
          patch.goal === 'lose_weight'
            ? 'lose'
            : patch.goal === 'gain_muscle'
              ? 'gain'
              : 'maintain';
      const content = {
        ...this.state.saved.content,
        answers: { ...this.state.saved.content.answers, ...changes },
      };
      this.save({ content });
      this.publish({ error: null, preview: null, message: 'Saved in this browser.' });
      this.schedule();
    } catch (error) {
      this.fail(error);
    }
  }

  go(step: number) {
    if (
      !this.state.readable ||
      this.state.submitting ||
      this.state.saved.submission ||
      !Number.isInteger(step) ||
      step < 0 ||
      step > 4
    )
      return;
    const { content } = this.state.saved;
    if (step > content.last_valid_step) {
      const error = setupError(content.answers, content.last_valid_step);
      if (error) {
        this.publish({ error });
        return;
      }
    }
    try {
      this.save({
        content: { ...content, last_valid_step: Math.min(step, firstIncomplete(content)) },
      });
      this.publish({ error: null });
      this.schedule();
    } catch (error) {
      this.fail(error);
    }
  }

  start() {
    this.stopped = false;
    this.abort = new AbortController();
    void (this.syncTask ?? Promise.resolve()).finally(async () => {
      if ((await this.sync()) && this.state.saved.content.last_valid_step === 4)
        await this.preview();
    });
  }
  stop() {
    this.stopped = true;
    window.clearTimeout(this.timer);
    this.abort.abort();
  }
  private schedule() {
    window.clearTimeout(this.timer);
    if (!this.state.conflict && !this.state.saved.submission)
      this.timer = window.setTimeout(() => {
        void this.sync();
      }, 600);
  }

  sync(): Promise<boolean> {
    if (this.syncTask) return this.syncTask;
    if (!this.owned() || !this.state.readable || this.state.conflict || this.state.saved.submission)
      return Promise.resolve(false);
    this.publish({ syncing: true, error: null });
    this.syncTask = this.reconcile()
      .catch((error) => {
        this.fail(error);
        return false;
      })
      .finally(() => {
        this.syncTask = null;
        this.publish({ syncing: false });
      });
    return this.syncTask;
  }

  private async status(): Promise<boolean> {
    const result = await this.request((signal) =>
      api.get<SetupStatus>('/api/onboarding/status', { signal })
    );
    this.assertOwned();
    if (result.complete && String(result.user._id) === this.accountID) {
      this.publish({ complete: result, error: null });
      localStorage.removeItem(this.key);
      return true;
    }
    return false;
  }

  private async reconcile(): Promise<boolean> {
    for (let attempt = 0; attempt < 8; attempt += 1) {
      this.assertOwned();
      // A prior storage failure may have left the newest answers only in memory.
      // Persist them, and every pending operation, before making a network write.
      this.save({});
      const pending = this.state.saved.pending;
      if (pending) {
        try {
          const { draft } = await this.request((signal) =>
            api.put<{ draft: RemoteSetupDraft }>('/api/onboarding/draft', pending.body, {
              operationID: pending.id,
              signal,
            })
          );
          this.assertOwned();
          this.checkRemote(draft);
          this.save({
            pending: null,
            serverRevision: draft.revision,
            baseline: contentSignature(normalizeContent(draft, this.defaults)),
          });
        } catch (error) {
          if (!(error instanceof ApiError && error.status === 409)) throw error;
          this.save({ pending: null });
          if (await this.status()) return true;
        }
      }
      const { draft: remote } = await this.request((signal) =>
        api.get<{ draft: RemoteSetupDraft | null }>('/api/onboarding/draft', { signal })
      );
      this.assertOwned();
      if (remote) {
        this.checkRemote(remote);
        const content = normalizeContent(remote, this.defaults);
        const remoteSignature = contentSignature(content);
        const localSignature = contentSignature(this.state.saved.content);
        if (remote.revision !== this.state.saved.serverRevision) {
          if (localSignature === remoteSignature)
            this.save({ serverRevision: remote.revision, baseline: remoteSignature });
          else if (localSignature === this.state.saved.baseline) {
            content.last_valid_step = Math.min(content.last_valid_step, firstIncomplete(content));
            this.save({ content, serverRevision: remote.revision, baseline: remoteSignature });
            this.publish({ preview: null });
          } else {
            this.publish({
              conflict: remote,
              error: null,
              message: 'Setup changed on another device. Review both versions before continuing.',
            });
            return false;
          }
        }
      } else {
        if ((this.state.saved.serverRevision ?? 0) > 0) {
          if (await this.status()) return true;
          throw new Error(
            'The cloud draft changed. Your local answers are kept. Retry after checking your other device.'
          );
        }
        this.save({ serverRevision: 0 });
      }
      if (remote && contentSignature(this.state.saved.content) === this.state.saved.baseline) {
        this.publish({ error: null, message: 'Saved on your account.' });
        return true;
      }
      this.save({
        pending: {
          id: operationID(),
          body: {
            ...structuredClone(this.state.saved.content),
            revision: this.state.saved.serverRevision ?? 0,
          },
        },
      });
    }
    throw new Error(
      'Your answers are saved in this browser. Choose Retry sync to finish uploading them.'
    );
  }

  private checkRemote(draft: RemoteSetupDraft) {
    if (
      String(draft.account_id) !== this.accountID ||
      ![1, 2].includes(draft.schema_version) ||
      !Number.isInteger(draft.revision) ||
      draft.revision < 1 ||
      !Number.isInteger(draft.last_valid_step) ||
      !draft.answers ||
      typeof draft.answers !== 'object' ||
      Array.isArray(draft.answers)
    )
      throw new Error(
        'This saved setup needs a newer app version. Your local answers have been kept.'
      );
  }

  async resolve(useCloud: boolean) {
    const remote = this.state.conflict;
    if (!remote) return;
    try {
      const cloud = normalizeContent(remote, this.defaults);
      const content = useCloud
        ? { ...cloud, last_valid_step: Math.min(cloud.last_valid_step, firstIncomplete(cloud)) }
        : this.state.saved.content;
      this.save({
        content,
        serverRevision: remote.revision,
        baseline: contentSignature(cloud),
        pending: null,
      });
      this.publish({ conflict: null, preview: null, error: null });
      await this.sync();
    } catch (error) {
      this.fail(error);
    }
  }

  async preview() {
    if (!(await this.sync()) || this.state.complete) return;
    const answers = this.state.saved.content.answers;
    const error = [0, 1, 2, 3].map((step) => setupError(answers, step)).find(Boolean);
    if (error) {
      this.publish({ error });
      return;
    }
    const signature = contentSignature(answers);
    try {
      const preview = await this.request((signal) =>
        api.post<SetupPreview>('/api/onboarding/preview', answers, { signal })
      );
      this.assertOwned();
      if (signature === contentSignature(this.state.saved.content.answers))
        this.publish({ preview: { ...preview, signature }, error: null });
    } catch (error) {
      this.fail(error);
    }
  }

  async finish() {
    if (!this.state.readable || this.state.submitting || this.state.conflict) return;
    this.publish({ submitting: true, error: null });
    window.clearTimeout(this.timer);
    try {
      this.assertOwned();
      if (await this.status()) return;
      if (!this.state.saved.submission) {
        if (!(await this.sync()) || this.state.complete) return;
        const answers = this.state.saved.content.answers;
        const error = [0, 1, 2, 3].map((step) => setupError(answers, step)).find(Boolean);
        if (error) throw new Error(error);
        if (this.state.preview?.signature !== contentSignature(answers))
          throw new Error('Review the current target preview before finishing.');
        this.save({
          submission: {
            id: operationID(),
            body: {
              ...structuredClone(answers),
              draftRevision: this.state.saved.serverRevision ?? 0,
            },
          },
        });
      }
      const pending = this.state.saved.submission!;
      const result = await this.request((signal) =>
        api.post<SetupStatus>('/api/onboarding/complete', pending.body, {
          operationID: pending.id,
          signal,
        })
      );
      this.assertOwned();
      if (!result.complete || String(result.user._id) !== this.accountID || !result.targets)
        throw new Error('Setup could not be confirmed. Retry to check its saved status.');
      this.publish({ complete: result, error: null });
      localStorage.removeItem(this.key);
    } catch (error) {
      if (this.owned() && error instanceof ApiError && [400, 409].includes(error.status)) {
        try {
          this.save({ submission: null });
          if (error.status === 409) await this.sync();
        } catch (storageError) {
          this.fail(storageError);
          return;
        }
      }
      this.fail(error);
    } finally {
      this.publish({ submitting: false });
    }
  }
}
