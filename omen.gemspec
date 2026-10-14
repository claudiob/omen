require_relative 'lib/omen/version'

Gem::Specification.new do |spec|
  spec.name        = 'omen'
  spec.version     = Omen::VERSION
  spec.authors     = [ 'Claudio Baccigalupo' ]
  spec.email       = [ 'claudiob@users.noreply.github.com' ]
  spec.homepage    = 'https://github.com/claudiob/omen'
  spec.summary     = 'Ask Claude about your own data'
  spec.description = 'Turns a question into the SQL that answers it, and runs it read-only'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri']      = spec.homepage
  spec.metadata['source_code_uri']   = 'https://github.com/claudiob/omen/'
  spec.metadata['changelog_uri']     = 'https://github.com/claudiob/omen/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://rubydoc.info/gems/omen'
  spec.required_ruby_version         = '>= 3'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'CHANGELOG.md', 'INSTRUCTIONS.md', 'LICENSE.txt', 'README.md']
  end

  spec.add_dependency 'active_job-performs' # to answer a question outside the request
  spec.add_dependency 'anthropic' # to reach Claude at all
  spec.add_dependency 'pg' # to read the table a result column came from, and to cast one back
  spec.add_dependency 'rails' # to autoload the models and prefix their tables
end
