import ipcapture.*;
import processing.serial.*;

IPCapture cam;
Serial port;      // The serial port

final int SEEK = 0;
final int RENDEZVOUS = 1;
final int ALIGNMENT = 2;
final int DOCK = 3;
final int FILL = 4;
final int UNDOCK = 5;
final int FILL_DIST = 640-45;
final int FILL_TIME = 38 * 1000;
final int WAIT_TIME = 5 * 1000;

int[] motorSpeeds = {0, 0, 0};
boolean fillingCup = false;


float cupCenter = -1;
float cupDistance = -1;

int fillStartTime = -1;
int state = 1;



void setup() {
  size(1920, 640);
  cam = new IPCapture(this, "http://10.18.3.101:8080/video", null, null);
  cam.start();

  // this works as well:

  // cam = new IPCapture(this);
  // cam.start("url", "username", "password");

  // It is possible to change the MJPEG stream by calling stop()
  // on a running camera, and then start() it with the new
  // url, username and password.
  print(Serial.list());
  String portName = Serial.list()[5];
  port = new Serial(this, portName, 57600);

  int time = millis();
  while (millis() - time <= 2000);
}

void delay(int millis){
  int time = millis();
  while (millis() - time <= millis);
}

int extractRed(int c) {
  float b = (red(c) - (blue(c) + green(c))) ;
  if (b < 0) {
    b = 0;
  }
  return color(b, b, b);
}

int[] extractRed(int[] im) {
  int[] out = new int[im.length];
  for (int i = 0; i < im.length; i++)
    out[i] = extractRed(im[i]);
  return out;
}

PImage thresh(PImage image, double threshhold) {
  int[] im = image.pixels;
  for (int i = 0; i < im.length; i++) {
    if (red(im[i]) > threshhold) {
      im[i] = color(255, 255, 255);
    } else {
      im[i] = color(0, 0, 0);
    }
  }
  image.pixels = im;
  image.updatePixels();
  return image;
}

boolean isCup(int bottomRow, int topRow) {
  return true;
}

PImage scanForCups(PImage image) {
  for (int i = image.height - 1; i >= 0; i--) {
    int firstPixel = -1;
    int lastPixel = -1;
    boolean lineStarted = false;
    for (int j = image.width - 1; j >= 0; j--) {
      int pI = i * image.width + j;//Pixel index
      if (i==FILL_DIST) {
        image.pixels[pI] = color (255, 0, 0);
      }
      if ((red(image.pixels[pI])>128)) {
        if (!lineStarted) {
          lineStarted = true;
          firstPixel = j;
        }
      } else {
        if (lineStarted) {
          lastPixel = j;
          lineStarted = false;
          if (firstPixel - lastPixel > 20) {
            cupCenter = (firstPixel + lastPixel)/2;
            for (int k = firstPixel; k >= lastPixel; k--) {
              pI = i * image.width + k;//Pixel index
              image.pixels[pI] = color (0, 255, 0);
            }
            cupDistance = i;
            image.updatePixels();
            return image;
          }
          else cupCenter = -1;
        }
      }
    }
  }
  image.updatePixels();
  return image;
}

void sendMotorSpeeds(){
  int[] speeds = {motorSpeeds[0], motorSpeeds[1], motorSpeeds[2]};
  
  if(speeds[2] < 0) speeds[2] = 0;
  speeds[1] = -speeds[1];
  speeds[2] = -speeds[2];
  for(int i = 0; i < 3; i++){
    speeds[i] = abs(speeds[i] + 90);
  }
  
  String[] stringSpeeds = {str(speeds[0]), str(speeds[1]), str(speeds[2])};
  
  for(int i = 0; i < 3; i++){
    while(stringSpeeds[i].length() < 3){
      stringSpeeds[i] = "0" + stringSpeeds[i];
    }
  }
  
  String serialCommand = stringSpeeds[0] + ":" + stringSpeeds[1] + ":" + stringSpeeds[2] + "\n";
  port.write(serialCommand);
  
}


void calcDrive() {
 float xError = -((480/2)-cupCenter);
 float deadband = 20;
 motorSpeeds[0] = 0;
 motorSpeeds[1] = 0;
 motorSpeeds[2] = 0;
 
  if(cupCenter < 0){ //no cup
    println("No Cup");
    if(millis() % 10000 < 5000){
      motorSpeeds[0] = -7;
      motorSpeeds[1] = 7;
    }
    else{
      motorSpeeds[0] = 7;
      motorSpeeds[1] = -7;
    }
  }
  else if((abs(xError) <= deadband || fillingCup)){ //centered cup
    println("Centered");
    
    if((abs(cupDistance - FILL_DIST) <= deadband/2) || fillingCup){ //Cup ready to be filled
      println("Filling Cup");

      if(!fillingCup){
        fillStartTime = millis();
      }
      
      fillingCup = true;
      motorSpeeds[2] = 70;
      
      if(millis() - fillStartTime > FILL_TIME){
        motorSpeeds[2] = 0;
        fillingCup = false;
        delay(WAIT_TIME);
      }
    }
    else{ //Need to move forward or back
      if(cupDistance >= (FILL_DIST+deadband/2)){ //backward
        println("Backing up");
        motorSpeeds[0] = -20;
        motorSpeeds[1] = -20;
        if(abs(cupDistance - FILL_DIST) <= deadband*4){
          println("Slow Back");
          motorSpeeds[0] = int(motorSpeeds[0] * 0.4); 
          motorSpeeds[1] = int(motorSpeeds[1] * 0.4); 
        }
      }
      else if(cupDistance <= (FILL_DIST-deadband/2)){ //forward
        println("Zoom Zoom Zoom");
        motorSpeeds[0] = 9;
        motorSpeeds[1] = 9;
        if(abs(cupDistance - FILL_DIST) <= deadband*2){
          println("Slow Zoom");
          motorSpeeds[0] = int(motorSpeeds[0] * 0.6); 
          motorSpeeds[1] = int(motorSpeeds[1] * 0.6); 
        }
      }
      else{ //it fucked up
        println("Fuck");
      }
    }
  }
  else{ //non-centered cup
    println("Non-Centered");
    if(xError < deadband/2){ //turn left
      println("Left");
      if(cupDistance >= (FILL_DIST+deadband/2)) motorSpeeds[0] = -10;
      else motorSpeeds[1] = 8;
      if(xError < deadband*2){
         motorSpeeds[1] = int(motorSpeeds[1] * 0.8);
      }
    }
    else if(xError > deadband/2){ //turn right
      println("Right");
      if(cupDistance >= (FILL_DIST+deadband/2)) motorSpeeds[1] = -10;
      else motorSpeeds[0] = 8;
      if(xError < deadband*2){
         motorSpeeds[0] = int(motorSpeeds[1] * 0.8);
      }
    }
    else{
     print("Fuck 2.0");
    }
  }
 
}

void serialEvent(Serial myPort) {
  try{
    int inByte = myPort.read();
    myPort.clear();
    sendMotorSpeeds();
  }
  catch(RuntimeException e){
     e.printStackTrace(); 
  }
}

void draw() {
  if (cam.isAvailable()) {
    cam.read();
    image(cam, 0, 0);
    for (int i = 0; i < cam.width*cam.height; i++ ) { 
      cam.pixels[i] = extractRed(cam.pixels[i]);
    } 
    cam.updatePixels();
    

    image(cam, 480, 0);
    PImage threshed = thresh(cam, 40);
    image(threshed, 480*2, 0);
    PImage scanned = scanForCups(threshed);
    image(scanned, 480*3, 0);
  }
  calcDrive();
  delay(10);
}
