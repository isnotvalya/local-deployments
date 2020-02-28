# ELK

**Only for development!**

## Запуск Elastic

```bash
$ docker network create elk
$ docker-compose -f elastic.yml up -d
```

Пароли доступа

```bash
$ # у Elastic должна быть включен параметр `xpack.security.enabled=true`
$ # Генерируем случайные пароли для elastic, kibana, logstash_system, beats_system, apm_system, remote_monitoring_user
$ docker-compose -f elastic.yml exec elastic elasticsearch-setup-passwords auto -u http://127.1:9200
```

## Запуск Kibana

```bash
$ # Обновляем ранее сгенерированный пароль от kibana в файле configs/kibana/config.yml
$ docker-compose -f kibana.yml up -d
$ # Для авторизации в веб kibana используется пароль от elastic
```

## Запуск Logstash

```bash
$ # Обновляем ранее сгенерированный пароль от logstash_system в файле configs/logstash/config/logstash.yml
$ docker-compose -f logstash.yml up -d
```

## Запуск Filebeat

```bash
$ docker network create backend
$ # Обновляем ранее сгенерированный пароль от elastic в файле configs/filebeat-docker/config/filebeat.yml и host сервера elastic
$ docker-compose -f filebeat-docker.yml up -d
```

## Веб

```bash
$ open http://127.0.0.1:5680/
```
