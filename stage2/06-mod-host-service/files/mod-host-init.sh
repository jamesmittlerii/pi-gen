#!/bin/sh
# Simple default mod-host patch: 2 stereo faders + master

GAIN_URI="http://moddevices.com/plugins/mod-devel/Gain2x2"

# Give mod-host a moment to attach to JACK
sleep 2

mod-host <<EOF
add $GAIN_URI
add $GAIN_URI
add $GAIN_URI

# Rename instances for clarity
rename 0 gain_a
rename 1 gain_b
rename 2 gain_master
EOF
