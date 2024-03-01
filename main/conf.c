/**
  ******************************************************************************
  * @file    conf.c
  * @author  Thomas Grübl
  * @brief   paccor4esp:
  *          - This file initializes the NVS, WiFi and Bluetooth.
  *          - Can be deleted/amended if you initialize NVS, WiFi or Bluetooth with
  *            different configuration elsewhere in your project.
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

/* Includes ------------------------------------------------------------------*/
#include <esp_err.h>

#include "esp_wifi.h"

#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_bt_device.h"

#include "nvs.h"
#include "nvs_flash.h"

#include "conf.h"
/*----------------------------------------------------------------------------*/

void init_nvs()
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND ||
        ret == ESP_ERR_NOT_FOUND || ret == ESP_ERR_NO_MEM)
    {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
}

void init_wifi()
{
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();

    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
}

void init_bluetooth()
{
    esp_bt_controller_config_t cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    esp_bt_mode_t mode = ESP_BT_MODE_BLE;

    ESP_ERROR_CHECK(esp_bt_controller_init(&cfg));
    ESP_ERROR_CHECK(esp_bt_controller_enable(mode));
    ESP_ERROR_CHECK(esp_bluedroid_init());
    ESP_ERROR_CHECK(esp_bluedroid_enable());
}

