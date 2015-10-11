#include <Servo.h>
#include <avr/wdt.h>
/*
  Serial Call and Response
 Language: Wiring/Arduino
 
 This program sends an ASCII A (byte of value 65) on startup
 and repeats that until it gets some data in.
 Then it waits for a byte in the serial port, and 
 sends three sensor values whenever it gets a byte in.
 
 Thanks to Greg Shakar and Scott Fitzgerald for the improvements
 
 The circuit:
 * potentiometers attached to analog inputs 0 and 1 
 * pushbutton attached to digital I/O 2
 
 Created 26 Sept. 2005
 by Tom Igoe
 modified 30 Aug 2011
 by Tom Igoe and Scott Fitzgerald
 
 This example code is in the public domain.
 
 http://www.arduino.cc/en/Tutorial/SerialCallResponse
 
 */

Servo left;
Servo right;
Servo gun;

void setup()
{
  //wdt_enable(WDTO_250MS);
  // start serial port at 9600 bps:
  Serial.begin(57600);
  left.attach(12);
  right.attach(11);
  gun.attach(10);
  pinMode(13,OUTPUT);
  pinMode(3,OUTPUT);
  pinMode(2,OUTPUT);
  digitalWrite(2, LOW);
  Serial.write(1);
  //establishContact();  // send a byte to establish contact until receiver responds 
}

void loop()
{
  // if we get a valid byte, read analog ins:

  if (Serial.available() > 0) {

    // get incoming byte:
    char charCommands[12] ;
    Serial.readBytesUntil('\n',charCommands,12);
    Serial.flush();
    String commands = String(charCommands);
    int leftVal = commands.substring(0,4).toInt();
    int rightVal = commands.substring(4,8).toInt();
    int gunVal = commands.substring(8,12).toInt();
    //Serial.println(leftVal);
    //Serial.println(rightVal);
    //Serial.println(gunVal);

    left.write(leftVal);
    right.write(rightVal);
    gun.write(gunVal);
    //wdt_reset();
  }
  
    if (millis()%1000 < 500){
      digitalWrite(3, HIGH);
    }
    else{
      digitalWrite(3, LOW);
    }

  Serial.write(1);

}

void establishContact() {
  while (Serial.available() <= 0) {
    Serial.print('A');   // send a capital A

    delay(300);
  }
}









