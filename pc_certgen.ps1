# Tested on Windows 11 and ESP32S3

# Dependencies:

	# 1. ESP-IDF (Espressif IoT Development Framework) 
		# https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/windows-setup.html
		
		# Building, flashing and monitoring the ESP project is automatically done in this script

	# 2. Python>=3.8 and python-pip
		# Make sure you can run python scripts and pip commands from your Shell
	
	# 3. CMake
	
	# 4. Git

$timestamp=(Get-Date -UFormat "%Y%m%d%H%M%S")
#### Project directories
$ESPRESSIF_IDF_HOME="C:/Users/Thomas/esp/esp-idf/"
$PROJECT_HOME="C:/Users/Thomas/esp-paccor/"
$PROJECT_NAME=(Split-Path "$PROJECT_HOME" -Leaf)

#### Scripts and executable
$IDF_SCRIPT_PATH="$ESPRESSIF_IDF_HOME" + "tools/"
$policymaker_script="$PROJECT_HOME" + "referenceoptions.ps1"
$extensions_script="$PROJECT_HOME" + "otherextensions.ps1"
$signer_bin="$PROJECT_HOME" + "bin/signer.bat"
$validator_bin="$PROJECT_HOME" + "bin/validator.bat"

### Files
$LOG_FILE="$PROJECT_HOME" + "esp_logfile.txt"
$SDKCONFIG="$PROJECT_HOME" + "sdkconfig"
$workspace="$PROJECT_HOME" + "pc_testgen"
$componentlist="$workspace" + "/localhost-componentlist.json"
$policyreference="$workspace" + "/localhost-policyreference.json"
$ekcert="$workspace" + "/ek.pem"
$pccert="$workspace" + "/platform_cert." + "$timestamp" + ".crt"
$sigkey="$workspace" + "/CAcert.p12"
$pcsigncert="$workspace" + "/PCTestCA.example.com.cer"
$extsettings="$workspace" + "/extentions.json"

### Certificate params
$serialnumber="0001"
$dateFormat="yyyyMMdd"
$dateNotBefore=(Get-Date -UFormat "%Y%m%d")
$add10years=(Get-Date).AddYears(10)
$dateNotAfter=(Get-Date -Date $add10years -Format $dateFormat)

### Key Pair params
$subjectDN="C=US,O=example.com,OU=PCTest"
$daysValid=(Get-Date).AddYears(10)
$sigalg="RSA"
$sigalgbits="2048"
$certStoreLocation="Cert:/CurrentUser/My/"
$pfxpassword="password"

### ESP-specific variables
$PORT="COM3"
$BAUD_RATE="115200"
$TARGET_DEVICE="esp32s3"

$SDKCONFIG_VARIABLES = @(
							"CONFIG_BT_ENABLED=y",
							"CONFIG_PARTITION_TABLE_CUSTOM=y",
							"CONFIG_PARTITION_TABLE_OFFSET=0xa000",
							"CONFIG_APP_REPRODUCIBLE_BUILD=y",
							"CONFIG_SECURE_BOOT=y"
						)


function extractESPData() {

	if (!(Test-Path -Path $ESPRESSIF_IDF_HOME )) {
		echo "Invalid Espressif IDF home path."
		exit 1
	}
	if (!(Test-Path -Path $PROJECT_HOME )) {
		echo "Invalid project home path."
		exit 1
	}
	if (!(Test-Path -Path "${PROJECT_HOME}main" )) {
		echo "`nC source files should be placed in the main directory of your project."
		echo "Creating main directory..."
		New-Item -Path ${PROJECT_HOME} -Name "main" -ItemType "directory" 
		exit 1
	}

	### Enable ESP-IDF in the current powershell session
	. ${ESPRESSIF_IDF_HOME}/install.ps1
	. ${ESPRESSIF_IDF_HOME}/export.ps1
	
	### Install windows-curses (ESP-IDF menuconfig requirement)
	pip install windows-curses
	
	### Create CMakeLists file (needs adjustment depending on the project)
	$cmake_home = "cmake_minimum_required(VERSION 3.16)`ninclude(${ESPRESSIF_IDF_HOME}tools/cmake/project.cmake)`nproject($PROJECT_NAME)"
	$cmake_main = "idf_component_register(SRCS `"main.c`" `"conf.c`" `"allcomponents.c`")"
	$cmake_home_path = "$PROJECT_HOME"+"CMakeLists.txt"
	$cmake_main_path = "$PROJECT_HOME"+"main/CMakeLists.txt"
	[IO.File]::WriteAllText($cmake_home_path, "$cmake_home")
	[IO.File]::WriteAllText($cmake_main_path, "$cmake_main")
	
	### Set target device
	Set-Location -Path "$IDF_SCRIPT_PATH"
	python idf.py -C "$PROJECT_HOME" set-target "$TARGET_DEVICE"
	
	### Enable bluetooth, set partition app_size large and enable reproducible build
	### Important: Reproducible build needs to be enabled to retain consistent firmware/bootloader/ELF hashes
	foreach ($var in $SDKCONFIG_VARIABLES) {
		Add-Content -Path $SDKCONFIG -Value $var
	}
	
	### Alternatively set sdkconfig variables using menuconfig
	#python idf.py -C "$PROJECT_HOME" menuconfig

	### Build project
	python idf.py -C "$PROJECT_HOME" build
	echo "`nBuild successful`n"

	### Flash ESP (UART)
	python idf.py -C "$PROJECT_HOME" -p "$PORT" -b "$BAUD_RATE" flash
	echo "`nFlash successful`n"
	echo "`nExtracting logs from $TARGET_DEVICE ...`n"

	### Start monitor on device and receive logs
	$monitorProcessOptions = @{
		FilePath = "powershell.exe"
		ArgumentList = "python.exe ${IDF_SCRIPT_PATH}/idf.py -C $PROJECT_HOME -p $PORT -b $BAUD_RATE monitor | Out-File $LOG_FILE"
		Verb = "RunAs"
		PassThru = $true
		WindowStyle = "Minimized"
	}
	$monitorProcess = Start-Process @monitorProcessOptions

	Start-Sleep -Seconds 10
	Stop-Process -InputObject $monitorProcess

	### Reset path
	Set-Location -Path "$PROJECT_HOME"

	if (!(Test-Path "$LOG_FILE" -PathType Leaf)) {
		echo "`nFailed to generate log file.`n"
		exit 1
	}

	echo "`nSuccessfully extracted logs from $TARGET_DEVICE`n"

	return 0
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.ps1
function createWorkspace() {
	if (!(Test-Path -Path $workspace )) {
		if( (New-Object Security.Principal.WindowsPrincipal(
				[Security.Principal.WindowsIdentity]::GetCurrent())
			).IsInRole(
				[Security.Principal.WindowsBuiltInRole]::Administrator)
		  ) {
		  md "$workspace" -ea 0
		  if(!$?) {
			  echo "Failed to make a working directory in " + "$workspace"
			  exit 1
		  }
		} else {
			echo "The first time this script is run, this script requires administrator privileges.  Please run as admin"
			exit 1
		}
	}
}

function getMockEKCert() {
	echo "ESP32 does not have a dedicated TPM. Generating an empty mock EK certificate..."
	echo "Instead, the SHA-256 checksum of the secure boot v2 RSA-3072 signing key is stored in the certificate."
	
	$cert_params = @{
		Type = 'Custom'
		Subject = 'C=US,O=example.com,OU=mockEK'
		KeyUsage = 'DigitalSignature'
		KeyAlgorithm = 'RSA'
		KeyLength = 2048
		NotAfter = (Get-Date).AddYears(10)
	}
	$cert = New-SelfSignedCertificate @cert_params
	
	$base64_cert = [System.Convert]::ToBase64String($cert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks)
	
	$pem_cert = "-----BEGIN CERTIFICATE-----" + "`r`n" + $base64_cert + "`r`n" + "-----END CERTIFICATE-----"
	$pem_cert | Out-File -FilePath $workspace/ek.pem -Encoding Ascii
    
}

function createComponentListJSON() {
	if (!(Test-Path "$componentlist" -PathType Leaf)) {
		python allcomponents.py
	} else {
		echo "Component file exists, skipping"
	}
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/referenceoptions.ps1
function createPolicyReferenceJSON() {
	if (!(Test-Path "$policyreference" -PathType Leaf)) {
		echo "Creating a Platform policy JSON file"
		powershell -ExecutionPolicy Bypass "$policymaker_script" "$policyreference"
		if (!$?) {
			echo "Failed to create the policy reference, exiting"
			Remove-Item "$policyreference" -Confirm:$false -Force
			exit 1
		}
	} else {
		echo "Policy settings file exists, skipping"
	}
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/otherextensions.ps1
function createExtensionsJSON() {
	if (!(Test-Path "$extsettings" -PathType Leaf)) {
		echo "Creating an extensions JSON file"
		powershell -ExecutionPolicy Bypass "$extensions_script" "$extsettings"
		if (!$?) {
			echo "Failed to create the extensions file, exiting"
			Remove-Item "$extsettings" -Confirm:$false -Force
			exit 1
		}
	} else {
		echo "Extensions file exists, skipping"
	}
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.ps1
function createSigningKeyPair() {
	if (!(Test-Path "$pcsigncert" -PathType Leaf)) {
		echo "Creating a signing key for signing platform credentials"
		$newcert=(New-SelfSignedCertificate -Type Custom -KeyExportPolicy Exportable -Subject "$subjectDN" -KeyUsage DigitalSignature -KeyAlgorithm "$sigalg" -KeyLength "$sigalgbits" -NotAfter "$daysValid" -CertStoreLocation "$certStoreLocation")
		if (!$?) {
			echo "Failed to create the key pair, exiting"
			exit 1
		}
		$passw=ConvertTo-SecureString -String "$pfxpassword" -Force -AsPlainText;
		$certStoreAddress="$certStoreLocation"
		$certStoreAddress+=($newcert.Thumbprint)
		Export-PfxCertificate -Cert "$certStoreAddress" -FilePath "$sigkey" -Password $passw
		if (!$?) {
			echo "Failed to export the PFX file, exiting"
			exit 1
		}
		Export-Certificate  -Cert "$certStoreAddress" -FilePath "$pcsigncert"
		if (!$?) {
			echo "Failed to export the certificate, exiting"
			exit 1
		}
		Get-ChildItem "$certStoreLocation" | Where-Object { $_.Thumbprint -match ($newcert.Thumbprint) } | Remove-Item
	} else {
		echo "Platform Signing file exists, skipping"
	}
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.ps1
function sign() {
	echo "Generating a signed Platform Credential"
	& $signer_bin -x "$extsettings" -c "$componentlist" -e "$ekcert" -p "$policyreference" -k "$sigkey" -N "$serialnumber" -b "$dateNotBefore" -a "$dateNotAfter" -f "$pccert" 
	if (!$?) {
		echo "The signer could not produce a Platform Credential, exiting"
		exit 1
	}
}

# identical to original PACCOR script https://github.com/nsacyber/paccor/blob/main/scripts/windows/pc_certgen.ps1
function validate() {
	echo "Validating the signature"
	& $validator_bin -P "$pcsigncert" -X "$pccert"

	if ($?) {
		echo "PC Credential Creation Complete."
		echo "Platform Credential has been placed in ""$pccert"
	} else {
		Remove-Item "$pccert" -Confirm:$false -Force
		echo "Error with signature validation of the credential."
	}
}


# function calls
extractESPData
createWorkspace
getMockEKCert
createComponentListJSON
createPolicyReferenceJSON
createExtensionsJSON
createSigningKeyPair
sign
validate