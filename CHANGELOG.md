# Changelog

All notable changes to this project will be documented in this file.

For more information about changelogs, check [Keep a Changelog](http://keepachangelog.com) and
[Vandamme](http://tech-angels.github.io/vandamme).

## 0.9.0 - 2026-09-18

* [Fix] An answer landing touches the reading it belongs to, so a page watching one refreshes
  on the answer rather than on whichever status change the run happens to make around it. A
  question already touched its reading, which is why a question appeared and its answer did not.
* [Fix] Making an audience's role and letting members into it are two transactions, not one.
  A managed database refuses to make a role at all, and a refusal takes its whole transaction
  with it -- so the membership a role already there only needed was rolled back with the
  refusal, and every statement run as it went on saying the app was misconfigured.
* [Change] An audience whose Postgres role could not be made says so once and narrows nothing,
  rather than failing table by table and then reporting the audience narrowed. A managed
  database refuses `CREATE ROLE` to the app's own user, and the refusal used to arrive as a
  screenful of `role does not exist` followed by a success line.

## 0.8.0 - 2026-09-16

* [Feature] Make how a Postgres role is made safely public, so a host builds the read-only role
  Omen requires with the care Omen builds its own: `Omen::Grants.made` takes `login:`,
  `Omen::Attributes.dangerous` and `.settable` take the role they are about, and `Omen.attempted`
  and `Omen.each_database` are the two a host's rake task calls. A host had to hand-write all of
  it, and the copy in Fountain asserted `NOSUPERUSER` -- which only a superuser may say, so the
  grant died at its second statement, warned, and left the deploy green for a year

* [Breaking change] `Omen::Attributes.exists?`, `.held` and `.dangerous` take the role to ask
  about rather than reading `Omen.config.narrow_role`, since a host asks about its own

* [Breaking change] `Omen::Attributes::SETTABLE` no longer carries `NOLOGIN`, which is now the
  default of `Omen::Attributes.settable login:` -- a role a host connects as needs `LOGIN`

* [Breaking change] `Omen::Inquirer.attempted` is `Omen.attempted` and `Omen::Inquirer::REFUSED`
  is `Omen::REFUSED`. Neither was ever about the inquirer, and a host calling `Omen::Inquirer`
  to build its reader read as though the two roles were one

## 0.7.0 - 2026-09-12

* [Bugfix] Keep the columns of an answer in the order the statement asked for them. They were
  held as `jsonb`, which sorts a row's keys by length, so a page drew them scrambled

* [Breaking change] Carry five turns of a thread rather than twenty, which is what a question
  usually leans on and what a thread nobody clears can afford to send again every time

## 0.6.0 - 2026-09-11

* [Feature] Carry only the last turns of a thread into the next question, `Omen.config.remembered`
  of them, 20 by default. A thread nobody clears was sending its whole history with every
  question and being charged for it again each time

## 0.5.0 - 2026-09-11

* [Breaking change] `omen_readings` carries a `type` column, so a host's two kinds of reading
  are two classes rather than two names for the same rows. Without it the class that loaded a
  row decided what it could read: a customer's own reading, loaded as the host's admin one, ran
  its statement as the wider role. Rows written before this migration have no type and come
  back as `Omen::Reading`, so a host with subclasses backfills its own -- one `UPDATE` per kind
* [Feature] Narrow a reading to one owner's rows. A subclass declares what its audience may
  read -- `narrows 'the_role', by: :provider_id, own: { 'bookings' => 'provider_id = %{owner}' },
  whole: %w[ zips ]` -- and `db:omen:grant` writes the role, the column grants and the policies.
  The rows are held by Postgres, so every statement Claude can write resolves through them
* [Feature] Turning row level security on takes nothing away from whoever could already read: a
  permissive policy for everybody goes on beside a RESTRICTIVE one for the narrowed role, which
  is ANDed with it and applies to nobody else -- a role made after the fact included
* [Feature] Grant the membership a narrowed role needs `WITH INHERIT FALSE`, so a role that may
  enter it is not itself held back by its policies. Postgres 16 and later
* [Feature] `db:omen:widen` takes every narrowing back off, and `db:omen:narrowed` says which
  roles each restrictive policy really holds back, membership included, and exits non-zero on
  one nobody asked for
* [Feature] Show Claude the schema the role may actually read: a table none of whose columns it
  holds `SELECT` on goes, and so does a column a column-level grant left out, so the prompt
  follows the grants rather than restating them
* [Fix] Revoke before granting a role the columns of a table, since a grant only ever adds: a
  column dropped from the list used to stay readable by whoever was granted it last time
* [Breaking change] `Omen::Query.new` and `Omen::Conversation.new` take the reading they answer,
  and `Omen::Instructions.block` and `Omen::Schema.new` take what it says they may read
* [Breaking change] The shape a reply is held to is `Omen::Reply::SHAPE`, and the config that
  sends it `Omen::Reply.output_config`, both moved off `Omen::Instructions`

## 0.4.0 - 2026-08-24

* [Breaking change] Prefix every database function this gem creates, and drop the names they
  had: `eastern` is now `omen_time_zone`, `miles_between` is `omen_miles_between`. A statement
  stored before this names the old ones, so re-running one fails rather than answering from a
  function nothing maintains -- an answer already drawn is unaffected, since its rows are stored
  rather than recomputed
* [Feature] Create `omen_today()` and tell Claude to build every relative window on it, so a
  statement kept and run again answers "last month" for the month it is run in rather than the
  month it was written in. `STABLE`, and a date rather than a timestamp
* [Feature] Ask for a note that says a sliding window the way the statement says it, and then
  what it comes to today, so a stored note does not stop being true on the second run

## 0.3.1 - 2026-08-24

* [Fix] Stop asserting the role attributes only a superuser may set, since `NOSUPERUSER`,
  `NOBYPASSRLS` and `NOREPLICATION` are refused outright by every managed database -- a role is
  created without them anyway, so they are read back and warned about rather than set
* [Fix] Run each statement of the grant in a savepoint of its own, so one a database refuses no
  longer discards the grants, the revocations and both functions behind it

## 0.3.0 - 2026-08-24

* [Feature] Create a `miles_between(lat1, lng1, lat2, lng2)` function and name it in the prompt,
  so a radius is four arguments rather than a dozen nested trigonometric calls that a reply
  balances by hand -- and gets wrong
* [Fix] Tell Claude that text is single-quoted and an apostrophe inside it is doubled, since a
  double-quoted literal is read as a column name and refuses the whole statement
* [Fix] Tell Claude to declare a `combine` where an encrypted value belongs inside a sentence,
  rather than returning the pieces as columns for the page to draw apart

## 0.2.2 - 2026-08-24

* [Fix] Run a load hook as each model loads, so a host declares `broadcasts_refreshes` and the
  rest through `ActiveSupport.on_load :omen_reading` rather than by naming the class while
  initializers run, which loaded Active Record before Rails was up
* [Fix] Read the adapter through the `:active_record` load hook, so a boot that never touches
  the database is not the boot that loads it early

## 0.2.1 - 2026-08-24

* [Fix] Declare `eastern()` over an instant as well as a stored timestamp, so a reply that
  reaches for `now()` finds a function rather than `does not exist`
* [Fix] Tell Claude not to ask the database what time it is, since the prompt already says
  what today is
* [Fix] Point RubyGems at the API reference, so a gem page and a gem listing say the same
  thing about where the documentation is

## 0.2.0 - 2026-08-21

* [Feature] Ask Claude a question about an app's own data, and run the SQL it writes against a
  read-only connection: three models, the prompt, the narrow role and the function a timestamp
  is read through, an install generator, and no controllers, routes or views

## 0.1.0 - 2026-08-21

* [Feature] An engine that loads and does not do anything yet
