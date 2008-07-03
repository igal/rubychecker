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

EXAMPLE:
    bash rubychecker.sh
        Runs test suites against the "ruby" interpreter in your current shell
        and records them to the "reports" directory.

DEPENDENCIES:
    - ruby
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

LICENSE:
    This program is provided under the same license as Ruby:
        http://www.ruby-lang.org/en/LICENSE.txt
