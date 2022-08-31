require_relative 'lib/trifle/stats/version'

Gem::Specification.new do |spec|
  spec.name          = 'trifle-stats'
  spec.version       = Trifle::Stats::VERSION
  spec.authors       = ['Jozef Vaclavik']
  spec.email         = ['jozef@hey.com']

  spec.summary       = 'Simple analytics backed by Redis, Postgres, MongoDB, '\
                       'Google Analytics, Segment, or whatever.'
  spec.description   = 'Trifle::Stats is a way too simple timeline analytics '\
                       'that helps you track custom metrics. Automatically '\
                       'increments counters for each enabled range. '\
                       'It supports timezones and different week beginning.'
  spec.homepage      = 'https://trifle.io'
  spec.licenses      = ['MIT']
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/trifle-io/trifle-stats'
  spec.metadata['changelog_uri'] = 'https://trifle.io/trifle-stats/changelog'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency('bundler', '~> 2.1')
  spec.add_development_dependency('byebug', '>= 0')
  spec.add_development_dependency('dotenv')
  spec.add_development_dependency('mongo', '>= 2.14.0')
  spec.add_development_dependency('sqlite3', '>= 1.4.4')
  spec.add_development_dependency('pg', '>= 1.2')
  spec.add_development_dependency('rake', '~> 13.0')
  spec.add_development_dependency('redis', '>= 4.2')
  spec.add_development_dependency('rspec', '~> 3.2')
  spec.add_development_dependency('rubocop', '1.0.0')

  spec.add_runtime_dependency('tzinfo', '~> 2.0')
end
