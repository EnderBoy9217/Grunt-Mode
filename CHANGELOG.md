# Changelog

# 2.12.2
* List of all grunt classes and their upgrades now included as a Markdown file

# 2.12.1
* Updated Thunderstore formatting

# 2.12.0
* AI now will contribute to hardpoints (each AI soldier counts as half a player)
* Increased default number of max players capturing a hardpoint to 5
* Added conVar to quickly change the max players contributing to hardpoint progress
* Heavily improved compatibility with other modes
* Individual class progression and overall progresssion now working in other modes
* Bounty hunt confirmed to be fully working

# 2.11.1
* Updated for most recent Northstar Release (Thank you to my community for pointing this out!)

# 2.11.0
* Increased melee knockback
* Spectres get additional melee knockback
* Melee damage slightly reduced for grunts
* Melee damage slightly increased for spectres
* AI Pilot Weapon accuracy doubled
* AI Pilots can now utilize the Kraber and Smart Pistol
* AI Pilot health 300 -> 250
* Special AI Units now drop their respective grenade
* Normal grunts have a 1/8 chance to drop their grenade
* All players (excluding next-gen pilots) will drop their grenade

# 2.10.2

* Fixed Specialist Upgrade Pop-Ups not correctly displaying
* Fixed desync issue with Sniper Spectre's doubletake
* Fixed issue where Sniper Spectre would not spawn with doubletake
* Fixed Crash when someone gains another turret after they leave

# 2.10.1

Economy:

* Killing a player on an enemy hardpoint awards an extra 3 (spendable) points
* Killing a player on a friendly hardpoint awards an extra 4 points
* Extra 5 points for hardpoint siege or snipe
* Extra 3 points for perimeter defense
* 5 points for hardpoint capture or amp
* 2 points for holding an amped hardpoint

# 2.10.0

NEW GAMEMODES:
- Grunt vs. Grunt (Players only)
- Hardpoint Attrition

Gameplay:
- Reapers now have a 25% of blowing up when they die
- Player droppods now have an exploding door
- Droppods have a new spawn animation

Economy:
- Drones now give 1 point per kill
- Turrets now give 3 points per kill

UI:
- Score popups no longer appear for 0 point kills (like MRVNs or worker drones)
- "Respawning as" now use popups instead of SendHudMessage (smooth animation + backend improvements)

Server Hosting:
- Set default MRVN count to 0 (can still be changed)
- Set default Gunship count to 0 (can still be changed, though gunships are buggy)

Bugs:
- Fixed Sniper Spectre Amped weapons unlock constantly popping up
- Fixed issue where Specialist and Sentry tech "ready to redeploy" messages appearing after you have changed loadouts
- Fixed issue where Specialists sometimes run out of drones to spawn
- Fixed some issues with Spectre Leader displaying incorrect point values after unlocks
- Fixed an issue where spectre leader unlocked blast spectre too early
- Cleaned up and improved some old code (Im getting better :)
- Improved Compatability with other modes (Modes like bounty hunt should work)
- Reworked point giver notification to be compatible with other modes
- Score for capturing/assaulting hardpoints is now combined into the "defense" score tab

# 2.9.0

- Nerfed reaper health (10000 -> 8000)
- Increased droppod spawn rate when a team is low on NPCs
- AI Specialists have a chance to have Fast Reload on their weapons
- AI Spectre Leaders have a chance to have Extended Mag on their weapons

Economy:
- Improved assist scoring to make it more readable + count toward unlocks (it will also add to your leaderboard score)
- Reduced some values to unlock classes

Classes:
- Upon unlocking a new attachment you will instantly recieve it
- Most classes have an extra attachment they can unlock
- Attachments are given to players when they are unlocked
- Fixed sending unlock messages twice
- Added Individual Class scores in the class choosing text
- Blast Spectre blast ability heavy damage reduced ( 20000 -> 8000 ) [No more one shotting dropships/titans, you had your fun]
- Pilot RE-45 now has Quickscope
- (More info in the txt file)

Server Hosting:
- Added ConVars for AI counts
- Added ConVars for Attrition escalation
- Added ConVars for class unlocks
- Added ConVars for OP Pilot unlock types (Any class, Free classes, Grunt Classes, or only Rifleman) [Default is now any grunt class]
- Added ConVars for attachment unlocks
- Added ConVars for class prices

# 2.8.0

New Classes:
1. Sniper
* Costing 10 points
* Equipped with a DMR, P2016, and an archer
* This class excels at dealing high damage at long ranges
* Unlock by getting 10 kills with the Marksman class
* More details in-game
2. *I couldn't tell you*
* Unlock by getting a 10 killstreak as a rifleman
* Find details after unlocking

Classes:
- You can now spawn as a sniper initially
- Blast Spectres no longer have double jump
- Sniper Spectre cost decreased to 30
- Sniper Spectre must now earn amped weapons
- Spectre Leader cost decreased to 40

**NEW CLASS UNLOCKS**
1. Spectre - Get 5 kills as a grunt
2. Sniper Spectre - Get 5 kills as a Spectre
3. Spectre Leader - Get 10 kills as a Spectre or Sniper Spectre
4. Blast Spectre - Get 5 kills as a Spectre Leader
5. Sentry Tech - Spawn 5 drones as a Specialist
6. Pilot - Get 20 kills as a grunt

**NEW ATTACHMENT UNLOCKS**
- Available weapon optics will unlock after 15 points with any class
- Available weapon upgrades/attachments (including threat scopes) will unlock after 30 points with any class
- Classes with 2 upgrades/attachments will unlock them individually after 20 point increments
- Pilots do not have to unlock their attachments

AI:
- AI will now refer to you as a standard grunt
- New AI Spectre Leader

Voicelines:
- Added 2 new voicelines when spotting enemy grunts
- Added 2 voicelines when spotting enemy reapers
- Added voicelines when spotting friendly spectres, reapers, or titans
- Removed ability for spectres or specialists to say grunt voicelines when spotting

UI:
- Changed too-many points from [LOCKED] to [$$$] for clarity
- Moved class info to right side of screen
- Moved class info slightly up
- Added 11 info tips, one will appear every 1-2 minutes
- Added points at top of class info screen

Bug fixes:
- Fixed bug where you wouldn't spawn in droppod if the game is in epilouge phase

Backend:
- Un-hardcoded class locking
- Added extra failsafe to prevent a spawn-as-locked-classes cheat

# 2.7.2

Bug Fixes:
- Fixed crash when trying to spawn a player in a dropship on a non-dropship map on round start (Last known crash)
- Added failsafe, because of it every player's first spawn will be a normal spawn

Gameplay:
- You will always join an existing dropship if it is available (Excluding pilots/spectres)
- Changed spawn chances to:
- * Create dropship 10%
- * Create droppod 40%
- * Normal Spawn 50%

# 2.7.1

Bug Fixes:
- Added failsafe for attempting to spawn player multiple times
- Fixed crash regarding last issue



Gameplay
- If a dropship is available, instead of spawning without an animation you will spawn in the dropship
- If the map you are currently playing on doesn't have defined/unobstructed dropship spawns, it will spawn you in a droppod instead (Dropship map whitelist)



# 2.7.0

Gameplay:
- Added Dropship Respawns (Only available for non-spectres) // 30% chance
- Teams have a default maximum of 1 dropship, but can have multiple if a pilot is spawning in
- Added Normal Respawns // 40% chance
- Droppod respawns now have a 30% chance
- Hero dropships and epilouge dropships have hugely reduced health pools ( 20000 -> 10300 )
- Added some of VoyageDB's spawn code, this will keep teams more organized and grouped together, and will reduce out-of-bounds spawns or spawnkilling

AI:
- Increased Stalker health
- Specialists now correctly spawn
- Specialists will have the communications model of the opposing team, and a special nametag
- Grunt dropships will spawn with a leader unit (either a shield captain or specialist)
- Grunt droppods will also spawn with a leader unit, but have a 33% chance not to
- Spectre droppods will no longer spawn with a leader unit
- Droppod AI now have correct weapons
- Leaders now have specialized weapons
- New AI Weapons
- Spectres spawn later in the round
- Leaders now have secondaries
- Shield captains may have attachments

UI:
- You should now be able to see friendly dropships, titans, and reapers from across the map
- Edited the Pilot description to fit the new changes
- Spawn Zones have been added to the minimap

Classes:
- Pilots will always create a new dropship and be the first person in it
- Pilots now have a kunai as a melee weapon (BUFF)

Economy:
- Specialists are now worth 4 points

Bug Fixes:
- Fixed Crash on maps with no dropship spawns
- Fixed crash from AI trying to gain score from assists
- Fixed crash when trying to set the squad leader to an unspecified person
- Spectres who try to enter a dropship / grunts to a full dropship will be sent in via drop pod
- Fixed rare crash where a pilot had an archer

### Backend:
- Minor Optimizations/cleanup all around


# 2.6.1

Backend:
- Prevented AI attempting to gain currency from assists against players

Gameplay:
- Grunt droppods will have a 50% chance of spawning a specialist, not a shield captain (shield captains still spawn 100% of the time from dropships)
Specialists will also spawn in 50% of spectre droppods

+ AI Shield Captains have a 50% chance of spawning with a grunt droppod
+ AI Specialists will spawn with every spectre droppod
+ No special units will be dropped with Stalkers
+ Increased Stalker Health


# 2.6.0

AI:
+ New AI Specialists (33% chance to spawn in Spectre Droppods)
+ New AI Shield Captains (33% chance to spawn in Grunt Droppods and always spawns in an AI Dropship)
+ New Stalker Drop Pods (Thanks VoyageDB for adding a failsafe I would otherwise have to create myself)

Gameplay:
- Removed Volt from stalker weapon pool

Economy:
+ AI Specialists give 5 points
+ AI Shield Captains give 5 points
+ AI Stalkers give 3 points
This should lead to players getting more points by targeting certain AI, making more points available

Backend:
+ Further Optimized player kill scores
+ Improved Level Escalation
- Removed Unused/unhelpful code snippets

Known Issues:
- AI Specialists have to use the Spectre model

# 2.5.4

Gameplay:
+ Suicide Spectre now gives 5 points upon attempted suicide
+ Suicide Spectre maximum hold time increased from 3.5 -> 5

# 2.5.3

Gameplay:
+ Points are awarded for assists (and scale with enemy class)
+ Fixed rodeo exploit, servers should be more stable

Backend:
+ Added ways to add to player points
- Removed unncessary anti-rodeo features

# 2.5.1
Gameplay:
+ 8 extra points are now awarded for destorying a dropship
+ Friendly AI will only be highlighted when within Line-Of-Sight (Does not apply to heavy armor units)
+ Gunships should now have longer firing bursts
+ Reworked Class system so spectre/specialist variants have to purchase their initial class first (should lead to some more linear and meaningful progression)
+ Enemy Grunt names will only show when aimed at

Classes:
+ Added Suicide Spectre Class
+ Added Spectre Leader Class
+ Improved Pilot Sliding
+ Pilot not affected by increase in gravity
+ Fixed rare occurance of rifleman having reduced health
+ Sniper Spectre now gets a charge rifle
+ Specialist now gets 1 extra drone every 20 seconds after using both drones
+ Sentry Tech now gets 1 extra turret every 30 seconds after using both turrets
+ Added tooltip for when your drone/turret regenerates
- Reduced Spectre Glide/Airstrafing capabilities

Backend:
+ Improved code
+ Added failsafes for potential crashes
+ Classes are now defined as mechanical or non-mechanical
+ Everyone now gets infinite tick glitch (Yay --communism-- canada)

# 2.3

## Classes:
+ **New class: Sentry Technician** - This class is able to place down 2 light anti-personnel sentry turrets, and are equipped with a cold war to deal with both large threats and groups of enemies, find more information in-game

+ Sniper Spectre weapons are now amped

+ Shield captains wall now follows him around

## AI:
+ Grunts will now spawn in dropships when able

+ Drones will no longer self-destruct

+ Sentry turrets will no longer self-destruct

- Reduced number of MRVNs by default

## Economy:
+ Killing AI Pilots now award 8 points instead of 1

+ Other economy changes

### Bug Fixes:

- Certain players can no longer spawn over 2 drones as a specialist


# 2.1.1:

**You can no longer rodeo while a pilot is entering a titan**