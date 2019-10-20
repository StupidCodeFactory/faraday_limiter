lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "faraday_limiter/version"

Gem::Specification.new do |spec|
  spec.name          = "faraday_limiter"
  spec.version       = FaradayLimiter::VERSION
  spec.authors       = ["yann marquet"]
  spec.email         = ["ymarquet@gmail.com"]

  spec.summary       = %q{API limiter for faraday}
  spec.description   = %q{API limiter for faraday}
  spec.homepage      = "https://github.com/StupidCodeFactory/faraday_limiter"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/StupidCodeFactory/faraday_limiter"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 0.12"
  spec.add_dependency "concurrent-ruby-edge", "~> 0.5.0"
  spec.add_dependency "redis", "~> 4.1.3"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "byebug", "~> 11.0"
  spec.add_development_dependency "webmock", "~> 3.7.6"
  spec.add_development_dependency "activesupport", ">= 4.1"
end
