module Omen
  # Everything said to a database to make the role a statement runs as: what it may be, what it
  # may read, and what it may not. Kept apart from the task that runs them, which is about a
  # database it has to find and a refusal it has to survive rather than about privileges.
  module Grants
    # Membership without inheritance, so a role that enters a narrowed one with SET LOCAL ROLE
    # is not itself held back by its policies. Postgres 16 and later; below that the grant is
    # refused and the task says so, which leaves a reading misconfigured rather than narrowing
    # somebody nobody meant to narrow.
    APART = 'GRANT %{role} TO %{member} WITH INHERIT FALSE'

    # DDL, which Active Record has no expression for, and not a query.
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] a writing one.
    # @param members [Array<String>] the roles that may SET LOCAL ROLE to this one. The owner
    #   running the task is one of them, and matters in tests, where Rails swaps the reading
    #   pool for the writing one and the test connection is the owner.
    # @return [Array<String>] the statements to run, in order.
    def self.statements(connection, members)
      role = connection.quote_table_name Omen.config.narrow_role
      [
        *made(connection, Omen.config.narrow_role),
        *members.map { |member| "GRANT #{role} TO #{connection.quote_table_name member}" },
        "GRANT USAGE ON SCHEMA public TO #{role}",
        "GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{role}",
        "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO #{role}",
        *revoked(connection, role),
        *Omen::Renamed.statements,
        *Omen::TimeZone.statements(connection),
        *Omen::Distance.statements(connection),
      ]
    end

    # Who may enter the role, and the schema it reads in. Kept apart from making the role: a
    # managed database refuses to make one at all, and a refusal takes its whole transaction
    # with it -- so membership granted in the same breath would be lost to a role that was
    # already there and only needed letting into.
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] a writing one.
    # @param name [String] the role to make.
    # @param members [Array<String>] the roles that may enter it, none of them inheriting it.
    # @return [Array<String>] the statements to run, in order.
    def self.narrowed(connection, name, members)
      role = connection.quote_table_name name
      [
        *members.map { |member| apart role, connection.quote_table_name(member) },
        "GRANT USAGE ON SCHEMA public TO #{role}",
      ]
    end

    # @param role [String] the role, quoted.
    # @param member [String] the role that may enter it, quoted.
    # @return [String] the statement that lets it in without handing it what the role holds.
    def self.apart(role, member) = APART % { role: role, member: member }

    # Named one by one rather than granted whole: a column added to hold a secret, or to count
    # what belongs to everybody, is one a role has to be given before it can read it. Taken away
    # first, since a grant only ever adds: without the revoke, a column dropped from the list
    # stays readable by whoever was granted it the last time this ran.
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] a writing one.
    # @param name [String] the role to grant them to.
    # @param table [String] the table whose columns are being granted.
    # @param refused [Regexp] the columns of it that role may not read.
    # @return [Array<String>] what it may read of that table, said over again.
    def self.granted(connection, name, table, refused)
      role = connection.quote_table_name name
      quoted = connection.quote_table_name table
      columns = connection.columns(table).map(&:name).grep_v(refused)
        .map { |column| connection.quote_column_name column }
      [ "REVOKE ALL ON #{quoted} FROM #{role}",
        "GRANT SELECT (#{columns.join ', '}) ON #{quoted} TO #{role}", ]
    end

    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] a writing one.
    # @param name [String] the role to make, where the database has not got it.
    # @param login [Boolean] whether anything connects as it, as a host's reading role does.
    # @return [Array<String>] the statements that make it and say what it may be.
    def self.made(connection, name, login: false)
      role = connection.quote_table_name name
      entered = login ? 'LOGIN' : 'NOLOGIN'
      [ 'DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = ' \
          "#{connection.quote name}) THEN CREATE ROLE #{role} #{entered}; END IF; END $$",
        "ALTER ROLE #{role} WITH #{Attributes.settable login: login}", ]
    end

    # Intersected, so a bare db:create with no table yet to revoke on is not a failure.
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] a writing one.
    # @param role [String] the role to hide this feature's own tables from.
    # @return [Array<String>] one REVOKE per table there is.
    def self.revoked(connection, role)
      (connection.tables & Omen.tables).map do |table|
        "REVOKE SELECT ON #{connection.quote_table_name table} FROM #{role}"
      end
    end
  end
end
