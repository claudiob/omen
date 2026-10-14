module Omen
  # Every fact about the app this feature is installed in, so none of its own classes names one.
  # All of them have a default, which is what makes the initializer a host writes optional.
  class Config
    # The Rails connection role a statement is read through. A host has to declare a read-only
    # one: Omen raises rather than falling back to the writing role, which is the point.
    attr_accessor :reading_role

    # The Postgres role a statement runs as, narrower again than the connection's own.
    attr_accessor :narrow_role

    # The Claude model a question is asked of.
    attr_accessor :claude_model

    # How many rows of one answer a page will show.
    attr_accessor :maximum_rows

    # How many of those rows an answer's words read out before saying there are more.
    attr_accessor :rows_read_out

    # How many turns of a thread travel with the next question.
    attr_accessor :remembered

    # The key the Anthropic API is reached with. Left unset, the SDK resolves one of its own.
    attr_accessor :api_key

    # What a host states as a name or as a path, each of them resolved only when it is wanted.
    attr_writer :record_class, :notes, :schema_path

    def initialize
      @reading_role = :reading
      @narrow_role = 'omen_inquirer'
      @claude_model = 'claude-opus-5'
      @maximum_rows = 100
      @rows_read_out = 8
      @remembered = 5
      @schema_path = 'db/schema.rb'
    end

    # A name rather than the class, since nothing is autoloaded while an initializer runs.
    # @return [Class] the Active Record whose descendants and connection roles this feature uses.
    def record = @record_class ? @record_class.constantize : default_record

    # @return [String] the host's own notes about its data, which its schema cannot state.
    def notes = @notes ? File.read(@notes) : ''

    # @return [Pathname] the file Rails keeps in step with the database, which Claude is shown.
    def schema = Rails.root.join @schema_path

  private

    def default_record = defined?(ApplicationRecord) ? ApplicationRecord : ActiveRecord::Base
  end
end
