#!/usr/bin/env ruby

# = RubyChecker - Runs checks on a Ruby interpreter
#
# == USAGE
#
#   rubychecker.rb [options] [suite or suites to run]
#
# == OPTIONS
#
#   * -t TAG
#     A tag to include in the filenames of the reports, e.g., a tag of
#     "p111" may create report files like "rspec_1.1.4_with_p111.log"
#   * -v
#     Displays version information and exits.
#   * -h
#     Displays this help information and exits.
#   * -F
#     Don't freshen existing checkouts (skip git pull, svn update, etc).
#   * -f
#     Freshens existing checkouts (git pull, svn update, etc).
#   * -p
#     Prepares dependencies and exits without running checks.
#   * -n
#     Dry-run, display commands to execute but don't run them.
#
# == BASIC EXAMPLES
#
#   # Runs test suites against the "ruby" interpreter in your current
#   # shell's PATH and records them to the "reports" directory:
#   ./rubychecker.rb
#
#   # Run only the test suite for rspec:
#   ./rubychecker.rb rspec
#
#   # Run only the test suite for rails version 2.1.0 and record the results
#   # into a report with the tag "p265" in the filenames:
#   ./rubychecker.rb -t p265 rails=2.1.0
#
# == COMPLEX EXAMPLE
#
#   # Download, compile and check a Ruby interpreter from SVN:
#
#   rubysvn=$PWD/cache/ruby
#   rubytmp=$PWD/tmp/ruby
#   export PATH=$rubytmp/bin:$PATH
#   mkdir -p cache
#   svn co http://svn.ruby-lang.org/repos/ruby/branches/ruby_1_8_6 $rubysvn
#   pushd $rubysvn
#       autoconf
#       ./configure --prefix=$rubytmp && make && make install
#   popd
#   ./rubychecker.rb -t svn186
#
# == DEPENDENCIES:
#   * ruby
#   * ruby headers
#   * complete build environment, e.g., gcc, make, etc
#   * grep
#   * git
#   * svn
#   * unzip
#   * MySQL headers
#   * SQLite3 headers
#   * MySQL server
#       You'll need to login as DBA and run:
#         CREATE DATABASE activerecord_unittest;
#         CREATE DATABASE activerecord_unittest2;
#         CREATE DATABASE actionwebservice_unittest;
#         CREATE USER 'rails'@'localhost' IDENTIFIED BY PASSWORD '';
#         GRANT ALL ON activerecord_unittest.* TO 'rails'@'localhost';
#         GRANT ALL ON activerecord_unittest2.* TO 'rails'@'localhost';
#         GRANT ALL ON actionwebservice_unittest.* TO 'rails'@'localhost';
#         FLUSH PRIVILEGES;
#
# == WHAT DOESN'T WORK YET:
#
#   * Any OS other than UNIX
#   * Any Ruby interpreter other than MRI 1.8
#
# == SOURCE CODE:
#
#   http://github.com/igal/rubychecker
#
# == ISSUE TRACKER:
#
#   http://code.google.com/p/rubychecker
#
# == LICENSE:
#
#   This program is provided under the same license as Ruby:
#     http://www.ruby-lang.org/en/LICENSE.txt

require 'fileutils'
require 'open-uri'
require 'pathname'
require 'set'
require 'uri'

class RubyChecker
  # Version of RubyChecker.
  VERSION = "r2"

  # Source URLs for dependencies.
  SOURCES = {
    :rails    => "git://github.com/rails/rails.git",
    :rspec    => "git://github.com/dchelimsky/rspec.git",
    :rubyspec => "git://github.com/rubyspec/rubyspec.git",
    :rubygems => "http://rubyforge.org/frs/download.php/38647/rubygems-1.2.0.zip",
  }

  # Gems to install.
  GEMS = %w(
    diff-lcs
    heckle
    hpricot
    mocha
    mspec
    mysql
    rake
    rcov
    sqlite3-ruby
    syntax
  )

  # Base working directory.
  attr_accessor :base_dir
  # Directory with cached downloads.
  attr_accessor :cache_dir
  # Directory with reports.
  attr_accessor :reports_dir
  # Directory with gems.
  attr_accessor :gems_dir

  # Pathname instance for base_dir.
  attr_accessor :base_path
  # Pathname instance for cache_dir.
  attr_accessor :cache_path
  # Pathname instance for reports_dir.
  attr_accessor :reports_path
  # Pathname instance for gems_dir.
  attr_accessor :gems_path

  # String to tag report filenames with, e.g., "p265".
  attr_accessor :tag
  # Freshen the checked-out files? Defaults to true.
  attr_accessor :freshen
  # Display commands without running them? Defaults to false.
  attr_accessor :dryrun

  # Instantiate a new RubyChecker object.
  #
  # Options:
  # * :base_dir => Base working directory to use. Defaults to current directory.
  # * :tag      => String to tag report filenames with, e.g., "p265". Defaults to "current".
  # * :freshen  => Freshen the checked-out files? Defaults to true.
  # * :dryrun   => Display commands without running them? Defaults to false.
  def initialize(opts={})
    @base_dir     = File.expand_path(opts[:base_dir] || Dir.pwd)
    @reports_dir  = File.expand_path(File.join(@base_dir, "reports"))
    @cache_dir    = File.expand_path(File.join(@base_dir, "cache"))
    @gems_dir     = File.expand_path(File.join(@cache_dir, "gems"))

    @base_path    = Pathname.new(@base_dir)
    @reports_path = Pathname.new(@reports_dir)
    @cache_path   = Pathname.new(@cache_dir)
    @gems_path    = Pathname.new(@gems_dir)

    @tag          = opts[:tag] || "current"
    @freshen      = opts[:freshen] != false
    @dryrun       = opts[:dryrun] == true || false
  end

  #---[ prepare ]---------------------------------------------------------

  # Prepare the environment, by checking out the sources, installing the
  # RubyGems application, and installing the Gem libraries.
  def prepare
    prepare_sources
    prepare_rubygems
    prepare_gems
  end

  # Prepare directories, by creating them if necessary.
  def prepare_dirs
    [@reports_dir, @cache_dir, @gems_dir].each do |dir|
      Dir.mkdir(dir) unless File.directory?(dir)
    end
  end

  # Prepare sources, download them if necessary.
  def prepare_sources
    SOURCES.each_pair do |suite, url|
      prepare_source_for(url, @freshen)
    end
  end

  # Download or freshen a download from +url+.
  def prepare_source_for(url, freshen=true)
    self.prepare_dirs
    FileUtils.cd(@cache_dir) do
      uri = URI.parse(url)
      case uri.scheme
      when "git"
        name = File.basename(url, ".git")
        if File.directory?(name)
          if freshen
            FileUtils.cd(name) do
              run "git checkout -f master"
              run "git pull --rebase origin master"
              run "git fetch --tags"
            end
          end
        else
          run "git clone #{url}"
        end
      when "http", "ftp"
        name = File.basename(url)
        unless File.exist?(name)
          File.open(name, "w+") do |writer|
            open(url) do |reader|
              writer.write(reader.read)
            end
          end
        end
      else
        raise ArgumentError, "Unknown revision control scheme: #{uri.scheme}"
      end
    end
  end

  # Prepare RubyGems application, install it if necessary.
  #
  # NOTE: This method sets the PATH to provide access to the installed Gem
  # libraries, so it must be called before the checks run.
  def prepare_rubygems
    begin
      require "rubygems"
      # RubyGems is installed
    rescue LoadError
      # RubyGems needs to be installed
      FileUtils.cd(@cache_dir) do
        archive = File.basename(SOURCES[:rubygems])
        dir     = File.basename(archive, ".zip")
        FileUtils.rm_rf(dir) if File.directory?(dir)
        # TODO consider using rubyzip?
        run "unzip #{archive}", true
        FileUtils.cd(dir) do
          run "ruby 'setup.rb' --no-ri --no-rdoc", true
        end
      end
    end
    ENV["PATH"] = "#{`gem env path`.strip}/bin:#{ENV['PATH']}"
  end

  # Prepare Gem libraries, install them if necessary.
  def prepare_gems(gems=GEMS)
    FileUtils.cd(@gems_dir) do
      listing = `gem list --local`
      missing = gems.reject{|package| listing.match(/^#{package}\s/)}
      run "gem install #{missing.join(' ')} --no-ri --no-rdoc", true if missing.size > 0
    end
  end

  #---[ check ]-----------------------------------------------------------

  # Check the +targets+ by running their test suites.
  #
  # Arguments:
  # * targets => String, Tuples, or Array of Strings that are either a word
  #   like "rspec" which represent a test suite's title, or a compound word
  #   like "rspec=1.1.4" which represents a test suite's title and variant.
  def check(*targets)
    targets.flatten!

    suites = Set.new

    if targets.size == 0
      suites += Suite.suites
    else
      targets.each do |target|
        title, variant = target.split("=")
        matches = Suite.suites_for(title, variant)
        if matches.size == 0
          raise ArgumentError, "Unknown suite: #{target}"
        else
          suites += matches
        end
      end
    end

    suites.each do |suite|
      suite.new(self).invoke
    end
  end

  #---[ reporting ]-------------------------------------------------------

  # Run the +command+. Displays the command alwasy, but only executes it if
  # @dryrun is false. If +fatal+ is true, a non-zero exit value from a system
  # call will cause the program to exit.
  def run(command, fatal=false)
    current_path    = Pathname.new(Dir.pwd)
    base2current    = current_path.relative_path_from(@base_path)
    current2reports = @reports_path.relative_path_from(current_path)
    displayable = "(cd #{base2current} && #{command.gsub(/#{@reports_dir}/, current2reports.to_s)})"

    puts(displayable)
    unless self.dryrun
      system(command) 
      if fatal && $?.exitstatus != 0
        puts "ERROR RUNNING: #{displayable}"
        exit $?.exitstatus
      end
    end
  end

  # Create a report file from the results of running the +command+ for the test
  # suite with the +title+ and +variant+.
  def create_report_for(command, title, variant)
    self.run("#{command} 2>&1 | tee #{self.report_filename_for(title, variant)}")
  end

  # Append to an existing report file the results of running the +command+ for
  # the test suite with the +title+ and +variant+.
  def append_report_for(command, title, variant)
    self.run("#{command} 2>&1 | tee -a #{self.report_filename_for(title, variant)}")
  end

  # Remove the report for the test suite with the +title+ and +variant.
  def remove_report_for(title, variant)
    report = self.report_filename_for(title, variant)
    File.delete(report) if File.exist?(report)
  end

  # Return a report filename for the test suite +title+ and +variant+. If the
  # +variant+ is nil, it's not included in the filename.
  def report_filename_for(title, variant=nil)
    return File.join(@reports_dir, "#{title}#{variant ? '_'+variant.to_s : ''}_with_#{@tag}.log")
  end

  #---[ suite ]-----------------------------------------------------------

  # A test suite hierarchy.
  class Suite
    class << self
      # Set of test suites, as Suite::Base subclasses.
      attr_accessor :suites
    end
    self.suites = Set.new

    # Return an array of test suite titles.
    def self.suite_titles
      self.suites.map{|suite| suite.title}
    end

    # Return an array of suites matching the +title+ and optional +variant+.
    def self.suites_for(title, variant=nil)
      self.suites.select{|suite| suite.title == title && (variant ? suite.variant == variant : true)}
    end

    # Common base for all Suite subclasses.
    class Base
      def self.inherited(subclass)
        # Add this test suite to the registry.
        Suite.suites << subclass

        subclass.module_eval do
          class << self
            # String title of test suite, e.g., "RSpec"
            attr_accessor :title

            # String variant of test suite, e.g., "1.1.4"
            attr_accessor :variant
          end

          # RubyChecker instance
          attr_accessor :checker
        end
      end

      # Instantiate a new suite subclass using the +checker+ instance.
      def initialize(checker)
        self.checker = checker
      end

      # Invoke the test suite.
      def invoke
        raise NotImplementedError, "Author of subclass forgot to implement #invoke"
      end

      # Return this Suite's title, e.g., "RSpec".
      def title
        self.class.title
      end

      # Return this Suite's variant, e.g., "1.1.4".
      def variant
        self.class.variant
      end

      # Run the +command+ and create a report from its results.
      def create_report_for(command)
        checker.create_report_for(command, self.title, self.variant)
      end

      # Run the +command+ and append its results to a report.
      def append_report_for(command)
        checker.append_report_for(command, self.title, self.variant)
      end

      # Remove an report, if it exists.
      def remove_report
        checker.remove_report_for(self.title, self.variant)
      end

      # Run a +command+.
      def run(command)
        checker.run(command)
      end
    end

    #---[ suites ]----------------------------------------------------------

    class RubySpec < Base # :nodoc:
      self.title   = "rubyspec"
      self.variant = "master"

      def invoke
        FileUtils.cd(File.join(checker.cache_dir, self.title, "1.8")) do
          create_report_for("mspec .")
        end
      end
    end

    class RSpec < Base # :nodoc:
      self.title   = "rspec"
      self.variant = "1.1.4"

      def invoke
        FileUtils.cd(File.join(checker.cache_dir, self.title)) do
          run "git checkout -f #{self.variant}"
          create_report_for("rake spec")
        end
      end
    end

    class Rails126 < Base # :nodoc:
      self.title   = "rails"
      self.variant = "1.2.6"

      def invoke
        FileUtils.cd(File.join(checker.cache_dir, self.title)) do
          run "git checkout -f v#{self.variant}"
          remove_report
          Dir["*"].select{|path| File.directory?(path)}.each do |dir|
            FileUtils.cd(dir) do
              if dir.match(/actionwebservice/)
                append_report_for("rake build_database")
              end
              append_report_for("rake test")
            end
          end
        end
      end
    end

    class Rails202 < Base # :nodoc:
      self.title   = "rails"
      self.variant = "2.0.2"

      def invoke
        FileUtils.cd(File.join(checker.cache_dir, self.title)) do
          run "git checkout -f v#{self.variant}"
          create_report_for("rake test")
        end
      end
    end

    class Rails210 < Base # :nodoc:
      self.title   = "rails"
      self.variant = "2.1.0"

      def invoke
        FileUtils.cd(File.join(checker.cache_dir, self.title)) do
          run "git checkout -f v#{self.variant}"
          create_report_for("rake test")
        end
      end
    end
  end

end

#===[ main ]============================================================

if __FILE__ == $0
  require 'getoptlong'
  require 'rdoc/usage'

  checker = RubyChecker.new
  targets = []
  prepare_only = false

  opts = GetoptLong.new(*[
    ['--dryrun',       '-n', GetoptLong::NO_ARGUMENT],
    ['--freshen',      '-f', GetoptLong::NO_ARGUMENT],
    ['--help',         '-h', GetoptLong::NO_ARGUMENT],
    ['--prepare',      '-p', GetoptLong::NO_ARGUMENT],
    ['--skip-freshen', '-F', GetoptLong::NO_ARGUMENT],
    ['--tag',          '-t', GetoptLong::OPTIONAL_ARGUMENT],
    ['--version',      '-v', GetoptLong::NO_ARGUMENT]
  ])

  begin
    opts.each do |opt, arg|
      case opt
      when '--dryrun'
        checker.dryrun = true
      when '--freshen'
        checker.freshen = true
      when '--help'
        RDoc::usage
      when '--prepare'
        prepare_only = true
      when '--skip-freshen'
        checker.freshen = false
      when '--tag'
        checker.tag = arg
      when '--version'
        puts "rubychecker #{RubyChecker::VERSION}"
        exit 0
      end
    end
  rescue GetoptLong::InvalidOption => e
    # Error is displayed automatically
    exit 7
  end

  targets.concat(ARGV)

  if targets.first == "README.txt"
    system "'#{__FILE__}' --help > README.txt"
    exit 0
  end

  checker.prepare
  checker.check(*targets) unless prepare_only
end
