#!/bin/bash

set -x
set -e
set -o pipefail

if [ -z "$FILESERVER" -o -z "$FS_SSH_USER" -o -z "$RELEASE_VERSION" -o -z "$GITHUB_OWNER" -o -z "$GITHUB_BRANCH" -o -z "$BUILD_NUMBER" -o -z "$WORKSPACE" ]
then
    echo "Required variable not set" >&2
    exit 1
fi

RELEASE_VERSION_ESCAPED=$(echo "$RELEASE_VERSION" | sed -e 's|\.|\\\.|g')

nc -w0 -u $FILESERVER 514 <<< "automated-build20: Build $RELEASE_VERSION ($BUILD_NUMBER) finish"

ssh $FS_SSH_USER@$FILESERVER "zcat /var/log/20-messages.1.gz | cat - /var/log/20-messages | awk '/ automated-build20: Build $RELEASE_VERSION_ESCAPED \($BUILD_NUMBER\) start/,/ automated-build20: Build $RELEASE_VERSION_ESCAPED \($BUILD_NUMBER\) finish$/' | gzip -c > automated-build.log.gz"

# TODO(NB) Try and do this in one step, the above command should be able to copy it directly, but ssh -A isn't working for some reason.
scp -q $FS_SSH_USER@$FILESERVER:automated-build.log.gz .

scp -q automated-build.log.gz $FS_SSH_USER@$FILESERVER:/home/shared/builds/$GITHUB_OWNER/$GITHUB_BRANCH/debug/functional-test-$RELEASE_VERSION-$BUILD_NUMBER.log.gz

scp -r /tmp/teacup-artifacts-$EXECUTOR_NUMBER $FILESERVER:/home/shared/builds/$GITHUB_OWNER/$GITHUB_BRANCH/debug/
rm -rf /tmp/teacup-artifacts-$EXECUTOR_NUMBER

set +x

echo
echo
echo "Errors in the log:"

if test -x "$WORKSPACE"/teacup/tools/extract-errors.py
then
    zcat automated-build.log.gz | "$WORKSPACE"/teacup/tools/extract-errors.py
else
    zcat automated-build.log.gz | awk '/^Traceback \(most recent/,/^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/'
fi
echo

cat <<EOF
Options to view the log:
http://$FILESERVER/builds/$GITHUB_OWNER/$GITHUB_BRANCH/debug/functional-test-$RELEASE_VERSION-$BUILD_NUMBER.log
http://$FILESERVER/builds/$GITHUB_OWNER/$GITHUB_BRANCH/debug/functional-test-$RELEASE_VERSION-$BUILD_NUMBER.log.gz
http://$FILESERVER/builds/$GITHUB_OWNER/$GITHUB_BRANCH/debug/teacup-artifacts-$EXECUTOR_NUMBER/
scp $FILESERVER:/home/shared/builds/$GITHUB_OWNER/$GITHUB_BRANCH/debug/functional-test-$RELEASE_VERSION-$BUILD_NUMBER.log.gz .

EOF
