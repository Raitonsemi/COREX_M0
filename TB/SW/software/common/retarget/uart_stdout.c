/*
 *-----------------------------------------------------------------------------
 * The confidential and proprietary information contained in this file may
 * only be used by a person authorised under and to the extent permitted
 * by a subsisting licensing agreement from Arm Limited or its affiliates.
 *
 *            (C) COPYRIGHT 2010-2013 Arm Limited or its affiliates.
 *                ALL RIGHTS RESERVED
 *
 * This entire notice must be reproduced on all copies of this file
 * and copies of this file may only be made by a person if such person is
 * permitted to do so under the terms of a subsisting license agreement
 * from Arm Limited or its affiliates.
 *
 *      SVN Information
 *
 *      Checked In          : $Date: 2017-10-10 15:55:38 +0100 (Tue, 10 Oct 2017) $
 *
 *      Revision            : $Revision: 371321 $
 *
 *      Release Information : Cortex-M System Design Kit-r1p1-00rel0
 *-----------------------------------------------------------------------------
 */

 /*

 UART functions for retargetting

 */
#ifdef CORTEX_M0
#include "CMSDK_CM0.h"
#endif

#ifdef CORTEX_M0PLUS
#include "CMSDK_CM0plus.h"
#endif

#ifdef CORTEX_M3
#include "CMSDK_CM3.h"
#endif

#ifdef CORTEX_M4
#include "CMSDK_CM4.h"
#endif

// Initialize UART0 (fixed baud, TX only)
void UartStdOutInit(void)
{
    // Your UART has a fixed baud rate (set in RTL)
    // CTRL register not implemented, so this is optional and harmless
    CMSDK_UART0->CTRL = 0x01;  // TX enable (if CTRL register exists)
    return;
}

// Transmit one character
unsigned char UartPutc(unsigned char my_ch)
{
    // Wait if TX FIFO is full (bit0 = tx_full)
    while (CMSDK_UART0->STATE & 1);
    CMSDK_UART0->DATA = my_ch;
    return my_ch;
}

// Receive one character (blocking)
unsigned char UartGetc(void)
{
    // Wait while RX FIFO is empty (bit1 = rx_empty in your design)
    while (CMSDK_UART0->STATE & 2);   // bit1=1 means empty, so wait
    return CMSDK_UART0->DATA;
}

// End-of-simulation helper (optional)
void UartEndSimulation(void)
{
    UartPutc((char)0x04); // Send EOT
    while (1);
}


