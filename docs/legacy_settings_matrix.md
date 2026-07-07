# Legacy Settings Behavior Matrix

> Status: Phase 0 baseline for the Settings & AI Services refactor.
>
> This document describes the behavior of the legacy implementation. It is not
> the target design. When an entry is marked `undefined`, migration must not
> preserve the accidental behavior.

## Classification

- `defined`: directly established by code and suitable for characterization
  tests before the refactor.
- `undefined`: depends on stale data, global state crossing Provider
  boundaries, or incidental fallback order. The new implementation must use
  the safe behavior recorded below.

## Persistence keys

| Key | Legacy scope | Writers | Readers | Classification |
| --- | --- | --- | --- | --- |
| `active_provider_id` | Global TTS selection | `ActiveTtsProviderId.set` | `ActiveTtsProviderId.load`, Library generation, Album generation | `defined` for registered IDs; stale IDs are `undefined` migration input |
| `active_voice_id` | Global TTS Voice selection | Voice Library select/create/clone/delete | Voice Library, Library generation, Album generation | `defined` only when the Voice belongs to the active Provider; cross-Provider values are `undefined` |
| `openai_compatible_dictionary_active_provider` | Global LLM Provider selection | first Provider creation, Model selection, active Provider deletion, legacy migration | `activeProvider`, Provider deletion | `defined` for an existing Provider ID; missing/stale IDs are `undefined` migration input |
| `openai_compatible_dictionary_model` | Global LLM Model selection | first Provider creation, Model selection, active Provider deletion, legacy setters/migration | settings summary, Model page, readiness, dictionary explanation | Provider ownership is not represented; compatibility after switching Provider is `undefined` |

## `active_provider_id`

| Location | Operation and scenario | Empty / invalid behavior | Provider constraint | Result |
| --- | --- | --- | --- | --- |
| `lib/tts/provider_registry.dart` · `ActiveTtsProviderId.build` | Supplies the in-memory value before persistence loads | Defaults to Kokoro Local | Registered built-in Provider | `defined` |
| `lib/tts/provider_registry.dart` · `ActiveTtsProviderId.load` | Reads once during app startup | Missing or unknown ID is ignored; in-memory default remains Kokoro Local; stored value is not repaired | Accepts only IDs present in `ProviderRegistry` | Valid restore is `defined`; stale storage repair is `undefined` |
| `lib/tts/provider_registry.dart` · `ActiveTtsProviderId.set` | Settings PopupMenu activates a TTS Provider | Unknown ID is ignored and not persisted | Accepts only registered IDs | `defined` |
| `lib/presentation/screens/library/library_screen.dart` · `_resolveProvider` | Resolves Provider for whole-book cache generation | Missing/unknown stored ID falls back to `activeTtsProviderProvider` | Registry lookup | `defined` while controller and storage agree; disagreement ordering is `undefined` |
| `lib/presentation/screens/album/album_screen.dart` · `_resolveProvider` | Resolves Provider for chapter generation | Same fallback as Library | Registry lookup | Same classification as Library |

### Migration rule

- A registered stored ID migrates to the active TTS Provider.
- A missing or stale ID does not select a Provider by list position. The new
  controller uses its explicit product default and emits a non-persisted
  migration notice when stale data was discarded.

## `active_voice_id`

| Location | Operation and scenario | Empty / invalid behavior | Provider constraint | Result |
| --- | --- | --- | --- | --- |
| `lib/presentation/screens/settings/voice_library_screen.dart` · `_loadActiveVoice` | Reads the global Voice ID for row selection | Missing value selects no row; an ID from another Provider also matches no row because the list is Provider-filtered | No validation at read time | Compatible value is `defined`; cross-Provider meaning is `undefined` |
| `voice_library_screen.dart` · `_setActiveVoice` | User selects a visible Voice | Writes the selected ID | UI list is filtered to the active Provider | `defined` |
| `voice_library_screen.dart` · `_createVoiceFromDescription` / `_cloneVoice` | Newly created Voice becomes active | Writes the returned Voice ID | Provider is the current active Provider, but storage does not encode this relationship | `defined` for a well-behaved Provider |
| `voice_library_screen.dart` · `_deleteVoice` | Deletes the selected active Voice | Writes an empty string, then clears local selection | Comparison uses only Voice ID | `defined`; empty-string-as-null is legacy-only |
| `lib/presentation/screens/library/library_screen.dart` · `_resolveVoice` | Resolves Voice for whole-book generation | Tries `book.voiceId`, then global `active_voice_id`; incompatible IDs are ignored; falls back to newest saved clone, otherwise first available Voice | Candidate list is filtered to the resolved Provider | Compatible selection and ordered fallback are `defined`; cross-Provider intent is `undefined` |
| `lib/presentation/screens/album/album_screen.dart` · `_resolveVoice` | Resolves Voice for chapter generation | Same preference order; then newest saved clone, then first available Voice | Candidate list is filtered to the resolved Provider | Same classification as Library |

### Migration rule

- Migrate the legacy Voice only when it can be proven to belong to the active
  TTS Provider (by stored Voice row or Provider-owned preset identity).
- Do not attach an unmatched Voice ID to another Provider and do not reproduce
  the legacy newest-clone/first-item fallback as a saved selection.
- An unmatched value becomes `setupRequired`; runtime fallback may remain an
  explicit playback policy, but it is not persisted as user intent.

## `openai_compatible_dictionary_active_provider`

All direct persistence access is centralized in
`OpenAiCompatibleExplanationProvider`.

| Method | Operation and scenario | Empty / invalid behavior | Provider constraint | Result |
| --- | --- | --- | --- | --- |
| `activeProvider` | Reads active Provider for settings, readiness, validation and explanation | No configurations returns `null`; missing/empty/stale ID returns the first configured Provider without repairing storage | Matches against saved configurations | Existing ID is `defined`; first-item fallback is `undefined` user intent |
| `addProvider` | Adds a Provider | The first Provider becomes active and clears the global Model; later additions do not activate | Newly persisted Provider | `defined` |
| `selectModel` | Selects a Model and implicitly activates its Provider | Rejects unknown Provider and empty Model | Provider must exist | Atomic legacy interaction is `defined`, but implicit activation is retired by the target design |
| `removeProvider` | Removes a Provider | If active, activates the first remaining Provider or writes `''`; clears Model. Removing an inactive Provider changes neither key | Compares stored active ID, not resolved `activeProvider` | Active deletion behavior is `defined`; list-order choice is not target behavior |
| `_migrateLegacyConfiguration` | Converts the pre-provider API key/base URL settings | Creates one Provider and writes its ID active | Derived legacy Provider | `defined` |

### Migration rule

- Existing IDs migrate directly.
- Missing, empty or stale IDs do not inherit `configurations.first` as user
  intent. The new state is `setupRequired` unless exactly one valid legacy
  Provider was created by the migration in the same transaction.
- Provider identity and display name must both be null or both be non-null in
  service summaries. A deleted Provider cannot leave a dangling summary.

## `openai_compatible_dictionary_model`

All direct persistence access is centralized in
`OpenAiCompatibleExplanationProvider`; screens consume the public API.

| Method | Operation and scenario | Empty / invalid behavior | Provider constraint | Result |
| --- | --- | --- | --- | --- |
| `model` | Reads the selected Model | Missing becomes `''`; surrounding whitespace is trimmed | None | String normalization is `defined`; Provider ownership is absent |
| `addProvider` | First Provider creation | Clears Model to `''` | First Provider only | `defined` |
| `selectModel` | Model page selects a Model | Rejects empty Model; writes Provider and Model together | Provider must exist; fetched-model membership is not validated | Write behavior is `defined`; model compatibility is `undefined` |
| `removeProvider` | Active Provider deletion | Clears Model; inactive deletion preserves it | Bound only through active-ID equality | `defined` |
| `setConfiguration` | Backward-compatible configuration setter | Writes any trimmed Model globally | Does not record Provider ownership | Storage behavior is `defined`; cross-Provider interpretation is `undefined` |
| `_migrateLegacyConfiguration` | Migrates single-provider settings | Preserves non-empty legacy Model; otherwise defaults DeepSeek to `deepseek-v4-flash`, Z.AI to `glm-5.1`, Custom to empty | Newly migrated Provider kind | `defined` |
| `isConfigured` / `explain` | Uses Model with resolved active Provider | Empty means not configured / throws; non-empty is sent without proving it belongs to active Provider | No compatibility validation | Empty behavior is `defined`; mismatched non-empty value is `undefined` |

### Migration rule

- Move a non-empty global Model into the active Provider's map only when the
  active Provider ID is valid.
- If Provider identity is missing/stale, or the Model is known to come from a
  different Provider, do not guess. Leave the Provider-scoped Model unset and
  enter `setupRequired`.
- Model selection in the new UI never changes the active Provider implicitly.

## Characterization coverage

| Legacy behavior | Test |
| --- | --- |
| Valid TTS Provider restores and a registered selection persists | `test/provider_settings_test.dart` |
| Missing/stale TTS Provider keeps the explicit Kokoro default and does not rewrite storage | `test/provider_settings_test.dart` |
| Unknown TTS Provider cannot be activated | `test/provider_settings_test.dart` |
| First LLM Provider becomes active and starts without a Model | `test/vocabulary_dictionary_test.dart` |
| Valid LLM Model selection writes Provider and Model together | `test/vocabulary_dictionary_test.dart` |
| Missing/stale LLM active ID resolves to first configuration without storage repair | `test/vocabulary_dictionary_test.dart` |
| Removing the active LLM Provider selects the first remaining Provider and clears Model | `test/vocabulary_dictionary_test.dart` |
| Legacy single-provider migration preserves a non-empty Model | `test/vocabulary_dictionary_test.dart` |

## Known unsafe fixtures for Phase 1

These inputs are intentionally not preserved as valid selections:

1. `active_voice_id` belongs to a different TTS Provider than
   `active_provider_id`.
2. `active_voice_id` is non-empty but cannot be resolved to a stored or preset
   Voice.
3. LLM active Provider ID is missing or references a deleted configuration
   while multiple Providers remain.
4. A non-empty global LLM Model exists without a valid active Provider.
5. A global LLM Model is incompatible with the active Provider.

Phase 1 migration tests must assert detection and `setupRequired`, not legacy
fallback selection.
