#!/bin/zsh

################################################################################
### Namespaces
NAMESPACE=local-dev
NAMESPACE_DB=${NAMESPACE}-dbs

################################################################################
### Databases

# PostgreSQL
# TODO: PG_SERVICE_NAME -> PG_NAME
PG_SERVICE_NAME=postgres
PG_DATABASE=testmydb
PG_HELM_VALUES_FILE=postgres/psql.yaml
# TODO: PG_SVC_NAME -> PG_SERVICE_NAME
PG_SVC_NAME=${PG_SERVICE_NAME}-postgresql

# PostgreSQL web UI
PGADMIN_SERVICE_NAME=pgadmin
PGADMIN_HELM_VALUES_FILE=postgres/pgadmin.yaml
PGADMIN_INGRESS_HOST=pgadmin.example.com

# MongoDB
MONGO_NAME=mongodb
MONGO_SERVICE_NAME=$MONGO_NAME
MONGO_FORWARD_PORT="27017:27017"
MONGO_HELM_VALUES_FILE=mongo/values.yaml

# MariaDB
MARIADB_NAME=mariadb
MARIADB_SERVICE_NAME=$MARIADB_NAME
MARIADB_FORWARD_PORT="3306:3306"
MARIADB_HELM_VALUES_FILE=mariadb/values.yaml

# Redis
REDIS_NAME=redis
REDIS_SERVICE_NAME=$REDIS_NAME
REDIS_HELM_VALUES_FILE=redis/values.yaml

# Kafka
KAFKA_NAME=kafka
KAFKA_SERVICE_NAME=$KAFKA_NAME
KAFKA_FORWARD_PORT="9092:9092"
KAFKA_HELM_VALUES_FILE=kafka/values.yaml

KAFDROP_NAME=kafdrop
KAFDROP_SERVICE_NAME=${KAFDROP_NAME}
KAFDROP_FORWARD_PORT="9000:9000"
KAFDROP_HELM_VALUES_FILE=_helm2/kafdrop/values.yaml

#
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
  kubectl create namespace $NAMESPACE
  _helm install --namespace $NAMESPACE $*
}
_helm_install_db() {
  kubectl create namespace $NAMESPACE_DB
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

  _helm_install_db --name $PGADMIN_SERVICE_NAME -f $PGADMIN_HELM_VALUES_FILE stable/pgadmin
}

pg_deploy_rs() {
  local db=${PG_DATABASE}
  local ingress_host=${PGADMIN_INGRESS_HOST}

  _helm_install_db --name $PG_SERVICE_NAME -f $PG_HELM_VALUES_FILE \
    --set postgresqlDatabase=$db \
    --set replication.enabled=true \
    --set replication.slaveReplicas=2 stable/postgresql

  # TODO: set ingress hostname
  echo "TODO: --set ingress.hosts[0].host=$ingress_host"
  echo "TODO: --set serverDefinitions.servers"

  _helm_install_db --name $PGADMIN_SERVICE_NAME -f $PGADMIN_HELM_VALUES_FILE stable/pgadmin
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

#
mongo_deploy() {
  local ns=${NAMESPACE_DB}

  _helm_install_db --name $MONGO_NAME -f $MONGO_HELM_VALUES_FILE stable/mongodb
}

mongo_drop_deploy() {
  _helm delete --purge $MONGO_NAME
}

mongo_forward() {
  local ns=${NAMESPACE_DB}

  kubectl --namespace $ns port-forward svc/${MONGO_SERVICE_NAME} ${MONGO_FORWARD_PORT}
}

#
redis_deploy() {
  local ns=${NAMESPACE_DB}

  _helm_install_db --name $REDIS_NAME -f $REDIS_HELM_VALUES_FILE stable/redis
}

redis_drop_deploy() {
  _helm delete --purge $REDIS_NAME
}

#
kafka_deploy() {
  local ns=${NAMESPACE_DB}

  helm repo add bitnami https://charts.bitnami.com/bitnami
  _helm_install_db --name $KAFKA_NAME -f $KAFKA_HELM_VALUES_FILE bitnami/kafka
}

kafka_drop() {
  _helm delete --purge $KAFKA_NAME
}

kafka_forward() {
  local ns=${NAMESPACE_DB}

  kubectl --namespace $ns port-forward svc/${KAFKA_SERVICE_NAME} ${KAFKA_FORWARD_PORT}
}

kafdrop_deploy() {
  # local ns=${NAMESPACE_DB}

  _helm_install_db --name $KAFDROP_NAME -f $KAFDROP_HELM_VALUES_FILE \
    --set kafka.brokerConnect=${KAFKA_NAME}:9092 \
    ./_helm2/kafdrop
}

kafdrop_drop() {
  _helm delete --purge $KAFDROP_NAME
}

kafdrop_forward() {
  local ns=${NAMESPACE_DB}

  kubectl --namespace $ns port-forward svc/${KAFDROP_SERVICE_NAME} ${KAFDROP_FORWARD_PORT}
}

#
mariadb_deploy() {
  helm repo add bitnami https://charts.bitnami.com/bitnami
  _helm_install_db --name $MARIADB_NAME -f $MARIADB_HELM_VALUES_FILE bitnami/mariadb
}

mariadb_drop() {
  _helm delete --purge $MARIADB_NAME
}

mariadb_forward() {
  local ns=${NAMESPACE_DB}

  kubectl --namespace $ns port-forward svc/${MARIADB_SERVICE_NAME} ${MARIADB_FORWARD_PORT}
}
#

drop_all() {
  echo TODO
}


case "$1" in
  ns-create) k8s_create_namespaces ;;
  ns-delete) k8s_drop_namespaces ;;
  # drop-all) drop_all ;;
  pg-up) pg_deploy ;;
  pg-rs-up) pg_deploy_rs ;;
  pg-drop) pg_drop_deploy ;;
  pg-open) pg_open_browser ;;
  pg-forward) pg_forward_port ;;
  pg-print-password) pg_print_password ;;
  mongo-deploy) mongo_deploy ;;
  mongo-drop) mongo_drop_deploy ;;
  mongo-forward) mongo_forward ;;
  redis-deploy) redis_deploy ;;
  redis-drop) redis_drop_deploy ;;
  kafka-deploy) kafka_deploy ;;
  kafka-drop) kafka_drop ;;
  kafka-forward) kafka_forward ;;
  kafdrop-deploy) kafdrop_deploy ;;
  kafdrop-drop) kafdrop_drop ;;
  kafdrop-forward) kafdrop_forward ;;
  mariadb-deploy) mariadb_deploy ;;
  mariadb-drop) mariadb_drop ;;
  mariadb-forward) mariadb_forward ;;
  *)
    NS=$NAMESPACE
    NSDB=$NAMESPACE_DB
    echo "\nUsage: $(basename "$0") <command>"
    echo "\nCommands:"
    echo "  ns-create   - create namespace '$NS', '$NSDB'"
    echo "  ns-delete   - delete namespace '$NS', '$NSDB"
    # echo "  drop-all    - drop all services in namespace '$NS' and '$NSDB' (namespaces not remove)"
    echo
    echo "PostgreSQL"
    echo "  pg-up       - deploy PostgreSQL and PgAdmin in namespace '$NSDB'"
    echo "  pg-rs-up    - deploy PostgreSQL (with ReplicaSet) and PgAdmin in namespace '$NSDB'"
    echo "  pg-drop     - drop PostgreSQL and PgAdmin"
    echo "  pg-open     - open browser with PgAdmin"
    echo "  pg-forward  - postgres forward port"
    echo "  pg-print-password  - print postgres password"
    echo
    echo "MariaDB"
    echo "  mariadb-deploy   - deploy MariaDB (namespace '$NSDB')"
    echo "  mariadb-drop     - drop MariaDB (namespace '$NSDB')"
    echo "  mariadb-forward  - forwarding port $MARIADB_FORWARD_PORT (namespace '$NSDB')"
    echo
    echo "MongoDB"
    echo "  mongo-deploy   - deploy MongoDB (namespace '$NSDB')"
    echo "  mongo-drop     - drop MongoDB (namespace '$NSDB')"
    echo "  mongo-forward  - forwarding port $MONGO_FORWARD_PORT (namespace '$NSDB')"
    echo
    echo "Redis"
    echo "  redis-deploy   - deploy Redis (namespace '$NSDB')"
    echo "  redis-drop     - drop Redis (namespace '$NSDB')"
    echo
    echo "Kafka"
    echo "  kafka-deploy     - deploy Kafka (namespace '$NSDB')"
    echo "  kafka-drop       - drop Kafka (namespace '$NSDB')"
    echo "  kafka-forward    - forwarding port $KAFKA_FORWARD_PORT (namespace '$NSDB')"
    echo "  kafdrop-deploy   - deploy Kafka UI (namespace '$NSDB')"
    echo "  kafdrop-drop     - drop Kafka UI (namespace '$NSDB')"
    echo "  kafdrop-forward  - forwarding port $KAFDROP_SERVICE_NAME (namespace '$NSDB')"
    echo
    exit 1
  ;;
esac
