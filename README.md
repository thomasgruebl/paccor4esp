# esp-paccor

A [Platform Attribute Certificate](https://trustedcomputinggroup.org/resource/tcg-platform-certificate-profile/) Creator for the ESP32 microcontroller.

## How to use

1. Download the latest release of the official [PACCOR](https://github.com/nsacyber/paccor/releases/) repository
2. Clone [this](https://github.com/thomasgruebl/esp-paccor) repository and copy the contents to a new folder in "{HOME}\paccor\scripts\esp" named "esp"

The paccor project structure should look as follows:
<pre>
├── bin     Original [PACCOR](https://github.com/nsacyber/paccor/releases/) repository contents
├── docs
├── lib
└── scripts
    ├── allcomponents.sh
    ├── get_ek.sh
    ├── .....  
    ├── smbios.sh
    ├── <b>esp         NEW folder with contents of this repository
        ├── allcomponents.py        The Python log parsing module
        ├── CMakeLists.txt          Gets automatically generated on first run
        ├── esp_logfile.txt         Gets automatically generated on first run
        ├── pc_certgen.ps1          Main entrypoint for Windows machines
        ├── pc_certgen.sh           Main entrypoint for Linux/MacOS machines
        ├── sdkconfig               Gets automatically generated on first run
        └── main
            ├── allcomponents.c     C module for extracting data from the ESP32
            ├── allcomponents.h     Corresponding header file
            ├── CMakeLists.txt      Gets automatically generated on first run
            ├── conf.c              C module for Wifi, Bluetooth, NVS initializations
            └── conf.h              Corresponding header file</b>
    └── windows
        ├── allcomponents.ps1
        ├── get_ek.ps1
        ├── .....  
        └── smbios.ps1
</pre>

3. Download and install the [ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/index.html) (Espressif IoT Development Framework)
4. Download and install the dependencies
    * Python>=3.8 and python-pip
    * Git
    * CMake
5. Set the variables in the <strong>pc_certgen.sh</strong> or <strong>pc_certgen.ps1</strong> script depending on your OS
    * Set the ESPRESSIF_IDF_HOME path variable (installation path of your ESP-IDF)
    * Set the ESPRESSIF_IDF_HOME path variables ("{HOME}\paccor\scripts\esp")
    * Adjust the certificate parameters (such as serial number and validity)
    * Adjust the ESP-specific variables such as baud rate, serial port name and target device type
    * Extend/amend the ESP-specific sdkconfig variables if needed

## Troubleshooting

* Check your hardware connection, are you attached to the USB or UART port?
* Check if your serial port is visible on your Windows machine (Device Manager) or Linux machine (dmesg | grep tty).
* Check your baud rate.
* Did you close your serial monitor terminal window before you tried flashing the ESP again?

## Contributing

1. Fork the repository
2. Create a new feature branch (`git checkout -b my-feature-branch-name`)
3. Commit your new changes (`git commit -m 'commit message' <changed-file>`)
4. Push changes to the branch (`git push origin my-feature-branch-name`)
5. Create a Pull Request

## Copyright

Parts of the code in the [pc_certgen.sh](https://github.com/thomasgruebl/esp-paccor/blob/main/pc_certgen.sh) and [pc_certgen.ps1](https://github.com/thomasgruebl/esp-paccor/blob/main/pc_certgen.ps1) files have been reused from [the official paccor repository](https://github.com/nsacyber/paccor). Copyright 2023 nsacyber. [LICENSE2](https://github.com/thomasgruebl/esp-paccor/blob/main/LICENSE2) applies.

The rest of the project is licensed under the MIT License. Copyright 2023 thomasgruebl. [LICENSE](https://github.com/thomasgruebl/esp-paccor/blob/main/LICENSE) applies.