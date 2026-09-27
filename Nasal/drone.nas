# turns a fg plane into a drone that can be controlled via mp-chat
# Modified by Phoenix
####THOUGHTS
#Decrease amount of elevators during phase 0/1 of takeoff for more control.
#Decrease roll during takeoff
#Make control of UAV not the MPchat - DONE! Securecomm now in opeartion!
#Because its super easy to spoof someone
var bomber = 1;
# The stealth and secure communication method
setprop("controls/drone/ispublic",0);

var agl_threshold2 = 1000;

var agl_threshold = 300;
var stall_threshold = 120;

var oppfunc = func(heading) {
    var opposite = 0;
    if (heading == 0) {
        opposite == 180;
    }   elsif (heading > 0) {
        opposite = heading - 180;
    }   else {
        opposite = heading + 180
    }
    print(opposite);
return opposite;
}



if (getprop("controls/drone/takeoffpitch") == nil){ # Sometimes AI.nas on civil planes is cool. ill put this here
    setprop("controls/drone/takeoffpitch",30);
}


var last_comm_time = systime();
setprop("/controls/drone/bomb","JDAM"); # Bomber Weapon
setprop("/controls/drone/bomber-mode",num(0)); # Bomber
setprop("/controls/flight/computer",1); # For the FDM
setprop("/controls/drone/enable",0); # Master Switch
setprop("/controls/drone/owner",""); # Owner Callsign
setprop("/controls/drone/mode","free-flight");
setprop("/controls/drone/stall_safety","armed");
setprop("/controls/drone/agl_safety","disarmed");
setprop("/controls/drone/damaged","false"); 
setprop("/payload/armament/msg",0); # Damage
setprop("/controls/drone/pattern",0);
setprop("/controls/drone/pattern-dir","-1");
setprop("/controls/drone/pattern-tightness",2); #1 = slow, 2 = normal, 3 = quick, 4 = supaquick!
setprop("/controls/gear/brake-parking",1);
setprop("/controls/drone/securecomm",0);  # Secure drone communication
setprop("/controls/drone/landcs","none"); # Landing marker callsign
setprop("/controls/drone/hist","none");   # Secure drone communication 
setprop("/controls/drone/autointercept",0); # SCCIS
setprop("/controls/drone/usecommnet",0); # Ability to use my sattelites communication network
# takeoff stuff
setprop("/commnet/message","");
setprop("/controls/drone/takeoff-landing/takeoff-stage",0);
setprop("controls/drone/pulluptimer",6.5); # the higher the number. the farther from the ground it takes to pull up. if you have this at like 3. it wont pull up untill its 3 seconds away from hiting the ground
setprop("/controls/drone/pullupsaftey","disarmed");
setprop("controls/drone/recoveralt",2000); # This is the altitude in which the drone "recovers" after being triggered pullup warning
setprop("controls/drone/followenabled",0);
setprop("/controls/drone/landafter",0); # Fly to land after
if (getprop("/controls/drone/securecomm") == 0) {
    print("drone.nas: INIT");
}

############################################
####MP CHAT COMMANDS
############################################

var incoming_listener = func {
    if (getprop("/controls/drone/securecomm") == 0) {
        var history = getprop("/sim/multiplay/chat-history");
    } else {
        if (getprop("controls/drone/usecommnet") != 1){
            var history = getprop("/controls/drone/hist");
        } else {
            var history = getprop("/commnet/message");
            screen.log.write("drone.nas: commnet enabled");
            if (getprop("commnet/message") != getprop("controls/drone/nethistold")) {
                print("ae");
            } else {
                screen.log.write("No no command from commnet");
                return 1;
            }
        }
    }
    var hist_vector = split("\n", history);
    var drone_cs = getprop("/sim/multiplay/callsign");
    if (size(hist_vector) > 0) {
        var last = hist_vector[size(hist_vector)-1];
        var last_vector = split(" ", last);
        var author = last_vector[0];
      author = left(author,size(author)-1);
        callsign = getprop("/controls/drone/owner");
        
        if ( last_vector[1] == drone_cs or last_vector[1] == "commandall" and size(last_vector) > 1 ) {
            if ( last_vector[2] == "control" and last_vector[3] == "request" ) {
                #request control of the drone
                #will hand over control after 15 minutes of no comms from owner.
                var cur_time = systime();
                if ( getprop("/controls/drone/owner") == "" ) {
                    setprop("/controls/drone/owner",author);
                    if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat","Drone owner set to: " ~ author);
                    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone owner set to: " ~ author ~ " Secure COMM Enabled");
        }
                } elsif ( cur_time - last_comm_time > 900 ) {
                    setprop("/controls/drone/owner",author);
                        if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat","Drone owner changed to: " ~ author);
                        } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone owner changed to: " ~ author);
                        }
                } else {
                        if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat","Current owner is: " ~ getprop("controls/drone/owner") ~ " - please wait for " ~ int(900 - (cur_time - last_comm_time)) ~ " seconds or request control from owner.");
                        }
                }
            } elsif (size(last_vector) > 2 and author == callsign or getprop("controls/drone/ispublic") == 1) {
            
                if ( last_vector[2] == "enable" ) {
                    #enable remote control
                    setprop("/controls/drone/enable",1);
                    
                    #freeze fuel
                    setprop("/sim/freeze/fuel","true");
    
                    #setup airport
                    setprop("/sim/tower/auto-position","false");
                    setprop("/controls/drone/base",getprop("/sim/airport/closest-airport-id"));
                    
                    #enable autopilot
                    setprop("/autopilot/locks/heading","dg-heading-hold");
                    setprop("/autopilot/locks/altitude","altitude-hold");
                    setprop("/autopilot/locks/speed","speed-with-throttle");

                    setprop("/autopilot/settings/target-altitude-ft",getprop("/position/altitude-ft"));
                    setprop("/autopilot/settings/target-speed-kt",int(getprop("/velocities/groundspeed-kt")));
                    setprop("/autopilot/settings/heading-bug-deg",getprop("/orientation/heading-magnetic-deg"));
                    setprop("/autopilot/settings/true-heading-deg",getprop("/orientation/heading-deg")); # guide drone to taxi marker
                    
               #if everything worked, update over chat.
                   if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat", "Drone control enabled");
                   } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone control enabled");
                        }
                    # Manual flight control  4 elevator 5 aileron 6 rudder 7 throttle
                } elsif ( last_vector[2] == "manual" and last_vector[3] == "control" and last_vector[4] != nil and last_vector[5] != nil and last_vector[6] != nil and last_vector[7] != nil) {
                    #disable drone control
                    setprop("/controls/drone/enable/",0);
                    setprop("/autopilot/locks/altitude","");
                    setprop("/autopilot/locks/heading","");
                    setprop("/autopilot/locks/speed","");
                    aitrack.setfltprop(last_vector[4],last_vector[5],last_vector[6],last_vector[7]);
                    aitrack.manualcontrol(getprop("/controls/drone/owner"));
                    
                    #let us know what's up.
                        if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat", "Drone remote control enabled");
                        } else {
                            setprop("/sim/multiplay/generic/string[8]","Manual Flight Control Actived");
                        }

                } elsif ( last_vector[2] == "fireAAM" ) {
                    setprop("/sim/multiplay/chat", "Drone Fireing Missile");
                setprop("/controls/armament/selected-weapon", "Aim-120");

                m2000_load.SelectNextPylon();
                #f22.fire(0,0); # Open the bay doors of the currently selected weapon
                var pylon = getprop("/controls/armament/missile/current-pylon");
                m2000_load.dropLoad(pylon);
                print("Should fire Missile");
                    setprop("/sim/multiplay/chat", "Fox 3!");
  } elsif ( last_vector[2] == "disable" ) {
                    #disable drone control
                    setprop("/controls/drone/enable/",0);
                    
                    #unfreeze fuel
                    setprop("/sim/freeze/fuel","false");
                    
                    #tower position stuff
                    setprop("/sim/tower/auto-position","true");            
    
                    #turn off autopilot
                    setprop("/autopilot/locks/altitude","");
                    setprop("/autopilot/locks/heading","");
                    setprop("/autopilot/locks/speed","");
                    
                    #let us know what's up.
                    if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat", "Drone control disabled");
                    } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone control disabled");
                        }

                } elsif ( last_vector[2] == "landspot" and last_vector[3] != nil ) {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone landing guidance has been set");
            } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone landing guideance has been set");
                }
                setprop("/controls/drone/landcs", last_vector[3]);

} elsif ( last_vector[2] == "landcoord" and last_vector[3] != nil and last_vector[4] != nil ) {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone lat/lon marker coordnites set");
            } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone landing coordnites #1 has been set");
                }
                setprop("/controls/AI/landpos/land1lat", num(last_vector[3]));
                setprop("/controls/AI/landpos/land1lon", num(last_vector[4]));


} elsif ( last_vector[2] == "armpullup") {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Altitude Warning Enabled");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone Altitude Warning Enabled");
            }
            setprop("controls/drone/pullupsaftey","armed");
} elsif ( last_vector[2] == "disarmpullup") {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Altitude Warning Disabled");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone Altitude Warning Disabled");
            }
            setprop("controls/drone/pullupsaftey","disarmed");
} elsif ( last_vector[2] == "pulluptime" and last_vector[3] != nil) {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Altitude Warning Set");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone Altitude Warning Set");
            }
            setprop("controls/drone/pulluptimer",num(last_vector[3]));
} elsif ( last_vector[2] == "pullupalt" and last_vector[3] != nil) {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Recovery Altitude Set");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone Recovery Altitude Set");
            }
            setprop("controls/drone/recoveralt",num(last_vector[3]));
} elsif ( last_vector[2] == "canchat") {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone AI.nas will send chat messages");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone AI.nas will send chat messages");
            }
            setprop("controls/AI/canchat",1);
} elsif ( last_vector[2] == "nochat") {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone AI.nas will not send chat messages");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone AI.nas will not send chat messages");
            }
            setprop("controls/AI/canchat",0);
} elsif ( last_vector[2] == "test-aitrack") {
            var testae = aitrack.test();
            if (testae == 1) {
                if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat", "TEST: Complete: Response: AI.nas aitrack Systems functional");
                } else {
                    setprop("/sim/multiplay/generic/string[8]","TEST: Complete: Response: AI.nas aitrack Systems functional");
                }
            } else {
                if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat", "TEST: Failed! No response");
                } else {
                    setprop("/sim/multiplay/generic/string[8]","TEST: Failed! No response");
                }                
            }

            setprop("controls/AI/canchat",0);
} elsif ( last_vector[2] == "lockcat") {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Catapult Locked!");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone Catapult Locked!");
            }
            launchcode.lockcatjsb();
} elsif ( last_vector[2] == "prepcat") {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Engines Full Power!");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone Engines Full Power!");
            }
            launchcode.prepcatjsb();
} elsif ( last_vector[2] == "launchcat") {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Catapult Launch!");
            } else {
                setprop("/sim/multiplay/generic/string[8]","Drone Catapult Launch!");
                setprop("autopilot/locks/altitude","pitch-hold");
                setprop("autopilot/settings/target-pitch-deg",30);
            }
            launchcode.launchcatjsb();
} elsif ( last_vector[2] == "nimitz" and last_vector[3] != nil) {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "MP-Nimitz: "~last_vector[3]~" Selected");
            } else {
                setprop("/sim/multiplay/generic/string[8]","MP-Nimitz: "~last_vector[3]~" Selected");
            }
            setprop("sim/mp-carriers/nimitz-callsign",last_vector[3]);
} elsif ( last_vector[2] == "landcoord2" and last_vector[3] != nil and last_vector[4] != nil ) {
            if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone lat/lon marker coordnites set");
            } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone landing coordnites #2 has been set");
                }
                setprop("/controls/AI/landpos/land2lat", num(last_vector[3]));
                setprop("/controls/AI/landpos/land2lon", num(last_vector[4]));


} elsif ( last_vector[2] == "land") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone landing");
    } else {
            setprop("/sim/multiplay/generic/string[8]","Drone landing");
        }
    setprop("/controls/AI/land", 1);
    aitrack.landing.start();
                
} elsif ( last_vector[2] == "wingman" and last_vector[3] != nil) {
    var wingmancallsign = last_vector[3];
if (getprop("/controls/drone/securecomm") == 0) {
    setprop("/sim/multiplay/chat", "Hi " ~ wingmancallsign ~ ", I am your wingman!");
    } else {
        setprop("/sim/multiplay/generic/string[8]","Hi " ~ wingmancallsign ~ ", I am your wingman!");
    }

    setprop("controls/SITU/wingman/wingman",last_vector[3]);
    setprop("controls/SITU/wingman/targetcallsign","");
    setprop("controls/SITU/wingman/status",1);
    situ.enablewingman();
} elsif ( last_vector[2] == "go-2" and last_vector[3] != nil) {

if (getprop("/controls/drone/securecomm") == 0) {
        setprop("/sim/multiplay/chat", "Roger!");
    } else {
        setprop("/sim/multiplay/generic/string[8]","Roger!");
    }
    setprop("controls/SITU/amiengaged",0);
    setprop("controls/SITU/wingman/targetcallsign",last_vector[3]);
    setprop("controls/SITU/wingman/status",2);
    setprop("controls/SITU/amiengaged",0);
                
} elsif ( last_vector[2] == "go-1") {

if (getprop("/controls/drone/securecomm") == 0) {
        setprop("/sim/multiplay/chat", "Roger.");
    } else {
        setprop("/sim/multiplay/generic/string[8]","Roger.");
    }
    setprop("controls/SITU/amiengaged",0);
    setprop("controls/SITU/wingman/status",1);
                
} elsif ( last_vector[2] == "leave") {

if (getprop("/controls/drone/securecomm") == 0) {
        setprop("/sim/multiplay/chat", "I am no longer your wingman.");
    } else {
        setprop("/sim/multiplay/generic/string[8]","I am no longer your wingman.");
    }
    setprop("controls/SITU/amiengaged",0);
    setprop("controls/SITU/wingman/status",1);
    situ.disablewingman();
                
} elsif ( last_vector[2] == "landgps") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone landing GPS mode");
    } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone landing GPS mode");
        }
                setprop("/controls/AI/land", 1);
                aitrack.gpslanding.start();
                
} elsif ( last_vector[2] == "say" and last_vector[3] != nil) {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", last_vector[3]);
    } else {
                                                    setprop("/sim/multiplay/chat", last_vector[3]);
                            setprop("/sim/multiplay/generic/string[8]","Message Sent to MPChat");

        }
                
} elsif ( last_vector[2] == "landgps2") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone landing GPS mode 2");
    } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone landing GPS mode 2");
        }
                setprop("/controls/AI/land", 1);
                aitrack.gpslanding2.start();
                
} elsif ( last_vector[2] == "land-carrier") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone landing on the carrier!");
    } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone landing on the carrier!");
        }
                setprop("/controls/AI/land", 1);
                aitrack.carrierlanding.start();
                
} elsif ( last_vector[2] == "goto-carrier") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone navigating to carrier. Then will land on the carrier!");
    } else {
        setprop("/sim/multiplay/generic/string[8]","Drone navigating to carrier. Then will land on the carrier!");
    }
                aitrack.carriernav.start();
                
} elsif ( last_vector[2] == "land-after") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone will land at destination airport!");
    } else {
        setprop("/sim/multiplay/generic/string[8]","Drone will land at destination airport!");
    }
                setprop("controls/drone/landafter",1);
                
} elsif ( last_vector[2] == "no-land") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone wont land at destination airport");
    } else {
        setprop("/sim/multiplay/generic/string[8]","Drone wont land at destination airport");
    }
                setprop("controls/drone/landafter",0);
                
} elsif ( last_vector[2] == "tiedown") {
    setprop("controls/tiedown",1);
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone tied down");
    } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone tied down");
        }
                
} elsif ( last_vector[2] == "remove-tiedown") {
    setprop("controls/tiedown",0);
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone ropes removed");
    } else {
                            setprop("/sim/multiplay/generic/string[8]","Drone ropes removed");
        }
                
} elsif ( last_vector[2] == "magic-level") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Magically Leveling out");
    }  else {
         setprop("/sim/multiplay/generic/string[8]","Drone Magically Leveling out");
        }

                aitrack.keepstraight.start();
                
} elsif ( last_vector[2] == "hook") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Arresting hook toggled");
    }  else {
         setprop("/sim/multiplay/generic/string[8]","Arresting hook toggled");
        }

        aitrack.togglehook();
} elsif ( last_vector[2] == "maxspeed") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Going as fast as possible");
    }

setprop("/autopilot/settings/target-speed-kt",26000);
} elsif ( last_vector[2] == "disable-magic") {
    if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone stopped Magically Leveling out");
    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone stopped Magically Leveling out");
        }


                aitrack.keepstraight.stop();
                
} elsif ( last_vector[2] == "recover") {
                aitrack.landing.stop();
                aitrack.carriernav.stop();
                if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone safe/ready to recover from the flight");
                } else {
                 setprop("/sim/multiplay/generic/string[8]","Drone safe and ready to recover from the flight");
                }
                aitrack.gpslanding2.stop();
                aitrack.gpslanding.stop();
                aitrack.carrierlanding.stop();
                setprop("/controls/drone/landairport",1);
                setprop("/controls/AI/land", 0);
                setprop("/controls/AI/landstage", 0);
                setprop("/controls/AI/flyingtocarrier", 0);
                
} elsif ( last_vector[2] == "prep") {
    aitrack.landing.stop();
    if (getprop("/controls/drone/securecomm") == 0) {
    setprop("/sim/multiplay/chat", "Preparing for combat");
    } else {
     setprop("/sim/multiplay/generic/string[8]","Preparing for combat");
    }
    aitrack.gpslanding2.stop();
    aitrack.gpslanding.stop();
    aitrack.carrierlanding.stop();
    aitrack.carriernav.start();
    setprop("/controls/AI/flyingtocarrier", 0);
    setprop("/controls/AI/land", 0);
    setprop("/controls/AI/landstage", 0);
    setprop("/sim/weight[0]/selected", "Aim-9x");
    setprop("/sim/weight[1]/selected", "Aim-120");
    setprop("/sim/weight[2]/selected", "Aim-120");
    setprop("/sim/weight[3]/selected", "Aim-120");
    setprop("/sim/weight[4]/selected", "Aim-120");
    setprop("/sim/weight[5]/selected", "Aim-120");
    setprop("/sim/weight[6]/selected", "Aim-120");
    setprop("/sim/weight[7]/selected", "Aim-120");    
    setprop("/sim/weight[8]/selected", "Aim-120");
    setprop("/sim/weight[9]/selected", "Aim-120");
    setprop("/sim/weight[10]/selected", "Aim-9x");
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
    setprop("controls/flight/wing-fold",0);              
    setprop("controls/tiedown",1);
    setprop("/autopilot/locks/heading","dg-heading-hold");
    setprop("/autopilot/locks/altitude","altitude-hold");
    setprop("/autopilot/locks/speed","speed-with-throttle");
    setprop("/autopilot/settings/target-altitude-ft",getprop("/position/altitude-ft"));
    setprop("/autopilot/settings/target-speed-kt",0);
    setprop("/autopilot/settings/heading-bug-deg",getprop("/orientation/heading-magnetic-deg"));
} elsif ( last_vector[2] == "load-wep") {
            setprop("controls/AI/weapons/weapon1/ammount",100);
            setprop("controls/AI/weapons/weapon2/ammount",100);
            if (getprop("/controls/drone/securecomm") == 0) {
            setprop("/sim/multiplay/chat", "Weapons loaded");
            } else {
             setprop("/sim/multiplay/generic/string[8]","Weapons loaded");
            }
            setprop("sim/weight[0]/selected", "Aim-9x");
            setprop("sim/weight[1]/selected", "Aim-120");
            setprop("sim/weight[2]/selected", "Aim-120");
            setprop("sim/weight[3]/selected", "Aim-120");
            setprop("sim/weight[4]/selected", "Aim-120");
            setprop("sim/weight[5]/selected", "Aim-120");
            setprop("sim/weight[6]/selected", "Aim-120");
            setprop("sim/weight[7]/selected", "Aim-120");    
            setprop("sim/weight[8]/selected", "Aim-120");
            setprop("sim/weight[9]/selected", "Aim-120");
            setprop("sim/weight[10]/selected", "Aim-9x");
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
                
} elsif ( last_vector[2] == "load-ag") {
                
            if (getprop("/controls/drone/securecomm") == 0) {
            setprop("/sim/multiplay/chat", "Weapons loaded");
            } else {
             setprop("/sim/multiplay/generic/string[8]","Weapons loaded");
            }
            setprop("sim/weight[0]/selected", "Aim-9x");
            setprop("sim/weight[1]/selected", "AGM-65");
            setprop("sim/weight[2]/selected", "AGM-65");
            setprop("sim/weight[3]/selected", "AGM-65");
            setprop("sim/weight[4]/selected", "AGM-65");
            setprop("sim/weight[5]/selected", "AGM-65");
            setprop("sim/weight[6]/selected", "AGM-65");
            setprop("sim/weight[7]/selected", "AGM-65");    
            setprop("sim/weight[8]/selected", "AGM-65");
            setprop("sim/weight[9]/selected", "AGM-65");
            setprop("sim/weight[10]/selected", "Aim-9x");
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
                
} elsif ( last_vector[2] == "remotecontrol") {
                aitrack.landing.stop();
                if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone enabled remote control");
                } else {
                 setprop("/sim/multiplay/generic/string[8]","Drone enabled remote control");
                }

                setprop("/controls/AI/land", 0);
                setprop("/controls/AI/landstage", 0);
                setprop("/controls/AI/remotecontrol", 1);
                setprop("/controls/AI/TGTCALLSIGN", getprop("controls/drone/owner"));
                aitrack.start();
                
} elsif ( last_vector[2] == "fireAAM" ) {
        if (getprop("/controls/drone/securecomm") == 0) {
                setprop("/sim/multiplay/chat", "Drone Fireing Missile");
        }
                setprop("/controls/armament/selected-weapon", "Aim-120");
                m2000_load.SelectNextPylon();
                #f22.fire(0,0); # Open the bay doors of the currently selected weapon
                var pylon = getprop("/controls/armament/missile/current-pylon");
                m2000_load.dropLoad(pylon);
                print("Should fire Missile");
                setprop("/sim/multiplay/chat", "Fox 3!");

} elsif ( last_vector[2] == "changeradar" ) {
		        radar.next_Target_Index();
		        setprop("/sim/multiplay/chat", "Changed Target");
			    var target = radar.GetTarget();
			    setprop("/sim/multiplay/chat", target);		

} elsif ( last_vector[2] == "launch" ) {
    if (getprop("/controls/drone/securecomm") == 0) {
			    setprop("/sim/multiplay/chat", "Launching UAV");
    } else {
         setprop("/sim/multiplay/generic/string[8]","Launching UAV");
    }

                setprop("/controls/gear/brake-parking", 0);
                launchcode.prelaunch();

} elsif ( last_vector[2] == "spawncarrier" ) {
        if (getprop("/controls/drone/securecomm") == 0) {
			                    setprop("/sim/multiplay/chat", "Going to nimitz carrier");
        } else {
         setprop("/sim/multiplay/generic/string[8]","Going to nimitz carrier");
        }

setprop("/position/longitude-deg", getprop("ai/models/carrier/position/longitude-deg"));
setprop("/position/latitude-deg", getprop("ai/models/carrier/position/latitude-deg"));
setprop("/position/altitude-ft", getprop("ai/models/carrier/position/deck-altitude-feet") + 18); 
#setprop("/position/longitude-deg",getprop("ai/models/carrier[2]/position/longitude-deg"));
#setprop("/position/latitude-deg", getprop("ai/models/carrier[2]/position/latitude-deg"));
#setprop("/position/altitude-ft",  getprop("ai/models/carrier[2]/position/deck-altitude-feet") + 18); 



} elsif ( last_vector[2] == "carrier" ) {
        if (getprop("/controls/drone/securecomm") == 0) {
			 setprop("/sim/multiplay/chat", "Launching from Carrier!");
        }  else {
         setprop("/sim/multiplay/generic/string[8]","Launching from Carrier!");
        }

        setprop("/controls/gear/brake-parking", 0);
        launchcode.launchyasim();

                } elsif ( last_vector[2] == "on" ) {
        if (getprop("/controls/drone/securecomm") == 0) {
			                    setprop("/sim/multiplay/chat", "Drone Starting Engines...");
        } else {
         setprop("/sim/multiplay/generic/string[8]","Drone Starting Engines...");
        }
            setprop("/controls/gear/brake-parking", 1);
            eng.engstart();

                } elsif ( last_vector[2] == "off" ) {
        if (getprop("/controls/drone/securecomm") == 0) {
			                    setprop("/sim/multiplay/chat", "Drone Shutting Down Engines...");
        } else {
         setprop("/sim/multiplay/generic/string[8]","Drone Shutting Down Engines...");
        }

                                setprop("/controls/gear/brake-parking", 1);
                                eng.engstop();

                } elsif ( getprop("/controls/drone/enable/") == 1 ){
                    if ( last_vector[2] == "carrier-speed" and last_vector[3] != nil ) {
                        setprop("/controls/tgt-speed-kts",num(last_vector[3]));
                        setprop("/controls/drone/mode","free-flight");
                        if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Carrier speed set to: " ~ last_vector[3]);
                        } else {
                         setprop("/sim/multiplay/generic/string[8]","Carrier speed set to: " ~ last_vector[3]);
                        }

                    }
                    if ( last_vector[2] == "carrier-heading" and last_vector[3] != nil ) {
                        setprop("/controls/target-course-deg",num(last_vector[3]));
                        setprop("/controls/drone/mode","free-flight");
                        if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Carrier heading set to: " ~ last_vector[3]);
                        } else {
                         setprop("/sim/multiplay/generic/string[8]","Carrier heading set to: " ~ last_vector[3])
                        }

                    }
                    if ( last_vector[2] == "heading" and last_vector[3] != nil ) {
                        setprop("/autopilot/settings/heading-bug-deg",num(last_vector[3]));
                        setprop("/controls/drone/mode","free-flight");
                        if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone heading set to: " ~ last_vector[3]);
                        }

                    } if ( last_vector[2] == "bomber" and last_vector[3] == "mode" and last_vector[4] != nil ) {
                        setprop("/controls/drone/bomber-mode",num(last_vector[4]));
                        setprop("/controls/drone/mode","free-flight");
                        if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone bomber mode set to: " ~ last_vector[4]);
                        }

                    } elsif ( last_vector[2] == "bomb" and last_vector[3] != nil ) {
                        setprop("/controls/drone/bomb",last_vector[3]);
    if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone bomb set to: " ~ last_vector[3]);
    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone bomb set to: " ~ last_vector[3]);
        }


                    } elsif ( last_vector[2] == "follow" and last_vector[3] != nil ) {
                        setprop("/controls/drone/mode","follow");
                        setprop("/controls/AI/TGTCALLSIGN",last_vector[3]);
                        setprop("/autopilot/locks/altitude", "agl-hold"); # Maintain MPs altitude
                        setprop("/autopilot/locks/heading", "true-heading-hold"); # ai.nas
                        setprop("controls/drone/followenabled",1); # For drone.nas not ai.nas
                        if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone Following: " ~ last_vector[3]);
                        }  else {
                         setprop("/sim/multiplay/generic/string[8]","Drone Following: " ~ last_vector[3]);
                        }

                        aitrack.start();
                        #stoppattern and start track
                    } elsif ( last_vector[2] == "stop" and last_vector[3] == "follow") {
                        setprop("/controls/drone/mode","free-flight");
                        setprop("controls/drone/followenabled",0); # For drone.nas not ai.nas
    if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone Returned to free flight");
    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone Returned to free flight");
        }

                        aitrack.stop();
                        setprop("/autopilot/locks/altitude", "altitude-hold");

                    } elsif ( last_vector[2] == "AGL" and last_vector[3] == "on" ) {
                        setprop("/controls/drone/agl_safety","armed");
                        setprop("/sim/multiplay/chat", "Low altitude warning enabled");
                    } elsif ( last_vector[2] == "AGL" and last_vector[3] == "off") {
                        setprop("/controls/drone/agl_safety","disarmed");        
                        setprop("/sim/multiplay/chat", "Low altitude warning disabled");
                        
                   } elsif ( last_vector[2] == "attack" and last_vector[3] == "on" ) {
                        setprop("/controls/AI/attack",1);
    if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Engaging target");
    }  else {
         setprop("/sim/multiplay/generic/string[8]","Engaging target");
        }

                    } elsif ( last_vector[2] == "attack" and last_vector[3] == "off") {
                        setprop("/controls/AI/attack",0);
                        aitrack.timer_attack.stop(); # stop attacking      
    if (getprop("/controls/drone/securecomm") == 0) {  
                        setprop("/sim/multiplay/chat", "Weapons are safe");
    } else {
         setprop("/sim/multiplay/generic/string[8]","Weapons are safe");
        }

                    } elsif ( last_vector[2] == "lag") {
                        setprop("/controls/AI/lagbehind", last_vector[3]);      
    if (getprop("/controls/drone/securecomm") == 0) { 
                        setprop("/sim/multiplay/chat", "Formation Lag Set");
    } else {
         setprop("/sim/multiplay/generic/string[8]","Formation Lag Set");
        }


                    } elsif ( last_vector[2] == "great" and last_vector[3] == "job!") {    
                        setprop("/sim/multiplay/chat", "Drone appreciates complement"); # lol
                    } elsif ( last_vector[2] == "altitude" and last_vector[3] != nil ) {

                        setprop("/autopilot/settings/target-altitude-ft",num(last_vector[3]));
    if (getprop("/controls/drone/securecomm") == 0) {
                    setprop("/sim/multiplay/chat", "Drone altitude set to: " ~ last_vector[3]);
    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone altitude set to: " ~ last_vector[3]);
        }
                    } elsif ( last_vector[2] == "speed" and last_vector[3] != nil ) {
                        setprop("/autopilot/settings/target-speed-kt",num(last_vector[3]));
    if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone speed set to: " ~ last_vector[3]);
    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone speed set to: " ~ last_vector[3]);
        }
                    } elsif ( last_vector[2] == "formate") {
                        setprop("controls/AI/formationmode", 1);
    if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone Enabled Automatic Formation speed");
    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone Enabled Automatic Formation speed");
        }
                    } elsif ( last_vector[2] == "runway" and last_vector[3] != nil) {
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone on final heading set");
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Drone on final heading set");
        }
                        setprop("controls/AI/landhdg", int(last_vector[3])); 
                    } elsif ( last_vector[2] == "intercept") {
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "This command only works with a Sam Control Center! Connect this UAV to one, then add callsigns to automatically intercept.");
                            } else {
                                if (getprop("/controls/drone/autointercept") == 0){
                                    # Turn it on
                                    setprop("/controls/drone/autointercept",1);
                                    setprop("/sim/multiplay/chat", "Auto Intercept Armed");
                                    return 1;
                                } 
                                if (getprop("/controls/drone/autointercept") == 1){
                                    # Turn it off
                                    setprop("/controls/drone/autointercept",0);
                                    setprop("/sim/multiplay/chat", "Auto Intercept Disarmed");
                                    aitrack.stop();
                                    setprop("controls/AI/attack",0);
                                }
                            }

                    } elsif ( last_vector[2] == "set" and last_vector[3] == "leader") {
                        situ.makemeleader();
                        if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "I am now the leader of the squadron!");
                        } else {
                          setprop("/sim/multiplay/generic/string[8]","Drone claimed leader");
                        }
                        situ.makemeleader();

                    } elsif ( last_vector[2] == "squadron" and last_vector[3] == "formate") {
                        situ.makemeleader();
                        if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "To Squadron: Formate!");
                        } else {
                          setprop("/sim/multiplay/generic/string[8]","Drone: To Squadron: Formate!");
                        }
                        situ.squadformateme();

                    } elsif ( last_vector[2] == "squadron" and last_vector[3] == "enable") {
                        setprop("controls/SITU/iamleader",0);
                        setprop("sim/multiplayer/generic/string[13]", "");

                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone joined The Squadron");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone joined the squadron. disabled leader");
                            }
                            situ.start();

                    } elsif ( last_vector[2] == "situ" and last_vector[3] == "a2a") {
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone enabled SITU A2A Awareness");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone enabled SITU A2A Awareness");
                            }
                           situ.enablea2a();

                    } elsif ( last_vector[2] == "position" and last_vector[3] != nil) {
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Formation position set");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Formation position set");
                            }
                           setprop("controls/AI/formation/heading",num(last_vector[3]));
                    } elsif ( last_vector[2] == "distance" and last_vector[3] != nil) {
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Formation positional distance set");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Formation positional distance set");
                            }
                           setprop("controls/AI/formation/distance",num(last_vector[3]));
                    }  elsif ( last_vector[2] == "situ" and last_vector[3] == "disablea2a") {
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone disabled SITU A2A Awareness");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone disabled SITU A2A Awareness");
                            }
                           situ.disablea2a();

                    } elsif ( last_vector[2] == "squadron" and last_vector[3] == "disable") {
                        setprop("controls/SITU/iamleader",0);
                        setprop("sim/multiplayer/generic/string[13]", "");

                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone left The Squadron");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone left the squadron");
                            }
                            situ.stop();

                    } elsif ( last_vector[2] == "copy" and last_vector[3] == "heading") {
                        setprop("controls/AI/formationmode", 1);
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone Will Copy Heading Within 0.3nm In Formation");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone Will Copy Heading Within 0.3nm In Formation");
                            }
                            setprop("/controls/AI/usehdgclose",1);
                    } elsif ( last_vector[2] == "normal" and last_vector[3] == "heading") {
                        setprop("controls/AI/formationmode", 1);
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone Wont Use Accurate heading up close"); 
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Drone Wont Use Accurate heading up close");
        }
        setprop("/controls/AI/usehdgclose",0);
                    } elsif ( last_vector[2] == "stop-formate") {
                        setprop("controls/AI/formationmode", 0);
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone Disabled Automatic Formation speed");
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Drone Disabled Automatic Formation speed");
        }
                    } elsif ( last_vector[2] == "pushback-mode") {
                        aitrack.braketimer.start();
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Pushback mode enabled. Go very slowly! (<10kts)");
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Pushback mode enabled.");
        }
                    } elsif ( last_vector[2] == "disable-pushback") {
                        aitrack.braketimer.stop();
                        setprop("controls/gear/brake-parking",1);
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Pushback mode disabled. Brakes engaged");
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Pushback mode disabled.");
        }
                    } elsif ( last_vector[2] == "taxi-mode" and last_vector[3] != nil) {
                        setprop("controls/AI/taximode",1);
                        #setprop("controls/AI/TGTCALLSIGN",getprop("controls/drone/owner")); # ai.nas listens to owner mp props
                        setprop("controls/AI/TGTCALLSIGN",last_vector[3]); # ai.nas listens to owner mp props
                        aitrack.start(); # Start taxi mode
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Taxi mode enabled. "~last_vector[3]~" is taxiing");
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Taxi mode enabled. "~last_vector[3]~" is taxiing");
        }
                    } elsif ( last_vector[2] == "wing-fold") {
                        setprop("controls/flight/wing-fold",!getprop("controls/flight/wing-fold"));

                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Toggling wings");
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Toggling wings.");
        }
                    } elsif ( last_vector[2] == "disable-taxi") {
                        aitrack.stop();
                        setprop("controls/AI/taximode",0);
                        setprop("controls/AI/TGTCALLSIGN","");
                        setprop("controls/gear/brake-parking",1);
                        setprop("/autopilot/locks/speed",""); # disable throttle(s)
                        setprop("/autopilot/settings/target-speed-kt",0);
                        setprop("controls/engines/engine[0]/throttle",0);
                        setprop("controls/engines/engine[1]/throttle",0);
                        setprop("controls/engines/engine[2]/throttle",0);
                        setprop("controls/engines/engine[3]/throttle",0);
                        setprop("controls/flight/rudder",0);
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Taxi mode disabled");
                            } else {
         setprop("/sim/multiplay/generic/string[8]","Taxi mode disabled.");
        }
                    } elsif ( last_vector[2] == "takeoff" ) {
                        setprop("/sim/multiplay/chat", "Drone taking off");
                        take_off_init();
                    } elsif ( last_vector[2] == "speedbrake-on" ) {
                        setprop("/sim/multiplay/chat", "Auto speedbrake");
         setprop("/sim/multiplay/generic/string[8]","speedbrake on");
                        aitrack.speedbraketimer.start();
                    } elsif ( last_vector[2] == "speedbrake-off" ) {
                        setprop("/sim/multiplay/chat", "Auto speedbrake off");
         setprop("/sim/multiplay/generic/string[8]","speedbrake off");
                        aitrack.speedbraketimer.stop();
                    } elsif ( last_vector[2] == "dogfight-speed" ) {
                        setprop("/sim/multiplay/chat", "DF speed on");
                        setprop("controls/AI/dfspeed",1);
         setprop("/sim/multiplay/generic/string[8]","df speed on");

                    } elsif ( last_vector[2] == "dogfight-speed-off" ) {
                        setprop("/sim/multiplay/chat", "DF speed off");
         setprop("/sim/multiplay/generic/string[8]","df speed off");
                        setprop("controls/AI/dfspeed",0);
                    } elsif ( last_vector[2] == "gear" and last_vector[3] == "deploy" ) {
                        setprop("/controls/gear/gear-down","true");
                        setprop("/sim/multiplay/chat", "Drone gear deployed");
                    } elsif ( last_vector[2] == "gear" and last_vector[3] == "retract" ) {
                        setprop("/controls/gear/gear-down","false");
                        setprop("/sim/multiplay/chat", "Drone gear retracted");
                    } elsif ( last_vector[2] == "brakes" and last_vector[3] == "on" ) {
                        setprop("/controls/gear/brake-parking",1);
                        setprop("/sim/multiplay/chat", "Drone brakes on");
                    } elsif ( last_vector[2] == "brakes" and last_vector[3] == "off" ) {
                        setprop("/controls/gear/brake-parking",0);
                        setprop("/sim/multiplay/chat", "Drone brakes off");
                    } elsif ( last_vector[2] == "repair" ) {
                        repair_damage();
                        
                    ####PATTERNS
                        
                    } elsif ( last_vector[2] == "pattern" and last_vector[3] == "oval" ) {
                        setprop("/controls/drone/mode","pattern");
                        setprop("/controls/drone/pattern",2);
                        setprop("/sim/multiplay/chat", "Drone flying oval pattern");
                        fly_pattern();
                    } elsif ( last_vector[2] == "pattern" and last_vector[3] == "triangle" ) {
                        setprop("/controls/drone/mode","pattern");
                        setprop("/controls/drone/pattern",3);
                        setprop("/sim/multiplay/chat", "Drone flying triangle pattern");
                        fly_pattern();
                    } elsif ( last_vector[2] == "pattern" and last_vector[3] == "square" ) {
                        setprop("/controls/drone/mode","pattern");
                        setprop("/controls/drone/pattern",4);
                        setprop("/sim/multiplay/chat", "Drone flying square pattern");
                        fly_pattern();
                    } elsif ( last_vector[2] == "pattern" and last_vector[3] == "pentagon" ) {
                        setprop("/controls/drone/mode","pattern");
                        setprop("/controls/drone/pattern",5);
                        setprop("/sim/multiplay/chat", "Drone flying pentagon pattern");
                        fly_pattern();
                    } elsif ( last_vector[2] == "pattern" and last_vector[3] == "hexagon" ){
                        setprop("/controls/drone/mode","pattern");
                        setprop("/controls/drone/pattern",6);
                        setprop("/sim/multiplay/chat", "Drone flying hexagon pattern");
                        fly_pattern();
                    } elsif ( last_vector[2] == "pattern" and last_vector[3] == "circle" ){
                        setprop("/controls/drone/mode","pattern");
                        setprop("/controls/drone/pattern",512);
                        setprop("/sim/multiplay/chat", "Drone flying circle pattern");
                        fly_pattern();
                    } elsif (last_vector[2] == "pattern" and last_vector[3] == "turn" and last_vector[4] == "left" ){
                        setprop("/controls/drone/pattern-dir","-1");
                        setprop("/sim/multiplay/chat", "Drone performing patterns turning left");
                    } elsif (last_vector[2] == "pattern" and last_vector[3] == "turn" and last_vector[4] == "right" ){
                        setprop("/controls/drone/pattern-dir","1");
                        setprop("/sim/multiplay/chat", "Drone performing patterns turning right");
                    } elsif (last_vector[2] == "pattern" and last_vector[3] == "slow" ){
                        setprop("/controls/drone/pattern-tightness",1);
                        setprop("/sim/multiplay/chat", "Drone performing patterns slowly");
                    } elsif (last_vector[2] == "pattern" and last_vector[3] == "normal" ){
                        setprop("/controls/drone/pattern-tightness",1.33);
                        setprop("/sim/multiplay/chat", "Drone performing patterns normally");
                    } elsif (last_vector[2] == "pattern" and last_vector[3] == "quick" ){
                        setprop("/controls/drone/pattern-tightness",2);
                        setprop("/sim/multiplay/chat", "Drone performing patterns quickly");
                    } elsif (last_vector[2] == "pattern" and last_vector[3] == "very" and last_vector[4] == "quick" ){
                        setprop("/controls/drone/pattern-tightness",3);
                        setprop("/sim/multiplay/chat", "Drone performing patterns very quickly");
                        
                    #### TACTICAL
                    
                    } elsif (last_vector[2] == "damage" and last_vector[3] == "off" ) {
                        setprop("/payload/armament/msg",0);
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone damage disabled");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone damage disabled");
                            }
                    } elsif (last_vector[2] == "damage" and last_vector[3] == "on" ) {
                        setprop("/payload/armament/msg",1);
    if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone damage enabled");
    } else {
         setprop("/sim/multiplay/generic/string[8]","Drone damage enabled");
        }
                    } elsif (last_vector[2] == "evade"){
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone performing random turns");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone performing random turns");
                            }
                        setprop("/controls/drone/mode","evade");
                        evade();

                    } elsif (last_vector[2] == "idle"){
                            if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone doing delayed random turns");
                            } else {
                             setprop("/sim/multiplay/generic/string[8]","Drone doing really delayed random turns");
                            }
                        setprop("/controls/drone/mode","evade");
                        random();

                    } elsif (last_vector[2] == "bfm 0"){
                        setprop("/sim/multiplay/chat", "Drone performing BFM training level 0.");
                        setprop("/controls/drone/mode","bfm 0");
                        bfm_0();
                        
                    #### DRONE REPORT    
                    
                    } elsif ( last_vector[2] == "report" ) {
                        settimer(report1,1);
                        
                    #### CHANGE OWNER
                        
                    } elsif ( last_vector[2] == "change" and last_vector[3] == "owner" and last_vector[4] != nil ) {
                        setprop("/controls/drone/owner",last_vector[4]);
                        setprop("/sim/multiplay/chat", "Drone owner changed to: " ~ last_vector[4]);
                        
                    #### FLY TO AIRPORT MODES
                    
                    } elsif ( last_vector[2] == "return" ) {
                        setprop("/controls/drone/mode","fly-to-airport");
                        setprop("/sim/tower/airport-id",getprop("/controls/drone/base"));
    if (getprop("/controls/drone/securecomm") == 0) {
                        setprop("/sim/multiplay/chat", "Drone returning to: " ~ getprop("/controls/drone/base"));
    }
                        fly_to_airport();
                    } elsif ( last_vector[2] == "fly" and last_vector[3] == "to" and last_vector[4] != nil ) {
                        setprop("/controls/drone/mode","fly-to-airport");
                  setprop("/sim/tower/latitude-deg",0);
                  setprop("/sim/tower/longitude-deg",0);
                        setprop("/sim/tower/airport-id",last_vector[4]);
                  if ( getprop("/sim/tower/latitude-deg") == 0 or getprop("/sim/tower/longitude-deg") == 0 ) {
                        if (getprop("/controls/drone/securecomm") == 0) {
                     setprop("/sim/multiplay/chat", "Drone cannot fly to " ~ last_vector[4] ~ " - not a valid airport.");
                        } else {
         setprop("/sim/multiplay/generic/string[8]","Drone cannot fly to " ~ last_vector[4] ~ " - not a valid airport.");
        }
                  } else { 
                        if (getprop("/controls/drone/securecomm") == 0) {
                           setprop("/sim/multiplay/chat", "Drone flying to: " ~ last_vector[4]);
                        } else {
         setprop("/sim/multiplay/generic/string[8]","Drone flying to: " ~ last_vector[4]);
        }
                           fly_to_airport();
                  }
                    }
                    
                last_comm_time = systime();
                
                }
            }
        }
    }

    # PhoenixCommNet stuff
    if (getprop("controls/drone/usecommnet") == 1) {
        # send message through there instead!
        # First we have to parse string[8]
        var oldstring = getprop("controls/drone/oldstring8");
        var string0 = getprop("sim/multiplay/generic/string[8]"); # our securecomm (now commnet) message
        if (oldstring != string0) {
            var string1 = ""~getprop("sim/multiplay/callsign")~": "~string0~""; # First make it look like that we are talking
            var string2 = string.replace(string1," ","_"); # Underscoreify it
            var string3 = string.replace(string2,"+","plus"); # And just for good messure
            screen.log.write("UAV Sendingmessage: "~string3~" Commnet Encoding successful");
            phoenixcommnet.sendmessage(string3); # And send it to the network
            setprop("controls/drone/oldstring8",string0);
        } else {
            screen.log.write("string8 hasnt changed!");
        }

    }
}

var report1 = func {
    setprop("/sim/multiplay/chat", "Drone speed: " ~ int(getprop("/instrumentation/airspeed-indicator/indicated-speed-kt")));
    settimer(report2,1);
}

var report2 = func {
    setprop("/sim/multiplay/chat", "Drone altitude: " ~ int(getprop("/instrumentation/altimeter/indicated-altitude-ft")));
    settimer(report3,1);
}

var report3 = func {
    setprop("/sim/multiplay/chat", "Drone heading: " ~ int(getprop("/instrumentation/magnetic-compass/indicated-heading-deg")));
    if ( getprop("controls/drone/mode") == "fly-to-airport" ) {
        settimer(report4,1);
    }
}

var report4 = func {
    setprop("/sim/multiplay/chat", "Drone destination: " ~ getprop("/sim/tower/airport-id"));
}

# Automatic Intercept System
var enableauto = func {
                   # theres a request from Remotecontrol.nas to launch because of bandit detection
                   # enable remote control
                    setprop("/controls/drone/enable",1);
                    
                    # freeze fuel
                    setprop("/sim/freeze/fuel","true");
    
                    # setup airport
                    setprop("/sim/tower/auto-position","false");
                    setprop("/controls/drone/base",getprop("/sim/airport/closest-airport-id"));
                    
                    # enable autopilot
                    setprop("/autopilot/locks/heading","dg-heading-hold");
                    setprop("/autopilot/locks/altitude","altitude-hold");
                    setprop("/autopilot/locks/speed","speed-with-throttle");

                    setprop("/autopilot/settings/target-altitude-ft",getprop("/position/altitude-ft"));
                    setprop("/autopilot/settings/target-speed-kt",int(getprop("/velocities/groundspeed-kt")));
                    setprop("/autopilot/settings/heading-bug-deg",getprop("/orientation/heading-magnetic-deg"));
                    
               # if everything worked, update over chat.
                    #setprop("/sim/multiplay/chat", "Drone Enabled and Launched externally");
                                setprop("/controls/gear/brake-parking", 0);
                                #returntobase();
                                launchcode.prelaunch();
}
setprop("controls/drone/histold","none");
setprop("controls/drone/inslot",0);
var updateremote = func(mpid) {
    print("checking slots!");
    var dronecs = getprop("/sim/multiplay/callsign");
    var slot1 = getprop("/controls/drone/slot1");
    var slot2 = getprop("/controls/drone/slot2");
    var slot3 = getprop("/controls/drone/slot3");
    var slot4 = getprop("/controls/drone/slot4");
    var inslot = 0;
    # Check Slots

    if (slot1 == dronecs) {
        inslot = 1;
        setprop("controls/drone/securecomm",1); # WE SECURE!
        # string[20] is the command feed
        var command = getprop("ai/models/multiplayer[" ~ mpid ~ "]/sim/multiplay/generic/string[4]");
        setprop("controls/drone/hist",command);
        var hist = getprop("controls/drone/hist");
        var histold = getprop("controls/drone/histold");
        setprop("controls/drone/slot",inslot);
        if (histold != hist) {
            # Command has changed
            incoming_listener();
            setprop("controls/drone/histold",hist);
        } else {
            # Command hasnt changed
            print("drone.nas command from sam control center hasnt changed");
        }


    }



    if (slot2 == dronecs) {
        print("drone.nas updateremote() in slot2");
        inslot = 2;
        setprop("controls/drone/securecomm",1); # WE SECURE!
        # string[20] is the command feed
        var command = getprop("ai/models/multiplayer[" ~ mpid ~ "]/sim/multiplay/generic/string[4]");
        setprop("controls/drone/hist",command);
        var hist = getprop("controls/drone/hist");
        var histold = getprop("controls/drone/histold");
        setprop("controls/drone/slot",inslot);
        if (histold != hist) {
            # Command has changed
            incoming_listener();
            setprop("controls/drone/histold",hist);
        } else {
            # Command hasnt changed
            print("drone.nas command from sam control center hasnt changed");
        }
    }
    if (slot3 == dronecs) {
        print("drone.nas updateremote() in slot3");
        inslot = 3;
        setprop("controls/drone/securecomm",1); # WE SECURE!
        # string[20] is the command feed
        var command = getprop("ai/models/multiplayer[" ~ mpid ~ "]/sim/multiplay/generic/string[4]");
        setprop("controls/drone/hist",command);
        var hist = getprop("controls/drone/hist");
        var histold = getprop("controls/drone/histold");
        setprop("controls/drone/slot",inslot);
        if (histold != hist) {
            # Command has changed
            incoming_listener();
            setprop("controls/drone/histold",hist);
        } else {
            # Command hasnt changed
            print("drone.nas command from sam control center hasnt changed");
        }
    }
    if (slot4 == dronecs) {
        print("drone.nas updateremote() in slot4");
        inslot = 4;
        setprop("controls/drone/securecomm",1); # WE SECURE!
        # string[20] is the command feed
        var command = getprop("ai/models/multiplayer[" ~ mpid ~ "]/sim/multiplay/generic/string[4]");
        setprop("controls/drone/hist",command);
        var hist = getprop("controls/drone/hist");
        var histold = getprop("controls/drone/histold");
        if (histold != hist) {
            # Command has changed
            incoming_listener();
            setprop("controls/drone/histold",hist);
        } else {
            # Command hasnt changed
            print("drone.nas command from sam control center hasnt changed");
        }
    }
    
    #
    # Automatic Interception System
    #    

    # Check masterarm
    if (getprop("controls/drone/autointercept") == 1) {
        print("autointercept enabled");
        var tgt1 = getprop("enemies/e1");
        var tgt2 = getprop("enemies/e2");
        var tgt3 = getprop("enemies/e3");
        var tgt4 = getprop("enemies/e4");   #
        var tgt5 = getprop("enemies/e5");   # Targets
        var tgt6 = getprop("enemies/e6");   # 
        var tgt7 = getprop("enemies/e7");
        var tgt8 = getprop("enemies/e8");
        var tgt9 = getprop("enemies/e9");
        var tgt10 = getprop("enemies/e10");
        var tgt11 = getprop("enemies/e11");
        var tgt12 = getprop("enemies/e12");
    #    misc.search(tgt1,1);
    #    misc.search(tgt2,1);
    #    misc.search(tgt3,1);
    #    misc.search(tgt4,1);
    #    misc.search(tgt5,1);   #
    #    misc.search(tgt6,1);   # Attack
    #    misc.search(tgt7,1);   #
    #    misc.search(tgt8,1);
    #    misc.search(tgt9,1);
    #    misc.search(tgt10,1);
    #    misc.search(tgt11,1);
    #    misc.search(tgt12,1);
# Gonna split it up, 3 targets per UAV!
if (inslot == 1) {
misc.search(tgt1,1);
misc.search(tgt2,1);
misc.search(tgt3,1);
}
if (inslot == 2) {
misc.search(tgt4,1);
misc.search(tgt5,1);
misc.search(tgt6,1);   
}
if (inslot == 3) {
misc.search(tgt7,1);
misc.search(tgt8,1);
misc.search(tgt9,1);   
}
if (inslot == 4) {
misc.search(tgt10,1);
misc.search(tgt11,1);
misc.search(tgt12,1); 
}

    }

}



var returntobase = func{
    setprop("/controls/drone/mode","fly-to-airport");
    setprop("/sim/tower/airport-id",getprop("/controls/drone/base"));
    setprop("/sim/multiplay/chat", "Drone Launched from: " ~ getprop("/controls/drone/base"));
    fly_to_airport();
}

# Automation
var engagebandit = func(bandit) {
    setprop("/controls/drone/mode","follow");
    setprop("/controls/AI/TGTCALLSIGN",bandit);
    setprop("/sim/multiplay/chat", "Drone Engaging: " ~ bandit);
    aitrack.start();
}


var formate = func() {
    print("ae")
}



#######################################################
#####DRONE NON-TACTICAL FLIGHT SYSTEMS
#######################################################

var take_off_init = func {
   if ( getprop ("position/altitude-agl-ft") > 100 ) {
      setprop("/sim/multiplay/chat","Drone already in air! I cant do that lol");
      return;
   }
    setprop("/autopilot/settings/target-altitude-ft",getprop("/position/altitude-ft"));
    setprop("/autopilot/settings/target-speed-kt",450);
    setprop("/controls/drone/mode","takeoff");
    take_off();
}

var take_off = func {
    if ( getprop("/controls/drone/mode") != "takeoff" ) {
        return;
    }
    setprop("/autopilot/locks/heading","taxi");
    setprop("/controls/drone/autopilot/roll-minimum",-8);
    setprop("/controls/drone/autopilot/roll-maximum",8);
    setprop("/controls/gear/brake-parking",0);
    var agl = getprop("/position/altitude-agl-ft");
    var ias = getprop("/velocities/airspeed-kt");
    var stage = getprop("/controls/drone/takeoff-landing/takeoff-stage");

    if ( ias > 170 and stage == 0 ) {
        #if our speed is greater than 175, start to climb.
        setprop("/controls/drone/takeoff-landing/takeoff-stage",1);
        setprop("/autopilot/locks/altitude","pitch-hold");
        setprop("/autopilot/settings/target-altitude-ft",getprop("/position/altitude-ft") + 8000);
        setprop("/autopilot/settings/target-pitch-deg",getprop("controls/drone/takeoffpitch"));
        setprop("/sim/multiplay/chat","beginning climb");
    } elsif ( agl > 300 and stage == 1 ) {
        #if agl is over 100 feet, we can set the climb rate to be more agressive
        setprop("/controls/drone/takeoff-landing/takeoff-stage",2);
        setprop("/autopilot/locks/altitude","altitude-hold");
        setprop("/controls/gear/gear-down","false");
        setprop("/sim/multiplay/chat","Drone airborn, retracting wheels.")
    } elsif ( agl > 700 and stage == 2 ) {
        #once we hit 500 agl, set even more aggressive climb rate, and exit take_off function
        setprop("/controls/drone/takeoff-landing/takeoff-stage",0);
        setprop("/autopilot/locks/heading","dg-heading-hold");
        setprop("/controls/drone/mode","free-flight");
        setprop("/autopilot/settings/heading-bug-deg",getprop("/orientation/heading-magnetic-deg"));
        setprop("/sim/multiplay/chat","Drone Enabled. Takeoff complete.")
    }
    settimer(take_off,1);
}

var fly_pattern = func {
    if ( getprop("controls/drone/mode") != "pattern" ){
        return;
    }
    
    var new_heading = ((360 / getprop("/controls/drone/pattern")) * getprop("/controls/drone/pattern-dir")) + getprop("/autopilot/settings/heading-bug-deg");
    if ( new_heading > 360 ){
        new_heading = new_heading - 360;
    } elsif ( new_heading < 0 ){
        new_heading = new_heading + 360;
    }
    setprop("/autopilot/settings/heading-bug-deg",new_heading);

    var time_to_next = (480 / getprop("/controls/drone/pattern-tightness")) / getprop("/controls/drone/pattern");
    settimer(fly_pattern,time_to_next);
}

var fly_to_airport = func {
    if ( getprop("/controls/drone/mode") == "fly-to-airport" ) {
        var end_loc = geo.Coord.new().set_latlon(getprop("/sim/tower/latitude-deg"),getprop("/sim/tower/longitude-deg"));
        var distance = end_loc.distance_to(geo.aircraft_position());
        var heading = end_loc.course_to(geo.aircraft_position());
        heading = heading + 180;
        if ( heading > 360 ) {
            heading = heading - 360;
        }
        if ( distance < 12500) {
            # in range!
            if (getprop("/controls/drone/landafter") == 1) {
                aitrack.autorunwaynav.start();
                setprop("/sim/multiplay/chat","Drone reached destination, Landing now");
                setprop("/controls/drone/mode","free-flight");
            } else {
                # Dont land
                heading = getprop("/autopilot/settings/heading-bug-deg") + (45 * (getprop("controls/drone/pattern-dir") * -1));
                setprop("/autopilot/settings/heading-bug-deg",heading);
                setprop("/controls/drone/pattern",64);
                setprop("/controls/drone/mode","pattern");
                setprop("/sim/multiplay/chat","Drone reached destination, entering circle pattern.");
                settimer(fly_pattern,30);
            }
        }
        setprop("/autopilot/settings/heading-bug-deg",heading);
        settimer(fly_to_airport,30);
    }
}

#######################################################
#####DRONE TACTICAL FLIGHT SYSTEMS
#######################################################

var check_aglias = func {
    var agl = getprop("/position/altitude-agl-ft");
    var ias = getprop("/velocities/airspeed-kt");
    
    if ( (agl < 5000 or ias < 240 ) and getprop("/controls/drone/damaged") == "true" ) {
        repair_damage();
        var new_alt = getprop("/position/altitude-ft") + 5000;
        setprop("/autopilot/settings/target-altitude-ft", new_alt);
        setprop("/autopilot/settings/target-speed-kt",350);
        setprop("/sim/multiplay/chat","Drone damage repaired, minimum speed/AGL threshold reached, attempting to save self.");
    } elsif ( getprop("/controls/drone/damaged") == "true" ) {
        settimer(check_aglias,.5);
    }
}

var repair_damage = func() {
    var failure_modes = FailureMgr._failmgr.failure_modes;
    var mode_list = keys(failure_modes);

    foreach(var failure_mode_id; mode_list) {
        FailureMgr.set_failure_level(failure_mode_id, 0);
    }
    
    setprop("/sim/multiplay/chat","Damage repaired.");
    setprop("/controls/drone/damaged","false");
}





var random = func {
    if ( getprop("/controls/drone/mode") != "free-flight" ) {
        return;
    } 

    var new_speed = 600 + (rand() * 300) - (rand() * 200);
    if ( new_speed < 250 ) {
        new_speed = 300 + ( rand() * 10 );
    }
    var new_heading = getprop("/autopilot/settings/heading-bug-deg") + (int(rand() * 360));
    if ( new_heading > 360 ) {
        new_heading = new_heading - 360;
    }
    var new_alt = getprop("/autopilot/settings/target-altitude-ft") + ( (rand() * 5000) - 2500 );
    if ( new_alt < (getprop("/position/altitude-ft") - getprop("/position/altitude-agl-ft")) + 1000 ) {
        new_alt = 6000;
    }

    setprop("/autopilot/settings/target-speed-kt",new_speed);
    setprop("/autopilot/settings/heading-bug-deg",new_heading);
    setprop("/autopilot/settings/target-altitude-ft",new_alt);

    var evade_timer = ( rand() * 30 ) + 150;

    settimer( random, evade_timer );
}





var evade = func {
    if ( getprop("/controls/drone/mode") != "evade" ) {
        return;
    } 

    var new_speed = getprop("/autopilot/settings/target-speed-kt") + ((rand() * 40) - 20);
    if ( new_speed < 250 ) {
        new_speed = 300 + ( rand() * 10 );
    }

    var new_heading = getprop("/autopilot/settings/heading-bug-deg") + (int(rand() * 360));
    if ( new_heading > 360 ) {
        new_heading = new_heading - 360;
    }

    var new_alt = getprop("/autopilot/settings/target-altitude-ft") + ( (rand() * 5000) - 2500 );
    if ( new_alt < (getprop("/position/altitude-ft") - getprop("/position/altitude-agl-ft")) + 1000 ) {
        new_alt = 2500;
    }

    setprop("/autopilot/settings/target-speed-kt",new_speed);
    setprop("/autopilot/settings/heading-bug-deg",new_heading);
    #setprop("/autopilot/settings/target-altitude-ft",new_alt);

    var evade_timer = ( rand() * 30 ) + 15;

    settimer( evade, evade_timer );
}


var bfm_0 = func {
    if ( getprop("/controls/drone/mode") != "bfm 0" ) {
        return;
    } 

    var new_heading = getprop("/autopilot/settings/heading-bug-deg") + (int(rand() * 360));
    if ( new_heading > 360 ) {
        new_heading = new_heading - 360;
    }

    setprop("/autopilot/settings/heading-bug-deg",new_heading);

    var bfm_0_timer = ( rand() * 30 ) + 15;

    settimer( bfm_0, bfm_0_timer );
}

###################################################
#####SAFETY LOOP
###################################################

var safety_loop = func {
    #first check if safeties are necessary - if agl > 300 and we aren't taking off.
    if ( getprop("/controls/drone/enable") == 0 or getprop("/controls/drone/mode") == "takeoff") {
        return;
    }
    if ( getprop("/position/altitude-agl-ft") < 300 and getprop("/controls/drone/agl_safety") == "armed" ) {
        
    print("AGL Warning Check On");


        aitrack.stop(); # Stop the AI tracker
        setprop("/autopilot/settings/heading-bug-deg",getprop("/orientation/heading-magnetic-deg"));# Level out the UAV
        setprop("/autopilot/locks/altitude","pitch-hold");
        setprop("/autopilot/settings/target-pitch-deg",60); # Pull up sharply
        setprop("/autopilot/settings/target-speed-kt",350);
        setprop("/controls/drone/agl_safety", "engaged"); # Let us enagage our actions
        setprop("/sim/multiplay/chat","Warning! Drone is too Low!"); # Notfiy owner
        setprop("/controls/drone/mode","free-flight");

    } 
    
    elsif ( getprop("/controls/drone/agl_safety") == "engaged" ) {
        print("AGL Safety Triggered!");
        if (getprop("/position/altitude-agl-ft") > 1000) {
                            #enable autopilot
        setprop("/autopilot/locks/heading","dg-heading-hold");
        setprop("/autopilot/locks/altitude","altitude-hold");
        setprop("/autopilot/locks/speed","speed-with-throttle");
        setprop("/autopilot/settings/target-altitude-ft",8000);
        setprop("/autopilot/settings/target-speed-kt",350);
        setprop("/autopilot/settings/heading-bug-deg",getprop("/orientation/heading-magnetic-deg"));
        setprop("/controls/drone/agl_safety","disarmed");
        setprop("/sim/multiplay/chat","Drone Recovered altitude Successfully! Actions reset to free flight. AGL disarmed");
        }
    }
    

}

###################################################
#####FCS CONTROL
###################################################

var fcs_control = func() {
    #simple fcs thingies based on ias
    
    #settings for easier changing
    
    var my_speed = getprop("/velocities/airspeed-kt");
    
    #roll
    var min_roll = 50;
    var min_roll_speed = 300;
    var max_roll = 70;
    var max_roll_speed = 600;
    
    #climb
    var min_climb_rate = 25;
    var min_climb_rate_speed = 225;
    var max_climb_rate = 65;
    var max_climb_rate_speed = 600;
    
    #set max roll degrees
    #uses 2d interpolation formula
    var roll_deg = min_roll + (my_speed - min_roll_speed) * (max_roll - min_roll) / (max_roll_speed - min_roll_speed);
    roll_deg = math.clamp( roll_deg, min_roll, max_roll );
    #print("calced r_deg: " ~ roll_deg);
    #print("my speed: " ~ my_speed);
    
    setprop("/controls/drone/autopilot/roll-minimum",-roll_deg);
    setprop("/controls/drone/autopilot/roll-maximum",roll_deg);
    
    
    #set climb rate
    var climb_rate = min_climb_rate + (my_speed - min_climb_rate_speed) * (max_climb_rate - min_climb_rate) / (max_climb_rate_speed - min_climb_rate_speed);
    climb_rate = math.clamp( climb_rate, min_climb_rate, max_climb_rate);
    setprop("/controls/drone/autopilot/min-climb-rate",-climb_rate);
    setprop("/controls/drone/autopilot/max-climb-rate",climb_rate);
    #print("calced c_r: " ~ climb_rate);
    
    
    settimer( func() { fcs_control(); }, 1);
}


var lnavupdate = func() {
    setprop("/autopilot/settings/heading-bug-deg",getprop("/instrumentation/gps/desired-course-deg") - 10);
}

lnavtimer = maketimer(5,lnavupdate);

# Button input for manual control
var buttoninput = func(a,b) {
    if (a == 2 and b == 5) {
        print("SPEEDHLD");
        if (getprop("instrumentation/afds/ap-modes/speed-mode") != "SPD"){
            setprop("instrumentation/afds/ap-modes/speed-mode","SPD");
            setprop("/autopilot/locks/speed","speed-with-throttle");
        } else {
            setprop("instrumentation/afds/ap-modes/speed-mode","");
            setprop("/autopilot/locks/speed","");
        }
    }
    if (a == 0 and b == 3) {
        print("LNAV");
        if (getprop("instrumentation/afds/ap-modes/roll-mode") != "LNAV"){
            setprop("instrumentation/afds/ap-modes/roll-mode","LNAV");
            setprop("/autopilot/locks/heading","dg-heading-hold");
            lnavtimer.start();
        } else {
            setprop("instrumentation/afds/ap-modes/roll-mode","");
            setprop("/autopilot/locks/heading","");
            lnavtimer.stop();
        }
    }
    if (a == 0 and b == 1) {
        print("HDG");
        if (getprop("instrumentation/afds/ap-modes/roll-mode") != "HDG HOLD"){
            setprop("instrumentation/afds/ap-modes/roll-mode","HDG HOLD");
            setprop("/autopilot/locks/heading","dg-heading-hold");
            lnavtimer.stop();
        } else {
            setprop("instrumentation/afds/ap-modes/roll-mode","");
            setprop("/autopilot/locks/heading","");
            
        }
    }
    if (a == 1 and b == 2) {
        print("V/S");
        if (getprop("instrumentation/afds/ap-modes/pitch-mode") != "V/S"){
            setprop("instrumentation/afds/ap-modes/pitch-mode","V/S");
            setprop("/autopilot/locks/altitude","vertical-speed-hold");
        } else {
            setprop("instrumentation/afds/ap-modes/pitch-mode","");
            setprop("/autopilot/locks/altitude","");
        }
    }
}
setprop("commnet/message","");
setprop("controls/drone/nethistold",""); # init that string
var commnetlistener = func() {
    if (getprop("controls/drone/usecommnet") == 1) {
        # scan for a new message
        if (getprop("commnet/message") != getprop("controls/drone/nethistold")) {
            screen.log.write("new message!");
            incoming_listener();
            setprop("controls/drone/nethistold",getprop("commnet/message"));
        }
    }
}

commnettimer = maketimer(0.5,commnetlistener);
commnettimer.start();



var pullupwarn = func() {
    # Pullup warning loop
    if (getprop("controls/drone/pullupsaftey") == "disarmed"){return 0;}
    print("Pullup warning enabled");
    var timer = getprop("sim/model/radar/time-until-impact");
    var timerlow = getprop("controls/drone/pulluptimer");
    if (timer < timerlow and timer != -1) {
        screen.log.write("PULLUP!");
        if (getprop("controls/drone/pullupsaftey") == "armed") {

            if (getprop("controls/AI/followenabled") == 1) {
                aitrack.stop(); # Stop all AIS
            }
            setprop("/autopilot/locks/heading","wing-leveler");
            setprop("/autopilot/locks/altitude","pitch-hold");
            setprop("/autopilot/settings/target-pitch-deg",35);
            setprop("/autopilot/locks/speed","speed-with-throttle");
            setprop("/autopilot/settings/target-speed-kt",400);
            setprop("controls/drone/pullupsaftey","activated");
        }

    }
    if (getprop("controls/drone/pullupsaftey") == "activated") {
        if (getprop("position/altitude-ft") > getprop("controls/drone/recoveralt")) {
            screen.log.write("Recovered");
            setprop("controls/drone/pullupsaftey","armed");
            setprop("/autopilot/locks/altitude","altitude-hold");
            setprop("/autopilot/locks/heading","dg-heading-hold");
            setprop("/autopilot/settings/target-altitude-ft",getprop("/position/altitude-ft"));
            if (getprop("controls/drone/followenabled") == 1) {
                aitrack.start();
                screen.log.write("Re engaging");
                            setprop("/autopilot/locks/heading","true-heading-hold");
            }
        }
    }
}



###################################################
#####INITIALIZATION
###################################################

setlistener("/sim/multiplay/chat-history", incoming_listener, 0, 0);
#setlistener("/controls/drone/damaged", check_aglias, 0, 0);


timer_safety = maketimer(0.1, safety_loop);
timer_safety.start();
timer_safety2 = maketimer(0.1, pullupwarn);
timer_safety2.start();
#safety_loop(); #currently buggy
fcs_control();
screen.log.write("drone.nas: Ready");