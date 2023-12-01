/**
  ******************************************************************************
  * @file    allcomponents.c
  * @author  Thomas Grübl
  * @brief   ESP-Paccor :
  *          - Extract data from an ESP32.
  ******************************************************************************
  * @attention
  *
  * [REF] Parts of the code have been adapted from the ESP example code
  * https://github.com/espressif/esp-idf/tree/master/examples
  *
  * All other parts:
  * Copyright (c) 2023 Thomas Grübl.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  *
  ******************************************************************************
*/

/* Includes ------------------------------------------------------------------*/
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <esp_err.h>

#include "sdkconfig.h"

#include "esp_mac.h"
#include "esp_wifi.h"
#include "esp_eth.h"
#include "esp_wps.h"

#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_bt_device.h"

#include "nvs.h"
#include "nvs_flash.h"

#include "esp_heap_caps.h"
#include "esp_chip_info.h"
#include "esp_flash.h"
#include "esp_ota_ops.h"
#include "bootloader_common.h"
#include "driver/gpio.h"

#define LOG_LOCAL_LEVEL ESP_LOG_INFO
#include "esp_log.h"

#include "allcomponents.h"
/*----------------------------------------------------------------------------*/

void get_base_mac_address()
{
    uint8_t base_mac_addr[6];
    if (esp_efuse_mac_get_default(base_mac_addr) != ESP_OK)
    {
        ESP_LOGE("BASE_MAC", "Failed to get base MAC address from EFUSE BLK0.");
        abort();
    }
    ESP_LOGI("BASE_MAC", "%x:%x:%x:%x:%x:%x",
             base_mac_addr[0],
             base_mac_addr[1],
             base_mac_addr[2],
             base_mac_addr[3],
             base_mac_addr[4],
             base_mac_addr[5]
            );
}

void get_eth_mac_address()
{
    uint8_t eth_mac[6];
    ESP_ERROR_CHECK(esp_read_mac(eth_mac, ESP_MAC_ETH));

    ESP_LOGI("ETH_MAC", "%x:%x:%x:%x:%x:%x",
             eth_mac[0],
             eth_mac[1],
             eth_mac[2],
             eth_mac[3],
             eth_mac[4],
             eth_mac[5]
            );
}

void get_wifi_mac_address()
{
    uint8_t mac[6];

    ESP_ERROR_CHECK(esp_read_mac(mac, ESP_MAC_WIFI_STA));
    ESP_LOGI("WIFI_STA MAC", "%x:%x:%x:%x:%x:%x",
             mac[0],
             mac[1],
             mac[2],
             mac[3],
             mac[4],
             mac[5]
            );
}

void get_bluetooth_address()
{
    uint8_t* btAddress;

    btAddress = esp_bt_dev_get_address();
    if (btAddress == NULL)
    {
        ESP_LOGE("BLUETOOTH", "Failed to get bluetooth MAC address. Bluetooth stack not enabled.");
        abort();
    }

    ESP_LOGI("BLUETOOTH_MAC", "%x:%x:%x:%x:%x:%x",
              btAddress[0],
              btAddress[1],
              btAddress[2],
              btAddress[3],
              btAddress[4],
              btAddress[5]
             );
}

void get_first_partition_info()
{
    const esp_partition_t* partition = esp_partition_find_first(ESP_PARTITION_TYPE_ANY, ESP_PARTITION_SUBTYPE_ANY, NULL);
    if (partition == NULL)
    {
        ESP_LOGI("First partition", "not found.");
    }
    ESP_LOGI("First partition", "Partition size: %lu \n Partition label: %s \n\n",
                partition->size,
                partition->label
            );
}

void get_nvs_stats()
{
    nvs_stats_t nvs_stats;
    ESP_ERROR_CHECK(nvs_get_stats(NULL, &nvs_stats));
    ESP_LOGI("NVS", "Stats: Count: UsedEntries = (%lu), FreeEntries = (%lu), AllEntries = (%lu)\n",
       (long unsigned int)nvs_stats.used_entries, (long unsigned int)nvs_stats.free_entries, (long unsigned int)nvs_stats.total_entries);
}

void get_heap_info()
{
    uint32_t caps = MALLOC_CAP_DEFAULT;
    heap_caps_print_heap_info(caps);
}

esp_chip_info_t get_chip_info()
{
    esp_chip_info_t chip_info;

    esp_chip_info(&chip_info);
    printf("Platform Model: %s ; Chip with %d CPU core(s), %s%s%s%s, ",
           CONFIG_IDF_TARGET,
           chip_info.cores,
           (chip_info.features & CHIP_FEATURE_WIFI_BGN) ? "WiFi/" : "",
           (chip_info.features & CHIP_FEATURE_BT) ? "BT" : "",
           (chip_info.features & CHIP_FEATURE_BLE) ? "BLE" : "",
           (chip_info.features & CHIP_FEATURE_IEEE802154) ? ", 802.15.4 (Zigbee/Thread)" : "");

    unsigned major_rev = chip_info.revision / 100;
    unsigned minor_rev = chip_info.revision % 100;
    printf("silicon revision v%d.%d,\n", major_rev, minor_rev);

    return chip_info;
}

void uint32_to_binary(uint32_t a, char* b) {
    int i;
    for (i = 31; i >= 0; i--) {
        b[31 - i] = (a & (1 << i)) ? '1' : '0';
    }
    b[32] = '\0';
}

void get_flash_info(esp_chip_info_t chip_info)
{
    uint32_t flash_size;
    uint32_t chip_id;
    uint64_t unique_chip_id;
    char binary_chip_id[33];
    unsigned int flash_manufacturer_id;

    ESP_ERROR_CHECK(esp_flash_read_id(NULL, &chip_id));
    ESP_ERROR_CHECK(esp_flash_read_unique_chip_id(NULL, &unique_chip_id));

    uint32_to_binary(chip_id, binary_chip_id);
    char bitmask[9];

    // extract manufacturer ID
    int len = strlen(binary_chip_id);
    int j = 0;
    int i = len - 1;
    while(j < 8)
    {
        bitmask[j] = binary_chip_id[i];
        i--;
        j++;
    }
    flash_manufacturer_id = strtol(bitmask, NULL, 2);

    ESP_LOGI("CHIP_ID", "%" PRIu32 "\n", chip_id);
    ESP_LOGI("UNIQUE_FLASH_CHIP_ID", "%" PRIu64 "\n", unique_chip_id);
    ESP_LOGI("FLASH_MANUFACTURER_ID", "%d\n", flash_manufacturer_id);

    if(esp_flash_get_size(NULL, &flash_size) != ESP_OK) {
        printf("Getting flash size failed");
        return;
    }

    ESP_LOGI("FLASH_SIZE", "%" PRIu32 "MB %s flash\n", flash_size / (uint32_t)(1024 * 1024),
           (chip_info.features & CHIP_FEATURE_EMB_FLASH) ? "embedded" : "external");
    ESP_LOGI("Minimum free heap size", "%" PRIu32 " bytes\n", esp_get_minimum_free_heap_size());
}

void get_wps_factory_info()
{
    wps_type_t wps_type = WPS_TYPE_PIN;
    esp_wps_config_t wps_cfg = WPS_CONFIG_INIT_DEFAULT(wps_type);
    ESP_LOGI("Factory Info", "Manufacturer info: \n");
    ESP_LOGI("Factory Info", "Manufacturer: %s\n", wps_cfg.factory_info.manufacturer);
    ESP_LOGI("Factory Info", "Model Number: %s\n", wps_cfg.factory_info.model_number);
    ESP_LOGI("Factory Info", "Model Name: %s\n", wps_cfg.factory_info.model_name);
    ESP_LOGI("Factory Info", "Device Name: %s\n", wps_cfg.factory_info.device_name);
}

char *get_partition_hash(esp_partition_t *partition)
{
    uint8_t sha_256[32] = {0};
    ESP_ERROR_CHECK(esp_partition_get_sha256(partition, sha_256));
    const size_t hash_len = sizeof(sha_256) * 2;
    char *hash_str = malloc(hash_len + 1);
    char *p_hash = hash_str;
    for (int i = 0; i < sizeof(sha_256); ++i)
    {
        p_hash += sprintf(p_hash, "%.2x", sha_256[i]);
    }
    return hash_str;
}

// NOTE: Reproducible build needs to be enabled in the ESP32 menuconfig (enabled by default in pc_certgen)
void get_firmware_hash()
{
    esp_partition_t *partition = (esp_partition_t *)esp_ota_get_running_partition();
    if (partition != NULL)
    {
        char *hash_str = get_partition_hash(partition);
        ESP_LOGI("Firmware partition SHA256 checksum", "%s\n", hash_str);
    }
}

// NOTE: Reproducible build needs to be enabled in the ESP32 menuconfig (enabled by default in pc_certgen)
void get_bootloader_hash()
{
    uint8_t sha_256[32] = {0};
    uint32_t address = 0x1000;
    printf("part table offset %x\n", CONFIG_PARTITION_TABLE_OFFSET);
    uint32_t size = 0x7000;
    ESP_ERROR_CHECK(bootloader_common_get_sha256_of_partition(address, size, 1, sha_256));

    const size_t hash_len = sizeof(sha_256) * 2;
    char *hash_str = malloc(hash_len + 1);
    char *p_hash = hash_str;
    for (int i = 0; i < sizeof(sha_256); ++i)
    {
        p_hash += sprintf(p_hash, "%.2x", sha_256[i]);
    }
    ESP_LOGI("Bootloader partition SHA256 checksum", "%s\n", hash_str);
}

// NOTE: Reproducible build needs to be enabled in the ESP32 menuconfig (enabled by default in pc_certgen)
void get_elf_hash()
{
    char elf_hash[32] = {0};
    size_t size = sizeof(elf_hash);
    esp_app_get_elf_sha256(elf_hash, size);
    ESP_LOGI("ELF SHA256 checksum", "%s\n", elf_hash);
}

void get_gpio_info()
{
    ESP_LOGI("GPIO PIN COUNT", "%d\n", GPIO_PIN_COUNT);
    printf("GPIO VALID PINS: ");
    for (int i = 0; i < GPIO_PIN_COUNT; ++i)
    {
        printf("%d", GPIO_IS_VALID_GPIO(i));
        if (i != (GPIO_PIN_COUNT - 1))
        {
            printf(", ");
        }
    }
    printf("\n");
    printf("GPIO PIN LEVELS: ");
    for (int i = 0; i < GPIO_PIN_COUNT; ++i)
    {
        printf("%d", gpio_get_level(i));
        if (i != (GPIO_PIN_COUNT - 1))
        {
            printf(", ");
        }
    }
    printf("\n");
}
