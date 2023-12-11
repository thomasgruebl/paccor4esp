/**
  ******************************************************************************
  * @file    main.c
  * @author  Thomas Grübl
  * @brief   ESP-Paccor
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
#include "conf.c"
#include "allcomponents.c"
/*----------------------------------------------------------------------------*/

void app_main(void)
{
    // nvs info
    init_nvs();
    get_first_partition_info();
    get_nvs_stats();

    // base mac address
    get_base_mac_address();

    // ethernet mac address
    get_eth_mac_address();

    // wifi
    init_wifi();
    get_wifi_mac_address();

    // bluetooth
    init_bluetooth();
    get_bluetooth_address();

    // chip info
    esp_chip_info_t chip_info = get_chip_info();

    // flash info
    get_flash_info(chip_info);

    // partition hashes
    get_firmware_hash();
    get_bootloader_hash();
    get_elf_hash();

    // gpio pins
    get_gpio_info();

    // wps factory info
    get_wps_factory_info();

    // read Secure Boot V2 RSA-PSS SHA-256 digest of the public key from eFuse BLK2
    get_efuse_key_block_hash();

    get_heap_info();

    /*while(1)
    {
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }*/
}
