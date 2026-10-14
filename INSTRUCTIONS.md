# Omen, in full

Everything there is to say about installing Omen and building on it. The [README](README.md) is
the short way in; this is the reasoning underneath it, and the place to come when a default
turns out not to suit.

You ask Claude a complex question about data stored by your Rails app.
Claude answers with the SQL. Rails runs it.

Omen is an engine that you too can use. You just need a Rails app running on PostgreSQL.
Omen provides the models and the logic to talk to Claude; to parse what it says; to run read-only statements.

Your data never travels. Claude is shown the schema and writes one `SELECT`; Rails runs it and
draws the answer (including encrypted attributes) for whoever asked. Nothing that statement returned is ever sent back.

## How to install

```sh
gem install omen
```

Or, in a `Gemfile`, pinned to the current minor while this is still below 1.0:

```ruby
gem 'omen', '~> 0.4.0'
```

Omen follows [Semantic Versioning](https://semver.org) from 1.0 onwards. Until then a release may
break whatever it likes, so the pin stops short of the next minor: `~> 0.4.0` takes every fix in
0.4 and nothing beyond it.

## Requirements

**PostgreSQL only** 

<details>
  <summary>This is not a gap waiting to be filled. </summary>
  Two of the guarantees Omen makes are
  Postgres features with no equivalent elsewhere: it identifies an encrypted column by the table OID
  and column number Postgres reports for each result column, which is what stops an alias or an
  expression from laundering one; and it narrows privileges for the statement it runs with
  `SET LOCAL ROLE`, which reverts when the transaction ends. MySQL has `SET ROLE` but nothing
  transaction-scoped, so a raised exception would leave a pooled connection holding the role. Omen
  raises at boot on any other adapter rather than running with a weaker promise.
</details>

**db/schema.rb in Rails** 

<details>
  <summary>Only the :ruby schema is supported. </summary>
  The schema is what Claude is shown, so an app
  on `db/structure.sql` cannot use Omen. Checked at boot and raised on, because copying a
  `structure.sql` to that path fails silently and with teeth: the strip regexes read the Ruby DSL,
  so they match nothing, Omen's own tables stay in the prompt, and Claude is shown the log of every
  question ever asked.
</details>

**Three database functions, all prefixed** 

<details>
  <summary>A timestamp, a day and a distance go through a function, never an expression. </summary>
  `db:omen:grant` creates all three, each named `omen_` so that none of them can take a name an
  app wanted for itself -- `today` especially. `omen_time_zone()` hands a stored timestamp back in
  the zone the company works in, so every date means the same whole days. `omen_today()` answers
  what day it is there, and the prompt builds every relative window on it, so a statement that is
  kept and run again answers "last month" for the month it is run in rather than the month it was
  written in. `omen_miles_between(lat1, lng1, lat2, lng2)` answers a great-circle distance in
  miles. The prompt names each and forbids writing any of them by hand: a conversion assembled per
  query drifts, and a great-circle expression runs to a dozen nested calls that a reply balances
  by hand and gets wrong. The first and last are `IMMUTABLE`; `omen_today()` is `STABLE`, because
  it reads the clock and an immutable function of the clock may be folded to a constant -- which
  is exactly the sliding this one exists to keep. All are executable by anyone, so none needs a
  grant. An app in another zone renames the first two; an app whose tables carry no coordinates
  never calls the last. None can be a migration: Rails' `:ruby` schema format dumps no functions,
  so `db:schema:load` would drop one a migration had made.
</details>

## Configuration

Installing by adding to your Gemfile and running three commands in your terminal: 

```sh
bin/rails g omen:install # adds the migrations + an initializer you can delete
bin/rails db:migrate     # creates the tables `omen_readings`, `omen_questions`, `omen_answers`
bin/rails db:omen:grant  # set the read-only role statements run as
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

### Requirements

- **A read-only connection role.** `connects_to database: { writing: :primary, reading: :reader }`
  on the record class, with the `reading` entry logging in as a Postgres role granted `SELECT`
  and nothing else. Omen raises rather than falling back to a role that could write, which is
  the point. Naming that role is the app's own business — Omen has none for it, and discovers
  it when granting — but making one is not, since a managed database refuses half the DDL it
  takes. `Omen::Grants.made`, `Omen::Attributes.dangerous`, `Omen.attempted` and
  `Omen.each_database` are public for that, and the README shows the task they add up to.
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
| `narrow_role` | `'omen_inquirer'` |
| `remembered` | `5`, the turns of a thread that travel with the next question |
| `rows_read_out` | `8`, the rows of an answer its words read out before saying there are more |
| `notes` | none, so the prompt says nothing about this app beyond its schema |

## What a host builds on top

`omen_readings` carries a `type`, so a subclass is a kind of reading rather than a second name
for every row: `Inquiry.all` counts inquiries, and a row answers as what it was written as,
whatever class asks for it. That last part is what keeps a narrowing honest, since what a
reading may read is the row's own to say.

```ruby
class Inquiry < Omen::Reading
  belongs_to :owner, polymorphic: true
end
```

`Omen::Reading.create! question: 'Where are the homes we serve?'` is the whole of asking; a
follow-up is `reading.ask '...'`. Each question is answered in a job, and the answer carries the
statement Claude wrote, the rows it found, and which header of theirs held an encrypted column.

Two things a subclass cannot reach, because the gem's own class is what a job loads:
`broadcasts_refreshes`, and anything else that has to be declared on `Omen::Reading` itself. One
line in the host does it, and `rails g omen:pages` below writes that line where there is a Turbo
to broadcast over:

```ruby
ActiveSupport.on_load(:omen_reading) { broadcasts_refreshes }
```

## Putting it on a screen

Omen ships no controllers, no views and no routes, and there is no engine to mount: what a
reading looks like belongs to the app that installs it. What it takes to *draw* one is the gem's
own business, though, and a fourth command hands that over:

```sh
bin/rails g omen:pages
```

```
      create  app/models/inquiry.rb
      create  app/controllers/inquiries_controller.rb
      create  app/views/inquiries/index.html.erb
      create  app/views/inquiries/show.html.erb
      create  app/views/inquiries/_form.html.erb
       route  resources :inquiries
```

`bin/rails s`, then `/inquiries`. Type a question and the answer arrives under it, with the
statement Claude wrote and the rows it found. Every one of those files lands in the host and is
the host's from then on -- rename them, restyle them, throw them away. Pass a name to be called
something else: `bin/rails g omen:pages Consultation` writes `Consultation`,
`ConsultationsController` and `app/views/consultations`.

The generator exists because four of the things those files get right are things nobody should
have to learn before their first question:

- **The controller descends from `ApplicationController`**, so whatever guards the rest of the
  app guards the one page that will run SQL across all of it. This is the reason the pages are
  generated into the host rather than mounted from the gem: a mounted engine inherits none of
  the app's `before_action`, and forgetting to say so publishes an ask-anything console.
- **There is no `new` and no `edit`.** Opening a reading is asking its first question, so
  `create` is the only way in and a blank one has no page; and a reading is never edited, so
  `update` calls `ask` and the thread grows by one. `question` is an attribute, not a column --
  an `edit` form would rewrite something nothing reads back.
- **The rows come from `answer.shown`, never `answer.result`.** The second is what Postgres
  handed over; the first is that read back through Active Record Encryption, with the columns
  Claude asked to be drawn joined. An answer with no `sql` is Claude asking something back, and
  `note` is where it says so.
- **The refresh is subscribed to as `Omen::Reading`.** Where the host has Turbo, `show` gets
  `turbo_stream_from @inquiry.becomes(Omen::Reading)` and a `config/initializers/omen_broadcasts.rb`
  is written beside it declaring `broadcasts_refreshes`. Both name the gem's class and not
  `Inquiry`, because a question reaches its reading through the association: what a job is
  handed, and so what it broadcasts as, is always `Omen::Reading`. A stream named after the
  subclass hears nothing. Where there is no Turbo neither line is written, and a reload is what
  shows an answer.

What the generator cannot do for you is the part above: `ANTHROPIC_API_KEY` has to be
resolvable, `db:omen:grant` has to have run, and `config/database.yml` has to have the read-only
entry that `connects_to` names. The two are missed differently, which is why the `show` page
draws both -- a reading that could not reach Claude at all is left `failed`, with the class of
what went wrong in the log and nothing in the page, since a message from that far down may quote
a row; a reading whose statement had no role to run as is answered, with
`Omen::Role::MISCONFIGURED` in `answer.error`.

## After the first deploy

The narrow role is granted `SELECT` on every table and then refused Omen's own three, which can
only happen once those tables exist. On a database that forbids `CREATE ROLE` — a managed one
usually does — the role is made by hand and the revocation with it:

```sql
REVOKE SELECT ON omen_readings, omen_questions, omen_answers FROM omen_inquirer;
```

A managed database also refuses `ALTER ROLE ... NOSUPERUSER`, since only a superuser may say it.
Omen skips that statement and carries on rather than stopping, then reads the role back and says
so if it holds `SUPERUSER`, `BYPASSRLS` or `REPLICATION` -- which a role it created never does.

A missed table there means Claude is shown the log of every question ever asked.

## License

MIT, see [LICENSE.txt](LICENSE.txt).
