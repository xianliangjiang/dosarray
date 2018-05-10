#/bin/sh -e
# DoSarray setup for HTTP
# Nik Sultana, December 2017, UPenn
#
# Use of this source code is governed by the Apache 2.0 license; see LICENSE

if [ -z "${DOSARRAY_SCRIPT_DIR}" ]
then
  echo "Need to configure DoSarray -- set \$DOSARRAY_SCRIPT_DIR" >&2
  exit 1
elif [ ! -e "${DOSARRAY_SCRIPT_DIR}/dosarray_config.sh" ]
then
  echo "Need to configure DoSarray -- could not find dosarray_config.sh at \$DOSARRAY_SCRIPT_DIR ($DOSARRAY_SCRIPT_DIR)" >&2
  exit 1
fi
source "${DOSARRAY_SCRIPT_DIR}/dosarray_config.sh"

# FIXME hardocoded to assume that the SERVER_IP is always the first element of DOSARRAY_PHYSICAL_HOSTS_PRIV
SERVER_IP="${DOSARRAY_PHYSICAL_HOSTS_PRIV[0]}"

if [ -z "${SERVER_PORT}" ]
then
  echo "Need to define \$SERVER_PORT" >&2
  exit 1
fi
if [ -z "${ATTACK}" ]
then
  echo "Need to define \$ATTACK" >&2
  exit 1
fi
if [ -z "${EXPERIMENT_DURATION}" ]
then
  echo "Need to define \$EXPERIMENT_DURATION" >&2
  exit 1
fi
if [ -z "${NO_OF_INSTANCES}" ]
then
  echo "Need to define \$NO_OF_INSTANCES" >&2
  exit 1
fi
if [ -z "${ATTACK_STARTS_AT}" ]
then
  echo "Need to define \$ATTACK_STARTS_AT" >&2
  exit 1
fi
if [ -z "${ATTACK_LASTS_FOR}" ]
then
  echo "Need to define \$ATTACK_LASTS_FOR" >&2
  exit 1
fi

if [ "${SERVER_PORT}" == "${PORT_Nginx}" ]
then
  ATTACK_ACTUALLY_LASTS_FOR=$(echo "1 * ${ATTACK_LASTS_FOR}" | bc -l)  # NOTE use for nginx
else
  ATTACK_ACTUALLY_LASTS_FOR=$(echo "2 * ${ATTACK_LASTS_FOR}" | bc -l)
fi

ATTACK_END_TIME=$(echo "${ATTACK_STARTS_AT} + ${ATTACK_ACTUALLY_LASTS_FOR}" | bc -l)
POST_ATTACK_PERIOD=$(echo "${EXPERIMENT_DURATION} - (${ATTACK_END_TIME} - ${ATTACK_LASTS_FOR})" | bc -l)


if [ -z "${ATTACKERS}" ]
then
  echo "Need to define \$ATTACKERS" >&2
  exit 1
fi

# NOTE could also us parameters "-G -s -S" for httping
MEASUREMENT_COMMAND="httping -g http://${SERVER_IP} -p ${SERVER_PORT} -i 1 -t 1 -c ${EXPERIMENT_DURATION} -s"
STOP_MEASUREMENT_COMMAND="killall httping"

if [ "${ATTACK}" -eq "${ATTACK_Slowloris}" ]
then
  ATTACK_COMMAND="perl /opt/attacks/sl/slowloris.pl -dns ${SERVER_IP} -port ${SERVER_PORT}"
  STOP_ATTACK_COMMAND="killall perl"
elif [ "${ATTACK}" -eq "${ATTACK_GoldenEye}" ]
then
  ATTACK_COMMAND="python /opt/attacks/GoldenEye/goldeneye.py http://${SERVER_IP}:${SERVER_PORT}"
  STOP_ATTACK_COMMAND="killall python"
elif [ "${ATTACK}" -eq "${ATTACK_TorsHammer}" ]
then
  ATTACK_COMMAND="python /opt/attacks/th/torshammer.py -t ${SERVER_IP} -p ${SERVER_PORT}"
  STOP_ATTACK_COMMAND="killall python"
else
  echo "Unrecognised attack"
  exit 2
fi

source ./dosarray_experiment_httpings.sh
#source ./dosarray_experiment_httpings_only.sh # Using this to run and stop the attacks interactively, while performance-tuning apache
