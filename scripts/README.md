# TRENTOS Helper Scripts

* `open_trentos_build_env.sh <CMD>`

Starts a TRENTOS build container and executes CMD in this environment. If none
is given bash is executed.

* `open_trentos_test_env.sh  <CMD>`

Starts a TRENTOS test container and executes CMD in this environment. If none
is given bash is executed.

* `install_bashrc.sh`

Installs open_trentos_build_env and open_trentos_test_env as bash commands.
Please read the documentation before running it.

* `run_qemu.sh <IMAGE_NAME> <ARGS>`

Starts a QEMU instance with the given image.

* `manage_tap.sh`

Script used to create TAP devices on your host system. Please read the
documentation before running it.

* `bash_functions.def`

The implementation of the open_trentos_build_env/open_trentos_test_env
functions.
