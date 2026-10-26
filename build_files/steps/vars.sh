# Variabili condivise dagli step. Ogni step fa: source "$(dirname "$0")/vars.sh"
set -ouex pipefail

FEDORA_VERSION=44

# Webcam FaceTime HD: sorgenti del modulo (patjak/facetimehd), versione fissata
FACETIMEHD_VERSION=0.7.2
FACETIMEHD_SHA256=ed4ca0a1388451c356c713957a9a597a5d625956d41a0dbcd618d04e12675a86
