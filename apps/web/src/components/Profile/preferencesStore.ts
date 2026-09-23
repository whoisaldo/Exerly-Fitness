import API_CONFIG from '../../config';
import { api, ApiError, getSessionScope } from '../../lib/api';
import { operationID } from '../../lib/ids';
import {
  changesFor,
  fieldsFor,
  heightText,
  number,
  signature,
  labels,
  type Preferences,
  type Value,
} from './preferences';

interface Pending {
  id: string;
  body: { base_revision: number; changes: Record<string, Value> };
}
interface Draft {
  version: 1;
  accountID: string;
  base: Preferences;
  fields: Record<string, string>;
  heightCM: number | null;
  pending: Pending | null;
  updatedAt: number;
}
interface State {
  draft: Draft | null;
  loading: boolean;
  saving: boolean;
  readable: boolean;
  error: string | null;
  message: string | null;
  conflict: Preferences | null;
  accepted: Preferences | null;
}
let branch: { current: string; previous: string | null } | undefined;

export class PreferencesStore {
  private state: State = {
    draft: null,
    loading: false,
    saving: false,
    readable: true,
    error: null,
    message: null,
    conflict: null,
    accepted: null,
  };
  private listeners = new Set<() => void>();
  private prefix: string;
  private key: string;
  private stopped = false;
  private controller = new AbortController();
  private task: Promise<void> | null = null;
  constructor(
    readonly accountID: string,
    private scope: string
  ) {
    this.prefix = `exerly.preferences.v1:${API_CONFIG.BASE_URL}:${accountID}:`;
    if (!branch) {
      branch = { current: operationID(), previous: null };
      try {
        branch.previous = sessionStorage.getItem('exerly.preferences.branch');
        sessionStorage.setItem('exerly.preferences.branch', branch.current);
      } catch {
        /* Each document still has its own storage record. */
      }
    }
    this.key = this.prefix + branch.current;
    try {
      const drafts = this.savedDrafts();
      const previous =
        drafts.find(({ key }) => key === this.key) ??
        drafts.find(({ key }) => key === this.prefix + branch!.previous) ??
        drafts[0];
      if (previous) {
        this.state.draft = previous.draft;
        localStorage.setItem(this.key, JSON.stringify(previous.draft));
      }
    } catch {
      this.state.readable = false;
      this.state.error =
        'Saved preferences could not be opened. Existing drafts have been kept. Check site storage and reload.';
    }
  }
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  getSnapshot = () => this.state;
  private publish(patch: Partial<State>) {
    if (this.stopped) return;
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener();
  }
  private owned() {
    return !this.stopped && getSessionScope() === this.scope;
  }
  private assertOwned() {
    if (!this.owned()) throw new DOMException('Account changed', 'AbortError');
  }
  private validate(snapshot: Preferences) {
    if (
      !snapshot ||
      snapshot.schema_version !== 1 ||
      snapshot.account_id !== this.accountID ||
      !Number.isInteger(snapshot.revision) ||
      snapshot.revision < 0 ||
      !snapshot.values ||
      Array.isArray(snapshot.values) ||
      snapshot.user?._id !== this.accountID
    )
      throw new Error(
        'The saved preferences response could not be read. Your draft is still here.'
      );
  }
  private persist(draft: Draft) {
    this.assertOwned();
    try {
      localStorage.setItem(this.key, JSON.stringify(draft));
    } catch {
      this.publish({ draft });
      throw new Error(
        'This browser could not save your draft. Free some storage before sending it. Your open answers are kept.'
      );
    }
    this.publish({ draft });
  }
  private fail(error: unknown) {
    if (!this.owned() || (error instanceof Error && error.name === 'AbortError')) return;
    this.publish({
      error:
        error instanceof Error
          ? error.message
          : 'Could not load preferences. Retry when connected.',
    });
  }
  private async request<T>(send: (signal: AbortSignal) => Promise<T>): Promise<T> {
    const source = this.controller.signal;
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
      return await send(controller.signal);
    } catch (error) {
      if (timedOut)
        throw new Error(
          'The connection took too long. Your draft is saved. Retry to check the result.'
        );
      throw error;
    } finally {
      window.clearTimeout(timer);
      source.removeEventListener('abort', cancel);
    }
  }
  private adopt(snapshot: Preferences) {
    this.validate(snapshot);
    this.persist({
      version: 1,
      accountID: this.accountID,
      base: snapshot,
      fields: fieldsFor(snapshot),
      heightCM: typeof snapshot.values.height === 'number' ? snapshot.values.height : null,
      pending: null,
      updatedAt: Date.now(),
    });
    this.publish({
      accepted: snapshot,
      conflict: null,
      message: 'Preferences are up to date.',
      error: null,
    });
  }
  start() {
    this.stopped = false;
    this.controller = new AbortController();
    void (this.task ?? Promise.resolve()).finally(() => this.load());
  }
  stop() {
    this.stopped = true;
    this.controller.abort();
  }
  private savedDrafts(): { key: string; draft: Draft }[] {
    return Object.keys(localStorage)
      .filter((key) => key.startsWith(this.prefix))
      .map((key) => {
        const draft = JSON.parse(localStorage.getItem(key)!) as Draft;
        if (
          draft.version !== 1 ||
          draft.accountID !== this.accountID ||
          !draft.fields ||
          Object.keys(labels).some((key) => typeof draft.fields[key] !== 'string') ||
          (draft.heightCM !== null && !Number.isFinite(draft.heightCM)) ||
          !Number.isFinite(draft.updatedAt) ||
          Object.values(draft.fields).some((value) => typeof value !== 'string') ||
          (draft.pending &&
            (typeof draft.pending.id !== 'string' ||
              !draft.pending.id ||
              !Number.isInteger(draft.pending.body?.base_revision) ||
              draft.pending.body.base_revision < 0 ||
              !draft.pending.body?.changes ||
              Array.isArray(draft.pending.body.changes) ||
              !Object.keys(draft.pending.body.changes).length))
        )
          throw new Error('Unreadable saved preferences');
        this.validate(draft.base);
        return { key, draft };
      })
      .sort((a, b) => b.draft.updatedAt - a.draft.updatedAt);
  }
  otherDrafts() {
    try {
      const seen = new Set([signature(this.state.draft?.fields)]);
      return this.savedDrafts().filter(({ key, draft }) => {
        const value = signature(draft.fields);
        if (key === this.key || seen.has(value)) return false;
        seen.add(value);
        return true;
      });
    } catch {
      return [];
    }
  }
  resume(key: string) {
    const draft = this.state.draft;
    if (!draft || draft.pending || this.state.saving || this.state.loading) return;
    try {
      const found = this.savedDrafts().find((entry) => entry.key === key);
      if (!found) return;
      // A recovered, unconfirmed save must retain the original revision and
      // operation. Copying its fields onto today's revision could overwrite a
      // later device edit without ever resolving that save.
      this.persist({
        ...found.draft,
        updatedAt: Date.now(),
      });
      this.publish({
        conflict: null,
        error: null,
        message: 'Recovered draft. Review it before saving.',
      });
      void this.load();
    } catch (error) {
      this.fail(error);
    }
  }
  edit(key: string, value: string) {
    const draft = this.state.draft;
    if (!draft || !this.state.readable || draft.pending || this.state.saving) return;
    try {
      const next = { ...draft, fields: { ...draft.fields, [key]: value }, updatedAt: Date.now() };
      if (key === 'height') {
        const parsed = number(value);
        if (parsed != null || !value.trim())
          next.heightCM =
            parsed == null ? null : parsed * (draft.fields.unitSystem === 'imperial' ? 2.54 : 1);
      }
      if (key === 'unitSystem') {
        if (draft.fields.height.trim() && number(draft.fields.height) == null)
          throw new Error('Correct the height before changing display units.');
        next.fields.height = heightText(next.heightCM, value);
      }
      this.persist(next);
      this.publish({
        error: null,
        message: 'Draft saved in this browser. Save preferences to apply it.',
      });
    } catch (error) {
      this.fail(error);
    }
  }
  load(): Promise<void> {
    if (this.task) return this.task;
    if (!this.owned() || !this.state.readable || this.state.saving) return Promise.resolve();
    this.publish({ loading: true, error: null });
    this.task = this.refresh()
      .catch((error) => this.fail(error))
      .finally(() => {
        this.task = null;
        this.publish({ loading: false });
      });
    return this.task;
  }
  private async refresh() {
    if (this.state.draft?.pending) await this.sendPending();
    const remote = await this.request((signal) =>
      api.get<Preferences>('/api/preferences', { signal })
    );
    this.assertOwned();
    this.validate(remote);
    const draft = this.state.draft;
    if (
      draft &&
      signature(draft.fields) !== signature(fieldsFor(draft.base)) &&
      remote.revision !== draft.base.revision
    ) {
      this.publish({
        conflict: remote,
        error: null,
        message: 'Preferences changed on another device. Review the differences.',
      });
    } else if (!draft || signature(draft.fields) === signature(fieldsFor(draft.base)))
      this.adopt(remote);
    else
      this.publish({
        accepted: remote,
        message: 'Your draft is saved locally. Review it before saving.',
      });
  }
  private async sendPending() {
    const draft = this.state.draft;
    if (!draft?.pending) return;
    this.persist(draft);
    try {
      const pending = draft.pending;
      const response = await this.request((signal) =>
        api.patch<Preferences>('/api/preferences', pending.body, {
          signal,
          operationID: pending.id,
        })
      );
      this.assertOwned();
      this.adopt(response);
    } catch (error) {
      if (error instanceof ApiError && [400, 409].includes(error.status)) {
        this.persist({ ...draft, pending: null });
        if (error.status === 409) {
          const remote = await this.request((signal) =>
            api.get<Preferences>('/api/preferences', { signal })
          );
          this.assertOwned();
          this.validate(remote);
          this.publish({ conflict: remote, error: null });
          return;
        }
      }
      throw error;
    }
  }
  async save() {
    if (
      !this.owned() ||
      !this.state.readable ||
      this.state.saving ||
      this.state.conflict ||
      !this.state.draft
    )
      return;
    if (this.task) await this.task;
    // A refresh can discover a conflict or outlive the signed-in account.
    // Two save clicks can also have been waiting on the same refresh.
    if (
      !this.owned() ||
      !this.state.readable ||
      this.state.saving ||
      this.state.conflict ||
      !this.state.draft
    )
      return;
    this.publish({ saving: true, error: null });
    try {
      const draft = this.state.draft!;
      if (!draft.pending) {
        const changes = changesFor(draft.base, draft.fields, draft.heightCM);
        if (!Object.keys(changes).length) {
          this.publish({ message: 'No unsaved changes.' });
          return;
        }
        this.persist({
          ...draft,
          pending: { id: operationID(), body: { base_revision: draft.base.revision, changes } },
        });
      }
      await this.sendPending();
      if (!this.state.conflict) {
        await this.refresh();
        if (!this.state.conflict) this.publish({ message: 'Preferences saved.' });
      }
    } catch (error) {
      this.fail(error);
    } finally {
      this.publish({ saving: false });
    }
  }
  async resolve(useServer: boolean) {
    const remote = this.state.conflict;
    const draft = this.state.draft;
    if (!remote || !draft || !this.owned() || this.state.saving || this.state.loading) return;
    try {
      if (useServer) this.adopt(remote);
      else {
        const changes = changesFor(draft.base, draft.fields, draft.heightCM);
        const values = structuredClone(remote.values);
        for (const [key, value] of Object.entries(changes))
          values[key] =
            value && typeof value === 'object' && !Array.isArray(value)
              ? { ...(values[key] as Record<string, Value>), ...value }
              : value;
        const merged = { ...remote, values };
        this.persist({
          ...draft,
          base: remote,
          fields: fieldsFor(merged),
          heightCM: typeof values.height === 'number' ? values.height : null,
          pending: null,
        });
        this.publish({ conflict: null, error: null });
        await this.save();
      }
    } catch (error) {
      this.fail(error);
    }
  }
}
