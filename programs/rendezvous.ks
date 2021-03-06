@lazyglobal off.
// Program Template

local programName is "rendezvous". //<------- put the name of the script here

// Header allowing for standalone operation.
//   If this program is to be used as part of a complete mission, run this script without parameters, and
//   then call the functions in the available_programs lexicon in the correct order of events for the mission
//   to build the MISSION_PLAN.
    // If you modify the number of parameters, be sure to fix the function call at the bottom of this file.
declare parameter p1 is "". 
declare parameter p2 is "". 

if not (defined available_programs) declare global available_programs is lexicon().
if not (defined kernel_ctl) runpath("0:/lib/core/kernel.ks"). 

//Add initialzer for this program sequence to the lexicon of available programs
// Could be written as available_programs:add...but that occasionally produces an error when run as a standalone script.
set available_programs[programName] to {
   //One time initialization code.
   //   Question: Why not simply have a script file with the contents of the initializer delegate?  Why the extra layers?
   //   Answer: It seems that the memory area for parameters passed to scripts is always the same.  So, when 
   //           a script defines a function to be called later, any additional script called with parameters will
   //           clobber the parameter intended for the first one.  The parameter below will be preserved and its value
   //           will remain available to the program, as long as the program is written within this scope, 
  
//======== Imports needed by the program =====
   if not (defined transfer_ctl) runpath("0:/lib/transfer_ctl.ks").
   if not (defined maneuver_ctl) runpath("0:/lib/maneuver_ctl.ks").
   
//======== Parameters used by the program ====
   // Don't forget to update the standalone system, above, if you change the number of parameters here.
   declare parameter engineName.
   declare parameter targetName.

//======== Local Variables =====

//=============== Begin program sequence Definition ===============================
   // The actual instructions implementing the program are in delegates, Which the initializer adds to the MISSION_PLAN.
   // In this case, the first part of the program sequence
   // is given as an anonymous function, and the second part is a function implemented in the maneuver_ctl library. 
   // If you do not like anonymous functions, you could implement a named function elsewhere and add a reference
   // to it to the MISSION_PLAN instead, like so: MISSION_PLAN:add(named_function@).

      local t is time:seconds.
   
      MISSION_PLAN:add({
         if not hastarget set target to targetName.
         if not hasnode {
            local mnvr is node(transfer_ctl["etaPhaseAngle"]()+time:seconds, 0,0, transfer_ctl["dv"]("Kerbin", target)).
            add(mnvr).
            set t to mnvr:eta+mnvr:orbit:period/2+time:seconds.

            maneuver_ctl["add_burn"]("node", "wolfhound", "node", mnvr:deltav:mag).
         }
         return OP_FINISHED.
      }).
      MISSION_PLAN:add(maneuver_ctl["burn_monitor"]).
      MISSION_PLAN:add({

         local dist is {return (positionat(target, time:seconds)-positionat(ship, time:seconds)).}.
         local relVelocity is {return (ship:velocity:orbit - target:velocity:orbit).}.
         local velToward is {return relVelocity():mag*cos(vang(relVelocity(), dist())).}.  //speed toward target
         print "toward: "+velToward() at(0, 5).
         print "RelVelocity: "+relVelocity():mag at(0, 6).
         lock steering to -1*relVelocity().
         if dist():mag < 150 {
            if relVelocity():mag < 1 {
               lock throttle to 0.
               lock steeering to ship:prograde.
               return OP_FINISHED.
            } else if relVelocity():mag > 1 {
               lock steering to -1*relVelocity().
               wait until vang(-1*(ship:velocity:orbit - target:velocity:orbit), ship:facing:forevector) < 1.
               lock throttle to abs(relVelocity():mag)/100.
            }
         } else {
            if velToward() < -0.5 {
               wait until vang(-1*relVelocity(), ship:facing:forevector) < 1.
               lock throttle to abs(relVelocity():mag)/100.
               wait until abs(relVelocity():mag) < 1.
               lock throttle to 0.
            } else if abs(velToward()) < 5 and relVelocity():mag < 6 {
               lock steering to dist().
               wait until vang(dist(), ship:facing:forevector) < 1.
               lock throttle to 0.1.
               wait until abs((ship:velocity:orbit - target:velocity:orbit):mag) > dist():mag/180. //
               lock throttle to 0.
            }
         }
         return OP_CONTINUE.
      }).
         
         
         
//========== End program sequence ===============================
   
}. //End of initializer delegate

// If run standalone, initialize the MISSION_PLAN and run it.
if p1 {
   available_programs[programName](p1).
   kernel_ctl["start"]().
   shutdown.
} 
