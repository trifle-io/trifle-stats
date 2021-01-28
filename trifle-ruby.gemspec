require_relative 'lib/trifle/ruby/version'

Gem::Specification.new do |spec|
  spec.name          = 'trifle-ruby'
  spec.version       = Trifle::Ruby::VERSION
  spec.authors       = ['Jozef Vaclavik']
  spec.email         = ['jozef@hey.com']

  spec.summary       = 'Simple analytics for tracking events and status counts'
  spec.description   = 'Trifle (ruby) allows you to submit counters and'\
                       'automatically storing them for each range.'\
                       'Supports multiple backend drivers.'
  spec.homepage      = "https://github.com/trifle-io/trifle-ruby"
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "https://github.com/trifle-io/trifle-ruby"

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
  spec.add_development_dependency('rake', '~> 13.0')
  spec.add_development_dependency('rspec', '~> 3.2')
  spec.add_development_dependency('rubocop', '1.0.0')
  spec.add_runtime_dependency('redis', '>= 4.2')
  spec.add_runtime_dependency('tzinfo', '~> 2.0')
end
