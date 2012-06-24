import ddf.minim.analysis.*;
import ddf.minim.*;
import controlP5.*;
import javax.sound.sampled.*;

Minim minim;
//AudioPlayer jingle;
AudioInput in;
FFT fft;
String windowName;
int numBands = 24;
int curNumBands;

// an array of info objects describing all of 
// the mixers the AudioSystem has. we'll use
// this to populate our gui scroll list and
// also to obtain an actual Mixer when the
// user clicks on an item in the list.
Mixer.Info[] mixerInfo;
int mixerIndex = 0; //7 is the NI input

float oscAmpThresh = 10;

void setup()
{
  size(512, 400);
  minim = new Minim(this);
  in = minim.getLineIn(Minim.STEREO, 2048);
  
  mixerInfo = AudioSystem.getMixerInfo();
  println("Using mixer info " + mixerInfo[mixerIndex].getName());
  Mixer mixer = AudioSystem.getMixer(mixerInfo[mixerIndex]);
  minim.setInputMixer(mixer);
  
  curNumBands = numBands;
  
  //jingle = minim.loadFile("drum_solo.mp3", 2048);
  //jingle.loop();
  // create an FFT object that has a time-domain buffer the same size as jingle's sample buffer
  // note that this needs to be a power of two and that it means the size of the spectrum
  // will be 512. see the online tutorial for more info.
  fft = new FFT(in.bufferSize(), in.sampleRate());
  fft.linAverages(numBands);
  fft.window(FFT.HAMMING);

  textFont(createFont("SanSerif", 12));
  windowName = String.valueOf(numBands) + " bands";
  
}


void drawRaw() {
  stroke(0, 0, 255);
  for(int i = 0; i < fft.specSize(); i++)
  {
    // draw the line for frequency band i, scaling it by 4 so we can see it a bit better
    line(i, height / 2, i, height / 2 - fft.getBand(i)*4);
  }
}

void drawAverages() {
  int w = int(width / fft.avgSize());
  
  int scaleFactor = 5; //for visibility
  
  stroke(255);
  for(int i = 0; i < fft.avgSize(); i++)
  {
    // draw a rectangle for each average, multiply the value by 5 so we can see it better
    //rect(i * w, height / 2, i * w + w, height / 2 - fft.getAvg(i) * scaleFactor);
    rect(i * w, height - fft.getAvg(i) * scaleFactor, w, fft.getAvg(i) * scaleFactor);
  }
  
  stroke(255, 0, 0);
  line (0, height - oscAmpThresh * scaleFactor, width, height - oscAmpThresh * scaleFactor);
}

void draw()
{
  background(0);
    
  //stroke(0, 0, 255);
  
  if (curNumBands != numBands) {
    numBands = curNumBands;
    fft.linAverages(numBands);
    windowName = String.valueOf(numBands) + " bands";
  }
  
  fft.forward(in.mix);

  drawRaw();
  drawAverages();

  //fill(255);
  // keep us informed about the window being used
  text(windowName + "+/- changes bands", 5, 20);
}

void keyReleased()
{
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
  
  else if (key == 't') {
      if ( in != null )
    {
      in.close();
    }
  
    mixerIndex++;
    println("Using mixer info " + mixerInfo[mixerIndex].getName());
    Mixer mixer = AudioSystem.getMixer(mixerInfo[mixerIndex]);
    minim.setInputMixer(mixer);
    in = minim.getLineIn(Minim.STEREO);
  }
  
}

void stop()
{
  // always close Minim audio classes when you finish with them
  in.close();
  minim.stop();
  
  super.stop();
}
