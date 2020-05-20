#!/bin/bash
# 部署微服务脚本
OPTION=$1
PROJECT=$2
PROFILE=$3
MONITOR_PORT=$4
CURRENT_USER=$(whoami)
pid=0
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export JAVA_OPTS="-Xms2048m -Xmx2048m"
export JAVA_OPTS_TEST="-Xms512m -Xmx512m"
export PROJECT_HOME=/home/winsonxu/workspace/
export APP_USER="winsonxu"
export VERSION=1.0.0-SNAPSHOT
LANG=en_US.UTF-8
export LANG
#获取线程
getPid() {
  APP=$1
  JAR_NAME=${APP#*.}-${VERSION}.jar
  jps_result=$(${JAVA_HOME}/bin/jps -ml | grep ${JAR_NAME} | grep active=${PROFILE})
  if [[ -n "$jps_result" ]]; then
    echo "[GET_PID] of ${APP}: ${jps_result};"
    pid=$(echo ${jps_result} | awk '{print $1}')
  else
    pid=0
    echo "[GET_PID] of ${APP}: not started."
  fi
}

checkServerHealth() {
  # shellcheck disable=SC2034
  count=0
  healthUrl="http://127.0.0.1:${MONITOR_PORT}/health"
  echo "[checkHealth] [${healthUrl}] blocking..........."
  while :; do
    # shellcheck disable=SC1083
    httpCode=$(curl -I -m 3 -o /dev/null -s -w %{httpCode} "${healthUrl}")
    if [[ ${httpCode} -eq 200 ]]; then
      echo "[checkHealth] finish"
      return
    fi
    sleep 3
  done
}

# 下线微服务
pauseServer() {
  pauseUrl="http://127.0.0.1:${MONITOR_PORT}/pause"
  echo "[pauseServer] [${pauseUrl}] "
  result=$(curl -X POST -m 5 -s "${pauseUrl}")
  echo "[pauseServer] result:${result}.blocking 30s............"
  sleep 30
}

startApp() {
  APP=$1
  DIR=${APP/./\/}
  JAR_NAME=${APP#*.}-${VERSION}.jar
  APP_DIR=${PROJECT_HOME}/${DIR}/
  getPid ${APP}
  if [[ ${pid} -ne 0 ]]; then
    echo "WARN: $APP already started! (pid=$pid)"
  else
    echo -n "[START] ${APP} :"
    JAVA_OPTS_RUNNING=${JAVA_OPTS}
    if [[ "${PROFILE}" == "test" ]]; then
      JAVA_OPTS_RUNNING=${JAVA_OPTS_TEST}
    fi
    cd ${APP_DIR} && nohup ${JAVA_HOME}/bin/java ${JAVA_OPTS_RUNNING} -jar ${JAR_NAME} --spring.profiles.active=${PROFILE} >nohup.log 2>&1 &
    if [[ $? -eq 0 ]]; then
      echo -e " [OK]"
    else
      echo -e " [Failed]"
    fi
    checkServerHealth
    if [[ $? -eq 0 ]]; then
      getPid ${APP}
      echo "『RELEASE_SUCCESS』: $APP (PID=$pid)"
    else
      echo "『RELEASE_FAIL』: $APP"
    fi
  fi
}

stopApp() {
  APP=$1
  getPid ${APP}
  if [[ ${pid} -ne 0 ]]; then
    echo "[STOP] $APP ...(pid=$pid) "
    pauseServer
    kill ${pid}
    if [[ $? -eq 0 ]]; then
      echo "[STOP] OK"
    else
      echo "[STOP] FAIL"
    fi
    sleep 5
  else
    echo "WARN: $APP is not running"
  fi
}
copyApp() {
  APP=$1
  # 将mq.feed替换成mq/feed
  DIR=${APP/./\/}
  # mq.feed替换成feed-1.0.0-SNAPSHOT.jar
  JAR_NAME=${APP#*.}-${VERSION}.jar
  # 应用的jar包存放的目录
  APP_DIR=${PROJECT_HOME}/${DIR}/
  mkdir -p ${APP_DIR}
  cp ${PROJECT_HOME}/source/${PROJECT}/target/${JAR_NAME} ${APP_DIR}
  echo "[COPY] ${PROJECT_HOME}/source/${PROJECT}/target/${JAR_NAME} ${APP_DIR}"
}

#主程序
if [[ "${CURRENT_USER}" != "${APP_USER}" ]]; then
  echo "must use ${APP_USER} to execute this script."
  # shellcheck disable=SC2242
  exit -1
fi

echo "================================================================"
case "$OPTION" in
'start')
  startApp ${PROJECT}
  ;;
'stop')
  stopApp ${PROJECT}
  ;;
'restart')
  stopApp ${PROJECT}
  startApp ${PROJECT}
  ;;
'release')
  stopApp ${PROJECT}
  copyApp ${PROJECT}
  startApp ${PROJECT}
  ;;
*)
  exit 1
  ;;
esac
echo "================================================================"