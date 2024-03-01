'''
  ******************************************************************************
  * @file    allcomponents.py
  * @author  Thomas Grübl
  * @brief   paccor4esp:
             - This script parses the ESP logdump and generates the componentlist JSON file
             - Replaces the functionality of https://github.com/nsacyber/paccor/blob/main/scripts/allcomponents.sh
             - and https://github.com/nsacyber/paccor/blob/main/scripts/windows/allcomponents.ps1
             - for the ESP32 use case
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2024 Thomas Grübl.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  *
  ******************************************************************************
'''

import json
import os
import logging
import re
from re import Pattern

logging.basicConfig(
    format='%(asctime)s %(levelname)-8s %(message)s',
    filename='python.log',
    encoding='utf-8',
    datefmt='%m/%d/%Y %I:%M:%S %p',
    level=logging.DEBUG)

LOG_FILE = "esp_logfile.txt"

# User customizable values
PLATFORMMANUFACTURER = "Espressif"

# ComponentClass values
# https://trustedcomputinggroup.org/wp-content/uploads/draft_TCG_Component_Class_Registry_v1.0_rev11_11October22.pdf
COMPCLASS_REGISTRY_TCG="2.23.133.18.3.1"

COMPCLASS_EMBEDDED_PROCESSOR = "00010008"
COMPCLASS_FLASH = "0006000A"
COMPCLASS_NIC = "00090000"
COMPCLASS_WIFI_ADAPTER = "00090003"
COMPCLASS_BLUETOOTH_ADAPTER = "00090004"
COMPCLASS_FIRMWARE = "00130003"
COMPCLASS_BOOTLOADER = "00130005"
COMPCLASS_GPIO = "000E0000"
COMPCLASS_ELF = "00130000"
COMPCLASS_EFUSE = "00130000"


def match_patterns(patterns: list[Pattern[str]], log_file: str) -> list[str]:
    """
    Performs REGEX pattern matching on the log file.

    Parameters
    ---------
    :param patterns: A list of regex patterns.
    :type patterns: list[Pattern[str]]
    :param log_file: The ESP log file in string format, containing all device data
    :type  log_file: str

    Returns
    -------
    :return data: Regex search matches.
    :rtype data: list[str]
    """

    data = list()
    for pattern in patterns:
        match = re.search(pattern, log_file)
        if match is not None:
            print(match.group())
            data.append(match.group())
        else:
            print("Not Specified")
            data.append('Not Specified')

    return data


def parse_log_file(log_file: str) -> dict[str, list[any]]:
    """
    Parses log file that contains the platform snapshot of the embedded device.

    Parameters
    ---------
    :param log_file: The ESP log file in string format, containing all device data
    :type log_file: str

    Returns
    -------
    :return all_data: A dictionary containing info about the platform, cpu, storage, network interfaces, ...
    :rtype all_data: dict[str, list[any]]
    """

    all_data = dict()

    regex_patterns_platform = [
        re.compile(r'(?<=Model Number: )(.*)'),                                 # Platform model
        re.compile(r'(?<=silicon revision )(.*)(?=,)'),                         # Platform version
        re.compile(r'(?<=BASE_MAC: )([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})')   # Platform serial
    ]

    regex_patterns_cpu = [
        re.compile(r'(?<=--toolchain-prefix )([^-]*)'),     # Manufacturer
        re.compile(r'(?<=Chip with )([^,]*)'),              # Model (cores)
        re.compile(r'(?<=cpu freq: )(.*)(?= Hz)'),          # Model (frequency)
        re.compile(r'(?<=CHIP_ID: )(.*)'),                  # Serial
        re.compile(r'(?<=silicon revision )(.*)(?=,)')      # Revision
    ]

    regex_patterns_flash = [
        re.compile(r'(?<=FLASH_MANUFACTURER_ID: )(.*)'),    # Manufacturer
        re.compile(r'(?<=FLASH_SIZE: )(.*)'),               # Model (flash size)
        re.compile(r'(?<=UNIQUE_FLASH_CHIP_ID: )(.*)')      # Serial
    ]

    regex_patterns_ethernet = [
        re.compile(r'(?<=Manufacturer: )(.*)'),             # Manufacturer
        re.compile(r'(?<=phy_version )(\d+,([^,]+))'),      # Model PHY version hash
        re.compile(r'(?<=ETH_MAC: )([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'), # Serial
        re.compile(r'(?<=phy_version )([^,]*)'),            # Revision -> PHY version num
    ]

    regex_patterns_wifi = [
        re.compile(r'(?<=Manufacturer: )(.*)'),                     # Manufacturer
        re.compile(r'(?<=wifi:wifi firmware version: )(.*)'),       # Model firmware version hash
        re.compile(r'(?<=WIFI_STA MAC: )([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'),  # Serial
        re.compile(r'(?<=wifi:wifi certification version:)(.*)'),  # Revision -> Certification version num
    ]

    regex_patterns_bluetooth = [
        re.compile(r'(?<=Manufacturer: )(.*)'),                         # Manufacturer
        re.compile(r'(?<=BT controller compile version \[)([^\]]*)'),   # BT compile version hash
        re.compile(r'(?<=BLUETOOTH_MAC: )([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'),  # Serial
    ]

    regex_patterns_firmware = [
        re.compile(r'(?<=Firmware partition SHA256 checksum: )(.*)')    # Serial
    ]

    regex_patterns_bootloader = [
        re.compile(r'(?<=Bootloader partition SHA256 checksum: )(.*)')  # Serial
    ]

    # ELF -> Executable and Linking Format hash
    regex_patterns_elf = [
        re.compile(r'(?<=ELF SHA256 checksum: )(.*)')                   # Serial
    ]

    # contains Secure Boot V2 RSA-PSS SHA-256 digest of the public key from eFuse BLK2
    regex_patterns_efuse = [
        re.compile(r'(?<=RSA-PSS SHA-256 checksum: )(.*)')              # Serial
    ]

    regex_patterns_gpio = [
        # The model field contains the bit array showing which GPIO pins are valid/invalid.
        re.compile(r'(?<=GPIO VALID PINS: )(.*)'),
        # The serial field contains the bit array showing the GPIO input levels.
        re.compile(r'(?<=GPIO PIN LEVELS: )(.*)')
    ]

    platform_data = match_patterns(regex_patterns_platform, log_file)
    cpu_data = match_patterns(regex_patterns_cpu, log_file)
    flash_data = match_patterns(regex_patterns_flash, log_file)
    ethernet_data = match_patterns(regex_patterns_ethernet, log_file)
    wifi_data = match_patterns(regex_patterns_wifi, log_file)
    bluetooth_data = match_patterns(regex_patterns_bluetooth, log_file)
    firmware_data = match_patterns(regex_patterns_firmware, log_file)
    bootloader_data = match_patterns(regex_patterns_bootloader, log_file)
    gpio_data = match_patterns(regex_patterns_gpio, log_file)
    elf_data = match_patterns(regex_patterns_elf, log_file)
    efuse_data = match_patterns(regex_patterns_efuse, log_file)

    # search match modifications
    cpu_data[1] = cpu_data[1] + ' ' + cpu_data[2] + ' Hz'
    del cpu_data[2]
    cpu_data.append("false")            # Fieldreplacable

    flash_data.append("Not defined")    # Revision
    flash_data.append("false")          # Fieldreplacable

    ethernet_data.append("true")        # Fieldreplacable
    ethernet_data.append(ethernet_data[2]) # ETHERNETMAC
    ethernet_data[1] = ethernet_data[1].split(",")[1]  # Revision

    wifi_data.append("true")            # Fieldreplacable
    wifi_data.append(wifi_data[2])      # WLANMAC

    bluetooth_data.append("Not defined") # Revision
    bluetooth_data.append("false")      # Fieldreplacable
    bluetooth_data.append(bluetooth_data[2])  # BLUETOOTHMAC

    firmware_data.insert(0, 'Not Specified')
    firmware_data.insert(0, 'Not Specified')

    bootloader_data.insert(0, 'Not Specified')
    bootloader_data.insert(0, 'Not Specified')

    elf_data.insert(0, 'Not Specified')
    elf_data.insert(0, 'Not Specified')

    efuse_data.insert(0, 'Not Specified')
    efuse_data.insert(0, 'Not Specified')

    gpio_data.insert(0, 'Not Specified')

    all_data['PLATFORM'] = platform_data
    all_data['CPU'] = cpu_data
    all_data['FLASH'] = flash_data
    all_data['ETHERNET'] = ethernet_data
    all_data['WIFI'] = wifi_data
    all_data['BLUETOOTH'] = bluetooth_data
    all_data['FIRMWARE'] = firmware_data
    all_data['BOOTLOADER'] = bootloader_data
    all_data['ELF'] = elf_data
    all_data['EFUSE'] = efuse_data
    all_data['GPIO'] = gpio_data

    return all_data


def generate_json_platform(data: list[str]) -> dict[str, dict[str, str]]:
    """
    Generates the JSON platform template
    (including the manufacturer string, model, version and serial number)

    Parameters
    ---------
    :param data: A list of platform-related data.
    :type data: list[str]

    Returns
    -------
    :return json_platform_template: A dictionary containing platform-related information.
    :rtype json_platform_template: dict[str, dict[str, str]]
    """
    json_platform_template = {
        "PLATFORM": {
            "PLATFORMMANUFACTURERSTR": PLATFORMMANUFACTURER,  # hardcoded
            "PLATFORMMODEL": data[0],
            "PLATFORMVERSION": data[1],
            "PLATFORMSERIAL": data[2]
        }
    }

    return json_platform_template


def generate_json_component(fields: dict[str, str], compclassvalue: str) -> dict[any]:
    """
    Generates the components JSON object containing information about the COMPONENTCLASSREGISTRY,
    COMPONENTCLASSVALUE, MANUFACTURER, MODEL, SERIAL, REVISION, ...

    Parameters
    ---------
    :param fields: Relevant fields to be included depending on the component type.
    :type fields: dict[str, str]
    :param compclassvalue: The component class value based on TCG Component Class Registry Version 1.0 Revision 11
                            September 21, 2022.
    :type compclassvalue: str

    Returns
    -------
    :return json_component_template: The JSON object containing the component parameters.
    :rtype json_component_template: dict[any]
    """

    json_component_template = {
        "COMPONENTCLASS": {
            "COMPONENTCLASSREGISTRY": COMPCLASS_REGISTRY_TCG,  # hardcoded
            "COMPONENTCLASSVALUE": compclassvalue
        },
    }

    for k, v in fields.items():
        if k == 'ETHERNETMAC':
            json_component_template.update({"ADDRESSES": [{
                "ETHERNETMAC": f"{v}"}]})
        elif k == 'WLANMAC':
            json_component_template.update({"ADDRESSES": [{
                "WLANMAC": f"{v}"}]})
        elif k == 'BLUETOOTHMAC':
            json_component_template.update({"ADDRESSES": [{
                "BLUETOOTHMAC": f"{v}"}]})
        else:
            json_component_template.update({f"{k}": f"{v}"})

    return json_component_template


def generate_json_property() -> dict[str, str]:
    """
    Generates the (optional) platform properties JSON object, which may contain
    characteristics of the platform that the issuer considers of interest to the consumer.

    Parameters
    ---------

    Returns
    -------
    :return json_property_template: The JSON object, containing the property name and value.
    :rtype json_property_template: dict[str, str]
    """

    json_property_template = {
        "PROPERTYNAME": "test",
        "PROPERTYVALUE": "test"
    }

    return json_property_template


def construct_final_json(all_data: dict[str, list[str]]) -> str:
    """
    Merges the PLATFORM, COMPONENTS, PROPERTIES JSON objects.

    Parameters
    ---------
    :param all_data: Contains all the component information sorted by type (e.g. CPU, RAM, ...).
    :type all_data: dict[str, list[str]]

    Returns
    -------
    :return final_json: The final JSON object, filled with the platform, component and property parameters.
    :rtype final_json: str
    """

    json_keywords_cpu = ['MANUFACTURER', 'MODEL', 'SERIAL', 'REVISION', 'FIELDREPLACEABLE']
    json_keywords_flash = ['MANUFACTURER', 'MODEL', 'SERIAL', 'FIELDREPLACEABLE']
    json_keywords_ethernet = ['MANUFACTURER', 'MODEL', 'SERIAL', 'REVISION', 'FIELDREPLACEABLE', 'ETHERNETMAC']
    json_keywords_wifi = ['MANUFACTURER', 'MODEL', 'SERIAL', 'REVISION', 'FIELDREPLACEABLE', 'WLANMAC']
    json_keywords_bluetooth = ['MANUFACTURER', 'MODEL', 'SERIAL', 'REVISION', 'FIELDREPLACEABLE', 'BLUETOOTHMAC']
    json_keywords_firmware = ['MANUFACTURER', 'MODEL', 'SERIAL']
    json_keywords_bootloader = ['MANUFACTURER', 'MODEL', 'SERIAL']
    json_keywords_elf = ['MANUFACTURER', 'MODEL', 'SERIAL']
    json_keywords_efuse = ['MANUFACTURER', 'MODEL', 'SERIAL']
    json_keywords_gpio = ['MANUFACTURER', 'MODEL', 'SERIAL']

    cpu_fields = dict(zip(json_keywords_cpu, all_data['CPU']))
    flash_fields = dict(zip(json_keywords_flash, all_data['FLASH']))
    ethernet_fields = dict(zip(json_keywords_ethernet, all_data['ETHERNET']))
    wifi_fields = dict(zip(json_keywords_wifi, all_data['WIFI']))
    bluetooth_fields = dict(zip(json_keywords_bluetooth, all_data['BLUETOOTH']))
    firmware_fields = dict(zip(json_keywords_firmware, all_data['FIRMWARE']))
    bootloader_fields = dict(zip(json_keywords_bootloader, all_data['BOOTLOADER']))
    elf_fields = dict(zip(json_keywords_elf, all_data['ELF']))
    efuse_fields = dict(zip(json_keywords_efuse, all_data['EFUSE']))
    gpio_fields = dict(zip(json_keywords_gpio, all_data['GPIO']))

    json_dict = dict()
    json_dict.update(generate_json_platform(all_data['PLATFORM']))

    json_component_array = {
        "COMPONENTS": [
            generate_json_component(fields=cpu_fields, compclassvalue=COMPCLASS_EMBEDDED_PROCESSOR),
            generate_json_component(fields=flash_fields, compclassvalue=COMPCLASS_FLASH),
            generate_json_component(fields=ethernet_fields, compclassvalue=COMPCLASS_NIC),
            generate_json_component(fields=wifi_fields, compclassvalue=COMPCLASS_WIFI_ADAPTER),
            generate_json_component(fields=bluetooth_fields, compclassvalue=COMPCLASS_BLUETOOTH_ADAPTER),
            generate_json_component(fields=firmware_fields, compclassvalue=COMPCLASS_FIRMWARE),
            generate_json_component(fields=bootloader_fields, compclassvalue=COMPCLASS_BOOTLOADER),
            generate_json_component(fields=elf_fields, compclassvalue=COMPCLASS_ELF),
            generate_json_component(fields=efuse_fields, compclassvalue=COMPCLASS_EFUSE),
            generate_json_component(fields=gpio_fields, compclassvalue=COMPCLASS_GPIO)
        ]
    }

    json_property_array = {
        "PROPERTIES": [
            generate_json_property()
        ]
    }

    json_dict.update(json_component_array)
    json_dict.update(json_property_array)

    final_json = json.dumps(json_dict, indent=4)

    return final_json


if __name__ == "__main__":
    if os.path.isfile(LOG_FILE):
        if os.name == 'nt':
            with open(LOG_FILE, 'r', encoding="utf-16") as f:
                log_file = f.read()
        else:
            with open(LOG_FILE, 'r', encoding="utf-8") as f:
                log_file = f.read()
    else:
        logging.error('Log file containing platform snapshot not found.')
        raise FileNotFoundError('Log file containing platform snapshot not found.')

    all_data = parse_log_file(log_file)
    json_object = construct_final_json(all_data)

    with open("pc_testgen/localhost-componentlist.json", "w") as outfile:
        outfile.write(json_object)
