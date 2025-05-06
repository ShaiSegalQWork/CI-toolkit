# Windows dev enironment

The following build dependencies need to be installed manually

- Windows Driver Kit: https://learn.microsoft.com/en-us/windows-hardware/drivers/download-the-wdk#download-icon-for-wdk-step-3-install-wdk
- WDF 8 Redist: https://go.microsoft.com/fwlink/p/?LinkID=253170

## CI setup
1. Run `ci_setup.ps1` via powershell
1. Add the Jenkins SSH key in `C:\ProgramData\ssh\administrators_authorized_keys`

## Manual MSYS2 setup
1. Install MSYS2
2. Clone this repo into the MSYS2 root, e.g. `/workspace/q-camera-processor`
3. In the MSYS2 UCRT64 shell:
   1. Create a python 3.10 venv (e.g. in `/workspace/venv`) and activate it: `. venv/scripts/activate`
   2. Run the `windows/env_setup.sh` script

# Usage

* Make sure to use the CX3_WINDOWS_MF camera type in your config file.
* The service will attempt to install the necessary device drivers on the first run. After a driver installation the service will exist. Make sure to re-connect the devices before re-running.
