/**
  ******************************************************************************
  * @file    allcomponents.h
  * @author  Thomas Grübl
  * @brief   Header for allcomponents.c module
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
*/


/**
  * @brief  Get base MAC address which is factory-programmed by Espressif in EFUSE.
  * @param  -
  * @retval -
*/
void get_base_mac_address(void);

/**
  * @brief  Get ethernet MAC address which can be derived from the base MAC.
  * @param  -
  * @retval -
*/
void get_eth_mac_address(void);

/**
  * @brief  Get wifi MAC address which can be derived from the base MAC.
  * @param  -
  * @retval -
*/
void get_wifi_mac_address(void);

/**
  * @brief  Get bluetooth MAC address which can be derived from the base MAC.
  * @param  -
  * @retval -
*/
void get_bluetooth_address(void);

/**
  * @brief  Get the size and label of the first partition.
  * @param  -
  * @retval -
*/
void get_first_partition_info(void);

/**
  * @brief  Get information about the used entries and free entries of the Non-Volatile Storage (NVS).
  * @param  -
  * @retval -
*/
void get_nvs_stats(void);

/**
  * @brief  Get summary of heap allocations.
  * @param  -
  * @retval -
*/
void get_heap_info(void);

/**
  * @brief  Get information about the chip features.
  * @param  -
  * @retval esp_chip_info_t - chip info struct containing CPU, wifi, bluetooth, revision information.
*/
esp_chip_info_t get_chip_info(void);

/**
  * @brief  uint32 to binary char array.
  * @param  a   uint32_t - input number
  * @param  b   char* - output binary string
  * @retval -
*/
void uint32_to_binary(uint32_t a, char* b);

/**
  * @brief  Get information about the flash storage, such as flash manufacturer ID and flash size.
  * @param  chip_info  esp_chip_info_t - chip info struct containing CPU, wifi, bluetooth, revision information.
  * @retval -
*/
void get_flash_info(esp_chip_info_t chip_info);

/**
  * @brief  Get WPS factory info (manufacturer, model number, model name, device name)
  * @param  -
  * @retval -
*/
void get_wps_factory_info(void);

/**
  * @brief  Compute SHA-256 checksum of a partition.
  * @param  partition - esp_partition_t* - pointer to the esp_partition struct.
  * @retval char* - Hash string
*/
char *get_partition_hash(esp_partition_t *partition);

/**
  * @brief  Compute SHA-256 checksum of firmware partition (calls get_partition_hash()).
  * @param  -
  * @retval -
*/
void get_firmware_hash(void);

/**
  * @brief  Compute SHA-256 checksum of bootloader partition (calls bootloader_common_get_sha256_of_partition()).
  * @param  -
  * @retval -
*/
void get_bootloader_hash(void);

/**
  * @brief  Compute SHA-256 checksum of Executable and Linkable Format (ELF) file (calls esp_app_get_elf_sha256()).
  * @param  -
  * @retval -
*/
void get_elf_hash(void);

/**
  * @brief Extracts the contents of EFUSE_BLK2. EFUSE_BLK2 is used for storing the SHA-256 digest of the public key.
        SHA-256 hash of public key modulus, exponent, pre-calculated R & M' values (represented as 776 bytes –
        offsets 36 to 812 - as per the Signature Block Format). RSA-3072.
  * @param  -
  * @retval -
*/
void get_efuse_key_block_hash(void);

/**
  * @brief  First bit array corresponds to valid pins 0->invalid, 1->valid. Second bit array corresponds to
   current input level of the GPIO pins 0->low, 1->high.
  * @param  -
  * @retval -
*/
void get_gpio_info(void);
