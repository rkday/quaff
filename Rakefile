require 'rake/testtask'
require 'rubocop/rake_task'
require 'yard'

Rake::TestTask.new do |t|
  t.libs = ["lib", "spec"]
  t.warning = true
  t.verbose = true
  t.test_files = FileList['spec/test_*.rb']
end

Rake::TestTask.new do |t|
  t.name = :functional_test
  t.libs = ["lib", "functional_test"]
  t.warning = true
  t.verbose = true
  t.test_files = FileList['functional_test/*test.rb']
end

YARD::Rake::YardocTask.new

RuboCop::RakeTask.new do |task|
  task.patterns = ['lib/**/*.rb', 'test/*.rb']
end
