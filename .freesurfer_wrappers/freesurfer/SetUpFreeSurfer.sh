#!/bin/bash
# Dummy FreeSurfer setup for container-based installation
# All FreeSurfer commands are wrapped to run in container
export FREESURFER_HOME="$(dirname "${BASH_SOURCE[0]}")"
exit 0
