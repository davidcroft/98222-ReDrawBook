/*
 * CapitiveSense Library Demo Sketch
 * Paul Badger 2008
 * Uses a high value resistor e.g. 10 megohm between send pin and receive pin
 * Resistor effects sensitivity, experiment with values, 50 kilohm - 50 megohm. Larger resistor values yield larger sensor values.
 * Receive pin is the sensor pin - try different amounts of foil/metal on this pin
 * Best results are obtained if sensor foil and wire is covered with an insulator such as paper or plastic sheet
 */

#include <CapacitiveSensor.h>
#include <SPI.h>
#include "Adafruit_BLE_UART.h"

// bluetooth
#define ADAFRUITBLE_REQ 10
#define ADAFRUITBLE_RDY 2
#define ADAFRUITBLE_RST 9
Adafruit_BLE_UART uart = Adafruit_BLE_UART(ADAFRUITBLE_REQ, ADAFRUITBLE_RDY, ADAFRUITBLE_RST);

// cap sensing
#define NUM_CAPSENSOR 5
#define SENVAL_COUNT 16
#define SENSING_THRESHOLD 200
#define SENSING_DELTA_THRESHOLD 10

int portPinList[] = {5, 6, 7, 8, A0, A1, A2, A3};
const int portPinCap = 4;
CapacitiveSensor   cs_p[] = {CapacitiveSensor(portPinCap,portPinList[0]), 
                             CapacitiveSensor(portPinCap,portPinList[1]),
                             CapacitiveSensor(portPinCap,portPinList[2]),
                             CapacitiveSensor(portPinCap,portPinList[3]), 
                             CapacitiveSensor(portPinCap,portPinList[4])
                             };

long senValAvg[NUM_CAPSENSOR];
long senValCnt;

//long curPage;

// Invoked whenever select ACI events happen
void aciCallback(aci_evt_opcode_t event)
{
  switch(event)
  {
    case ACI_EVT_DEVICE_STARTED:
      Serial.println(F("Advertising started"));
      break;
    case ACI_EVT_CONNECTED:
      Serial.println(F("Connected!"));
      break;
    case ACI_EVT_DISCONNECTED:
      Serial.println(F("Disconnected or advertising timed out"));
      break;
    default:
      break;
  }
}

// Invoked whenever data arrives on the RX channel
void rxCallback(uint8_t *buffer, uint8_t len)
{
  Serial.print(F("Received "));
  Serial.print(len);
  Serial.print(F(" bytes: "));
  for(int i=0; i<len; i++)
   Serial.print((char)buffer[i]); 

  Serial.print(F(" ["));

  for(int i=0; i<len; i++)
  {
    Serial.print(" 0x"); Serial.print((char)buffer[i], HEX); 
  }
  Serial.println(F(" ]"));

  /* Echo the same data back! */
  //uart.write(buffer, len);
}

void setup()                    
{  
  // set parameters of capacitive sensors
  int i=0;
  while(i<NUM_CAPSENSOR) {
    cs_p[i].set_CS_AutocaL_Millis(0xFFFFFFFF);     // turn off autocalibrate on channel 1 - just as an example
    i++;
  }

  // set serial port 
  Serial.begin(9600);
  while(!Serial);
  Serial.println("init finished.");
  
  // iniialize sensor val array and counter
  i = 0;
  while(i<NUM_CAPSENSOR) {
    senValAvg[i] = 0;
    i++;
  }
  senValCnt = SENVAL_COUNT;
  
  // init bluetooth
  uart.setRXcallback(rxCallback);
  uart.setACIcallback(aciCallback);
  uart.setDeviceName("reDraw1"); /* 7 characters max! */
  uart.begin();
}

void loop()
{
  // bluetooth update (very important)
  uart.pollACI();
  
  // cap sensing
  long start = millis();
  long val;
    
  int i=0;
  while(i<NUM_CAPSENSOR) {
    // get current sensing val and calculate the average
    val = cs_p[i].capacitiveSensor(30);
    //Serial.println(senValCnt);
    senValAvg[i] += val;
   i++;
  }
    
  senValCnt--;
  if (senValCnt <= 0) {
    // calculate the average of sensing val
    int i = 0;
    while(i<NUM_CAPSENSOR) {
      senValAvg[i] = senValAvg[i]/SENVAL_COUNT;
      i++;
    }
      
    // find the index with the max average val
    i = 0;
    int maxIndex = 0;
    while (i<NUM_CAPSENSOR) {
      if (senValAvg[i] > senValAvg[maxIndex]) {
        maxIndex = i;
      }
      i++;
    }
    // find the second max average val
    i = 0;
    int secMaxIndex = 0;
    int tmp = senValAvg[maxIndex];
    senValAvg[maxIndex] = 0;
    while (i<NUM_CAPSENSOR) {
      if (senValAvg[i] > senValAvg[secMaxIndex]) {
        secMaxIndex = i;
      }
      i++;
    }
    senValAvg[maxIndex] = tmp;  // restore max value
      
    // send a message after connected
    // Ask what is our current status
    aci_evt_opcode_t status = uart.getState();
    if (status == ACI_EVT_CONNECTED) {
      uint8_t sendBuf[7];
      sendBuf[0] = '@';
      sendBuf[1] = 'p';
      sendBuf[2] = 'a';
      sendBuf[3] = 'g';
      sendBuf[4] = 'e';
      sendBuf[5] = ':';
      if ((senValAvg[maxIndex] > SENSING_THRESHOLD) && (senValAvg[maxIndex]-senValAvg[secMaxIndex]>SENSING_DELTA_THRESHOLD)) {
        sendBuf[6]  = '0' + maxIndex+1;
        Serial.print("@page:");
        Serial.print(maxIndex+1);
        Serial.println("#");
        //Serial.print("\t");
        //Serial.println(senValAvg[maxIndex]);
      }
      else {
        sendBuf[6]  = '0';
        Serial.println("@page:0#");
      }
      uart.write(sendBuf, 7);
    }

    // reset senValCnt and senValVal array
    i=0;
    while(i<NUM_CAPSENSOR) {
      senValAvg[i] = 0;
      i++;
    }
    senValCnt = SENVAL_COUNT;    
  }  
  delay(20);                             // arbitrary delay to limit data to serial port 
}

