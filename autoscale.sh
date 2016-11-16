#!/bin/bash
#
set -x

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -n)
    PROJECT="$2"
    shift # past argument
    ;;
    -d)
    DC="$2"
    shift # past argument
    ;;
    *)
            # unknown option
   ;;
esac
shift # past argument or value
done

TOTAL=0

oc get pods -o jsonpath='{range .items[*]}{.metadata.name} {.status.podIP} {.status.phase}
{end}' -n ${PROJECT} | egrep "^${DC}-.-..... .*Running$" | \
while read POD IP PHASE ; do
    TOTAL=$(($TOTAL + 0$( curl -q -s -o - http://$IP/get-metrics ) ))
done


# Arbitrary formula to calculate required number of replicas
NEEDED=$(( 3 + (($TOTAL-1)/2) ))

#
CURRENT=$(oc get dc $DC -o jsonpath='{.spec.replicas}' -n $PROJECT)


# To avoid thrashing only scale-up
[ $NEEDED -ne $CURRENT ] && echo Replicas Current: $CURRENT Desired: $NEEDED

RC=$(oc get rc -n $PROJECT -o jsonpath='{range .items[*]}{.metadata.name}
{end}' | egrep "^$DC-.*")

echo "oc scale rc ${RC} --replicas=${NEEDED} -n ${PROJECT}"
