#!/bin/bash
# jenkins部署脚本
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export JAVA_OPTS="-Xms4096m -Xmx4096m"
export PROJECT_HOME=/home/workspace/ntesgod
export APP_USER="www-data"
export APP_HOME=apps
export VERSION=1.0.0-SNAPSHOT
export ALL_APPS=("admin-server")
LANG=en_US.UTF-8
export LANG

OPTION=$1
PROJECT=$2
CURRENT_USER=`whoami`
PROFILE=$3
#初始化全局pid变量
pid=0

print_usage() {
    echo "usage: $0 build test|server";
    echo "       $0 start|stop|restart all|admin-server test|server";
    exit -1;
}

backup() {
    APP=$1
    NOW=`date '+%Y%m%d_%H%M%S'`
    APP_DIR=${APP/./\/}-${PROFILE}
    JAR_NAME=${APP#*.}-${VERSION}.jar
    cp ${APP_HOME}/${APP_DIR}/${JAR_NAME} release/${JAR_NAME}.${PROFILE}.${NOW}

    echo "[BACKUP] ${APP_HOME}/${APP_DIR}/${JAR_NAME} to release/${JAR_NAME}.${PROFILE}.${NOW}"
}

copy() {
	APP=$1
	# 将mq.feed替换成mq/feed
	DIR=${APP/./\/}
    # mq.feed替换成feed-1.0.0-SNAPSHOT.jar
    JAR_NAME=${APP#*.}-${VERSION}.jar
    # 应用的jar包存放的目录
    APP_DIR=${APP_HOME}/${DIR}-${PROFILE}/

    mkdir -p ${APP_DIR}
    cp source/${JAR_NAME} ${APP_DIR}

    echo "[COPY] source/${JAR_NAME} to ${APP_DIR}"
}

get_pid() {
    APP=$1
    JAR_NAME=${APP#*.}-${VERSION}.jar
    jps_result=`${JAVA_HOME}/bin/jps -ml | grep ${JAR_NAME} |grep active=${PROFILE}`

    if [ -n "$jps_result" ]; then
        echo "[GET_PID] of ${APP}: ${jps_result};"
        pid=`echo ${jps_result} | awk '{print $1}'`
    else
        pid=0
        echo "[GET_PID] of ${APP}: not started."
   fi
}

start() {
    APP=$1
    DIR=${APP/./\/}
    JAR_NAME=${APP#*.}-${VERSION}.jar
    APP_DIR=${APP_HOME}/${DIR}-${PROFILE}/
    get_pid ${APP}
    if [ ${pid} -ne 0 ]; then
        echo "WARN: $APP already started! (pid=$pid)";
    else
        echo -n "[START] ${APP} :";
        cd ${APP_DIR} && nohup ${JAVA_HOME}/bin/java ${JAVA_OPTS} -jar ${JAR_NAME} --spring.profiles.active=$PROFILE > ${PROJECT_HOME}/log/${APP}-${PROFILE}.log 2>&1 &

        if [ $? -eq 0 ]; then
            echo -e " [OK]"
        else
            echo -e " [Failed]"
        fi
        sleep 5
        get_pid ${APP}
        if [ ${pid} -ne 0 ]; then
            echo "RELEASE_SUCCESS: $APP (PID=$pid)"
        else
            echo "RELEASE_FAIL: $APP"
        fi
    fi
}

stop() {
    APP=$1
    get_pid ${APP}

    if [ ${pid} -ne 0 ]; then
      echo -n "[STOP] $APP ...(pid=$pid) "
      kill -9 ${pid}
      if [ $? -eq 0 ]; then
         echo " [OK]"
      else
         echo " [Failed]"
      fi
      sleep 5
   else
      echo "WARN: $APP is not running"
   fi
}

if [ "${CURRENT_USER}" != "${APP_USER}" ]; then
    echo "must use ${APP_USER} to execute this script."
    exit -1;
fi

if [ "$1" == "" ]; then
    print_usage
fi
if [ "${PROFILE}" == "" ]; then
    print_usage;
fi
if [ "${OPTION}" == "start" -a "${PROJECT}" == "" ]; then
    print_usage
fi
echo "================================================================"
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
        #backup ${PROJECT}
        stop ${PROJECT}
        copy ${PROJECT}
        start ${PROJECT}
        ;;
  *)
    print_usage
    exit 1
esac
echo "================================================================"
