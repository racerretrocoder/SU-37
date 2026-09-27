# Ai "Searcher", and other random stuff!
# Created by Phoenix, Skid, and Uapilot
#
# This script is used to search for another pilots properties (Mainly the rotor prop)
# it can be used for counter messure detection. and more.


# Skid, Phoenix

# Search Funtion V2
# The way i want this to work is you input it a callsign misc.search("Skid"); then itll search ai/models/multiplayer for Skid
# If it finds what we want. That will check out successfully, then itll read from the ID of our MP target and see if our target is flaring or not. via the rotors prop 
# Its kinda like Phoenix's Lockhelper.nas But expanded apon


var search = func(cs,isuav = 0){
    track(smallsearch(cs),isuav);
    print("misc.nas: search: ",cs);
}


# Phoenix
# This reads the property assigned to flares on the selected MPid

var lastflare = 0;

var track = func(mpid,isuav=0) {
    if (isuav == 0) {
          print("Misc.track: MPID:");
          print(mpid); # We have our number
          print(getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")); #threat is the right one. 
          var flareint = getprop("/ai/models/multiplayer[" ~ mpid ~ "]/rotors/main/blade[3]/flap-deg");
          # Is our bandit flaring?
          if (flareint != nil){
          if (flareint != lastflare){
          if (flareint > 0) {
          setprop("payload/armament/flares", 1);
          print("misc.nas Flares detected.");
          lastflare = flareint;
          print("Last flareint:");
          print(lastflare);
            }
          } else {
              setprop("payload/armament/flares", 0);
              print("bandit has not released a new flare");
            }
          } else {
              print("Bandit dose not support counter messures  flareint = nil");
          }
    } else {

          if (getprop("/gear/gear/wow") == 1) {
        # Where a UAV on the ground looking for a threat
          print("misc.nas: Searching if one of the threats are within our range");
          print(mpid); # We have our number
          print(getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")); #threat is the right one. 
          var distance = getprop("/ai/models/multiplayer[" ~ mpid ~ "]/radar/range-nm"); # Distance away from threat in nm
          print("Threat Distance from us:");
          print(distance);
          var threatradius = getprop("controls/AI/deploy-range");
          print("Our Deploy Range: ");
          print(threatradius);
        # Is our threat within our set radius?
          if (distance < threatradius) {

            # Bandit is in our radius 
            # lets Check to see if we can deploy or some other UAV already deployed
            # Never mind. too difficult

            # Lets deploy at threat when the sam control center has us in the correct UAV slot
            print("Bandit in our airspace Deploying...");
            setprop("payload/armament/msg", 1); # Turn on damage
            print(getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign"));
            var bandit = getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign");
            drone.enableauto(); # Automaticaly enable the UAV and Launch from the launcher
            drone.engagebandit(bandit); # Engage the threat
            setprop("controls/AI/attack", 1); # Enable attacking
        
            setprop("sim/weight[0]/selected", "Aim-120");
            setprop("sim/weight[1]/selected", "Aim-120");
            setprop("sim/weight[2]/selected", "Aim-120");
            setprop("sim/weight[3]/selected", "Aim-120");
            setprop("sim/weight[4]/selected", "Aim-120");
            setprop("sim/weight[5]/selected", "Aim-120");
            setprop("sim/weight[6]/selected", "Aim-120");
            setprop("sim/weight[7]/selected", "Aim-120");    
            setprop("sim/weight[8]/selected", "Aim-120");
            setprop("sim/weight[9]/selected", "Aim-120");
            setprop("sim/weight[10]/selected", "Aim-120");

#
# Load the weapons
#

            setprop("controls/armament/station[0]/release", 0);
            setprop("controls/armament/station[1]/release", 0);
            setprop("controls/armament/station[2]/release", 0);
            setprop("controls/armament/station[3]/release", 0);
            setprop("controls/armament/station[4]/release", 0);
            setprop("controls/armament/station[5]/release", 0);
            setprop("controls/armament/station[6]/release", 0);
            setprop("controls/armament/station[7]/release", 0);    
            setprop("controls/armament/station[8]/release", 0);
            setprop("controls/armament/station[9]/release", 0);
            setprop("controls/armament/station[10]/release", 0);

            setprop("controls/drone/owner", getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign"));
                        # UAV owner is now the sam control center
            }
        }
    }
}

var smallsearch = func(cs=nil) {
  var list = props.globals.getNode("/ai/models").getChildren("multiplayer");
  var total = size(list);
  var mpid = 0;
  for(var i = 0; i < total; i += 1) {
      if (cs != nil) {
      # were searching for someone...
      if (getprop("ai/models/multiplayer[" ~ i ~ "]/callsign") == cs) {
          # we have our number
          #print(mpid);
          mpid = i;
          #track(mpid,0); # run the flare detection/RND on this Multiplayer property
          return mpid; # Bam!
          
     }
      var callsign = list[i].getNode("callsign").getValue();
     }
   }
}



var getbearingto = func(cs=nil) {
  # only works if in radar range. Dosent have to be in radar view
  var list = props.globals.getNode("/ai/models").getChildren("multiplayer");
  var total = size(list);
  var mpid = 0;
  for(var i = 0; i < total; i += 1) {
      if (cs != nil) {
      # were searching for someone...
      if (getprop("ai/models/multiplayer[" ~ i ~ "]/callsign") == cs) {
          # we have our number
          print(mpid);
          mpid = i;
          return getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg");    
        }
      var callsign = list[i].getNode("callsign").getValue();
     }
   }
}

var searchsize = func() {
  var list = props.globals.getNode("/ai/models").getChildren("multiplayer");
  var total = size(list);
  return total;
}


var calcdamage = func(lat,lon,mslname="none"){
       # screen.log.write("testing distance");
        print("Calcing");
        var aimplist = searchsize();
        var impactbomb = geo.Coord.new();
        impactbomb.set_latlon(lat,lon,0);
        var lat2 = 0;
        var lon2 = 0;
        var playercoord = geo.Coord.new();
        for(var i = 0; i < aimplist; i += 1) {
                print(i);
                lat2 = getprop("ai/models/multiplayer[" ~ i ~ "]/position/latitude-deg");
                lon2 = getprop("ai/models/multiplayer[" ~ i ~ "]/position/longitude-deg");
                if (lat2 == nil) {
                    #screen.log.write("nil");
                    return;
                }
                playercoord.set_latlon(lat2,lon2,0);
               # screen.log.write(printf("%i",  impactbomb.distance_to(playercoord)));
                if (impactbomb.distance_to(playercoord) < 51) {
                    var callsign = getprop("ai/models/multiplayer[" ~ i ~ "]/callsign");
                    var distance = impactbomb.distance_to(playercoord);
                    missile.MISSILE.broddamage(callsign,distance,mslname);
                }
        }
}

# Uapilot finddel() string stuff
var finddel = func(thestring, sub) {
	if (substr(thestring, -size(sub)) == sub) { # Negation of the size() output. That seems to be the fastest way. And it works constantly!
        var answer = substr(thestring, 0, size(thestring) - size(sub));
		#print(answer);
        return answer; # Deleted the sub!
    } else {
        #print("didnt work :( "~sub~"");
	    return thestring; # what can it be
    }
}
setprop("/f22/fcs/rollrate",20);
setprop("/autopilot/locks/fcs","");
setprop("/autopilot/locks/fcsaileron","");
var fcsloop = func() {
  # Loop it slowly
  var controlThresh = 0.01;
  var negcontrolThresh = -1 * controlThresh;
  var fcsmode = getprop("/f22/fcsmode");#mode
  var glimit = getprop("/f22/fcs/glimit");#g
  var alimit = getprop("/f22/fcs/aoalimit");#alpha
  var elevator = getprop("/controls/flight/elevator");
  var aileron = getprop("/controls/flight/aileron");
  var rudder = getprop("/controls/flight/rudder");
  var disableelev = 0;
  var disableaile = 2;
    setprop("f22/fcs/mode","AUTO G"); # the text
    # AF1g mode
    # do control check
    if (elevator > controlThresh) {
      disableelev = 1;
      disableaile = 1; # Disable Roll control aswell when flying
    }

    if (elevator < 0) {
      if (elevator < negcontrolThresh){
        disableelev = 1;
        disableaile = 1; # Disable Roll control aswell when flying
      }
    }

    
    if (aileron > controlThresh) {
      disableaile = 1;
    }

    if (aileron < 0) {
      if (aileron < negcontrolThresh){
        disableaile = 1;
      }
    }
    var rollrate = getprop("/f22/fcs/rollrate");
    var negrollrate = rollrate * -1;
    if (getprop("/orientation/roll-rate-degps") < rollrate and getprop("/orientation/roll-rate-degps") > negrollrate) {
      if (disableaile != 1) {
        disableaile = 0;
      }
    }
    # final checks
    # Note: if getprop("fdm/jsbsim/fcs/engine-gen-spin-output") is nil. then the == 0 is auto ignored
    if (getprop("fdm/jsbsim/fcs/engine-gen-spin-output") == 0 or getprop("autopilot/locks/altitude") != "" or getprop("orientation/pitch-deg") < -70 or getprop("orientation/pitch-deg") > 70 or getprop("velocities/airspeed-kt") < 10) {
      disableelev = 1;
      disableaile = 1;
    }
    if (getprop("orientation/roll-deg") < -90 or getprop("orientation/roll-deg") > 90) {
      disableelev = 1;
    }
    # Elevator
    if (disableelev == 0){
      # not moving controls, criteria met and fcs enabled
      setprop("/autopilot/locks/fcs","1g");
      if (getprop("f22/fcs/controls/pitch") == 0) {
         setprop("f22/fcs/controls/pitch",getprop("orientation/pitch-deg")); # Set holding point
      }
    } else {
      setprop("f22/fcs/controls/elevator",0);
      setprop("f22/fcs/controls/rudder",0);
      setprop("f22/fcs/controls/pitch",0);
      setprop("/autopilot/locks/fcs","");
    }

    # Aileron
    if (disableaile == 0){
      # not moving controls, criteria met and fcs enabled
      setprop("/autopilot/locks/fcsaileron","1g");
      if (getprop("f22/fcs/controls/roll") == 0) {
         setprop("f22/fcs/controls/roll",getprop("orientation/roll-deg")); # Set holding point
      }
    } else {
      setprop("f22/fcs/controls/aileron",0);
      setprop("f22/fcs/controls/roll",0);
      setprop("/autopilot/locks/fcsaileron","");
    }
}

fcstimer = maketimer(0.1,fcsloop);
fcstimer.start();