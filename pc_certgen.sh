#!/bin/bash
# Tested on Ubuntu 22.04.3 LTS and ESP32S3

# Dependencies:

	# 1. ESP-IDF (Espressif IoT Development Framework) 
		# https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html
		
		# Building, flashing and monitoring the ESP project is automatically done in this script

	# 2. Python>=3.8 and python-pip
		# Make sure you can run python scripts and pip commands from your Shell
	
	# 3. CMake
	
	# 4. Git
	
	# 5. Java
		# Install Java and make sure to set $JAVA_HOME
	
	# make this script executable by running 'chmod 777 pc_certgen.sh'

timestamp=$(date +%Y%m%d%H%M%S)
#### Project directories
ESPRESSIF_IDF_HOME="/home/tom/esp/esp-idf"
PROJECT_HOME="/home/tom/sampleproject"
PROJECT_NAME=$(basename "$PROJECT_HOME")

#### Scripts and executable
IDF_SCRIPT_PATH="$ESPRESSIF_IDF_HOME""/tools"
policymaker_script="$PROJECT_HOME""/referenceoptions.sh"
extensions_script="$PROJECT_HOME""/otherextensions.sh"
signer_bin="$PROJECT_HOME""/bin/signer"
validator_bin="$PROJECT_HOME""/bin/validator"

### Files
LOG_FILE="$PROJECT_HOME""/esp_logfile.txt"
SDKCONFIG="$PROJECT_HOME""/sdkconfig"
workspace="$PROJECT_HOME""/pc_testgen"
componentlist="$workspace""/localhost-componentlist.json"
policyreference="$workspace""/localhost-policyreference.json"
ekcert="$workspace""/ek.crt"
pccert="$workspace""/platform_cert.""$timestamp"".crt"
sigkey="$workspace""/private.pem"
pcsigncert="$workspace""/PCTestCA.example.com.pem"
extsettings="$workspace""/extentions.json"

### Certificate params
serialnumber="0001"
dateNotBefore=$(date '+%Y%m%d')
dateNotAfter=$(date '+%Y%m%d' -d "+10 years")

### Key Pair params
subjectDN="/C=US/O=example.com/OU=PCTest"
daysValid="3652"
sigalg="rsa:2048"

### ESP-specific variables
PORT="/dev/ttyACM0"
BAUD_RATE="115200"
TARGET_DEVICE="esp32s3"

declare -a SDKCONFIG_VARIABLES=(	
									"CONFIG_BT_ENABLED=y"
									"CONFIG_PARTITION_TABLE_CUSTOM=y"	
									"CONFIG_PARTITION_TABLE_OFFSET=0xa000"							
									"CONFIG_APP_REPRODUCIBLE_BUILD=y"
									"CONFIG_SECURE_BOOT=y"
								)

extractESPData() {

	if [ ! -d "$ESPRESSIF_IDF_HOME" ]; then
		echo "Invalid Espressif IDF home path."
		exit 1
	fi
	
	if [ ! -d "$PROJECT_HOME" ]; then
		echo "Invalid project home path."
		exit 1
	fi
	
	if [ ! -d "$PROJECT_HOME""/main" ]; then
		echo "\nC source files should be placed in the main directory of your project."
		echo "Creating main directory..."
		mkdir "$PROJECT_HOME""/main"
		exit 1
	fi
	
	### Change serial port permissions
	sudo chmod 666 "$PORT"

	### Enable ESP-IDF in the current bash session
	sh "$ESPRESSIF_IDF_HOME""/install.sh"
	. "$ESPRESSIF_IDF_HOME""/export.sh"
	
	### Create CMakeLists file (needs adjustment depending on the project)
	echo -e "cmake_minimum_required(VERSION 3.16)\ninclude($ENV${IDF_PATH}/tools/cmake/project.cmake)\nproject($PROJECT_NAME)" > "$PROJECT_HOME""/CMakeLists.txt"
	echo -e "idf_component_register(SRCS \"main.c\" \"conf.c\" \"allcomponents.c\")" > "$PROJECT_HOME""/main/CMakeLists.txt"
	
	### Set target device
	cd "$IDF_SCRIPT_PATH"
	python idf.py -C "$PROJECT_HOME" set-target "$TARGET_DEVICE"
	
	### Enable bluetooth, set partition app_size large and enable reproducible build
	### Important: Reproducible build needs to be enabled to retain consistent firmware/bootloader/ELF hashes
	for i in "${SDKCONFIG_VARIABLES[@]}"
	do
		echo "$i" >> "$SDKCONFIG"
	done
	
	### Alternatively set sdkconfig variables using menuconfig
	#python idf.py -C "$PROJECT_HOME" menuconfig
	
	### Build project
	python idf.py -C "$PROJECT_HOME" build
	echo "\nBuild successful\n"

	### Flash ESP (UART)
	python idf.py -C "$PROJECT_HOME" -p "$PORT" -b "$BAUD_RATE" flash
	echo "\nFlash successful\n"
	echo "\nExtracting logs from $TARGET_DEVICE ...\n"

	### Start monitor on device and receive logs
	x-terminal-emulator -e "python idf.py -C \"$PROJECT_HOME\" -p \"$PORT\" -b \"$BAUD_RATE\" monitor > \"$LOG_FILE\"" &
	sleep 10

	### Reset path
	cd "$PROJECT_HOME"

	if ! [ -e "$LOG_FILE" ]; then
		echo "\nFailed to generate log file.\n"
		exit 1
	fi

	echo "\nSuccessfully extracted logs from $TARGET_DEVICE\n"

	return 0
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.sh
createWorkspace() {
	if [ ! -d "$workspace" ]; then
		mkdir "$workspace"
		sudo chmod -R 777 "$workspace"
		if [ $? -ne 0 ]; then
			echo "Failed to make a working directory in ""$workspace"
			exit 1
		fi
	fi
	
	return 0
}

getMockEKCert() {
	echo "ESP32 does not have a dedicated TPM. Generating an empty mock EK certificate..."
	echo "Instead, the SHA-256 checksum of the secure boot v2 RSA-3072 signing key is stored in the certificate."
	$(openssl req -x509 -nodes -days "$daysValid" -newkey "$sigalg" -out "$ekcert" -subj "/C=US/O=example.com/OU=mockEK" >> /dev/null)
}

createComponentListJSON() {
	if ! [ -e "$componentlist" ]; then
		python allcomponents.py
	else
		echo "Component file exists, skipping"
	fi
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.sh
getPolicyReferenceJSON() {
	if ! [ -e "$policyreference" ]; then
	    echo "Creating a Platform policy JSON file"
	    bash "$policymaker_script" > "$policyreference"
	    if [ $? -ne 0 ]; then
		echo "Failed to create the policy reference, exiting"
		rm -f "$policyreference"
		exit 1
	    fi
	else
	    echo "Policy settings file exists, skipping"
	fi
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.sh
createExtensionsJSON() {
	if ! [ -e "$extsettings" ]; then
	    echo "Creating an extensions JSON file"
	    bash "$extensions_script" > "$extsettings"
	    if [ $? -ne 0 ]; then
		echo "Failed to create the extensions file, exiting"
		rm -f "$extsettings"
		exit 1
	    fi
	else
	    echo "Extensions file exists, skipping"
	fi
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.sh
createSigningKeyPair() {
	if ! [ -e "$pcsigncert" ]; then
	    echo "Creating a signing key for signing platform credentials"
	    $(openssl req -x509 -nodes -days "$daysValid" -newkey "$sigalg" -keyout "$sigkey" -out "$pcsigncert" -subj "$subjectDN" >> /dev/null)
	    if [ $? -ne 0 ]; then
		echo "Failed to create the key pair, exiting"
		exit 1
	    fi
	else 
	    echo "Platform Signing file exists, skipping"
	fi
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.sh
sign() {
	echo "Generating a signed Platform Credential"
	bash $signer_bin -x "$extsettings" -c "$componentlist" -e "$ekcert" -p "$policyreference" -k "$sigkey" -P "$pcsigncert" -N "$serialnumber" -b "$dateNotBefore" -a "$dateNotAfter" -f "$pccert" 
	if [ $? -ne 0 ]; then
	    echo "The signer could not produce a Platform Credential, exiting"
	    exit 1
	fi
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.sh
validate() {
	echo "Validating the signature"
	bash $validator_bin -P "$pcsigncert" -X "$pccert"

	if [ $? -eq 0 ]; then
	    echo "PC Credential Creation Complete."
	    echo "Platform Credential has been placed in ""$pccert"
	else
	    rm -f "$pccert"
	    echo "Error with signature validation of the credential."
	fi
}


# function calls
extractESPData
createWorkspace
getMockEKCert
createComponentListJSON
getPolicyReferenceJSON
createExtensionsJSON
createSigningKeyPair
sign
validate

