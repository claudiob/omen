# Be sure to restart your server when you modify this file.
# Every setting Omen has is listed with the default it takes where the line is left out, so
# an app that accepts all of them can delete the block. What an app has to provide outside
# this file -- the read-only connection, the narrow role and the database function -- is in
# the gem's README, and none of it is optional.

Omen.configure do |config|
  # The Active Record whose descendants are read for encrypted columns, and whose connection
  # roles a statement is run through. A name, since nothing is autoloaded while this runs.
  # config.record_class = 'ApplicationRecord'

  # The Rails connection role a statement is read through. This app has to declare it with
  # connects_to: Omen raises rather than falling back to a role that could write.
  # config.reading_role = :reading

  # The Postgres role the statement itself runs as, narrower again than the connection's own.
  # Created by bin/rails db:omen:grant, which is also what revokes Omen's own tables from it.
  # config.narrow_role = 'omen_inquirer'

  # config.claude_model = 'claude-opus-5'

  # How many rows of one answer a page shows. One more than this is read, so the page can say
  # there are more without counting them.
  # config.maximum_rows = 100

  # How many of those rows an answer's words read out before saying there are more.
  # config.rows_read_out = 8

  # How many turns of a thread travel with the next question. A thread nobody clears would
  # otherwise carry its whole history into each one, and be charged for it again each time.
  # config.remembered = 5

  # Left unset, the Anthropic SDK resolves ANTHROPIC_API_KEY and its own wider chain.
  # config.api_key = Rails.application.credentials.dig :anthropic, :api_key

  # A file of prose about this app's own data: what it is, and where a table's rows really
  # are. Everything the schema cannot say, and Claude is given it verbatim.
  # config.notes = Rails.root.join 'config/omen_notes.md'

  # Where Rails keeps the schema this app dumps, which is what Claude is shown.
  # config.schema_path = 'db/schema.rb'
end
