#!/usr/bin/env bash

_V=2
init_environment="0"

#this var is weird. i need a way to get back home. work out later.
#_SRC_DIR=.
#source $_SRC_DIR/src-log.sh
#logvv "Test"

function main() {
#log "2nd Test"
#logv "inter test"
#logvv "inter-intra test"
#input_parse "$@"
#alert "You suck"
#ext_log "This would be output to a log sys specified"
#trace "- someday"

if [[ "$init_environment" = "1" ]]
then
sudo apt-get install docker.io docker-compose \
  postgresql-9.6 postgresql-server-dev-9.6 postgresql-client-9.6 postgresql-contrib-9.6 postgresql-plpython-9.6 \
  libxml2-dev libxslt-dev \
  vim python-pip python-dev build-essential memcached screen \
  libxml2-utils nginx postgresql postgresql-client \
  postgresql-contrib libpq-dev nodejs rbenv ruby-build virtualenv \
  git graphviz redis-server qt5-default libqt5webkit5-dev python3 \
  python-pip git-core curl zlib1g-dev build-essential libssl-dev \
  libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev \
  libxslt1-dev libcurl4-openssl-dev python-software-properties \
  libffi-dev


git clone https://github.com/openstax/tutor-server
git clone https://github.com/openstax/tutor-js
git clone https://github.com/openstax/os-webview
git clone https://github.com/openstax/pattern-library
git clone https://github.com/openstax/exercises
git clone https://github.com/Connexions/cnx-db
git clone https://github.com/Connexions/cnx-archive
git clone https://github.com/Connexions/cnx-recipes
git clone https://github.com/Connexions/webview
fi

#tutor server
log "changing into tutor-server directory"
cd tutor-server
#post grest install 
# sudo apt-get install postgresql postgresql-client postgresql-contrib libpq-dev
# brew install postgres
#sudo service postgresql restart
#sudo vim /etc/postgresql/9.6/main/pg_hba.conf
#change Change peer to md5 or create a new md5 entry for localhost (127.0.0.1).
sudo service postgresql restart
#create psogres user for the app
log "entering postgres"
sudo -u postgres -i
createuser --superuser --pwprompt ox_tutor
exit
log "left posgrest?"
sudo service postgresql restart
#install redis
#sudo apt-get install redis-server


#setup ruby
rbenv install 2.2.3
source ~/.bashrc && source ~/.profile
#gem install bundler
#source ~/.bashrc && source ~/.profile
#bundle install

#setup dbs
#bin/rake db:setup
#bin/rake db:reset
#bin/rake db:drop db:create db:migrate db:seed

#start tutor-server, bound to https://localhost:3001
#bin/rails s
#console tutor-server
#bin/rails c
########################END TUTOR###################

# nvm
# gem install bundler 

#yarn 

# gem install scss_lint
#
#
}
#end main...

#COLOR
__RED='\033[0;31m'
__NC='\033[0m'
__YEL='\033[1;33m'
__GRN='\033[0;32m'
__WHT='\033[1;37m'
__BACK_RED='\033[41m'
#END COLOR

#this is the error function. Indicates a problem which no logic
#has been written to handle
function log () {
if [[ $_V -ge 0 ]]; then
  echo -e "${__RED}[ERR]${__NC}  ${BASH_SOURCE##*/}:${FUNCNAME[1]}:${BASH_LINENO[0]}: $@" >&2
fi
    }
#this is the warn function. Indicates a irregularity that has been either
#ignored or rectified. 
    function logv () {
    if [[ $_V -ge 1 ]]; then
      echo -e "${__YEL}[WARN]${__NC} ${BASH_SOURCE##*/}:${FUNCNAME[1]}:${BASH_LINENO[0]}: $@" >&2
    fi
  }
#this is a info function. Gives terminal notice to the "user". Intended to be 
#redirected to the same file as warn and err, but is not nearly
#as verbose as ext_log (not even close) think of log as being cheap traces
  function logvv () {
  if [[ $_V -ge 2 ]]; then
    echo -e "${__GRN}[INFO]${__NC} ${BASH_SOURCE##*/}:${FUNCNAME[1]}:${BASH_LINENO[0]}: $@" >&2
  fi
}
#this is a function that alerts for failure. 
function alert () {
echo -e "${__BACK_RED}${__WHT}[FATAL] ${BASH_SOURCE##*/}:${FUNCNAME[1]}:${BASH_LINENO[0]}: $@${__NC}" >&2
}
#this is function that writes large amounts of debug output to another 
#logging system. 
function ext_log () {
echo -e "[LOG] ${BASH_SOURCE##*/}:${FUNCNAME[1]}:${BASH_LINENO[0]}: $@" >&2
}
# the trace function is to be overridden by the debug function supplied by
#the developer.
function trace () {
echo -e "[TRACE] ${BASH_SOURCE##*/}:${FUNCNAME[1]}:${BASH_LINENO[0]}: Currently Unsupported $@" >&2
}
#end

#who really does any work around here anyway
main "$@"
