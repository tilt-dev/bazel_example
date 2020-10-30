#!/bin/bash

set -euo pipefail

tilt ci
tilt down
