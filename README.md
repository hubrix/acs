# ACS — Access Control System

Employee access-request workflow app: employees (or their managers) request
access to resources, requests route through manager → resource owner → help
desk approval, and the help desk grants or revokes the underlying permissions.
It also drives new hire, rehire, transfer and termination workflows off the
same request pipeline.

Ruby 4.0.2 · Rails 8.1 · PostgreSQL 17.

## Running it locally

Requires Ruby 4.0.2 and a PostgreSQL server.

```sh
bundle install
cp config/database.yml.example config/database.yml   # defaults to localhost:5433
cp config/app.yml.example config/app.yml             # LDAP off in development
bin/rails db:setup                                   # create, load schema, seed
bin/rails dartsass:build                             # compile the SCSS
bin/dev                                              # http://localhost:3000
```

`db:seed` creates a demo organisation. Log in as `admin`, `helpdesk`, `boss` or
`employee`, all with the password `asdfasdf`. Demo users are only seeded outside
production; set `SEED_DEMO_USERS=true` to force them.

If your PostgreSQL is not on port 5433, set `DATABASE_PORT` (and
`DATABASE_HOST` / `DATABASE_USER` / `DATABASE_PASSWORD` as needed) or edit
`config/database.yml`.

### With Docker instead

```sh
docker compose up --build
docker compose exec web bin/rails db:seed
```

## Tests

```sh
bundle exec rspec       # 335 examples: models, mailers, controllers, auth
bundle exec cucumber    # 50 scenarios covering the end-to-end workflows
```

Both run against the fixtures in `spec/fixtures`, which describe a small
organisation (`timothyho` at the root, `rcooper` managing `dengle`, `mgroulx`
owning most resources, `mstreet` and `jserrano` on the help desk).

## Configuration

| File | Purpose |
| --- | --- |
| `config/app.yml` | Auth backends, mail sender and SMTP, exception recipients, CSV import column order. Not in version control; see `config/app.yml.example`. |
| `config/database.yml` | Database connection. Not in version control. |
| `config/credentials.yml.enc` | Rails credentials, including `secret_key_base`. Needs `config/master.key` or `RAILS_MASTER_KEY`. |

## Authentication

Auth backends are pluggable and declared under `auth.backends` in
`config/app.yml`. More than one can be enabled at once, so the login page can
offer a password form alongside a button per identity provider.

| Backend | Kind | What it does |
| --- | --- | --- |
| `local` | password | Verifies against the `crypted_password` column via Authlogic. Worth leaving on as a break-glass path for when the provider is down. |
| `google_workspace` | redirect | OAuth sign-in, plus optional Admin SDK directory lookups. |
| `openid_connect` | redirect | Any other OIDC provider — Okta, Entra ID, Auth0, Keycloak — by configuration alone. |

A backend never creates users. ACS users carry a manager, a job and a
permission template, which come from the new-hire workflow, not from a
provider profile. So an identity is matched to an **existing active** user by
email, the link is recorded in `linked_accounts` (keyed on the provider's
stable uid, so a later email change does not orphan it), and anything that
matches nobody is refused.

Set `auth.impersonation: true` and a login of `actor-target` authenticates as
`actor` but starts the session as `target`, for support. It is off by default,
the actor must be an administrator, and the target must be someone who could
have signed in themselves. An existing login always wins over the split, so an
employee whose login contains a hyphen can still sign in while it is on.

### Connecting Google Workspace

1. Create an OAuth client (Web application) in Google Cloud and register
   `https://your-host/auth/google_workspace/callback` as a redirect URI.
2. Fill in `client_id`, `client_secret` and `hosted_domain`, and set
   `enabled: true`. `hosted_domain` is enforced against the `hd` claim on the
   way back, not merely passed to Google as a hint.
3. Optional, for the directory half: create a service account, enable
   domain-wide delegation, grant it
   `https://www.googleapis.com/auth/admin.directory.user.readonly`, and set
   `directory.enabled`, `directory.impersonate` and
   `directory.service_account_json`. Without it ACS still works; it just only
   knows about logins that already exist in ACS when generating `jdoe2`.

### Adding another backend

Subclass `Acs::Auth::Backend` in `app/lib/acs/auth/backends`, declare its
`kind`, return an `Acs::Auth::Identity`, and register the class in
`Acs::Auth::BACKEND_CLASSES`. A `:password` backend implements
`#authenticate`; a `:redirect` backend implements `#omniauth_provider`,
`#omniauth_args` and `#identity_from`. Optionally expose an
`Acs::Auth::Directory` so login generation can see accounts that exist at the
provider but not yet in ACS.

## Deploying

`Dockerfile` builds a production image (assets precompiled, running as an
unprivileged user on port 3000) and `config/deploy.yml.example` is a Kamal
configuration to go with it.

```sh
cp config/deploy.yml.example config/deploy.yml   # then edit
kamal setup
```

The image needs `RAILS_MASTER_KEY` and `DATABASE_URL`, and `config/app.yml`
mounted in (it holds the LDAP and SMTP settings). The container runs
`bin/rails db:prepare` on boot.

## Notes on the 2011 → 2026 upgrade

This app was Rails 3.0.6 on Ruby 1.9.2. Beyond the framework upgrade:

- **Sphinx search** (`thinking-sphinx`, needed a Sphinx daemon) was replaced by
  PostgreSQL full-text search via `pg_search`. `SearchController` searches the
  same models the Sphinx index covered.
- **`change_logger`** (last released 2011) is now the `ChangeLoggable` concern
  and `ChangeLogger` module in `app/models`, writing to the same `change_logs`
  table. Models opt into HABTM audit callbacks explicitly.
- **The vendored `preferences` plugin** (2010) is now the `Preferenceable`
  concern, keeping the plugin's `preferred_*` accessors and the `preferences`
  table.
- **Rails Observers** (removed in Rails 5) became model callbacks on `User`,
  `Request` and `AccessRequest`.
- **Assets**: Compass/SCSS and a `public/` tree became Propshaft with
  `dartsass-rails`. The 2011 RequireJS/jQuery bundle still lives in
  `public/javascripts` because RequireJS resolves modules against undigested
  paths; it still provides `data-method` and `data-confirm` handling.
- **Tests**: RSpec 2.5 → 8.0 (the old suite targeted classes that no longer
  existed and was rewritten), and Cucumber's webrat steps were ported to
  Capybara.
- **LDAP** was removed in favour of the pluggable auth backends described
  above. It did two jobs — verifying passwords by bind, and searching the
  directory for taken logins — which are now the `Backend` and `Directory`
  ports respectively.

WORKFLOWS:

1. User requests permission for themselves
2. Request moves to manager.
  On approval: Request moves to resource owner, notify user of progress.
  On denial: Stop processing request, notify user of denial 
3. Resource owner recieves request
  On approval: Request moves to help desk, notify user of progress.
  On denial: Stop processing request, notify user of denial.
4. Help desk recieves request, completes it, notifies user of request.

EVENTS TO NOTIFY USERS OF
assigned as resource owner
user tries to create access request to resource with no owner

Workflows:
New Hire Workflow -
    1) New Hire From Hiring Manager
        Steps: Hiring manager submits new user (via form or CSV) -> requests submitted to:
            HR Approval ->  Helpdesk -> HR -> Complete
            HR Denial -> Flag rejected -> Complete
    2) New Hire From Human Resources
        Steps: HR submits a new user (via form or CSV) -> requests submitted to:
            Helpdesk -> HR -> Complete

Rehire workflow -
    1) Rehire from Human Resources
        Steps: Click "Rehire" button -> Choose new job/department/manager if necessary -> submit Grant requests to:
            Helpdesk -> Complete

Transfer (promote-demote) workflow -
    1) Hiring Manager transfer
        Steps: Click "Transfer" button -> Choose new job/department/manager if necessary -> submit Grant requests to:
            HR Approval -> Helpdesk -> Complete
            HR Denial -> Complete

    2) Human Resources transfer
        Steps: Click "Transfer" button -> Choose new job/department/manager if necessary -> submit Grant requests to:
            Helpdesk -> Complete

Termination Workflow -
    1) Termination from Hiring Manager
        Steps: Click "Terminate" button -> Asks for confirmation -> submit Revoke requests to:
            HR Approval -> Helpdesk -> Complete
            HR Denial -> Complete
    2) Termination from Human Resources
         Steps: Click "Terminate" button -> Asks for confirmation -> submit Revoke requests to:
            Helpdesk -> Complete

Request Workflow -
    1) Request from end user (Self-request)
        Steps: Click "Request" button -> select access -> submit Grant requests to:
            Hiring Manager Approval -> Owner Approval -> HR Approval -> Helpdesk -> Complete
            Hiring Manager Approval -> Owner Approval -> HR Denial -> Complete
            Hiring Manager Approval -> Owner Denial -> Complete
            Hiring Manager Denial -> Complete

    2) Request from hiring manager (manager request)
        Steps: Click "Request" button -> select access -> submit Grant requests to:
            Owner Approval -> HR Approval -> Helpdesk -> Complete
            Owner Approval -> HR Denial -> Complete
            Owner Denial -> Complete

    3) Request from owner (owner request)
        Steps: Click "Request" button -> select access -> submit Grant requests to:
            HR Approval -> Helpdesk -> Complete
            HR Denial -> Complete

Revoke workflow -
    1) Revoke from Hiring Manager
        Steps: Hiring Manager Selects access to revoke -> submits Revoke requests to:
            Helpdesk -> Complete
    2) Revoke from Resource Owner
        Steps: Owner selects access to revoke -> submits Revoke requests to:
            Hiring Manager -> Helpdesk -> Complete
