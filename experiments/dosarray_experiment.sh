#/bin/sh -e
# Main support functions for running DoSarray experiments
# Nik Sultana, February 2018, UPenn

if [ -z "${DOSARRAY_SCRIPT_DIR}" ]
then
  echo "Need to configure DoSarray -- set \$DOSARRAY_SCRIPT_DIR" >&2
  exit 1
elif [ ! -e "${DOSARRAY_SCRIPT_DIR}/config/dosarray_config.sh" ]
then
  echo "Need to configure DoSarray -- could not find dosarray_config.sh at \$DOSARRAY_SCRIPT_DIR/config (${DOSARRAY_SCRIPT_DIR}/config)" >&2
  exit 1
fi
source "${DOSARRAY_SCRIPT_DIR}/config/dosarray_config.sh"

# This is used to insert a manifest in the RESULT_DIR, describing the date at
# which the experiment was made, and a full dump of all configuration
# variables.
function dosarray_manifest() {
  DESTINATION_FILE="$1"
  echo "#  Generated by DoSarray v${DOSARRAY_VERSION} on $(date)" > "${DESTINATION_FILE}"

  if [ -z "${DOSARRAY_INCLUDE_MANIFEST}" ]
  then
    echo "Manifest generation is disabled (by default)" >> "${DESTINATION_FILE}"
  else
    echo "#  Variables:" >> "${DESTINATION_FILE}"
    echo "$(set -o posix; set)" >> "${DESTINATION_FILE}"
    echo "#  Functions:" >> "${DESTINATION_FILE}"
    echo "$(declare -f)" >> "${DESTINATION_FILE}"
  fi
}

function dosarray_tmp_file() {
  TAG="${1}"
  TMPFILE=`mktemp -q /tmp/dosarray.${TAG}.XXXXXX`
  if [ $? -ne 0 ]; then
    echo "DoSarray: Could not create temporary file"
    exit 1
  fi
  echo "${TMPFILE}"
}

function dosarray_http_experiment() {
  TARGET=$1
  ATTACK=$2
  EXPERIMENT_SET=$3
  PRE_DESTINATION_DIR=$4
  NUM_RUNS=$5

  source "${DOSARRAY_SCRIPT_DIR}/src/dosarray_http_experiment_options.sh"

  if [ -z "${NUM_RUNS}" ]
  then
    TOTAL_RUNS=1
  else
    TOTAL_RUNS=${NUM_RUNS}
  fi

  # FIXME add script to combine + visualise data from multiple runs
  for RUN in `seq 1 ${TOTAL_RUNS}`
  do
    if [ "${TOTAL_RUNS}" -eq "1" ]
    then
      export DESTINATION_DIR="${PRE_DESTINATION_DIR}/"
    else
      echo "Starting run ${RUN} of ${TOTAL_RUNS}"
      export DESTINATION_DIR="${PRE_DESTINATION_DIR}/${RUN}/"
    fi

    echo "Started HTTP experiment at $(date): ${TARGET}, ${ATTACK}, ${EXPERIMENT_SET}"
    STD_OUT=`dosarray_tmp_file stdout`
    STD_ERR=`dosarray_tmp_file stderr`
    echo "  Writing to ${DESTINATION_DIR}"
    MANIFEST=`dosarray_tmp_file manifest`
    dosarray_manifest ${MANIFEST}

    TITLE="$(target_str ${TARGET}), $(attack_str ${ATTACK}), ${EXPERIMENT_SET}" \
    ${DOSARRAY_SCRIPT_DIR}/src/dosarray_run_http_experiment.sh ${TARGET} ${ATTACK} \
    > ${STD_OUT} \
    2> ${STD_ERR}

    if [ -z "${DOSARRAY_INCLUDE_STDOUTERR}" ]
    then
      echo "DoSarray stdout was collected in: ${STD_OUT}"
      echo "DoSarray stderr was collected in: ${STD_ERR}"

      # FIXME this "Generated by" string is repeated in different places -- turn into a function?
      echo "#  Generated by DoSarray v${DOSARRAY_VERSION} on $(date)" > "${DESTINATION_DIR}/dosarray.stdout"
      echo "stdout collection is disabled (by default)" >> "${DESTINATION_DIR}/dosarray.stdout"

      echo "#  Generated by DoSarray v${DOSARRAY_VERSION} on $(date)" > "${DESTINATION_DIR}/dosarray.stderr"
      echo "stderr collection is disabled (by default)" >> "${DESTINATION_DIR}/dosarray.stderr"
    else
      echo "#  Generated by DoSarray v${DOSARRAY_VERSION} on $(date)" > "${DESTINATION_DIR}/dosarray.stdout"
      cat ${STD_OUT} >> ${DESTINATION_DIR}/dosarray.stdout
      echo "#  Generated by DoSarray v${DOSARRAY_VERSION} on $(date)" > "${DESTINATION_DIR}/dosarray.stderr"
      cat ${STD_ERR} >> ${DESTINATION_DIR}/dosarray.stderr

      rm ${STD_OUT}
      rm ${STD_ERR}
    fi

    mv ${MANIFEST} ${DESTINATION_DIR}/dosarray.manifest

    echo "Finished at $(date)"
  done
}
