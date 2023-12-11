/**
  ******************************************************************************
  * @file    conf.h
  * @author  Thomas Grübl
  * @brief   Header for conf.c module
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2023 Thomas Grübl.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  *
  ******************************************************************************
*/


/**
  * @brief  Initialize Non-Volatile Storage (NVS). Remove if initialization is performed in different
    part of the project.
  * @param  -
  * @retval -
*/
void init_nvs(void);

/**
  * @brief  Initialize WiFi with the default config. Remove if initialization is performed in different
    part of the project.
  * @param  -
  * @retval -
*/
void init_wifi(void);

/**
  * @brief  Initialize Bluetooth with the default config. Remove if initialization is performed in different
    part of the project.
  * @param  -
  * @retval -
*/
void init_bluetooth(void);