#!/bin/bash

docker build -t kumquat-kernel-build . && \
docker run -it --rm -v ./source:/workdir kumquat-kernel-build /workdir/build.sh