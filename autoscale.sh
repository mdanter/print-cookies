#!/bin/bash
#
#set -x
[ $# -eq 0 ] && { echo "Usage: $0 -d <dc> -n <project>"; exit 1; }

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
    PORT=$(oc get service $DC -o jsonpath='{range .spec}{.ports[0].targetPort}
{end}')

    CURRENT=$(curl -q -s -o - http://$IP:$PORT/get-metrics/)
    TOTAL=$(($TOTAL + $CURRENT))
done


# Arbitrary formula to calculate required number of replicas
NEEDED=$(( 3 + (($TOTAL-1)/2) ))

# Get the current replica count
CURRENT=$(oc get dc $DC -o jsonpath='{.spec.replicas}' -n $PROJECT)

# To avoid thrashing only scale-up
[ $NEEDED -ne $CURRENT ] && echo Replicas Current: $CURRENT Desired: $NEEDED

echo "oc scale dc/${DC} --replicas=${NEEDED} -n ${PROJECT}"
# this will actually change the replicas, uncomment if needed
#oc scale dc/${DC} --replicas=${NEEDED} -n ${PROJECT}
