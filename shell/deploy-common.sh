#!/bin/bash
# 通用的发布脚本
OPTION=$1
PROJECT=$2
PROFILE=$3
MONITOR_PORT=$4
WITH_NGINX=$5

CURRENT_USER=`whoami`
pid=0
nginx_pid=0

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export JAVA_OPTS="-Xms4096m -Xmx4096m"
export JAVA_OPTS_TEST="-Xms512m -Xmx512m"
export PROJECT_HOME=/home/workspace/ntesgod
export APP_USER="www-data"
export VERSION=1.0.0-SNAPSHOT

LANG=en_US.UTF-8
export LANG

copy() {
    APP=$1
    # 将mq.feed替换成mq/feed
    DIR=${APP/./\/}
    # mq.feed替换成feed-1.0.0-SNAPSHOT.jar
    JAR_NAME=${APP#*.}-${VERSION}.jar
    # 应用的jar包存放的目录
    APP_DIR=${PROJECT_HOME}/${DIR}/
    mkdir -p ${APP_DIR}
    cp ${PROJECT_HOME}/source/${DIR}/target/${JAR_NAME} ${APP_DIR}
    echo "[COPY] ${PROJECT_HOME}/source/${DIR}/target/${JAR_NAME} to ${APP_DIR}"
}

get_pid() {
    APP=$1
    JAR_NAME=${APP#*.}-${VERSION}.jar
    jps_result=`${JAVA_HOME}/bin/jps -ml | grep " ${JAR_NAME}"`
    if [[ -n "$jps_result" ]]; then
        pid=`echo ${jps_result} | awk '{print $1}'`
    else
        pid=0
   fi
}

get_nginx_pid() {
    ps_result=`ps aux |grep nginx|grep master`
    if [[ -n "$ps_result" ]]; then
        nginx_pid=`echo ${ps_result} | awk '{print $2}'`
    else
        nginx_pid=0
    fi
}
start_nginx() {
    if [[ "${WITH_NGINX}" != "true" ]]; then
        return
    fi
    get_nginx_pid
    if [[ ${nginx_pid} -ne 0 ]]; then
        echo "[START_NGINX] WARN: nginx already started! (pid=$nginx_pid)";
    else
        sudo /home/nginx/sbin/nginx
        sleep 1
        get_nginx_pid
        if [[ ${nginx_pid} -ne 0 ]]; then
            echo "『START_NGINX』 ...(pid=${nginx_pid}) SUCCESS"
        else
            echo "『START_NGINX』Failed"
        fi
    fi
}

stop_nginx() {
    if [[ "${WITH_NGINX}" != "true" ]]; then
        return
    fi
    get_nginx_pid
    if [[ ${nginx_pid} -ne 0 ]]; then
        nid=${nginx_pid}
        count=0
        sudo /home/nginx/sbin/nginx -s quit
        while :
        do
            sleep 1
            get_nginx_pid
            if [[ ${nginx_pid} -eq 0 ]]; then
                echo "『STOP_NGINX』...(pid=$nid) SUCCESS"
                return
            else
                let count++
                if [[ ${count} -gt 20 ]]; then
                    echo "『STOP_NGINX』...(pid=$nid) Failed"
                    return 1
                fi
            fi
        done
    fi
}

check_server_health() {
    count=0
    health_url="http://127.0.0.1:${MONITOR_PORT}/health"
    echo "[check_health] [${health_url}] blocking..........."
    while :
    do
        http_code=`curl -I -m 3 -o /dev/null -s -w %{http_code} "${health_url}"`
        if [[ ${http_code} -eq 200 ]]; then
            return
        else
            sleep 3
            let count++
            if [[ ${count} -gt 20 ]]; then
                return 1
            fi
        fi
    done
}

start() {
    APP=$1
    DIR=${APP/./\/}
    JAR_NAME=${APP#*.}-${VERSION}.jar
    APP_DIR=${PROJECT_HOME}/${DIR}/
    get_pid ${APP}
    if [[ ${pid} -ne 0 ]]; then
        echo "WARN: $APP already started! (pid=$pid)";
    else
        echo -n "『STARTING』 ${APP} ......";
        JAVA_OPTS_RUNNING=${JAVA_OPTS}
        if [[ "${PROFILE}" == "test" ]]; then
            JAVA_OPTS_RUNNING=${JAVA_OPTS_TEST}
        fi
        cd ${APP_DIR} && nohup ${JAVA_HOME}/bin/java ${JAVA_OPTS_RUNNING} -jar ${JAR_NAME} --spring.profiles.active=${PROFILE} > nohup.log 2>&1 &
        if [[ $? -eq 0 ]]; then
            echo -e " [OK]"
            if [[ "${MONITOR_PORT}" != "0" ]]; then
                check_server_health
            fi
            if [[ $? -eq 0 ]]; then
                get_pid ${APP}
                echo "『RELEASE_SUCCESS』: $APP (PID=$pid)"
                start_nginx
            else
                echo "『RELEASE_FAIL』: $APP"
            fi
        else
            echo -e " [Failed]"
        fi
    fi
}


stop() {
    APP=$1
    stop_nginx
    get_pid ${APP}
    if [[ ${pid} -ne 0 ]]; then
      echo -n "『STOP』 $APP ...(pid=$pid) "
      kill ${pid}
      if [[ $? -eq 0 ]]; then
         echo -e " [OK]"
         sleep 3
      else
         echo -e " [Failed]"
      fi
   else
      echo "WARN: $APP is not running"
   fi
}

if [[ "${CURRENT_USER}" != "${APP_USER}" ]]; then
    echo "must use ${APP_USER} to execute this script."
    # shellcheck disable=SC2242
    exit -1;
fi

echo "================================================================"
echo "OPTION:${OPTION},PROJECT:${PROJECT},PROFILE=${PROFILE},MONITOR_PORT:${MONITOR_PORT},WITH_NGINX=${WITH_NGINX}"

case "$OPTION" in
    'start')
        start ${PROJECT}
        ;;
    'stop')
        stop ${PROJECT}
        ;;
    'restart')
        stop ${PROJECT}
        start ${PROJECT}
        ;;
    'release')
        stop ${PROJECT}
        copy ${PROJECT}
        start ${PROJECT}
        ;;
  *)
    exit 1
esac
echo "================================================================"
