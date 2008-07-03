#!/bin/bash

# Please run this program with "--help" or review the "usage" function
# below for information on this program and how to use it.

#=======================================================================

# Display usage
usage () {
    cat <<HERE
rubychecker - runs checks on a Ruby interpreter

USAGE: rubychecker.sh [OPTIONS] [BASEDIR]

OPTIONS:
    -t tag
        Name of interpreter to use when naming reports, e.g., "p111" or
        "svn12345". Defaults to "current".

    -v
        Displays version number and quits.

    -U
        Skip checkouts

    -R
        Skip installing RubyGems program

    -G
        Skip installing Gem libraries

    -S
        Skip checkouts, RubyGems, and Gems


BASE DIRECTORY STRUCTURE

    cache

    reports

EXAMPLE

  ./rubychecker.sh .
      This will use the current directory as the working directory.
HERE
}

#===[ Settings ]========================================================

# Sources
RAILS_SOURCE="git://github.com/rails/rails.git"
RSPEC_SOURCE="git://github.com/dchelimsky/rspec.git"
MSPEC_SOURCE="git://github.com/rubyspec/mspec.git"
RUBYSPEC_SOURCE="git://github.com/rubyspec/rubyspec.git"
RUBYGEMS_SOURCE="http://rubyforge.org/frs/download.php/38646/rubygems-1.2.0.tgz"

#===[ Functions ]=======================================================

# Switch into directory, silently.
pushds () {
    local dir="$1"

    pushd "$dir" > /dev/null
}

# Return to previous directory, silently.
popds () {
    popd > /dev/null
}

# Display error message and exit with error.
fail () {
    local message="$1"

    echo "ERROR: $message"
    exit 1
}

# Download the specified URL into the current directory.
download () {
    local url=$1
    wget --continue --timeout=10
}

# Prepare the RubyGems library
prepare_rubygems () {
    # TODO avoid reinstalling rubygems if already present

    if [ $SKIP_RUBYGEMS = 1 ]; then
        export PATH="$(gem env path)/bin:$PATH"
    else
        pushds "$CACHE_DIR"
            if [ -d rubygems ]; then
                echo "* rubygems already installed"
            else
                download "$RUBYGEMS_SOURCE"
                tar xvfz $(basename "$RUBYGEMS_SOURCE")
                mv $(basename "$RUBYGEMS_SOURCE" .tgz) "rubygems"
            fi

            pushds "rubygems"
                ruby "setup.rb" --no-ri --no-rdoc
                export PATH="$(gem env path)/bin:$PATH"
            popds
        popds
    fi
}

# Prepare many Gems
prepare_gems () {
    # TODO avoid reinstalling gems already present
    # TODO cache downloaded gems locally

    export GEM_HOME="$CACHE_DIR/gems"

    if [ $SKIP_GEMS = 1 ]; then
        return 0;
    else
        mkdir -p "$GEM_HOME"

        pushds "$CACHE_DIR/mspec"
            rake gem
            gem install pkg/*.gem --no-ri --no-rdoc
        popds

        gem install rake sqlite3-ruby mysql rake diff-lcs syntax mocha rcov heckle hpricot --no-ri --no-rdoc
    fi
}

# Checkout or freshen Git code from URL
prepare_git_checkout () {
    local url="$1"
    local dir=$(basename "$url" .git)

    pushds "$CACHE_DIR"
        if [ -d $dir ]; then
            echo "* updating git checkout: $dir"
            pushds "$dir"
                git pull --rebase
            popds
        else
            echo "* checking out git repository: $url"
            git clone "$url"
        fi
    popds
}

# Prepare source code checkouts
prepare_checkouts () {
    if [ $SKIP_CHECKOUTS = 1 ]; then
        return 0
    else
        prepare_git_checkout "$RAILS_SOURCE"
        prepare_git_checkout "$RSPEC_SOURCE"
        prepare_git_checkout "$MSPEC_SOURCE"
        prepare_git_checkout "$RUBYSPEC_SOURCE"
    fi
}

# Prepare dependencies
prepare () {
    prepare_checkouts
    prepare_rubygems
    prepare_gems
}

# Check test suites
check () {
    check_rubyspec
    check_rspec
    check_rails
}

check_rubyspec () {
    pushds "${CACHE_DIR}/rubyspec/1.8"
        mspec . 2>&1 | tee "${REPORTS_DIR}/rubyspec_with_${TAG}.log"
    popds
}

check_rspec () {
    pushds "${CACHE_DIR}/rspec"
        local version=1.1.4
        git checkout "$version" # TODO extract hardcoded versions
        rake spec 2>&1 | tee "${REPORTS_DIR}/rspec_${version}_with_${TAG}.log"
    popds
}

check_rails () {
    pushds "${CACHE_DIR}/rails"
        local version="2.1.0"
        git checkout "$version"
        rake test 2>&1 | tee "${REPORTS_DIR}/rails_${version}_with_${TAG}.log"

        local version="2.0.2"
        git checkout "$version"
        rake test 2>&1 | tee "${REPORTS_DIR}/rails_${version}_with_${TAG}.log"

        local version="1.2.6"
        local log="${REPORTS_DIR}/rails_${version}_with_${TAG}.log"
        git checkout "$version"
        cat /dev/null > "$log"
        for f in `find * -maxdepth 0 -type d`; do
            (cd $f && rake test) 2>&1 | tee -a "$log"
        done
    popds
}

#===[ Main ]============================================================

# Defaults
TAG="current"
SKIP_CHECKOUTS=0
SKIP_RUBYGEMS=0
SKIP_GEMS=0

# Process arguments
while getopts 'd:t:vGRSU' OPTION
do
    case $OPTION in
    d)
        # TODO deal with absolute paths!
        BASE_DIR="${PWD}/${OPTARG}"
        ;;
    t)
        TAG="$OPTARG"
        ;;
    v)
        echo "rubychecker 0.1"
        exit 0
        ;;
    G)
        SKIP_GEMS=1
        ;;
    R)
        SKIP_RUBYGEMS=1
        ;;
    S)
        SKIP_CHECKOUTS=1
        SKIP_GEMS=1
        SKIP_RUBYGEMS=1
        ;;
    U)
        SKIP_CHECKOUTS=1
        ;;
    ?)
        echo "Unknown variable"
        exit 2
        ;;
    esac
done
shift $(($OPTIND - 1))

# Set paths
REPORTS_DIR="$BASE_DIR/reports"
CACHE_DIR="$BASE_DIR/cache"

# Check arguments
if ! [ "$BASE_DIR" ]; then
    fail "Base directory not specified, see --help"
fi

# Create directories
if ! [ -d "$BASE_DIR" ]; then mkdir -p "$BASE_DIR"; fi
if ! [ -d "$CACHE_DIR" ]; then mkdir -p "$CACHE_DIR"; fi
if ! [ -d "$REPORTS_DIR" ]; then mkdir -p "$REPORTS_DIR"; fi

prepare
check

#===[ Fin ]=============================================================
