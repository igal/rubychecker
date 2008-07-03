rubychecker - runs checks on a Ruby interpreter

USAGE: rubychecker.sh [OPTIONS]

OPTIONS:
    -t tag
        Name of interpreter to use when naming reports, e.g., "p111" or
        "svn12345". Defaults to "current".

    -v
        Displays version number and quits.

    -C
        Skip checkouts

    -S
        Skip all preparations that can be skipped

BASIC EXAMPLE:
    # Runs test suites against the "ruby" interpreter in your current
    # shell's PATH and records them to the "reports" directory:

    ./rubychecker.sh

COMPLETE EXAMPLE:
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
    ./rubychecker.sh -t svn186

DEPENDENCIES:
    - ruby
    - ruby headers
    - complete build environment, e.g., gcc, make, etc
    - bash
    - grep
    - wget
    - git
    - svn
    - tar
    - MySQL headers
    - SQLite3 headers
    - MySQL server
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
    - Any OS other than UNIX
    - Any Ruby interpreter other than MRI 1.8

SOURCE CODE: 
    http://github.com/igal/rubycheck_sh

ISSUE TRACKER:
    http://code.google.com/p/rubychecker
    
LICENSE:
    This program is provided under the same license as Ruby:
        http://www.ruby-lang.org/en/LICENSE.txt
