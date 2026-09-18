# NGFW Playwright repository reference

This is a maintained reference for the NGFW Vue UI Playwright harness. It
describes repository conventions that affect test implementation; it is not a
generic Playwright tutorial or a feature scenario catalog.

## Repository layout

The harness is under `untangle-vue-ui/source/playwright`.

Important files to inspect before editing:

- `playwright.config.ts`: base URL, authentication-state path, projects,
  dependencies, CI behavior, retries, workers, reporter, and browser settings.
- `package.json`: installed Playwright version and test scripts.
- `tests/auth.setup.ts`: credential-backed login and storage-state creation.
- `README.md`: local installation and execution instructions.
- `.gitignore`: generated auth state, reports, and test results.

The exact config is authoritative. Do not assume project names, dependencies,
parallelism, or timeout policy without inspecting it.

## Authentication and environment

The setup project logs in once and saves the browser storage state. Feature
projects should reuse that state rather than repeat login actions. Credentials,
appliance URLs, storage-state paths, and CI flags are runtime configuration;
keep them out of TypeScript constants and source control.

The current harness uses these environment concepts:

- `NGFW_UI_URL`: appliance or development UI base URL.
- `NGFW_USERNAME` and `NGFW_PASSWORD`: login credentials.
- `NGFW_STORAGE_STATE`: optional storage-state output/input path.

When a valid storage state already exists, a targeted `--no-deps` run can skip
the setup project. A full project run is required to exercise credential-backed
setup.

## Application source boundary

NGFW `source/src` files may be route, store, setup, or product wrappers rather
than the complete visible component implementation. When a wrapper imports
from the shared UI package, trace the export through the shared package index
and into its owning source tree. Do not copy selectors, labels, conditional
branches, or form behavior from an unrelated duplicate component directory.

For a new feature, discover the boundary with narrow searches such as:

~~~sh
rg -n --glob '!node_modules/**' "from ['\"]vuntangle['\"]" untangle-vue-ui/source/src
rg -n "FeatureExport|shared/Feature" ../vuntangle/src/shared/index.js ../vuntangle/src
~~~

Then inspect the product wrapper, the route entry under
`untangle-vue-ui/source/src/router`, the matching shared export, the owning
component, and any adapter/store code that changes the data shape. Assert the
rendered user contract rather than internal store objects.

## Navigation and existing test conventions

Prefer the real user navigation path for feature tests. If an existing focused
pilot test uses a verified SPA history/popstate entry technique, reuse it only
when the route and entry behavior have been confirmed; do not turn that
technique into a blanket bypass for every new test.

After actions, wait for observable readiness rather than only a URL or an
arbitrary delay. For slow asynchronous operations, use a bounded,
operation-appropriate timeout and then assert the resulting UI state.

## Test placement model

As coverage grows, retain visible intent separation:

~~~text
source/playwright/
  constants/       # scenario values and factories
  fixtures/        # shared context and repeated actions
  resources/       # larger static files or payloads
  tests/
    smoke/         # fast, read-only health/navigation checks
    crud/          # create/edit/delete and persistence with cleanup
    data-validation/ # controlled existing data and presentation checks
~~~

Do not create empty layers for ceremony. Match the current repository and add
a directory/helper only when the scenario justifies it. Specs own business
actions and assertions; helpers own repeated mechanics; constants/factories
own reusable data; setup/teardown own environment and created-state lifecycle.

## Data lifecycle

For read-only or data-validation tests, use controlled existing state and do
not hide persistent mutations in setup. For CRUD tests:

- generate unique names or values where shared state requires it;
- resolve eligible dependencies from the current UI or approved fixture;
- register created identity as soon as the save is accepted;
- clean up through a supported UI or approved helper contract, including after
  assertion failures;
- restore edited pre-existing data when the scenario changes it and a safe
  restore path exists.

Do not add a database loader, backend cleanup API, or another product suite's
fixture contract without verifying an NGFW backend contract.

## Commands

From `untangle-vue-ui/source/playwright`:

~~~sh
yarn install
yarn playwright install chromium

NGFW_UI_URL='https://<NGFW_HOST>/console/' \
NGFW_USERNAME='<USER>' \
NGFW_PASSWORD='<REDACTED_SECRET>' \
yarn test:<project>
~~~

For focused work, use the installed local Playwright binary:

~~~sh
yarn playwright test tests/<spec>.spec.ts --project=<project> --no-deps
~~~

Use the repository's configured lint and type checks when present. Keep
`test.only`, committed `test.skip`, and `page.pause()` out of final code.

## Website-suite patterns

The broader website suite's useful transferable patterns are separation of
setup, fixtures, constants, tests, utilities, resources, and teardown; saved
authentication state; distinct smoke/CRUD/data-validation lanes; generated
data registries; and explicit cleanup. Website-specific accounts, cloud
identifiers, database loaders, and cleanup APIs are not NGFW dependencies.
