# Omen

You ask Claude a complex question about the data your Rails app already holds.
Claude answers with the SQL. Rails runs it.

<!-- The demo goes here. Drop the recording in as demo.gif at the root of the repo and
     uncomment the line below:

![Asking Omen a question inside a Rails app](demo.gif)
-->

Your data never travels. Claude is shown the schema and writes one `SELECT`; Rails runs it
read-only and draws the answer -- encrypted columns included -- for whoever asked. Nothing that
statement returned is ever sent back.

## Running it

In your `Gemfile`, pinned to the current minor while this is still below 1.0:

```ruby
gem 'omen', '~> 0.10.0'
```

Then four commands:

```sh
bin/rails g omen:install   # the migrations and an initializer you may delete
bin/rails db:migrate       # omen_readings, omen_questions, omen_answers
bin/rails db:omen:grant    # the read-only role a statement runs as, and three functions
bin/rails g omen:pages     # a model, a controller, three views and a route, all yours
```

`bin/rails s`, then `/inquiries`. Type a question and the answer arrives under it, with the
statement Claude wrote and the rows it found.

## What your app has to have first

None of it is Omen's to create, and each is checked rather than assumed:

- **PostgreSQL**, and a `db/schema.rb` rather than a `structure.sql`. Both are raised on at boot.
- **A read-only connection role**: `connects_to database: { writing: :primary, reading: :reader }`
  on `ApplicationRecord`, where `reader` logs in as a Postgres role granted `SELECT` and nothing
  else. Omen raises rather than falling back to a role that could write, which is the point.
  Naming that role is yours; making one safely is not, since a managed database refuses half the
  DDL it takes — so `Omen::Grants.made`, `Omen::Attributes.dangerous`, `Omen.attempted` and
  `Omen.each_database` are public, and a host's own task is the grants it wants and little else:

      module Reader
        ROLE = 'your_app_reader'

        def self.grant = Omen.each_database { |connection| grant_on connection }

        def self.grant_on(connection)
          statements(connection).each { |it| Omen.attempted connection, it }
          held = Omen::Attributes.dangerous connection, ROLE
          warn "#{ROLE} holds #{held.to_sentence}" if held.any?
        end

        def self.statements(connection)
          role = connection.quote_table_name ROLE
          Omen::Grants.made(connection, ROLE, login: true) +
            [ "GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{role}", ... ]
        end
      end

  `Omen.attempted` runs each statement in a savepoint and warns rather than raising, so one
  refusal discards neither the deploy nor the statements behind it. `Omen::Grants.made` asserts
  only what whoever may create a role may set: saying `NOSUPERUSER` needs the `SUPERUSER`
  attribute, so it is read back with `Omen::Attributes.dangerous` and warned about instead.
- **`ANTHROPIC_API_KEY`**, or a key named in the initializer.
- **Active Record Encryption keys**, without which an encrypted column reads back as a
  placeholder rather than as its value, quietly.
- **An `ApplicationJob`**, since a reading is answered outside the request.

## What you get

`Omen::Reading.create! question: 'Where are the homes we serve?'` is the whole of asking, and
`reading.ask '...'` is a follow-up. Each question is answered in a job, and the answer carries
the statement Claude wrote, the rows it found, and which of their headers held an encrypted
column. `rails g omen:pages` writes the pages that draw all of that, into your app, for you to
keep or replace.

## Two kinds of reading

`omen_readings` carries a `type`, so a subclass of `Omen::Reading` is a kind of reading rather
than a second name for every row: `Inquiry.count` counts inquiries, and a row answers as what it
was written as, whatever class asks for it. That last part is what keeps a narrowing honest --
what a reading may read is the row's own to say, not the caller's.

Upgrading an app that already has readings: they were written without a type, so they come back
as `Omen::Reading` until you say what they were. One `UPDATE omen_readings SET type = 'Inquiry'`
per kind, in a migration of your own.

## Narrowing a reading to one owner's rows

A reading answers with whatever its role may read, so an app that lets a customer ask about
their own data says so on the reading, and `db:omen:grant` writes it into the database:

```ruby
class Consult < Omen::Reading
  belongs_to :provider

  narrows 'provider_inquirer', by: :provider_id,
    own: {
      'bookings' => 'provider_id = %{owner}',
      'locations' => 'EXISTS (SELECT 1 FROM bookings WHERE bookings.location_id = locations.id)',
    },
    whole: %w[ states zips ], except: /_count\z/

  def notes = Rails.root.join('config/provider_notes.md').read
end
```

`own` is every table it reads rows of, and what makes a row its own -- `%{owner}` stands for
whoever the reading names, and a table reaching through another needs no owner of its own, since
the policy on the table it reaches through has already run. `whole` is read entire, because
nothing in those tables is anybody's; `except` is the columns of those it may not read, a counter
over everybody being the case it exists for. A credential is refused everywhere, by name, without
being asked for.

What that buys is that it does not matter what SQL Claude writes -- a join, a `WITH`, a `UNION`,
a subquery on a table it was never shown -- every path resolves through the policy, and rows
outside it do not exist for that role. The reading's own row says who it is: the setting is `SET
LOCAL` inside the transaction the statement runs in, and gone with it. A reading that names
nobody reads nothing.

### What it does not take away

Row level security binds every role but a table's owner, so turning it on could empty a table for
everybody else. It does not: each table gets a permissive policy for everybody beside the
`RESTRICTIVE` one for the narrowed role, which is ANDed with it and applies to nobody else -- a
role created afterwards included. The membership that lets a role enter the narrowed one is
granted `WITH INHERIT FALSE` (Postgres 16 and later) so that entering it is not the same as being
held back by it.

`db:omen:narrowed` says which roles each restrictive policy really holds back, membership and all,
and exits non-zero on one nobody asked for -- worth running in CI, since an over-narrowed role
reads empty rather than raising. `db:omen:widen` takes it all back off.

## Everything else

[INSTRUCTIONS.md](INSTRUCTIONS.md) has the reasoning: why Postgres and no other adapter, what
`db:omen:grant` creates and what to do on a managed database that forbids it, every setting and
its default, what the generated pages get right and why, and what a host can build on top.

## License

MIT, see [LICENSE.txt](LICENSE.txt).
