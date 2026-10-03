require 'test_helper'

# The role a reading's statement runs as, and the function it reads a timestamp through.
class Omen::InquirerTest < ActiveSupport::TestCase
  test 'the task a host runs makes the role and the function, and runs again over both' do
    2.times { assert_output(/Granted SELECT on omen_dummy_test/) { Omen::Inquirer.grant } }
  end

  test 'the role is refused the tables a reading is kept in, and granted to whoever reads' do
    ApplicationRecord.with_connection do |connection|
      said = Omen::Grants.statements connection, %w[ somebody ]

      Omen.tables.each do |table|
        assert_includes said, %(REVOKE SELECT ON "#{table}" FROM "omen_inquirer")
      end
      assert_includes said, 'GRANT "omen_inquirer" TO "somebody"'
      assert_includes said, 'ALTER ROLE "omen_inquirer" WITH ' \
                            "#{Omen::Attributes.settable}"
      assert(said.any? { |statement| statement.include? Omen::TimeZone::ZONE })
    end
  end

  # A managed database refuses `NOSUPERUSER` outright -- only a superuser may say it -- and that
  # one refusal used to discard the grants, the revocations and both functions behind it. The
  # refusal is spelled differently here, since the user running these tests is a superuser and
  # would be allowed: what is being tested is surviving a refusal, not causing one.
  test 'a statement the database refuses does not discard the ones after it' do
    ApplicationRecord.with_connection do |connection|
      said = capture_io do
        Omen.attempted connection, 'SELECT 1 FROM a_table_nobody_made'
        Omen.attempted connection, 'CREATE TEMPORARY TABLE omen_probe (id int)'
      end

      assert_match(/Skipped, refused by the database/, said.last)
      assert_equal 0, connection.select_value('SELECT count(*) FROM omen_probe')
    end
  end

  # A managed database never grants CREATEROLE, and a deploy has to finish anyway, having said
  # what somebody has to make by hand.
  test 'a database that will not make the role is warned about rather than raised on' do
    Omen.config.narrow_role = 'pg_reserved_for_postgres' # a name no database will hand over

    said = on_its_own_connection { |connection| capture_io { Omen::Inquirer.grant_on connection } }

    assert_match(/Could not make/, said.last)
  ensure
    Omen.config.narrow_role = 'omen_inquirer'
  end

  # What a managed database does: the app's own user may not create a role, and every table
  # of the narrowing then fails for the same reason. One message, and nothing claimed narrowed.
  test 'an audience whose role cannot be made says so once, not once per table' do
    narrowing = Omen::Narrowing.new role: 'pg_reserved_for_postgres', by: :owner_id,
      own: { 'homes' => 'id = %{owner}' }

    said = on_its_own_connection do |connection|
      capture_io { Omen::Inquirer.narrowed connection, narrowing, %w[ somebody ] }
    end

    assert_match(/Could not make pg_reserved_for_postgres/, said.last)
    assert_no_match(/Narrowed/, said.first)
  end

  # Installation step one leaves a host with no reading role declared, and that is a message
  # rather than a failure: nothing reads through the narrow role until there is one.
  test 'the user a host reads through is discovered, and says so where there is none yet' do
    assert_not_nil Omen::Inquirer.reader

    Omen.config.reading_role = :nowhere_at_all
    assert_nil Omen::Inquirer.reader
  ensure
    Omen.config.reading_role = :reading
  end

private

  # Kept off the connection this test runs in, whose transaction a refused statement would abort.
  def on_its_own_connection(&)
    config = ActiveRecord::Base.configurations.configs_for env_name: 'test', name: 'primary'
    ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection config, &
  end
end
