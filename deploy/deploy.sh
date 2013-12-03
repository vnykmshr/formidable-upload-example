#!/usr/bin/env bash

VERSION="0.4.0"
CONFIG=./deploy.conf
LOG=$(mktemp /tmp/deploy.XXXXXX)
TEST=1
REF=
ENV=

#
# Output usage information.
#

usage() {
  cat <<-EOF

  Usage: deploy [options] <env> [command]

  Options:

    -C, --chdir <path>   change the working directory to <path>
    -c, --config <path>  set config path. defaults to ./deploy.conf
    -T, --no-tests       ignore test hook
    -V, --version        output program version
    -h, --help           output help information

  Commands:

    setup                run remote setup commands
    update               update deploy to the latest release
    revert [n]           revert to [n]th last deployment or 1
    config [key]         output config file or [key]
    curr[ent]            output current release commit
    prev[ious]           output previous release commit
    exec|run <cmd>       execute the given <cmd>
    console              open an ssh session to the host
    list                 list previous deploy commits
    [ref]                deploy to [ref], the 'ref' setting, or latest tag

EOF
}

#
# Abort with <msg>
#

abort() {
  echo
  echo "  $@" 1>&2
  echo
  exit 1
}

#
# Log <msg>.
#

log() {
  echo "  ○ $@"
}

#
# Set configuration file <path>.
#

set_config_path() {
  test -f $1 || abort invalid --config path
  CONFIG=$1
}

#
# Check if config <section> exists.
#

config_section() {
  grep "^\[$1" $CONFIG &> /dev/null
}

#
# Get config value by <key>.
#

config_get() {
  local key=$1
  test -n "$key" \
    && grep "^\[$ENV" -A 30 $CONFIG \
    | grep "^$key" \
    | head -n 1 \
    | cut -d ' ' -f 2-999
}

#
# Output version.
#

version() {
  echo $VERSION
}

#
# Run the given remote <cmd>.
#

run() {
  local url="`config_get user`@`config_get host`"
  local key=`config_get key`
  if test -n "$key"; then
    local shell="ssh -i $key $url"
  else
    local shell="ssh $url"
  fi
  echo $shell "\"$@\"" >> $LOG
  $shell $@
}

#
# Launch an interactive ssh console session.
#

console() {
  local url="`config_get user`@`config_get host`"
  local key=`config_get key`
  if test -n "$key"; then
    local shell="ssh -i $key $url"
  else
    local shell="ssh $url"
  fi
  echo $shell
  exec $shell
}

#
# Output config or [key].
#

config() {
  if test $# -eq 0; then
    cat $CONFIG
  else
    config_get $1
  fi
}

#
# Execute hook <name> relative to the path configured.
#

hook() {
  test -n "$1" || abort hook name required
  local hook=$1
  local path=`config_get path`
  local cmd=`config_get $hook`
  if test -n "$cmd"; then
    log "executing $hook \`$cmd\`"
    run "cd $path/current; \
      SHARED=\"$path/shared\" \
      $cmd $ENV $@ 2>&1 | tee -a $LOG; \
      exit ${PIPESTATUS[0]}"
    test $? -eq 0
  else
    log hook $hook
  fi
}

#
# Collect log data for deploy log
#
# collect data deploy ref
collect() {
  data[0]="env='$ENV'"
  data[1]="host='`config_get host`'"
  data[2]="ref='`config_get ref`'"
  data[3]="user='`whoami`'"
  data[4]="from='`hostname -s`'"
  data[5]="fromip='`ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -n1 | awk '{print $2}' | cut -c 6-`'"
  data[6]="commit='`current_commit`'"
  data[7]="message='`current_commit_message`'"
  echo ${data[@]}
}

#
# Run setup.
#

setup() {
  local path=`config_get path`
  local repo=`config_get repo`
  run "mkdir -p $path/shared/pids $path/shared/logs $path/source"
  test $? -eq 0 || abort setup paths failed
  log running setup
  log cloning $repo
  run "git clone $repo $path/source"
  test $? -eq 0 || abort failed to clone
  hook post-setup || abort post-setup hook failed
  log setup complete
}

#
# Deploy [ref].
#

deploy() {
  local ref=$1
  local path=`config_get path`
  log deploying

  hook pre-deploy || abort pre-deploy hook failed

  # fetch source
  log fetching updates
  run "cd $path/source && git fetch --all"
  test $? -eq 0 || abort fetch failed

  run "cd $path/source && git submodule update"
  test $? -eq 0 || abort submodule update failed

  # latest tag
  if test -z "$ref"; then
    log fetching latest tag
    ref=`run "cd $path/source && git for-each-ref refs/tags \
      --sort=-authordate \
      --format='%(refname)' \
      --count=1 | cut -d '/' -f 3"`
    test $? -eq 0 || abort failed to determine latest tag
  fi

  # reset HEAD
  log resetting HEAD to $ref
  run "cd $path/source && git reset --hard $ref"
  test $? -eq 0 || abort git reset failed

  # link current
  run "ln -sfn $path/source $path/current"
  test $? -eq 0 || abort symlink failed

  # deploy log
  run echo "`current_commit` >> $path/.deploys"
  test $? -eq 0 || abort deploy log append failed

  hook post-deploy || abort post-deploy hook failed

  # deploy log to amon
  hook log-deploy `collect log-data` || log log-deploy hook faild, no deploy log for you

  if test $TEST -eq 1; then
    hook test
    if test $? -ne 0; then
      log tests failed, reverting deploy
      quickly_revert_to 1 && log "revert complete" && exit
    fi
  else
    log ignoring tests
  fi

  # done
  log successfully deployed $ref
}

#
# Get current commit.
#

current_commit() {
  local path=`config_get path`
  run "cd $path/source && \
      git rev-parse --short HEAD"
}

#
# Current commit message
#
current_commit_message() {
  local path=`config_get path`
  run "cd $path/source && git log -n 1 --format=format:%s%n%b HEAD"
}

#
# Get <n>th deploy commit.
#

nth_deploy_commit() {
  local n=$1
  local path=`config_get path`
  run "cat $path/.deploys | tail -n $n | head -n 1 | cut -d ' ' -f 1"
}

#
# List deploys.
#

list_deploys() {
  local path=`config_get path`
  run "cat $path/.deploys"
}

#
# Revert to the <n>th last deployment, ignoring tests.
#

quickly_revert_to() {
  local n=$1
  log "quickly reverting $n deploy(s)"
  local commit=`nth_deploy_commit $((n + 1))`
  TEST=0 deploy "$commit"
}

#
# Revert to the <n>th last deployment.
#

revert_to() {
  local n=$1
  log "reverting $n deploy(s)"
  local commit=`nth_deploy_commit $((n + 1))`
  deploy "$commit"
}

#
# Require environment arg.
#

require_env() {
  config_section $ENV || abort "[$ENV] config section not defined or $CONFIG missing"
  test -z "$ENV" && abort "<env> required"
}

# parse argv

while test $# -ne 0; do
  arg=$1; shift
  case $arg in
    -h|--help) usage; exit ;;
    -V|--version) version; exit ;;
    -c|--config) set_config_path $1; shift ;;
    -C|--chdir) log cd $1; cd $1; shift ;;
    -T|--no-tests) TEST=0 ;;
    run|exec) require_env; run "cd `config_get path` && $@"; exit ;;
    console) require_env; console; exit ;;
    curr|current) require_env; current_commit; exit ;;
    prev|previous) require_env; nth_deploy_commit 2; exit ;;
    revert) require_env; revert_to ${1-1}; exit ;;
    setup) require_env; setup $@; exit ;;
    list) require_env; list_deploys; exit ;;
    collect) collect $@; exit ;;
    config) config $@; exit ;;
    *)
      if test -z "$ENV"; then
        ENV=$arg;
      else
        REF="$REF $arg";
      fi
      ;;
  esac
done

require_env

# deploy
deploy "${REF:-`config_get ref`}"
