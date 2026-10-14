module Omen
  # Which roles a restrictive policy really holds back. A role that inherits the privileges of
  # a narrowed one is narrowed along with it, so a page can go empty for somebody nobody meant
  # to narrow -- silently, since an empty answer raises nothing.
  module Bound
    # A policy is written for one role and named after it, so a binding anybody asked for is
    # one whose policy name ends in the name of the role it turned up for.
    ROLES = <<~SQL
      SELECT p.tablename, p.policyname, r.rolname FROM pg_policies p
        CROSS JOIN LATERAL unnest(p.roles) AS named(rolname)
        JOIN pg_roles r ON pg_has_role(r.oid, named.rolname::regrole::oid, 'USAGE')
       WHERE p.permissive = 'RESTRICTIVE' AND p.schemaname = current_schema() AND NOT r.rolsuper
       ORDER BY p.tablename, p.policyname, r.rolname
    SQL

    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] any one.
    # @return [Array<Array<String>>] the table, the policy and the role it holds back.
    def self.roles(connection) = connection.select_rows ROLES

    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] any one.
    # @return [Array<Array<String>>] the ones a host did not ask for.
    def self.surprises(connection)
      roles(connection).reject { |_table, policy, role| policy.end_with? role }
    end
  end
end
