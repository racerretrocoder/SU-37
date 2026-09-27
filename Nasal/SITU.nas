# SITU.nas | Namespace: situ

# Written by Phoenix

# Situational awareness with friendly UAV and enemies!
# UAV Squadrons
# And air to air combat
# (and air to ground combat (wip))

# ae

print("SITU.nas: INIT...");
setprop("controls/SITU/rwrreal",1); # Use RWR realism
setprop("controls/SITU/situinstalled",1);
setprop("controls/SITU/a2arwr",0);
setprop("controls/SITU/amiengaged",0); # If we are in a tangent! lol
setprop("controls/SITU/iamleader",0);
var isUAV = 1;
setprop("controls/SITU/delay",0);
var dishdg = 75;
setprop("controls/SITU/a2gcantargetall",1);
setprop("controls/SITU/evading",0);

var newky58 = func(message) {
    var isleader = getprop("controls/SITU/iamleader");
    var situcmd = getprop("sim/multiplay/generic/string[13]");
    var evading = getprop("controls/SITU/evading");
    screen.log.write("New ky-58 message");
    screen.log.write(message);
    var thesplit = split(":", message);
    print("thesplit: ",thesplit);
    var callsign = thesplit[0];
    print("callsign: ",callsign);
    var kymsg = thesplit[1];
    print("kymsg: ",kymsg);
    var msgsplit = split(",", kymsg);
    print("msgsplit: ",msgsplit);
    command1 = msgsplit[0];
    if (command1 == "MAWACTIVE") {
        screen.log.write("Friendly UAV in squad got MAW at!");
        if (isleader == 1) {
            # Squadron member got shot at, I am the squadron leader, Not being attacked atm
            if (situcmd != "1,a") {
                # Not currently attacking anyone.
                # attack the shooter!
                command2 = msgsplit[1];
                setprop("sim/multiplay/generic/string[13]","1,a");
                setprop("sim/multiplay/generic/string[12]",command2);# Make squadron buddies attack our second target
                screen.log.write("SITU attack on shooter");
                # now check for us
                if (getprop("controls/SITU/amiengaged") == 0) {
                    var inlist = aitrack.checkattackqueuecallsign(command2);
                    if (inlist == 0) {
                        setprop("controls/AI/TGTCALLSIGN","");
                        var tgtmpid = misc.smallsearch(command2);
                        aitrack.situengage(tgtmpid,command2,0);
                    }
                }
            }
        } else {
            screen.log.write("We are not evading or a leader");
        }
    }
}


# Squadron stuff!
# first:
# Get a list of known UAVs
var updateuavlist = func(cs=nil) {
    print("SITU.nas: Function: updateuavlist()");
    # missile checks
    var mlwlauncher = getprop("payload/armament/MLW-launcher");
    var activecallsign = getprop("payload/armament/MAW-active-callsign");
    var semiactivecallsign = getprop("payload/armament/MAW-semiactive-callsign");
    var list = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var total = size(list);
    # run missile checks
    if (activecallsign != "" or semiactivecallsign != "") {
        setprop("controls/SITU/evading",1);
        screen.log.write("SITU: detected missile");
        if (activecallsign != "") {
            # notify others
            setprop("controls/SITU/amiengaged",1);
            if (KY58.getpower() == 0){
			    screen.log.write("KY58 is currently OFF. Please turn it on, And set the settings to match your copilots");
				return 0;
			} else {
			    var callsign = getprop("sim/multiplay/callsign");
                var activecallsign = getprop("payload/armament/MAW-active-callsign");
                setprop("controls/ky58/buffer","MAWACTIVE,"~activecallsign~"");
			    KY58.chat.push("" ~ callsign ~ ": " ~ getprop("controls/ky58/buffer") ~ "");
			    var message = getprop("controls/ky58/buffer");
			    screen.log.write("KY-58: " ~ callsign ~ ": "~ message ~ "",1,0.5,0);
			    setprop("sim/multiplay/generic/string[8]",getprop("controls/ky58/buffer"));
			    setprop("controls/ky58/buffer","");
            }
            screen.log.write("SITU: its an active missile!");
        }
    }



    # string[10] is the identifier string for the UAVs and the Sam Control Center most of the time
    for(var i = 0; i < total; i += 1) {
        if (getprop("ai/models/multiplayer[" ~ i ~ "]/sim/multiplay/generic/string[10]") == "UAV") {
            # UAV found is he on datalink?
            var callsign = getprop("ai/models/multiplayer[" ~ i ~ "]/callsign");
            setprop("controls/SITU/UAV/contact[" ~ i ~ "]/callsign",callsign);
            var datalink_data = datalink.get_data(callsign);
            if (datalink_data.on_link() == 1) {
                # Friendly UAV found on datalink!
                setprop("controls/SITU/UAV/contact[" ~ i ~ "]/onlink",1);
                setprop("controls/SITU/UAV/contact[" ~ i ~ "]/data1",getprop("ai/models/multiplayer[" ~ i ~ "]/sim/multiplay/generic/string[11]")); # Status, or Role of the UAV in the squad
                setprop("controls/SITU/UAV/contact[" ~ i ~ "]/data2",getprop("ai/models/multiplayer[" ~ i ~ "]/sim/multiplay/generic/string[12]")); # Extra data
                var cmd = getprop("ai/models/multiplayer[" ~ i ~ "]/sim/multiplay/generic/string[13]");
                if (cmd == "1," or cmd == "1,d" or cmd == "1,f" or cmd == "1,a") {
                    # 1 i am leader! 
                    # d dispearse from me!
                    # f formate with me!
                    # a attack my target!
                    # we are friendly UAV linked to leader
                    
                    setprop("controls/SITU/UAV/contact[" ~ i ~ "]/isuavleader",1);
                    if (cmd == "1,f") {
                        # FIRST CHECK IF WE ENGAGED
                        if (getprop("controls/SITU/amiengaged") == 1){
                            screen.log.write("Cant formate! im engaged with a bandit!");
                        } else {
                            if (getprop("controls/AI/attack") == 1) {
                                aitrack.stop();
                                setprop("controls/AI/attack",0);
                                aitrack.timer_attack.stop(); # stop attacking   
                                aitrack.weapondelaytimer.stop(); # stop attacking   
                            }
                            # We are free to do what we want!
                            aitrack.timer_attack.stop(); # stop attacking   
                            aitrack.weapondelaytimer.stop(); # stop attacking   
                            setprop("/controls/AI/attack",0);
                            setprop("/controls/AI/lagbehind",0.1);
                            setprop("/controls/AI/formationmode",1);     
                            setprop("/controls/AI/usehdgclose",0);
                            setprop("/controls/AI/TGTCALLSIGN",callsign);
                            aitrack.start();
                        }
                    }
                    if (cmd == "1,d") {
                        aitrack.stop();
                        aitrack.timer_attack.stop();
                        setprop("/controls/AI/attack",0);
                        setprop("/controls/AI/formationmode",0);     
                        setprop("/autopilot/settings/heading-bug-deg",getprop("/orientation/heading-magnetic-deg") + dishdg);
                        setprop("/autopilot/locks/heading","dg-heading-hold");
                        #setprop("/autopilot/locks/altitude","altitude-hold");
                        #setprop("/autopilot/locks/speed","speed-with-throttle");
                        delay10sec();
                    }
                    if (cmd == "1,a") {
                        if (getprop("/controls/AI/attack") == 0){
                            setprop("/controls/AI/attack",1); # Execute once!
                            setprop("/autopilot/locks/altitude", "agl-hold"); # Maintain MPs altitude
                            setprop("/autopilot/locks/heading", "true-heading-hold"); # ai.nas
                        }
                        setprop("/controls/AI/formationmode",0);
                        # check if this callsign is in our queue?
                        var banditcallsignsitu = getprop("ai/models/multiplayer[" ~ i ~ "]/sim/multiplay/generic/string[12]");
                        var inqueue = aitrack.checkattackqueuecallsign(banditcallsignsitu); # 1 its in queue | 0 its not in the queue     
                        setprop("controls/AI/TGTCALLSIGN",banditcallsignsitu);
                    }

                } else {
                    setprop("controls/SITU/UAV/contact[" ~ i ~ "]/isuavleader",0);
                }
                setprop("controls/SITU/UAV/contact[" ~ i ~ "]/data3",getprop("ai/models/multiplayer[" ~ i ~ "]/sim/multiplay/generic/string[13]")); # Command to us from member
            } else {
                # ENEMY UAV!
                setprop("controls/SITU/UAV/contact[" ~ i ~ "]/onlink",0);
            }
        } else {
            # Not a UAV
            print("mpid: "~i~" not a UAV!");
        }
    }
}

var makemeleader = func() {
    print("UAV is now the leader");
    setprop("controls/SITU/iamleader",1);
    setprop("sim/multiplay/generic/string[13]","1,");
}

var squadformateme = func() {
    # All UAVs formate on me! (if your not in a tanget)
    setprop("sim/multiplay/generic/string[13]","1,f");
}



updatesitu = maketimer (0.3,updateuavlist);

restore = func {
    updatesitu.start();
    restoresitu10.stop();
}
restoresitu10 = maketimer(10,restore);

var delay10sec = func { 
    setprop("controls/STIU/delay",10);
    updatesitu.stop();
    restoresitu10.start();
}

var start = func {
    updatesitu.start();
    setprop("controls/AI/cancheckmissile",0);
}

var stop = func {
    updatesitu.stop();
    setprop("controls/AI/cancheckmissile",1);
}


 # A 2 A

var SituAirToAirRwrSearch = func() {
    # For every multiplayer. Call situairtoairrwr
    # from me misc.nas :D
    var list = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var total = size(list);
    var mpid = 0;
    for(var i = 0; i < total; i += 1) {
        # Code loops for every MP
        SituAirToAirRwr(i);
    }
}


var SituAirToAirRwr = func(mpid) {
    # A2A Situational awareness controller
    # someone is flying a dogfighter! lets check its status
    # check if the model is installed
    print("SITU.nas: Function: SituAirToAirRwr()");
    setprop("ai/models/multiplayer[" ~ mpid ~ "]/model-installed",1); # this is to make the model name be without "[]" ae!
    var plane = getprop("ai/models/multiplayer[" ~ mpid ~ "]/model-short"); # What they are flying
    # the plane variable only works if the mplist was toggled at least once! mplist must be shown again if they change planes
    var shortType = "nil"; # lol
    var stealth = 0;
    # threat database
    if (plane == "ADF-11Fa"){ # Dont do this yet
        shortType = "Raven";
        stealth = 1;
    }
    if (plane == "F-16"){
        shortType = "16";
    }
    if (plane == "F-15C"){
        shortType = "15";
    }
    if (plane == "F-15D"){
        shortType = "15";
    }
    if (plane == "f-14b"){
        shortType = "14";
    }
    if (plane == "F-22-Raptor"){
        shortType = "Raptor";
        stealth = 1;
    }
    if (plane == "F-35A"){
        shortType = "Lightning-A";
        stealth = 1;
    }
    if (plane == "F-35B"){
        shortType = "Lightning-B";
        stealth = 1;
    }
    if (plane == "F-35C"){
        shortType = "Lightning-C";
        stealth = 1;
    }
    if (plane == "X-02"){
        shortType = "Wyvern";
        stealth = 1;
    }
    if (plane == "YFQ-42A"){
        shortType = "UCAV";
        stealth = 1;
    }
    if (plane == "SU-37"){
        shortType = "Terminator";
        stealth = 1;
    }
    if (plane == "X-02S"){
        shortType = "Strike Wyvern";
        stealth = 1;
    }
    # end the calls!
    # now is this plane a dogfighter?

    if (shortType != "nil") {
        # Military Aircraft

        if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR") == nil){
            # new bogey! 
            setprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR",0);
        }
        if (getprop("ai/models/multiplayer[" ~ mpid ~ "]sim/multiplay/generic/int[2]") == 1) {
            screen.log.write("There RWR is off");
            if (getprop("controls/SITU/rwrreal") == 1){ # Made a toggle for rwr realism
                return 1;
            }
        }
        var isradarhappy = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/in-range");
        screen.log.write("SITU.nas: Datalink check!");
        var callsign = getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign");
        var datalink_data = datalink.get_data(callsign);
        if (datalink_data != nil) { # nil detect
            if (datalink_data.on_link() == 1) {
                isradarhappy = 0; # Dont engage friendly planes!
                screen.log.write("This MPID is on datalink!");
            }
        }

        screen.log.write(isradarhappy);
        if (isradarhappy == 0) {
            print(""~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" Not in range or other factors apply :(");
        } else {
            # in range
            print(""~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" in range!!! :D");
            # ok Check if hes pointing at us
            # we do this by getting the "opposite" of bearing-deg from our radar
            # then we compare it to there real heading of direction. then we can create a range if they are in to be on "rwr"
            # opposite!
            print("computing opposite!");
            if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") == 0) {
                opposite == 180;
            }   elsif (getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") > 0) {
                opposite = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") - 180;
                print(opposite);
            }   else {
                opposite = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") + 180;
                print(opposite);
            }
            if (opposite < 0) {
                opposite = opposite + 360;
                print("added 360 to opposite!");
            }
            print("opposite: "~opposite~" of: "~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~"");
            # now we compare the opposite of the radar direction to there real heading
            # orientation/true-heading-deg
            confirmA = 0; # Confirmation logic!
            confirmB = 0; # Confirmation logic!

            # You can change the "+-60" to what ever number you want. the higher the number. the more pointer the tharget has to be. 
            # Target has to be pointing at is closely!
            if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/orientation/true-heading-deg") < opposite + 30){ # less than opposite + 20!
                confirmA = 1;
            }
            if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/orientation/true-heading-deg") > opposite - 30){ # greater than opposite - 20!
                confirmB = 1;
            }
            # Total degrees: 60
            # if target pointing at us?
            if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/velocities/true-airspeed-kt") < 20){ # If they are NOT moving
                confirmA = 0; # Dont engage non moving targets!
                confirmB = 0; # Dont engage non moving targets!
                screen.log.write("target too slow!! ae");
            }
            if (confirmA == 1 and confirmB == 1) {
                # if true-airspeed-kt > 20 mpid/velocities
                # A boogey is pointing at us
                # Did we already give him the rwr?
                screen.log.write("Confirmed");
                # check the spike!


                #
                # Confirmed boogey actions
                #

                if (getprop("payload/armament/spikee") == callsign) {
                    screen.log.write("This boogey is spiking us!!");
                    # Jump straight to 2
                    if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR") == 0) {
                        setprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR",2);
                    }
                }
                if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR") == 2){
                    print("RWR ALERT!: "~shortType~" CS:"~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" POTENTIONAL THREAT!");
                    screen.log.write("RWR ALERT!: "~shortType~" CS:"~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" POTENTIONAL THREAT!");
                    #setprop("sim/multiplay/chat","RWR: "~shortType~": UAV Engaged!"); # Phoenix: RWR: 16
                    setprop("controls/AI/attack",1);
                    setprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR",3);
                    var callsign = getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign");
                    aitrack.situengage(mpid,callsign,"ae");
                } 
                if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR") == 1){
                    print("RWR ALERT!: "~shortType~" CS:"~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" POTENTIONAL THREAT!");
                    screen.log.write("RWR ALERT!: "~shortType~" CS:"~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" POTENTIONAL THREAT!");
                    #setprop("sim/multiplay/chat","RWR: "~shortType~": Potentional Threat!"); # Phoenix: RWR: 16
                    setprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR",2);
                } 
                if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR") == 0) { # new threat!
                    # rwr spike!
                    #setprop("sim/multiplay/chat","RWR: "~shortType~":"); # Phoenix: RWR: 16
                    print("RWR ALERT!: "~shortType~" CS:"~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" Alert 1!");
                    setprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR",1);
                }
                if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR") == -1) {
                    screen.log.write("This shorttype got shot down!");
                }
            } else {
                print("Bogey not pointing at me!");
            }
        }
    } else {
        screen.log.write("ShortType is nil for mpid: "~mpid~"");
    }
}


a2atimer = maketimer(5,SituAirToAirRwrSearch);

var enablea2a = func() {
    a2atimer.start();
    setprop("sim/messages/atc","Situational Air to Air combat enabled");
    aitrack.clearqueue();
    setprop("controls/SITU/a2arwr",1);
    setprop("controls/SITU/olddrone",getprop("controls/drone/mode"));
}

var disablea2a = func() {
    a2atimer.stop();
    aitrack.stop();
    setprop("/autopilot/locks/altitude", "altitude-hold");
    setprop("sim/messages/atc","Situational Air to Air combat disabled");
    aitrack.clearqueue();
    setprop("controls/SITU/a2arwr",0);
}

# A 2 G
var SituAirToGndRwrSearch = func() {
    # For every multiplayer. Call situairtoairrwr
    # from me misc.nas :D
    var list = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var total = size(list);
    var mpid = 0;
    for(var i = 0; i < total; i += 1) {
        # Code loops for every MP
        SituAirToGndRwr(i);
    }
}


var SituAirToGndRwr = func(mpid) {
    # A2G Situational awareness controller
    # Surface to air threats are scattered across the battle field
    # Function runs on every MP
    print("SITU.nas: Function: SituAirToGndRwr()");
    setprop("ai/models/multiplayer[" ~ mpid ~ "]/model-installed",1); # this is to make the model name be without "[]" ae!
    var plane = getprop("ai/models/multiplayer[" ~ mpid ~ "]/model-short"); # What they are flying
    # the plane variable only works if the mplist was toggled at least once! mplist must be shown again if they change planes
    var shortType = -1;
    # rangedb.nas
    var callsign = getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign");
    var shortType = rangedb.getthreatmodelfromcs(callsign);
    screen.log.write(shortType);
    if (shortType != -1) {
        # Data for ground unit has been found!
        # First check the range of our guy
        var isradarhappy = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/in-range"); # This is to give the drone a set "range" of engagement
        screen.log.write("SITU.nas: Datalink check!");
        var callsign = getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign");
        var datalink_data = datalink.get_data(callsign);
        if (datalink_data != nil) { # nil detect
            if (datalink_data.on_link() == 1) {
                isradarhappy = 0; # Dont engage friendly ground units
                screen.log.write("This threatdb is on datalink!");
            }
        }

        screen.log.write(isradarhappy);
        if (isradarhappy == 0) {
            print(""~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" Not in range :(");
        } else {
            # in range and not on_link()
            # Threat identified
            print(""~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~" in range!!! :D");
            # Get opposite just in case...
            print("computing opposite!");
            var threatbearingtrue = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg");
            if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") == 0) {
                opposite == 180;
            }   elsif (getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") > 0) {
                opposite = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") - 180;
                print(opposite);
            }   else {
                opposite = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/bearing-deg") + 180;
                print(opposite);
            }
            if (opposite < 0) {
                opposite = opposite + 360;
                print("added 360 to opposite!");
            }
            print("opposite: "~opposite~" of: "~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~"");
            # Now for more threatdb stuff
            # We need information about this sam
            var threatdbid = rangedb.getthreatdbid(shortType);
            # We already know that it is listed in the DB
            print(threatdbid);
            var maxrange = getprop("controls/RNGDB/gndthreats/THREAT[" ~ threatdbid ~ "]/maxrange");
            var type = getprop("controls/RNGDB/gndthreats/THREAT[" ~ threatdbid ~ "]/type"); # How to go about killing it
            var samweapontype = getprop("controls/RNGDB/gndthreats/THREAT[" ~ threatdbid ~ "]/type"); # What to expect when were shot at
            confirmA = 0; # Confirmation logic!
            confirmB = 0; # Confirmation logic!
            var threatignore = 0;
            var ourrangetothreat = getprop("ai/models/multiplayer[" ~ mpid ~ "]/radar/range-nm");
            var engagerange = getprop("controls/RNGDB/gndthreats/THREAT[" ~ threatdbid ~ "]/minengagerange");
            # Airtoground radar spike avoid
            if (threatignore = 1) {
                screen.log.write("Will avoid the threat: "~getprop("ai/models/multiplayer[" ~ mpid ~ "]/callsign")~"");
                if (maxrange + 5 < ourrangetothreat) {
                    # We are getting too close!
                    # make a check that nothing is to the right / left of us
                    # will implement that in a bit
                    # just turn right 4 now
                    var ourhdgbug = getprop("autopilot/settings/heading-bug-deg");
                    var ourhdgtru = getprop("autopilot/settings/true-heading-deg");
                    screen.log.write("were too close to this threat!");
                    setprop("autopilot/settings/heading-bug-deg",ourhdgbug + 60); # turn away
                    setprop("autopilot/settings/true-heading-deg",ourhdgtru + 60); # turn away
                }
            }
            # Are we in engage range?
            setprop("controls/AI/agmode",1);
            if (engagerange > ourrangetothreat) {

                if (getprop("ai/models/multiplayer[" ~ mpid ~ "]/SITUAG") != 1) {
                    screen.log.write("Engaging a ground threat");
                    setprop("ai/models/multiplayer[" ~ mpid ~ "]/SITUAG",1); # engage this guy
                    aitrack.situengage(mpid,callsign,"ae");
                    setprop("autopilot/locks/heading","true-heading-hold");
                }

            }
        }
    } else {
        screen.log.write("ShortType is nil for mpid: "~mpid~"");
    }
}

a2gtimer = maketimer(5,SituAirToGndRwrSearch);

var enablea2g = func() {
    a2gtimer.start();
    setprop("sim/messages/atc","Situational Air to Ground combat enabled");
    aitrack.clearqueue();
    setprop("controls/SITU/a2arwr",1);
}

var disablea2g = func() {
    a2gtimer.stop();
    aitrack.stop();
    setprop("autopilot/locks/altitude", "altitude-hold");
    setprop("sim/messages/atc","Situational Air to Ground combat disabled");
    aitrack.clearqueue();
    setprop("controls/SITU/a2arwr",0);
}

var wingmanloop = func() {
    print("SITU.nas: missionloop()");
    var friendcallsign = getprop("controls/SITU/wingman/wingman");
    var status = getprop("controls/SITU/wingman/status");
    var targetcallsign = getprop("controls/SITU/wingman/targetcallsign");
    if (friendcallsign != nil and status != 0) {
        if (status == 1) {
            # Stick with our friend
            # We are free to do what we want!
            setprop("controls/SITU/amiengaged",0);
            aitrack.timer_attack.stop(); # stop attacking!
            aitrack.weapondelaytimer.stop(); # stop attacking!
            setprop("controls/AI/attack",0);
            setprop("controls/AI/lagbehind",0.1);
            setprop("controls/AI/formationmode",1);     
            setprop("controls/AI/usehdgclose",0);
            setprop("controls/AI/TGTCALLSIGN",friendcallsign);
            aitrack.start();
        }
        if (status == 2) { # attack an air target!
            if (getprop("controls/SITU/amiengaged") == 0){
                aitrack.stop();
                setprop("controls/AI/TGTCALLSIGN",targetcallsign);
                setprop("controls/AI/attack",1);
                setprop("controls/AI/formationmode",0);     
                setprop("controls/AI/usehdgclose",0);
                setprop("autopilot/settings/target-speed-kt",500);
                aitrack.start();
                setprop("controls/SITU/amiengaged",1);
            } else {
                var mpid = misc.smallsearch(targetcallsign);
                var therespeed = getprop("ai/models/multiplayer[" ~ mpid ~ "]/velocities/true-airspeed-kt");
                if (therespeed == nil) {
                    therespeed = getprop("ai/models/multiplayer[" ~ mpid ~ "]/velocities/airspeed-kt");
                }
                if (therespeed < 20) {
                    # kill confirmed
                    aitrack.stop();
                    setprop("controls/SITU/amiengaged",0);
                    setprop("controls/SITU/wingman/status",1);
                }
            }
        }
    }
}

wingmantimer = maketimer(1,wingmanloop);

var enablewingman = func() {
    wingmantimer.start();
    setprop("sim/messages/atc","Wingman enabled");
    aitrack.clearqueue();
    setprop("controls/SITU/a2arwr",1);
}

var disablewingman = func() {
    wingmantimer.stop();
    aitrack.stop();
    setprop("/autopilot/locks/altitude", "altitude-hold");
    setprop("sim/messages/atc","Wingman disabled.");
    aitrack.clearqueue();
    setprop("controls/SITU/a2arwr",0);
}

var reset = func(cs=nil) {
  var list = props.globals.getNode("/ai/models").getChildren("multiplayer");
  var total = size(list);
  var mpid = 0;
  
  for(var i = 0; i < total; i += 1) {
      setprop("ai/models/multiplayer[" ~ mpid ~ "]/MESITU/RWR",0);
      screen.log.write("Reset this multiplayer situ awareness rwr integers");
   }
   
}




# end SITU.nas
print("SITU.nas: Ready");