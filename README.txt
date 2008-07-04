
RUBYCHECKER - RUNS CHECKS ON A RUBY INTERPRETER
===============================================

USAGE
-----
  rubychecker.rb [options] [suite or suites to run]


OPTIONS
-------
  * -t TAG
    A tag to include in the filenames of the reports, e.g., a tag of
    "p111" may create report files like "rspec_1.1.4_with_p111.log"
  * -v
    Displays version information and exits.
  * -h
    Displays this help information and exits.
  * -F
    Don't freshen existing checkouts (skip git pull, svn update, etc).
  * -f
    Freshens existing checkouts (git pull, svn update, etc).
  * -p
    Prepares dependencies and exits without running checks.
  * -n
    Dry-run, display commands to execute but don't run them.


BASIC EXAMPLES
--------------
  # Runs test suites against the "ruby" interpreter in your current
  # shell's PATH and records them to the "reports" directory:
  ./rubychecker.rb

  # Run only the test suite for rspec:
  ./rubychecker.rb rspec

  # Run only the test suite for rails version 2.1.0 and record the results
  # into a report with the tag "p265" in the filenames:
  ./rubychecker.rb -t p265 rails=2.1.0


COMPLEX EXAMPLE
---------------
  # Download, compile and check a Ruby interpreter from SVN:

  rubysvn=$PWD/cache/ruby
  rubytmp=$PWD/tmp/ruby
  export PATH=$rubytmp/bin:$PATH
  mkdir -p cache
  svn co http://svn.ruby-lang.org/repos/ruby/branches/ruby_1_8_6 $rubysvn
  pushd $rubysvn
      autoconf
      ./configure --prefix=$rubytmp && make && make install
  popd
  ./rubychecker.rb -t svn186


DEPENDENCIES:
-------------
  * ruby
  * ruby headers
  * complete build environment, e.g., gcc, make, etc
  * grep
  * git
  * svn
  * unzip
  * MySQL headers
  * SQLite3 headers
  * MySQL server
      You'll need to login as DBA and run:
        CREATE DATABASE activerecord_unittest;
        CREATE DATABASE activerecord_unittest2;
        CREATE DATABASE actionwebservice_unittest;
        CREATE USER 'rails'@'localhost' IDENTIFIED BY PASSWORD '';
        GRANT ALL ON activerecord_unittest.* TO 'rails'@'localhost';
        GRANT ALL ON activerecord_unittest2.* TO 'rails'@'localhost';
        GRANT ALL ON actionwebservice_unittest.* TO 'rails'@'localhost';
        FLUSH PRIVILEGES;


WHAT DOESN'T WORK YET:
----------------------
  * Any OS other than UNIX
  * Any Ruby interpreter other than MRI 1.8


SOURCE CODE:
------------
  http://github.com/igal/rubychecker


ISSUE TRACKER:
--------------
  http://code.google.com/p/rubychecker


LICENSE:
--------
  This program is provided under the same license as Ruby:
    http://www.ruby-lang.org/en/LICENSE.txt

