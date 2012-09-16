import ddf.minim.analysis.*;
import ddf.minim.*;
import codeanticode.syphon.*;
import oscP5.*;
import netP5.*;



static final boolean SYPHON_ENABLED = false;



static final int DRAW_MODE_DEBUG = 1;
static final int DRAW_MODE_RAW_ONLY = 2;

static final int OSC_MODE_THRESHOLD = 1;
static final int OSC_MODE_ALL_MESSAGES = 2;

int drawMode = 1;
int OSCMode = 1;

Minim minim;
AudioInput in;
FFT fft;

PGraphics canvas;
SyphonServer server;

String windowName;
int numBands = 24;
int curNumBands;
int scaleFactor = 5;
float oscAmpThresh = 5;
float currBinVals[];
float currFrameMaxAvgVal = 0;

//for OSC
OscP5 oscP5;
NetAddress myRemoteLocation;

// draw params
int baselineHeight = 20;
color rawStrokeColor = color(0, 0, 255);
color avgStrokeColor = color(255);
color avgFillColor = color(255);
color avgEnabledFillColor = color(0, 255, 0);


void setup()
{
  size(512, 400, P3D);
  
  // Create canvas to draw to for syphon image
  canvas = createGraphics(512, 400, P3D);
  
  if (SYPHON_ENABLED) {
    // Create syhpon server to send frames out.
      server = new SyphonServer(this, "Processing Syphon");    
  }
  
  minim = new Minim(this);
  in = minim.getLineIn(Minim.STEREO, 2048);
  
  curNumBands = numBands;
  currBinVals = new float[numBands];
  
  //jingle = minim.loadFile("drum_solo.mp3", 2048);
  //jingle.loop();
  // create an FFT object that has a time-domain buffer the same size as jingle's sample buffer
  // note that this needs to be a power of two and that it means the size of the spectrum
  // will be 512. see the online tutorial for more info.
  fft = new FFT(in.bufferSize(), in.sampleRate());
  fft.linAverages(numBands);
  fft.window(FFT.HAMMING);

  //canvas.textFont(createFont("SanSerif", 12));
  windowName = String.valueOf(numBands) + " bands";
  
  oscP5 = new OscP5(this, 12000);
  myRemoteLocation = new NetAddress("127.0.0.1", 57001);
}


void drawRaw() {
  canvas.stroke(rawStrokeColor);
  for(int i = 0; i < fft.specSize(); i++)
  {
    // draw the line for frequency band i, scaling it by 4 so we can see it a bit better
    canvas.line(i, height, i, height - baselineHeight - fft.getBand(i)*4);
    
    if (drawMode == DRAW_MODE_DEBUG) {
      fill(rawStrokeColor);
    
    }
    
  }
}

void drawAverages() {
  int w = int(width / fft.avgSize());
  
  canvas.stroke(avgStrokeColor);
  
  float maxBinAvgVal = 0;
  
  for(int i = 0; i < fft.avgSize(); i++)
  {
    // get current bin avg val
    float currAvg = fft.getAvg(i);    
    
    // if currAvg is greater than threshold we fill with green otherwise, white
    if (currAvg > oscAmpThresh) {
      canvas.fill(avgEnabledFillColor);
    } else {
      canvas.fill(avgFillColor);
    }
    
    int bottomStrokeOffset = 2; // draw a couple pixels below the bottom so we can draw over top of the rectangle's bottom stroke
    
    // draw a rectangle for each average, multiply the value by scaleFactor so we can see it better
    canvas.rect(i * w, height - baselineHeight - bottomStrokeOffset - currAvg * scaleFactor, w, currAvg * scaleFactor);    
  }
  
  // draw a red line to indicate our current threshold value
  canvas.stroke(255, 0, 0);
  canvas.line (0, height - baselineHeight - oscAmpThresh * scaleFactor, width, height - baselineHeight - oscAmpThresh * scaleFactor);
}


void analyzeFrame() {
  
  // reset max value
  currFrameMaxAvgVal = 0;
  
  for (int i = 0; i < fft.avgSize(); i++) {
    
    // get current bin avg val
    float currAvg = fft.getAvg(i);    
    
    // set currBinAvg val in array
    currBinVals[i] = currAvg;
    
    // adjust local max val variable if necessary
    if (currAvg > currFrameMaxAvgVal) {
      currFrameMaxAvgVal = currAvg;
    }
    
  }
  
}

void draw()
{
  
  canvas.beginDraw();
  
  canvas.background(0);
    
  if (curNumBands != numBands) {
    numBands = curNumBands;
    currBinVals = new float[numBands];
    fft.linAverages(numBands);
    windowName = String.valueOf(numBands) + " bands";
  }
  
  fft.forward(in.left);

  drawRaw();
  
  if (drawMode == DRAW_MODE_DEBUG) {
    
    drawAverages();    
    
    // show keyboard commands
    canvas.text(" (+/- changes bands, u/d changes amplitude thresh, 'o' OSCMode, 'SPACE' Draw Mode)", 5, 20);
    // keep us informed about the window being used
     canvas.text(windowName, 5, 40);
     
    // show current OSCMode
    String oscModeString = null;
    if (OSCMode == OSC_MODE_ALL_MESSAGES) {
      oscModeString = "ALL_MESSAGES"; 
    } else {
      oscModeString = "THRESHOLD";
    } 
    canvas.text("OSCMode:  " + oscModeString, 5, 60);
  }

   
  canvas.endDraw();
  
  // draw canvas to window
  image(canvas, 0, 0);
  
  if (SYPHON_ENABLED) {
    server.sendImage(canvas); 
  }
  
  // populate the currBinVals array and the currFrameMaxAvgVal variable
  analyzeFrame();

  
  // will send OSC if OSC_MODE_ALL_MESSAGES is enabled or the frame's max value is above a threshold
  if (OSCMode == OSC_MODE_ALL_MESSAGES || currFrameMaxAvgVal > oscAmpThresh) {
    sendOSCMessage(currFrameMaxAvgVal, currBinVals);        
  }
}

void keyPressed() {
  if ( key == 'w' ) 
  {
    // a Hamming window can be used to shape the sample buffer that is passed to the FFT
    // this can reduce the amount of noise in the spectrum
    windowName = "Hamming";
  }
  
  else if ( key == 'e' ) 
  {
    fft.window(FFT.NONE);
    windowName = "None";
  }
  
  else if (key == '+') {
    curNumBands++;
  }
  else if (key == '-') {
    curNumBands--;
  }

  else if (key == 'u') {
    oscAmpThresh++;
    println("Up key");
  }
  else if (key == 'd') {
    oscAmpThresh--;
  }
  else if (key == 'o') {
    if (OSCMode == OSC_MODE_THRESHOLD) {
      OSCMode = OSC_MODE_ALL_MESSAGES;
    } else {
      OSCMode = OSC_MODE_THRESHOLD;
    }
  } else if (key == ' ') {
    if (drawMode == DRAW_MODE_DEBUG) {
      drawMode = DRAW_MODE_RAW_ONLY;
    } else {
      drawMode = DRAW_MODE_DEBUG;
    }
  }
}

void stop()
{
  // always close Minim audio classes when you finish with them
  in.close();
  minim.stop();
  
  super.stop();
}

void sendOSCMessage(float val, float[] binVals) {
  OscMessage myMessage = new OscMessage("/acw");
  myMessage.add("cc");
  myMessage.add(15);
  myMessage.add(binVals.length);

  myMessage.add(val);
  if (binVals != null) {
    myMessage.add(binVals);
  }


  /* send the message */
  oscP5.send(myMessage, myRemoteLocation); 
  println("sent message: " + myMessage);
}
