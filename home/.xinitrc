#!/bin/sh
export XDG_SESSION_TYPE=x11

# Intel Iris Xe — hardware acceleration
export LIBVA_DRIVER_NAME=iHD
export VDPAU_DRIVER=va_gl

# Start i3
exec i3
