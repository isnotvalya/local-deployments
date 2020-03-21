#!/bin/zsh

ENV_FILE=_compose/env

docker_compose() {
  docker-compose --env-file ${ENV_FILE} $*
}

_command_stack() {
  local cmd="$1"
  local name="$2"
  local compose_file=_compose/${name}.yml

  shift ; shift ;

  test -f "${compose_file}" || {
    echo "Error: File not found: '${compose_file}'"
    exit 1
  }

  case "$cmd" in
    up)
      echo "* Deploying stack '${name}' ..."
      docker_compose -f ${compose_file} up -d --build --force-recreate
    ;;
    ps)
      docker_compose -f ${compose_file} ps $*
    ;;
    down)
      echo "* Destroying stack '${name}' ..."
      docker_compose -f ${compose_file} down
    ;;
    restart)
      echo "* Restarting stack '${name}' ..."
      docker_compose -f ${compose_file} down
      docker_compose -f ${compose_file} up -d --build --force-recreate
    ;;
  esac
}

up_stack() {
  for name in $* ; do
    _command_stack up $name
  done
}

restart_stack() {
  for name in $* ; do
    _command_stack restart $name
  done
}

ps_stack() {
  for name in $* ; do
    _command_stack ps $name
  done
}

down_stack() {
  for name in $* ; do
    _command_stack down $name
  done
}

down_all() {
  for name in _compose/*.yml ; do
    down_stack "$(basename $name .yml)"
  done
}

case "$1" in
  up)       shift ; up_stack $* ;;
  ps)       shift ; ps_stack $* ;;
  down)     shift ; down_stack $* ;;
  restart)  shift ; restart_stack $* ;;
  down-all) down_all ;;
  *)
    echo "Usage: $(basename "$0") <command> <services>"
    echo
    echo "Examples:"
    for name in _compose/*.yml ; do
      echo "  zsh ./$(basename "$0") up $(basename $name .yml)"
    done
    echo
    exit 1
  ;;
esac
