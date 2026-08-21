# Omen

Staff ask Claude a question about the data an app holds; Claude writes the SQL, Rails runs it.

Omen ships the models and the logic to talk to Claude, parse what it says back, and run the
statement it wrote against a read-only connection. It ships **no controllers, routes or views** —
the pages belong to the app that installs it.

The rows never travel. Claude is shown the schema and writes one `SELECT`; Rails runs it and
draws the answer for whoever asked. Nothing that statement returned is ever sent back.

## How to install

```sh
gem install omen
```

Or, in a `Gemfile`, pinned to the current major:

```ruby
gem 'omen', '~> 0.2'
```

Omen follows [Semantic Versioning](https://semver.org), so `~> major.minor` means `bundle update`
never crosses a breaking change.

## Requirements

**PostgreSQL only.** This is not a gap waiting to be filled. Two of the guarantees Omen makes are
Postgres features with no equivalent elsewhere: it identifies an encrypted column by the table OID
and column number Postgres reports for each result column, which is what stops an alias or an
expression from laundering one; and it narrows privileges for the statement it runs with
`SET LOCAL ROLE`, which reverts when the transaction ends. MySQL has `SET ROLE` but nothing
transaction-scoped, so a raised exception would leave a pooled connection holding the role. Omen
raises at boot on any other adapter rather than running with a weaker promise.

**`db/schema.rb`, in Rails' `:ruby` schema format.** The schema is what Claude is shown, so an app
on `db/structure.sql` cannot use Omen. Checked at boot and raised on, because copying a
`structure.sql` to that path fails silently and with teeth: the strip regexes read the Ruby DSL,
so they match nothing, Omen's own tables stay in the prompt, and Claude is shown the log of every
question ever asked.

**Eastern time.** A stored timestamp is read through an `eastern()` function the rake task
creates, and every date the prompt asks Claude to reason about is a date in `America/New_York`.
An app that works in another zone has to say so in the function and rename it.

## Configuration

Installing is three commands and, if you want to change anything, one file.

### The steps

```sh
bin/rails generate omen:install   # three migrations, and an initializer you may delete
bin/rails db:migrate
bin/rails db:omen:grant           # the role a statement runs as, and the function it reads a
                                  # timestamp through
```

`db:omen:grant` is worth running from the tasks that build a database, so a fresh one is never
missing the role. In `lib/tasks` of the host:

```ruby
granted = Rake::Task['db:omen:grant']

%w[ db:create db:prepare db:reset db:test:prepare ].each do |name|
  Rake::Task[name].enhance do
    granted.reenable
    granted.invoke
  end
end
```

### What the app around it has to provide

Configuration is optional. Installation is not: four of these are the app's, and Omen cannot
supply any of them.

- **A read-only connection role.** `connects_to database: { writing: :primary, reading: :reader }`
  on the record class, with the `reading` entry logging in as a Postgres role granted `SELECT`
  and nothing else. Omen raises rather than falling back to a role that could write, which is
  the point. Creating that role is the app's own business — Omen has no name for it, and
  discovers it when granting.
- **Active Record Encryption keys.** Without them an encrypted column reads back as the
  placeholder rather than as the value, quietly.
- **An `ApplicationJob`.** A reading is answered outside the request, and the job descends
  from the app's own base class.
- **A `db/schema.rb`.** It is the prompt, so a reading cannot happen before the first
  `db:migrate` has dumped one.

### The options

Every setting has a default, so the initializer is optional. `rails generate omen:install`
writes it with each line commented out, as the list of what there is to say.

| Setting | Default |
|---|---|
| `record_class` | `'ApplicationRecord'`, falling back to `ActiveRecord::Base` |
| `reading_role` | `:reading` |
| `narrow_role` | `'omen_inquirer'` |
| `claude_model` | `'claude-opus-5'` |
| `maximum_rows` | `100` |
| `api_key` | unset, so the Anthropic SDK resolves `ANTHROPIC_API_KEY` and its wider chain |
| `notes` | none, so the prompt says nothing about this app beyond its schema |
| `schema_path` | `'db/schema.rb'` |

## What a host builds on top

`Omen::Reading` has a `type` column nowhere, so a subclass is a transparent second name for the
same rows: `Inquiry.all` carries no type condition, and `to_partial_path` becomes
`inquiries/inquiry`.

```ruby
class Inquiry < Omen::Reading
  belongs_to :user
end
```

`Omen::Reading.create! question: 'Where are the homes we serve?'` is the whole of asking; a
follow-up is `reading.ask '...'`. Each question is answered in a job, and the answer carries the
statement Claude wrote, the rows it found, and which header of theirs held an encrypted column.

Two things a subclass cannot reach, because the gem's own class is what a job loads:
`broadcasts_refreshes`, and anything else that has to be declared on `Omen::Reading` itself. One
line in the host does it:

```ruby
Rails.application.config.to_prepare { Omen::Reading.broadcasts_refreshes }
```

## After the first deploy

The narrow role is granted `SELECT` on every table and then refused Omen's own three, which can
only happen once those tables exist. On a database that forbids `CREATE ROLE` — a managed one
usually does — the role is made by hand and the revocation with it:

```sql
REVOKE SELECT ON omen_readings, omen_questions, omen_answers FROM omen_inquirer;
```

A missed table there means Claude is shown the log of every question ever asked.

## License

MIT, see [LICENSE.txt](LICENSE.txt).
