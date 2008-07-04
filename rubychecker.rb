#!/usr/bin/env ruby

# = RubyChecker - Runs checks on a Ruby interpreter
#
# == USAGE
#
#   rubychecker.sh [options] [suite or suites to run]
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
#   * -f
#     Freshens existing checkouts (git pull, svn update, etc).
#   * -p
#     Prepares dependencies and exits without running checks.
#
# == BASIC EXAMPLE
#
#   # Runs test suites against the "ruby" interpreter in your current
#   # shell's PATH and records them to the "reports" directory:
#
#   ./rubychecker.rb
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
#   * bash
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
#   http://github.com/igal/rubycheck_sh
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
require 'uri'

class RubyChecker
  VERSION = "r1"

  SOURCES = {
    :rails    => "git://github.com/rails/rails.git",
    :rspec    => "git://github.com/dchelimsky/rspec.git",
    :rubyspec => "git://github.com/rubyspec/rubyspec.git",
    :rubygems => "http://rubyforge.org/frs/download.php/38647/rubygems-1.2.0.zip",
  }

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

  SUITES = %w(
    rubyspec
    rspec
    rails
  )

  attr_accessor :base_dir
  attr_accessor :cache_dir
  attr_accessor :reports_dir
  attr_accessor :gems_dir
  attr_accessor :tag
  attr_accessor :freshen

  def initialize(opts={})
    @base_dir = File.expand_path(opts[:base_dir] || Dir.pwd)
    @tag      = opts[:tag] || "current"
    @freshen  = opts[:freshen] == true || false

    @reports_dir = File.expand_path(File.join(@base_dir, "reports"))
    @cache_dir   = File.expand_path(File.join(@base_dir, "cache"))
    @gems_dir    = File.expand_path(File.join(@cache_dir, "gems"))
  end

  #---[ prepare ]---------------------------------------------------------

  def prepare
    prepare_sources
    prepare_rubygems
    prepare_gems
  end

  def prepare_dirs
    [@reports_dir, @cache_dir, @gems_dir].each do |dir|
      Dir.mkdir(dir) unless File.directory?(dir)
    end
  end

  def prepare_sources
    SOURCES.each_pair do |suite, url|
      prepare_source_for(url)
    end
  end

  def prepare_source_for(url)
    self.prepare_dirs
    FileUtils.cd(@cache_dir) do
      uri = URI.parse(url)
      case uri.scheme
      when "git"
        name = File.basename(url, ".git")
        if File.directory?(name)
          if @freshen
            FileUtils.cd(name) do
              system "git checkout -f master"
              system "git pull --rebase origin master"
              system "git fetch --tags"
            end
          end
        else
          system "git clone #{url}"
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

  def prepare_rubygems
    begin
      require "rubygems"
      # RubyGems already installed
    rescue LoadError
      # RubyGems needs to be installed
      FileUtils.cd(@cache_dir) do
        archive = File.basename(SOURCES[:rubygems])
        dir     = File.basename(archive, ".zip")
        FileUtils.rm_rf(dir) if File.directory?(dir)
        # TODO consider using rubyzip?
        system "unzip #{archive}"
        FileUtils.cd(dir) do
          system "ruby 'setup.rb' --no-ri --no-rdoc"
        end
      end
    end
  end

  def prepare_gems
    FileUtils.cd(@gems_dir) do
      listing = `gem list --local`
      missing = GEMS.reject{|package| listing.match(/^#{package}\s/)}
      system "gem install #{missing.join(' ')} --no-ri --no-rdoc" if missing.size > 0
    end
  end

  #---[ check ]-----------------------------------------------------------

  def check(*targets)
    targets.flatten!
    targets.concat(SUITES) if targets.size == 0
    targets.each do |suite|
      name = "check_#{suite}"
      if self.respond_to?(name)
        self.send(name)
      else
        raise ArgumentError, "Unknown suite: #{suite}"
      end
    end
  end

  def check_rubyspec
    name = "rubyspec"
    FileUtils.cd(File.join(@cache_dir, name, "1.8")) do
      system "mspec . 2>&1 | tee #{report_filename_for(name)}"
    end
  end

  def check_rspec
    name = "rspec"
    version = "1.1.4"
    FileUtils.cd(File.join(@cache_dir, name)) do
      system "git checkout -f #{version}"
      system "rake spec 2>&1 | tee #{report_filename_for(name, version)}"
    end
  end

  RAILS_TESTS = {
    "2.1.0" => lambda{|checker|
      name = "rails"
      version = "2.1.0"
      system "git checkout -f v#{version}"
      system "rake test 2>&1 | tee #{checker.report_filename_for(name, version)}"
    },
    "2.0.2" => lambda{|checker|
      name = "rails"
      version = "2.0.2"
      system "git checkout -f v#{version}"
      system "rake test 2>&1 | tee #{checker.report_filename_for(name, version)}"
    },
    "1.2.6" => lambda{|checker|
      name = "rails"
      version = "1.2.6"
      system "git checkout -f v#{version}"
      report = checker.report_filename_for(name, version)
      system "cat /dev/null > #{report}"
      Dir["*"].select{|path| File.directory?(path)}.each do |dir|
        FileUtils.cd(dir) do
          system "rake test 2>&1 | tee -a #{report}"
        end
      end
    }
  }

  def check_rails(variant=nil)
    name = "rails"
    FileUtils.cd(File.join(@cache_dir, name)) do
      if variant
        RAILS_TESTS[variant].call(self)
      else
        RAILS_TESTS.each_pair do |variant, routine|
          routine.call(self)
        end
      end
    end
  end

  #---[ misc ]------------------------------------------------------------

  def report_filename_for(suite, version=nil)
    return File.join(@reports_dir, "#{suite}#{version ? '_'+version.to_s : ''}_with_#{@tag}.log")
  end
end

if __FILE__ == $0
  require 'getoptlong'
  require 'rdoc/usage'

  rc = RubyChecker.new
  targets = []
  prepare_only = false

  opts = GetoptLong.new(*[
    ['--freshen', '-f', GetoptLong::NO_ARGUMENT],
    ['--help',    '-h', GetoptLong::NO_ARGUMENT],
    ['--prepare', '-p', GetoptLong::NO_ARGUMENT],
    ['--tag',     '-t', GetoptLong::OPTIONAL_ARGUMENT],
    ['--version', '-v', GetoptLong::NO_ARGUMENT]
  ])

  begin
    opts.each do |opt, arg|
      case opt
      when '--freshen'
        rc.freshen = true
      when '--help'
        RDoc::usage
      when '--prepare'
        prepare_only = true
      when '--tag'
        rc.tag = arg
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

  rc.prepare
  rc.check(*targets) unless prepare_only
end
