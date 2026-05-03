/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   This file contains the common defines of the application.
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32g0xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define LED0_Pin GPIO_PIN_13
#define LED0_GPIO_Port GPIOC
#define LED1_Pin GPIO_PIN_14
#define LED1_GPIO_Port GPIOC
#define LED2_Pin GPIO_PIN_15
#define LED2_GPIO_Port GPIOC
#define X0_Pin GPIO_PIN_0
#define X0_GPIO_Port GPIOA
#define X1_Pin GPIO_PIN_1
#define X1_GPIO_Port GPIOA
#define X2_Pin GPIO_PIN_2
#define X2_GPIO_Port GPIOA
#define X3_Pin GPIO_PIN_3
#define X3_GPIO_Port GPIOA
#define X4_Pin GPIO_PIN_4
#define X4_GPIO_Port GPIOA
#define X5_Pin GPIO_PIN_5
#define X5_GPIO_Port GPIOA
#define X6_Pin GPIO_PIN_6
#define X6_GPIO_Port GPIOA
#define X7_Pin GPIO_PIN_7
#define X7_GPIO_Port GPIOA
#define Y0_Pin GPIO_PIN_0
#define Y0_GPIO_Port GPIOB
#define Y1_Pin GPIO_PIN_1
#define Y1_GPIO_Port GPIOB
#define Y2_Pin GPIO_PIN_2
#define Y2_GPIO_Port GPIOB
#define Y10_Pin GPIO_PIN_10
#define Y10_GPIO_Port GPIOB
#define MENU_Pin GPIO_PIN_0
#define MENU_GPIO_Port GPIOD
#define Y3_Pin GPIO_PIN_3
#define Y3_GPIO_Port GPIOB
#define Y4_Pin GPIO_PIN_4
#define Y4_GPIO_Port GPIOB
#define Y5_Pin GPIO_PIN_5
#define Y5_GPIO_Port GPIOB
#define Y6_Pin GPIO_PIN_6
#define Y6_GPIO_Port GPIOB
#define Y7_Pin GPIO_PIN_7
#define Y7_GPIO_Port GPIOB
#define Y8_Pin GPIO_PIN_8
#define Y8_GPIO_Port GPIOB
#define Y9_Pin GPIO_PIN_9
#define Y9_GPIO_Port GPIOB

/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
