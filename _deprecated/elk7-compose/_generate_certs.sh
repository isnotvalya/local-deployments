#!/bin/zsh

FILE_CA_CONF="test/ssl-ca.conf"
FILE_BEAT_CONF="test/ssl-beat.conf"
FILE_LOGSTASH_CONF="test/ssl-logstash.conf"
FILE_SERIAL_CA_CERT="test/serial"

DAYS=3650

CA_CRT="test/ca.crt"
CA_KEY="test/ca.key"

LOGSTASH_KEY="test/logstash.key"
LOGSTASH_CSR="test/logstash.csr"
LOGSTASH_CRT="test/logstash.crt"

FILEBEAT_KEY="test/filebeat.key"
FILEBEAT_CSR="test/filebeat.csr"
FILEBEAT_CRT="test/filebeat.crt"

cleanup() {
    for file in $FILE_SERIAL_CA_CERT $CA_CRT $CA_KEY \
                $LOGSTASH_KEY $LOGSTASH_CSR $LOGSTASH_CRT \
                $FILEBEAT_KEY $FILEBEAT_CSR $FILEBEAT_CRT ; do
        test -f "$file" && ( rm -fv "$file" || exit 1 )
    done
}

exec_ssl() {
    openssl $* || exit 1
}

create_serial() {
    local ca_cert="$1"

    printf "" > $FILE_SERIAL_CA_CERT

    res="$(exec_ssl x509 -in $ca_cert -text -noout -serial | grep 'serial=' | awk -F"=" '{print $2}')"

    if [[ ! "${#res}" == 16 ]] ; then
        echo "ERROR: length serial number != 16"
        exit 1
    fi

    printf "$res" > $FILE_SERIAL_CA_CERT
}

generate_ca_certificate_x509() {
    local ca_key="$1"
    local ca_cert_out="$2"
    local ca_file_config="$3"
    local days="${4:-3650}"

    exec_ssl genrsa -out $ca_key 2048
    exec_ssl req -x509 -new -nodes \
        -sha256 \
        -days $days \
        -config $ca_file_config \
        -key $ca_key \
        -out $ca_cert_out
}

generate_certificate_req() {
    local out_key="$1"
    local out_csr="$2"
    local config="$3"

    exec_ssl genrsa -out $out_key 2048
    exec_ssl req -sha512 -new \
        -key $out_key \
        -out $out_csr \
        -config $config
}

generate_signed_certificate_x509() {
    local ca_key="$1"
    local ca_crt="$2"
    local ca_serial="$3"
    local csr="$4"
    local crt_out="$5"
    local config="$6"
    local days="${7:-3650}"

    create_serial $ca_crt
    exec_ssl x509 \
        -req \
        -sha512 \
        -days $days \
        -CAserial $ca_serial \
        -CA $ca_crt \
        -CAkey $ca_key \
        -in $csr \
        -out $crt_out \
        -extensions v3_req \
        -extfile $config
}

example_logstash_pipeline_input() {
    cat <<EOL
### pipeline/logstash.conf

input {
  beats {
    port => 5044
    ssl => true
    ssl_verify_mode => "force_peer"
    ssl_certificate_authorities => ["$CA_CRT"]
    ssl_certificate => "$LOGSTASH_CRT"
    ssl_key => "$LOGSTASH_KEY"
  }
}
EOL
}

example_filebeat_inputs() {
    cat <<EOL
### filebeat.yml

filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /test.log
output.logstash:
  hosts: ["logstash.example.com:5044"]
  ssl:
    certificate_authorities: ["$CA_CRT"]
    certificate: "$FILEBEAT_CRT"
    key: "$FILEBEAT_KEY"
EOL
}

case "$1" in
    clean)
        cleanup
        ;;
    ca)
        generate_ca_certificate_x509 $CA_KEY $CA_CRT $FILE_CA_CONF $DAYS
        ;;
    certs)
        # logstash
        generate_certificate_req $LOGSTASH_KEY $LOGSTASH_CSR $FILE_LOGSTASH_CONF
        generate_signed_certificate_x509 \
            $CA_KEY $CA_CRT $FILE_SERIAL_CA_CERT \
            $LOGSTASH_CSR $LOGSTASH_CRT $FILE_LOGSTASH_CONF $DAYS

        # filebeat
        generate_certificate_req $FILEBEAT_KEY $FILEBEAT_CSR $FILE_BEAT_CONF
        generate_signed_certificate_x509 \
            $CA_KEY $CA_CRT $FILE_SERIAL_CA_CERT \
            $FILEBEAT_CSR $FILEBEAT_CRT $FILE_BEAT_CONF $DAYS
        ;;
    examples)
        example_logstash_pipeline_input

        printf "\n"
        example_filebeat_inputs

        printf "\n"
        ;;
    *)
        echo "Usage: $(basename "$0") <clean|ca|certs|examples>"
        exit 1
        ;;
esac
