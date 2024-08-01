using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;
using Toybox.Application as App;
using Toybox.Position;
using Toybox.Background;

var GlobalTouched = -1;
var mW;
var mH;
var _debug       = false;
const RAY_EARTH     = 6378137d;   
const XMARGING      = 4;
const YMARGING      = 10;

/*
   Compass, wind and direction to start.

   Displays a compass with a wind arrow. Once an activity is started it also displays the direction to the start point and the distance (as the crow flies).
   Tap on the field to get the garmin weather forecast for the next 5 hours. The blue bar is the chance on rain (0-100%), the green bar is the wind strength and red is for the temparature.

   - next hour winddirection forecast displayed as light gray arrow
   - green fillin for wind direction variance for the next 5 hours

   - small layout improvements
   - tab on winspeed to change the unit (Bft, m/s, km/h)
   - added setting for default winspeed unit
*/

class CompassView extends Ui.DataField {
    hidden const OFFSETY       = - 6;
    hidden const _180_PI       = 180d/Math.PI;
    hidden const _PI_180       = Math.PI/180d; 

    hidden var isSpdMetric = true;
    hidden var mAmbientPressure = 0;
    hidden var mSF1 = Gfx.FONT_GLANCE;
    hidden var mSF1N = Gfx.FONT_GLANCE_NUMBER;
    hidden var mSF4 = Gfx.FONT_SMALL;
    hidden var mSF2 = Gfx.FONT_TINY;
    hidden var mSF3 = Gfx.FONT_XTINY;
    hidden var mBearing;
    hidden var mTrack;
    hidden var mDistance = 0.0;
    hidden var mHome = null;
    hidden var mWind;
    hidden var mWindspeed;
    hidden var mTemp;
    hidden var mConnectie = false;
    hidden var mShowCompass = true;
    hidden var mWindSpeedUnit = 0;

    /******************************************************************
     * INIT 
     ******************************************************************/  
    function initialize() {
      try {
        DataField.initialize();  
      } catch (ex) {
        debug ("init error: "+ex.getErrorMessage());
      }         
    }

    function getSettings() {
      try {
         mWindSpeedUnit = Application.getApp().getProperty("windspeed"); 
       } catch(ex) {
        debug("getSettings error: "+ex.getErrorMessage());
      }
    }

    /******************************************************************
     * DRAW HELPERS 
     ******************************************************************/  
    function setStdColor (dc) {
      if (getBackgroundColor() == Gfx.COLOR_BLACK) {
         dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      } else {
          dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
      }   
    }

    function createRGB( r,  g,  b) {   
      r = Math.round(r).toNumber();
      g = Math.round(g).toNumber();
      b = Math.round(b).toNumber();
      return ((r & 0xff) << 16) + ((g & 0xff) << 8) + (b & 0xff);
    }

    function getRGB(hex) {
       var r = (hex & 0xFF0000) >> 16;
       var g = (hex & 0xFF00) >> 8;
       var b = (hex & 0xFF);

       return [r, g, b];
    }

    function fillRectangleGrad(dc, x, y, w, h, mh, rs, gs, bs, re, ge, be) {

      var dr = (re - rs)/mh;
      var dg = (ge - gs)/mh;
      var db = (be - bs)/mh;

      for (var i=0; i<h; i++) {
        dc.setColor(createRGB(rs+i*dr, gs+i*dg, bs+i*db), Gfx.COLOR_TRANSPARENT);
        dc.drawLine(x, y-i, x+w, y-i);
      }
    }
    /******************************************************************
     * LABELS
     ******************************************************************/
    function drawSmallArrow (dc, track, bearing, xx, yy) {
        var x1_3 = 0.0;
        var y1_3 = 0.0;
        var x2_3 = 0.0;
        var y2_3 = 0.0;
        var x3_3 = 0.0;
        var y3_3 = 0.0;         
        var x4_3 = 0.0;
        var y4_3 = 0.0;    
        var x5_3 = 0.0;
        var y5_3 = 0.0;       
        var xoffset = 0;
        var yoffset = 0;
        var angle;

        // Radias of the circle and arrows
        var r = 12;

        // angle of the compass, point to north     
        if (track!=null) {
          angle = - (track* _180_PI) - 90;      
        } else {
          angle = - 315 - 90;
        }  
               
        var l  = 1;
        var l1 = .25;
                                               	                    
        if ((bearing!=null) && (track!=null)) {
          // heading to next way point
          // angle = (track - bearing)*_180_PI - 90;
          angle = (-track + bearing)*_180_PI - 90;
          l = 0.00;
          l1 = 0.80;
          var l2 = 1.00;
          
          var x =  r * Math.cos(angle*_PI_180) * l ;
          var y =  r * Math.sin(angle*_PI_180) * l ;  
 
          x1_3 = Math.round(x + r * Math.cos((angle+90)*_PI_180) * l1);
          y1_3 = Math.round(y + r * Math.sin((angle+90)*_PI_180) * l1); 
              
          x2_3 = Math.round(r * Math.cos(angle*_PI_180) * l2);
          y2_3 = Math.round(r * Math.sin(angle*_PI_180) * l2);
          
          x3_3 = Math.round(x + r * Math.cos((angle-90)*_PI_180) * l1);
          y3_3 = Math.round(y + r * Math.sin((angle-90)*_PI_180) * l1);   
          
          x4_3 = Math.round(r * Math.cos((angle)*_PI_180) * (-l2));
          y4_3 = Math.round(r * Math.sin((angle)*_PI_180) * (-l2));      
          
          x5_3 = Math.round(r * Math.cos((angle)*_PI_180) * 0.15);
          y5_3 = Math.round(r * Math.sin((angle)*_PI_180) * 0.15);       
         }     
       
        xoffset = xx;
        yoffset = yy;
        
        ////////////////////////////////////////////////////////////////// 
        // Circle around arrows 
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);  
        dc.drawCircle(xoffset, yoffset, r);
              
        ////////////////////////////////////////////////////////////////// 
        // bearing        
        if ((bearing != null)) {
          dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
          dc.setPenWidth(3);
          dc.drawLine(x5_3+xoffset,y5_3+yoffset, x4_3+xoffset,y4_3+yoffset);    

          dc.setPenWidth(1);     
          //dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
          dc.fillPolygon([[x1_3+xoffset,y1_3+yoffset],[x2_3+xoffset,y2_3+yoffset],[x5_3+xoffset,y5_3+yoffset]]);   
          //dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
          dc.fillPolygon([[x2_3+xoffset,y2_3+yoffset],[x3_3+xoffset,y3_3+yoffset],[x5_3+xoffset,y5_3+yoffset]]);  
          //dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
    }
  
     function drawSmallPointer (dc, track, bearing, xx, yy) {
        var x1_3 = 0.0;
        var y1_3 = 0.0;
        var x2_3 = 0.0;
        var y2_3 = 0.0;
        var x3_3 = 0.0;
        var y3_3 = 0.0;         

        var x5_3 = 0.0;
        var y5_3 = 0.0;     

        var r = 14;
                                                   	                    
        if ((bearing!=null) && (track!=null)) {
          // heading to next way point
          // angle = (track - bearing)*_180_PI - 90;
          var angle = (-track + bearing)*_180_PI - 90;
          var l = 0.0;
          var l1 = 1.0;
          var l2 = 1.00;
          
          var x =  r * Math.cos(angle*_PI_180) * l ;
          var y =  r * Math.sin(angle*_PI_180) * l ;  
 
          x1_3 = Math.round(x + r * Math.cos((angle+140)*_PI_180) * l1);
          y1_3 = Math.round(y + r * Math.sin((angle+140)*_PI_180) * l1); 
              
          x2_3 = Math.round(r * Math.cos(angle*_PI_180) * l2);
          y2_3 = Math.round(r * Math.sin(angle*_PI_180) * l2);
          
          x3_3 = Math.round(x + r * Math.cos((angle-140)*_PI_180) * l1);
          y3_3 = Math.round(y + r * Math.sin((angle-140)*_PI_180) * l1);     
          
          x5_3 = Math.round(r * Math.cos((angle)*_PI_180) * -0.35);
          y5_3 = Math.round(r * Math.sin((angle)*_PI_180) * -0.35);       
              
          dc.setPenWidth(1);     
          dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT); 
          dc.fillPolygon([[x1_3+xx,y1_3+yy],[x2_3+xx,y2_3+yy],[x5_3+xx,y5_3+yy]]);   
          dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT); 
          dc.fillPolygon([[x2_3+xx,y2_3+yy],[x3_3+xx,y3_3+yy],[x5_3+xx,y5_3+yy]]);  
           if (getBackgroundColor() == Gfx.COLOR_BLACK) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT); 
          } else {
           dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);  
          } 
          dc.drawLine(x1_3+xx, y1_3+yy, x2_3+xx, y2_3+yy);
          dc.drawLine(x2_3+xx, y2_3+yy, x3_3+xx ,y3_3+yy );
          dc.drawLine(x3_3+xx ,y3_3+yy, x5_3+xx ,y5_3+yy );
          dc.drawLine(x5_3+xx ,y5_3+yy, x1_3+xx, y1_3+yy );

        }
    }

    /******************************************************************
     * WEATHER 
     ******************************************************************/  
    function drawForecast(dc) {  
      try {    
        var y1; 
        var y2; 
        var x1;
        var x2;

        var dx;  
        var maxforecast = 5; 
        var c = Weather.getHourlyForecast();
        var n = maxforecast;

        var maxheight = mH - 2 * YMARGING;
 
        y1 = mH/2 - maxheight/2; 
        y2 = y1 + maxheight; 
        
        x1 = XMARGING;
        x2 = mW - XMARGING - XMARGING;
        dx = (x2 - x1)  / (n-1);

        var maxT;
        var minT;
        var maxW;
        var minW;

        setStdColor(dc);

        for (var t=0; t<3; t++) {
          // min max bepalen
          var min;
          var max;

          switch (t) {
            case 1: 
              if (mTemp!=null) {
                min  = mTemp-3;
                max  = mTemp+3;
              }
              minT = min;
              maxT = max;
              break;
            case 2:
              if (mWindspeed!=null) { 
                min = mWindspeed-5;
                max = mWindspeed+5;
              }
              minW = min;
              maxW = max;
              break;
            case 0:
              min = 0;   
              max = 100;
            break;
          }
          
          if (min==null) {
            min = 10;
          }

          if (max==null) {
            max = min + 20;
          }

          var delta = max - min;
          var mh = (y2 - y1 - 2);
          if (delta==0) {
            delta = 0;
          } else {
            delta = mh/delta;
          }


          for (var i = 0;  i<n; i++) {
            var hour = null;
            if ((c != null) && (i<c.size())) {
               hour = c[i];
            } 
            var v;
            var RGB_S;
            var RGB_E;

            switch (t) {
              default: 
                break;
              case 1:
                if (hour!=null) {
                  v = hour.temperature;
                } else {
                  v = mTemp;
                }
                RGB_E = getRGB(Graphics.COLOR_RED);
                break;
              case 2: 
                if (hour!=null) {
                  v = hour.windSpeed * 3.6; 
                } else {
                  v = mWindspeed;
                }
                RGB_E = getRGB(Graphics.COLOR_GREEN);
                break;
              case 0:
                if (hour!=null) {
                  v = hour.precipitationChance;
                } else {
                  v = 0;
                }
                RGB_E = getRGB(Graphics.COLOR_BLUE);
                break;
            }
            var darker  = 1.0;
            var lighter = 0.90;
            RGB_S = RGB_E;
            RGB_E = [RGB_E[0] * darker, RGB_E[1] * darker, RGB_E[2] * darker ];
            RGB_S = [RGB_S[0] + lighter * (255-RGB_S[0]), RGB_S[1] + lighter * (255-RGB_S[1]), RGB_S[2] + lighter * (255-RGB_S[2])];
                 
            if ( v == null ) {
              v = min+max/2;
            }

            v = v - min;
            var xx = x1 + i * dx;
            var hh;
            hh = delta * v;
            dc.setPenWidth(4);

            if ((t==2) ) {
              var dir = null;
              if (hour!=null) {
                dir = hour.windBearing;
              }

              if ((dir!=null) && (i>0)){
                if (mTrack!=null) {
                  dir = (dir+180) * _PI_180;
                  drawSmallPointer(dc, mTrack, dir, xx - 12, y1+mH/3);
                  dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
                }
              }
            }

            dc.setPenWidth(3);
            
            if (i<n-1) {
              var xs = Math.round(xx + (t+0)*(dx/3));
              var tol = 0;
              var out = false;
              if (hh>maxheight+tol) {
                hh = maxheight+tol;
                out = true;
              }
              if (hh<0) {
                hh = 0;
              }
              fillRectangleGrad(dc, xs, y2, dx/3, hh, maxheight+tol, RGB_S[0], RGB_S[1], RGB_S[2], RGB_E[0], RGB_E[1], RGB_E[2]);
              if (out) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon( [
                                  [xs           , y2-hh]    , 
                                  [xs+dx/12     , y2-hh+6] , 
                                  [xs+dx/6      , y2-hh]    ,
                                  [xs+dx/6+dx/12, y2-hh+6] , 
                                  [xs+dx/3      , y2-hh] 
                                ]
                                );
              }
            }

            
            // hour marker
            dc.setPenWidth(1);
            if ((i>0) ) {
              if (i<n-1) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(xx, y1, xx, y2);
              }
              if (i<n-2) {
                var today;
                if (hour!=null) {
                  today = Gregorian.info(hour.forecastTime, Time.FORMAT_MEDIUM);
                  dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                  dc.drawText(xx+3, y1+6, mSF3, today.hour, Gfx.TEXT_JUSTIFY_LEFT);
                }
              }
            }
          }
        }

        // Bounding box
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x1, y1, x2+dx, y1);
        dc.drawLine(x1, y2, x2+dx, y2);
        dc.setPenWidth(1);
        dc.drawLine(x1, y1+125/2, x2+dx, y1+125/2);

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x1, y1+6  , mSF3, maxT.format("%i")+"°", Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x1, y2-20 , mSF3, minT.format("%i")+"°", Gfx.TEXT_JUSTIFY_LEFT);
 

        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW-XMARGING, y1+6  ,mSF3, maxW.format("%i")+"kmh", Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(mW-XMARGING, y2-20, mSF3, minW.format("%i")+"kmh", Gfx.TEXT_JUSTIFY_RIGHT);
      } catch (ex) {
        debug("drawforcast error: "+ex.getErrorMessage());
        return false;
      }  
    }

    function drawWind (dc) {
      try {
        var track     = mTrack;
        var bearing   = mHome;
        var wind      = mWind;
        var windspeed = mWindspeed;

        var r = mH/2.2;

        if (mH>200) {
          r = mH * 0.35;
        }

        if (r*2>mW) {
          r = mW * 0.40;
        }

        var xoffset = mW/2;
        var yoffset = mH/2;
     

        var x1;
        var y1;
        var x2;
        var y2;
        var x3;
        var y3;
        var x4;
        var y4;
        var mWindG = null;

     
        if ((mDistance==null) || (mDistance<100) || (mDistance>1000)) {
          // meer plaats maken voor de afstand tot start punt
          xoffset += 10;
        }
       
        ////////////////////////////////////////////////////////////// 
        // WIND GARMIN FORCAST  
        try {
          // COmpass Circle

          dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

          dc.setPenWidth(6);
          dc.drawCircle(xoffset, yoffset, r-17);          
          dc.setPenWidth(1);
          dc.drawCircle(xoffset, yoffset, r-27);

          var c = Weather.getHourlyForecast();
          if ((c!=null) && (c.size()>0)) {
            for (var ii=0; ii<c.size(); ii++) {   
              if (c[ii].windBearing!=null) {      
                if (ii==0) {
                  mWindG = c[ii].windBearing;
                }       
                if (ii<5) {
                  dc.setPenWidth(6);
                  dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                  //var angle = (wind - (track * _180_PI)) - 90;  

                  var t = 0;
                  if (track!=null) {
                    t = track;
                  }
                  
                  var angle = 360 - ( (c[ii].windBearing - (t * _180_PI)) - 90 );      
                  var start = angle + 10;
                  var end   = angle - 10 ;     

                  dc.drawArc(xoffset, yoffset, r-17, Gfx.ARC_CLOCKWISE, start , end );
                }
              }
            }      
          }     
        } catch (ex) {
          debug("drawwind wind error: "+ex.getErrorMessage());
        }


        ////////////////////////////////////////////////////////////// 
        // COMPASS
        try {
          var angle = 0;  
          if (track!=null) {
            angle = - (track* _180_PI) - 90;        
          } else {
            if (bearing!=null) {
              angle = (bearing* _180_PI)  - 360 - 90;
            } 
          }  
                  
          var l;
          var l1;

          for (var j=1; j<2; j++) {
            // 0 = Inner roos, 1 = outer roos
            if (j==1) {
              l  = 1.0;
              l1 = 0.18;
            } else {
              l  = 0.55;
              l1 = 0.20;
            }
            for (var i=1; i>=0 ; i--) {

              var a=0;
              var b=0;
              if (j==1) {
                a = angle + i * 180.0;
                b = 90;
              } else {
                a = angle + 45 + i * 90;
                b = 20;
              }

              x1 = Math.round(r * Math.cos(a*_PI_180) * l);
              y1 = Math.round(r * Math.sin(a*_PI_180) * l);    
              x2 = Math.round(r * Math.cos((a+b)*_PI_180) * l1);
              y2 = Math.round(r * Math.sin((a+b)*_PI_180) * l1); 
              x3 = Math.round(r * Math.cos((a-b)*_PI_180) * l1);
              y3 = Math.round(r * Math.sin((a-b)*_PI_180) * l1);

              
              dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
              if (j==1) {
                if (i==0) {
                  dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
                }
                if (i==2) {
                  dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                }
              }

              dc.fillPolygon([
                            [x1+xoffset,y1+yoffset]
                            ,[x2+xoffset,y2+yoffset]
                            ,[xoffset,yoffset]
                            ]);
            
              dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
              if (j==1) {
                if (i==0) {
                  dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                }
                if (i==2) {
                  dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                }
              }

              dc.fillPolygon([
                            [x1+xoffset,y1+yoffset]
                            ,[x3+xoffset,y3+yoffset]
                            ,[xoffset,yoffset]
                            ]);
          

              if (getBackgroundColor() == Gfx.COLOR_BLACK) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
              } else {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
              } 
          
              dc.setPenWidth(2);   
              dc.drawLine(x1+xoffset,y1+yoffset,x2+xoffset,y2+yoffset);
              dc.drawLine(x3+xoffset,y3+yoffset,x1+xoffset,y1+yoffset);
            }
          }
        } catch (ex) {
          debug("drawwind compass error: "+ex.getErrorMessage());
        }

        ////////////////////////////////////////////////////////////// 
        // WIND GARMIN       
        try {
          if ((wind!=null) && (mWindG!=null) && (track!=null)) {                        
            // angle of the wind,points to the wind direction
            if ( (mWindG-wind>10) || (mWindG-wind<-10) ) {   
              var angle = (mWindG - (track * _180_PI)) - 90;  
              var extra = 0.1;
              var l =  1.0 +extra;
              var l1 = 0.25;
              var l2 = 0.35 +extra;
              
              var x =  r * Math.cos(angle*_PI_180) * l ;
              var y =  r * Math.sin(angle*_PI_180) * l ;  

              x1 =  Math.round(r * Math.cos(angle*_PI_180) * (0.77+extra)) ;
              y1 =  Math.round(r * Math.sin(angle*_PI_180) * (0.77+extra));  

              x2 = Math.round(x + r * Math.cos((angle+90)*_PI_180) * l1);
              y2 = Math.round(y + r * Math.sin((angle+90)*_PI_180) * l1); 
                  
              x3 = Math.round(r * Math.cos(angle*_PI_180) * l2);
              y3 = Math.round(r * Math.sin(angle*_PI_180) * l2);
              
              x4 = Math.round(x + r * Math.cos((angle-90)*_PI_180) * l1);
              y4 = Math.round(y + r * Math.sin((angle-90)*_PI_180) * l1);             
      
              dc.setPenWidth(1);
              dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
              dc.drawLine(x1+xoffset,y1+yoffset,x2+xoffset,y2+yoffset);
              dc.drawLine(x2+xoffset,y2+yoffset,x3+xoffset,y3+yoffset);
              dc.drawLine(x3+xoffset,y3+yoffset,x4+xoffset,y4+yoffset);            
              dc.drawLine(x4+xoffset,y4+yoffset,x1+xoffset,y1+yoffset); 
            }
          }           
        } catch (ex) {
          debug("drawwind wind error: "+ex.getErrorMessage());
        }

        ////////////////////////////////////////////////////
        // BEARING, terug naar start
        try {
          if ((bearing!=null) && (track!=null)) {
            var angle = (-track + bearing)*_180_PI - 90;
            var extra = 0.1;
            var l  = 0.35 + extra;
            var l1 = 0.55 + extra;
            var l2 = 0.25;
            var l3 = 1.0  + extra;
            
            var x =  r * Math.cos(angle*_PI_180) * l ;
            var y =  r * Math.sin(angle*_PI_180) * l ;  

            x1 = Math.round(r * Math.cos(angle*_PI_180) * l1 ) ;
            y1 = Math.round(r * Math.sin(angle*_PI_180) * l1);

            x2 = Math.round(x + r * Math.cos((angle+90)*_PI_180) * l2);
            y2 = Math.round(y + r * Math.sin((angle+90)*_PI_180) * l2); 
                
            x3 = Math.round(r * Math.cos(angle*_PI_180) * l3);
            y3 = Math.round(r * Math.sin(angle*_PI_180) * l3);
            
            x4 = Math.round(x + r * Math.cos((angle-90)*_PI_180) * l2);
            y4 = Math.round(y + r * Math.sin((angle-90)*_PI_180) * l2);              

          
            if (bearing != null)   {
              dc.setPenWidth(1);     
              if (getBackgroundColor() == Gfx.COLOR_BLACK) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
              } else {
                dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
              }

              dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
              dc.fillPolygon(
                            [                       
                              [x1+xoffset,y1+yoffset]
                            ,[x2+xoffset,y2+yoffset]
                            ,[x3+xoffset,y3+yoffset]
                            ]
                            );

              dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
              dc.fillPolygon(
                            [[x1+xoffset,y1+yoffset]
                            ,[x3+xoffset,y3+yoffset]
                            ,[x4+xoffset,y4+yoffset]]
                            );
      
              dc.setPenWidth(2);
              setStdColor (dc);
              dc.drawLine(x1+xoffset,y1+yoffset,x2+xoffset,y2+yoffset);
              dc.drawLine(x2+xoffset,y2+yoffset,x3+xoffset,y3+yoffset);
              dc.drawLine(x3+xoffset,y3+yoffset,x4+xoffset,y4+yoffset);            
              dc.drawLine(x4+xoffset,y4+yoffset,x1+xoffset,y1+yoffset);            
            }
          }
        } catch (ex) {
          debug("drawwind bearing error: "+ex.getErrorMessage());
        }


        ////////////////////////////////////////////////////////////// 
        // WIND   
        try {
          if ((wind!=null) && (track!=null)) {                  
            // angle of the wind,points to the wind direction
            var angle = (wind - (track * _180_PI)) - 90;  
            var extra = 0.1;
            var l =  1.0 +extra;
            var l1 = 0.25;
            var l2 = 0.35 +extra;
            
            var x =  r * Math.cos(angle*_PI_180) * l ;
            var y =  r * Math.sin(angle*_PI_180) * l ;  

            x1 =  Math.round(r * Math.cos(angle*_PI_180) * (0.77+extra)) ;
            y1 =  Math.round(r * Math.sin(angle*_PI_180) * (0.77+extra));  

            x2 = Math.round(x + r * Math.cos((angle+90)*_PI_180) * l1);
            y2 = Math.round(y + r * Math.sin((angle+90)*_PI_180) * l1); 
                
            x3 = Math.round(r * Math.cos(angle*_PI_180) * l2);
            y3 = Math.round(r * Math.sin(angle*_PI_180) * l2);
            
            x4 = Math.round(x + r * Math.cos((angle-90)*_PI_180) * l1);
            y4 = Math.round(y + r * Math.sin((angle-90)*_PI_180) * l1);             
    
      
            dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(
                            [                       
                            [x1+xoffset,y1+yoffset]
                            ,[x2+xoffset,y2+yoffset]
                            ,[x3+xoffset,y3+yoffset]
                            ]
                            );

            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(
                            [[x1+xoffset,y1+yoffset]
                            ,[x3+xoffset,y3+yoffset]
                            ,[x4+xoffset,y4+yoffset]]
                            );
            if (getBackgroundColor() == Gfx.COLOR_BLACK) {
              dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            } else {
              dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } 
            dc.setPenWidth(2);
            dc.drawLine(x1+xoffset,y1+yoffset,x2+xoffset,y2+yoffset);
            dc.drawLine(x2+xoffset,y2+yoffset,x3+xoffset,y3+yoffset);
            dc.drawLine(x3+xoffset,y3+yoffset,x4+xoffset,y4+yoffset);            
            dc.drawLine(x4+xoffset,y4+yoffset,x1+xoffset,y1+yoffset); 
          }           
        } catch (ex) {
          debug("drawwind wind error: "+ex.getErrorMessage());
        }


        //////////////////////////////////////////////////////////////////
        // Text, Temp, Wind Speed, Alarm, Distance
        try {
          var bft = 3;
      
          if (wind != null)  {
            windspeed = windspeed; // km/u
            if (windspeed!=null) {
              if (windspeed<=5) {          // 1
                bft = 1;           
              } else if (windspeed<=11) {  // 2
                bft = 2;         
              } else if (windspeed<=19) {  // 3
                bft = 3;   
              } else if (windspeed<=28) { //  4
                bft = 4;
              } else if (windspeed<=38) { //  5
                bft = 5;
              } else if (windspeed<=49) { //  6             
                bft = 6;
              } else if (windspeed<=61) { //  7         
                bft = 7;
              } else if (windspeed<=74) { //  8             
                bft = 8;
              } else if (windspeed<=88) { //  9            
                bft = 9;
              } else if (windspeed<=102) { //  10             
                bft = 10;
              } else if (windspeed<=117) { //  11      
                bft = 11;
              } else {                    //  12
                bft = 12;             
              }
            }
          }
          
          setStdColor (dc);          
          var h = dc.getTextDimensions("X", mSF4);
          // Temp
          if (mTemp!=null) {
            dc.drawText(XMARGING, YMARGING, mSF4, Math.round(mTemp).format("%i")+"°", Gfx.TEXT_JUSTIFY_LEFT);
          }

          // Windspeed
          if (mWindspeed!=null) {
            var v = bft.format("%i")+"bft";
            switch (mWindSpeedUnit) {
              case 0:
                v = bft+"bft";
                break;
              case 1:
                v = Math.round(windspeed / 3.6).format("%i")+"ms";
                break;
              case 2:
                v = Math.round(windspeed).format("%i")+"kh";
                break;
            }

            //dc.drawText(XMARGING, mH-YMARGING-28, mSF4, v2, Gfx.TEXT_JUSTIFY_RIGHT);
            //dc.drawText(XMARGING, mH-YMARGING-28, mSF4, Math.round(windspeed).format("%i")+"m/s", Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(XMARGING, mH-h[1], mSF4, v, Gfx.TEXT_JUSTIFY_LEFT);
          }
          
          // Hemelsbreed afstand
          if (mDistance!=null) {
            var v2 = "";
            var dist = mDistance;
            if (dist>=1000) { v2 = (Math.round(dist/1000)).format("%i")+"km";}
            if (dist<1000) {  v2 = (Math.round(dist)).format("%i")+"m"; }
            dc.drawText(mW-XMARGING, mH-h[1], mSF4, v2, Gfx.TEXT_JUSTIFY_RIGHT);
          }  
 
        } catch (ex) {
          debug("drawwind text error: "+ex.getErrorMessage());
        }
      } catch (ex) {
        debug("drawwind error: "+ex.getErrorMessage());
      } 

    }

    function drawWeather (dc) {
        if (!mShowCompass) {
          drawForecast(dc) ;
        } else {
          drawWind(dc);
        }
    }

    /******************************************************************
     * COMPUTE 
     ******************************************************************/  
    function setWeather() {
      try {
        var c = Weather.getCurrentConditions();  
        if (c!=null) {
          mWindspeed = c.windSpeed * 3.6;
          mWind      = c.windBearing;
          mTemp      = c.temperature;
        }  
      } catch (ex) {
         debug("setWeather error: "+ex.getErrorMessage());
      }               
    }


    function compute(info) {
      try {  
        // ambientPressure
        mAmbientPressure = 0;
        if (info has :ambientPressure ) {
          if (info.ambientPressure  != null)  {
                mAmbientPressure = info.ambientPressure;
          } 
        }

        // get track (=compass)      
        mTrack = null;     
        if (info.track  != null)  {
            mTrack = info.track;
        } 
        
        // bearing
        mBearing = null;
        if (info has :bearing) {
          if (info.bearing != null) {
            mBearing = info.bearing;  
          }
        }        
        
        // Distance and orientation back home
        mHome = null;
        mDistance = null;  
        if ((info.currentLocation != null) && (info.currentLocationAccuracy!=null) && (info.startLocation!=null)) {
          if (info.currentLocationAccuracy>=2) {       
            var  latitude_point_start;
            var  longitude_point_start;
            var  latitude_point_arrive;
            var  longitude_point_arrive;

            latitude_point_arrive = info.startLocation .toRadians()[0];
            longitude_point_arrive = info.startLocation .toRadians()[1];
          
            latitude_point_start = info.currentLocation.toRadians()[0];
            longitude_point_start = info.currentLocation.toRadians()[1];
                                            
            mDistance = Math.acos(Math.sin(latitude_point_start)*
                          Math.sin(latitude_point_arrive) + 
                          Math.cos(latitude_point_start)*
                          Math.cos(latitude_point_arrive)*
                          Math.cos(longitude_point_start-longitude_point_arrive)
                        );
              
            if( RAY_EARTH * mDistance > 0) {
              mHome = Math.acos((Math.sin(latitude_point_arrive)-Math.sin(latitude_point_start)*Math.cos(mDistance))/(Math.sin(mDistance)*Math.cos(latitude_point_start)));
          
            if( Math.sin(longitude_point_arrive-longitude_point_start) <= 0 ) {
              mHome = 2*Math.PI-mHome;
              }
            }
            mDistance = RAY_EARTH * mDistance;

            if (mDistance>200000) {
              mDistance = 99000;
            }
          }
        }

        setWeather();
      } catch (ex) {
          debug("Compute error: "+ex.getErrorMessage());
      }                  
    }
  
    /******************************************************************
     * On Update
     ******************************************************************/  
    function Touched(area) {
      debug("Touched ");      
    }

    function handleTouch() {
      try {
        if (GlobalTouched==1) {
           GlobalTouched = -1;
           mShowCompass = !mShowCompass;
        }
        if (GlobalTouched==2) {
           GlobalTouched = -1;
           mWindSpeedUnit++;
           if (mWindSpeedUnit>2) {
            mWindSpeedUnit = 0;
           }
        }        
      } catch (ex) {
        GlobalTouched = -1;
        debug("handleTouch error: "+ex.getErrorMessage());
      }
    }
  
    function onUpdate(dc) { 
       try {
        mW = dc.getWidth();
        mH = dc.getHeight();
        handleTouch();
        dc.setColor(getBackgroundColor(), getBackgroundColor()); 
        dc.clear();
        setStdColor(dc); 
        drawWeather(dc);   
      } catch (ex) {
        debug("onUpdate ALL error: "+ex.getErrorMessage());
     }
    }

}
