#!/bin/bash

# Check if running in GitHub Actions
if [ "$GITHUB_ACTIONS" = "true" ]; then
    docker build -t kumquat-kernel-build . && \
    docker run --rm -v ./source:/workdir kumquat-kernel-build /workdir/build.sh
else
    docker build -t kumquat-kernel-build . && \
    docker run -it --rm -v ./source:/workdir kumquat-kernel-build /workdir/build.sh
fi