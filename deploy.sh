#!/bin/zsh

################################################################################
### Namespaces
NAMESPACE=local-dev
NAMESPACE_DB=${NAMESPACE}-dbs

################################################################################
### Databases

# PostgreSQL
PG_SERVICE_NAME=postgres
PG_DATABASE=testmydb
PG_HELM_VALUES_FILE=postgres/psql.yaml
PG_SVC_NAME=${PG_SERVICE_NAME}-postgresql

# PostgreSQL web UI
PGADMIN_SERVICE_NAME=pgadmin
PGADMIN_HELM_VALUES_FILE=postgres/pgadmin.yaml
PGADMIN_INGRESS_HOST=pgadmin.example.com

_kubectl() {
  kubectl $* || exit 1
}
_kubectl_ns() {
  kubectl --namespace $NAMESPACE $*
}
_helm() {
  helm $*
}
_helm_install() {
  _helm install --namespace $NAMESPACE $*
}
_helm_install_db() {
  _helm install --namespace $NAMESPACE_DB $*
}

k8s_create_namespaces() {
  _kubectl create namespace $NAMESPACE
  _kubectl create namespace $NAMESPACE_DB
}
k8s_drop_namespaces() {
  _kubectl delete namespace $NAMESPACE
  _kubectl delete namespace $NAMESPACE_DB
}

pg_deploy() {
  local ns=${NAMESPACE_DB}
  local db=${PG_DATABASE}
  local ingress_host=${PGADMIN_INGRESS_HOST}

  _helm_install_db --name $PG_SERVICE_NAME -f $PG_HELM_VALUES_FILE \
    --set postgresqlDatabase=$db \
    --set replication.enabled=false \
    stable/postgresql

  # TODO: set ingress hostname
  echo "TODO: --set ingress.hosts[0].host=$ingress_host"
  echo "TODO: --set serverDefinitions.servers"

  _helm_install_db --name $PGADMIN_SERVICE_NAME -f $PGADMIN_HELM_VALUES_FILE \
    stable/pgadmin
}

pg_deploy_rs() {
  local ns=${NAMESPACE_DB}
  local db=${PG_DATABASE}
  local ingress_host=${PGADMIN_INGRESS_HOST}

  _helm_install_db --name $PG_SERVICE_NAME -f $PG_HELM_VALUES_FILE \
    --set postgresqlDatabase=$db \
    --set replication.enabled=true \
    --set replication.slaveReplicas=2 stable/postgresql

  # TODO: set ingress hostname
  echo "TODO: --set ingress.hosts[0].host=$ingress_host"
  echo "TODO: --set serverDefinitions.servers"

  _helm_install_db --name $PGADMIN_SERVICE_NAME -f $PGADMIN_HELM_VALUES_FILE \
    stable/pgadmin
}

pg_drop_deploy() {
  local ns=${NAMESPACE_DB}

  _helm delete --purge $PGADMIN_SERVICE_NAME
  _helm delete --purge $PG_SERVICE_NAME
}

pg_forward_port() {
  _kubectl_ns port-forward svc/${PG_SVC_NAME} 5432:5432
}

pg_print_password() {
  local ns=$NAMESPACE
  local svc=${PG_SERVICE_NAME}-postgresql
  local password=$(kubectl get secret --namespace $ns $svc -o jsonpath="{.data.postgresql-password}" | base64 --decode)

  echo $password
}

pg_open_browser() {
  local url="${PGADMIN_INGRESS_HOST}"

  grep ${url} /etc/hosts &>/dev/null || {
    echo "\n!!! Add a line to the file '/etc/hosts':"
    echo "    127.0.0.1  $url\n"
  }

  open http://$url
}

case "$1" in
  ns-create) k8s_create_namespaces ;;
  ns-delete) k8s_drop_namespaces ;;
  pg-up) pg_deploy ;;
  pg-rs-up) pg_deploy_rs ;;
  pg-drop) pg_drop_deploy ;;
  pg-open) pg_open_browser ;;
  pg-forward) pg_forward_port ;;
  pg-print-password) pg_print_password ;;
  *)
    NS=$NAMESPACE
    NSDB=$NAMESPACE_DB
    echo "\nUsage: $(basename "$0") <command>"
    echo "\nCommands:"
    echo "  ns-create   - create namespace '$NS', '$NSDB'"
    echo "  ns-delete   - delete namespace '$NS', '$NSDB"
    echo
    echo "PostgreSQL:"
    echo "  pg-up       - deploy PostgreSQL and PgAdmin in namespace '$NSDB'"
    echo "  pg-rs-up    - deploy PostgreSQL (with ReplicaSet) and PgAdmin in namespace '$NSDB'"
    echo "  pg-drop     - drop PostgreSQL and PgAdmin"
    echo "  pg-open     - open browser with PgAdmin"
    echo "  pg-forward  - postgres forward port"
    echo "  pg-print-password  - print postgres password"
    echo
    exit 1
  ;;
esac
