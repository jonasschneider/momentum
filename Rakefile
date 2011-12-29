require "bundler/gem_tasks"

task :default => [:spec]

require 'rspec/core/rake_task'
desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern    = FileList['spec/**/*_spec.rb']
  t.rspec_opts = %w(-fp --color)
end
