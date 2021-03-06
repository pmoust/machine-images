#!/usr/bin/env bash
# This script attempts to substitute values in templated files
# Usage: subst -f map-file [key1=value1 ...] template
set -e

function HELP {
>&2 cat << EOF

  Usage: ${0} [-f map-file] [key1=value1 ...] template

  This script acquires key-value pairs from various sources and then uses
  them to make substitutions in the specified template file. The result is
  output to stdout.

    -i            Modify the template inplace, when used you may use multiple
                  template files simultaneously

    -f map-file   Reads further substitution values from the specified map-file
                  (in key=value pairs).

    -p stack      Reads the CFN stack parameters (these will appear with a
                  prefix of 'param.').

    -t            Reads the instance tags (these will appear with a prefix of
                  'tag.'). If a tag exists called aws:cloudformation:stack-id
                  and the instance has the right permissions then the stack
                  parameters will be read as if the -p parameter had been passed
                  with the value of the stack-id tag.

    -h            Displays this help message. No further functions are
                  performed.

    template      The template to apply substitutions to.

EOF
exit 1
}

declare SUBST_ARGS=""
declare SED_BASE_ARGS=""
declare SUBST_FILE=""

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
source ${SCRIPTPATH}/metadata.sh

# Process options
while getopts itp:f:h FLAG; do
  case $FLAG in
    i)
      SED_BASE_ARGS="-i"
      ;;
    f)
      SUBST_ARGS="${SUBST_ARGS} -f ${OPTARG}"
      ;;
    t)
      SUBST_ARGS="${SUBST_ARGS} -t"
      ;;
    p)
      SUBST_ARGS="${SUBST_ARGS} -p ${OPTARG}"
      ;;
    h)  #show help
      HELP
      ;;
  esac
done
shift $((OPTIND-1))

eval declare -A SUBS=$(get_metadata ${SUBST_ARGS})

# Read command line KV pairs
while (( $# )); do
  if (echo $1 | grep '=' > /dev/null); then
    key=${1%%=*}
    value=${1#*=}
    SUBS[$key]=$value
    >&2 echo " >> $key = ${SUBS[$key]}"
    shift
  else
    break
  fi
done

>&2 echo "done with params"

sed_args=${SED_BASE_ARGS}
# build up the sed command line
for K in "${!SUBS[@]}"; do
  >&2 echo $K
  sed_args="${sed_args} -e 's|@${K}@|${SUBS[$K]}|g'"
done

if [ "${SED_BASE_ARGS:0:2}" == "-i" ]; then
  while (( $# )); do
    template_file=$1
    eval sed ${sed_args} ${template_file}
    shift
  done
else
  template_file=$1
  eval sed ${sed_args} ${template_file}
fi
