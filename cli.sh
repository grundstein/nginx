#!/bin/bash

OUT_DIR="$PWD/out"
SRC_DIR="$PWD/src"
NGINX_SRC_DIR="$SRC_DIR/nginx"
HOSTS_DIR="$PWD/../magic/hosts"
GITLAB_DIR="$PWD/../gitlab"
REDMINE_DIR="$PWD/../redmine"

IP=172.18.0.5

source ./ENV.sh
source ../../bin/tasks.sh

echo "container: $CONTAINER_NAME"

function build {
  echo-start "build"

  nginx-build
  # magic-build

  docker build \
    --tag=$CONTAINER_NAME \
    --build-arg="PORT_80=$HOST_PORT_80" \
    --build-arg="PORT_443=$HOST_PORT_443" \
    --build-arg="TARGET_DIR=$TARGET_DIR" \
    --build-arg="VERSION=$VERSION" \
    . # dot!

  echo-finished "build"
}

function run() {
  remove

  echo-start "run"

  docker run \
    --detach \
    --name $CONTAINER_NAME \
    --publish $HOST_PORT_80:$CONTAINER_PORT_80 \
    --publish $HOST_PORT_443:$CONTAINER_PORT_443 \
    --volume $DATA_DIR/nginx/logs:$TARGET_DIR/logs \
    --net user-defined \
    --ip $IP \
    $CONTAINER_NAME

  ip $IP

  echo-finished "run"
}

function nginx-build() {
  echo-start "build"

  gitlab_ip_file=$GITLAB_DIR/SERVER_IP
  gitlab_name_file=$GITLAB_DIR/SERVER_NAME

  mkdir -p $OUT_DIR

  cp $NGINX_SRC_DIR/* $OUT_DIR

  if [ -f $gitlab_ip_file ]; then
    if [ -f $gitlab_name_file ]; then
      mkdir -p $OUT_DIR/sites-enabled/


      gitlab_ip=$(cat $gitlab_ip_file)
      gitlab_name=$(cat $gitlab_name_file)
      echo "Build Gitlab config with IP: $gitlab_ip and NAME: $gitlab_name"

      sed \
        -e "s/|SERVER_IP|/$gitlab_ip/g" \
        -e "s/|SERVER_NAME|/$gitlab_name/g" \
        $SRC_DIR/sites-enabled/nginx > $OUT_DIR/sites-enabled/gitlab

      echo-success "gitlab nginx config build finished"

    else
      echo-fail "$server_name_file does not exist"
    fi

  else
    echo "FAIL: $server_ip_file does not exist"
  fi

  redmine_ip_file=$REDMINE_DIR/SERVER_IP
  redmine_name_file=$REDMINE_DIR/SERVER_NAME

  mkdir -p $OUT_DIR

  cp $NGINX_SRC_DIR/* $OUT_DIR

  if [ -f $redmine_ip_file ]; then
    if [ -f $redmine_name_file ]; then
      mkdir -p $OUT_DIR/sites-enabled/

      redmine_ip=$(cat $redmine_ip_file)
      redmine_name=$(cat $redmine_name_file)
      echo "Build Redmine config with IP: $redmine_ip and NAME: $redmine_name"

      sed \
        -e "s/|SERVER_IP|/$redmine_ip/g" \
        -e "s/|SERVER_NAME|/$redmine_name/g" \
        $SRC_DIR/sites-enabled/nginx > $OUT_DIR/sites-enabled/redmine

      echo-success "redmine nginx config build finished"

    else
      echo-fail "$server_name_file does not exist"
    fi

  else
    echo-fail "$server_ip_file does not exist"
  fi

  echo-finished "Gitlab and Redis Config build"
}


function magic-build() {
  echo-start "magic build"

  for host_dir in $(ls $HOSTS_DIR); do \
    full_dir=$HOSTS_DIR/$host_dir
    if [ -d $full_dir ]; then
      conf_file=$SRC_DIR/sites-enabled/nginx
      if [ -f $conf_file ]; then
        out_file=$OUT_DIR/sites-enabled/$host_dir
        server_ip_file=$full_dir/SERVER_IP
        server_name_file=$full_dir/SERVER_NAME

        if [ -f $server_ip_file ]; then
          if [ -f $server_name_file ]; then

            echo "writing magic host config for host $host_dir to $out_file"

            sed \
              -e "s/|SERVER_IP|/$(cat $server_ip_file)/g" \
              -e "s/|SERVER_NAME|/$(cat $server_name_file)/g" \
              $conf_file > $out_file

            echo-success "nginx magic host config build finished"

          else
            echo-fail "$server_name_file does not exist"
          fi

        else
          echo-fail "$server_ip_file does not exist"
        fi

      else
        echo-fail "$conf_file does not exist"
      fi

    else
      echo-fail "$full_dir is not a dir"
    fi
  done

  echo-finished "magic-build"
}

function clean() {
  echo-start "cleaning up"

  rm -rf ./out

  echo-finished "cleanup"
}

function help() {
  echo "\
Container: $CONTAINER_NAME

USAGE:
make TASK
./cli.sh TASK

TASKS:
  build       - docker builds the container
  run         - docker runs the container
  magic-build - get ip and hostnames from magic hosts
  nginx-build - get ip and hostname from gitlab
  remove      - docker remove the container
  clean       - rm the out directory
  logs        - tail the docker logs
  debug       - connect to the container
"
}

if [ $1 ]
then
  function=$1
  shift
  $function $@
else
  help $@
fi
