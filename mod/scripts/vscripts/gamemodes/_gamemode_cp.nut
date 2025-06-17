untyped

global function GamemodeCP_Init
global function RateSpawnpoints_CP
global function DEV_PrintHardpointsInfo

//NOTICE: ALL "PGS_ASSAULT_SCORE instances have been replaced with PGS_DEFENSE SCORE for gruntmode compatability"

// needed for sh_gamemode_cp_dialogue
global array<entity> HARDPOINTS

struct HardpointStruct
{
	entity hardpoint
	entity trigger
	entity prop

	array<entity> imcCappers
	array<entity> militiaCappers
}

struct CP_PlayerStruct
{
	entity player
	bool isOnHardpoint
	array<float> timeOnPoints //floats sorted same as in hardpoints array not by ID
}

struct {
	bool ampingEnabled = true

	array<HardpointStruct> hardpoints
	array<CP_PlayerStruct> players

	//GM Stuff
	// Due to team based escalation everything is an array
	array< int > levels = [ 0, 0 ]
	array< array< string > > podEntities = [ [ "npc_soldier" ], [ "npc_soldier" ] ]
	array< bool > reapers = [ false, false ]

	array< bool > marvins = [ false, false ]
	array< bool > prowlers = [ false, false ]
	array< bool > stalkers = [ false, false ]
	array< bool > weapondrops = [ false, false ]

	array< bool > gunships = [ false, false ]
	array< bool > pilots = [ false, false ]
	array< bool > titans = [ false, false ]
} file

void function GamemodeCP_Init()
{
	//------------------------------------------ Ported from attrition

	gruntSupportedGameMode = true
	AddCallback_GameStateEnter( eGameState.Prematch, OnPrematchStart )
	AddCallback_GameStateEnter( eGameState.Playing, OnPlaying )

	AddCallback_OnNPCKilled( GiveGruntPoints )
	AddCallback_OnPlayerKilled( GiveGruntPoints )

	if ( GetCurrentPlaylistVarInt( "aitdm_archer_grunts", 0 ) == 0 )
	{
		AiGameModes_SetNPCWeapons( "npc_soldier", [ "mp_weapon_rspn101", "mp_weapon_dmr","mp_weapon_g2", "mp_weapon_lmg", "mp_weapon_shotgun", "mp_weapon_alternator_smg", "mp_weapon_r97", "mp_weapon_car", "mp_weapon_vinson", "mp_weapon_rspn101_og","mp_weapon_rocket_launcher"] )
		AiGameModes_SetNPCWeapons( "npc_spectre", [ "mp_weapon_defender", "mp_weapon_sniper", "mp_weapon_doubletake", "mp_weapon_hemlok_smg" ] )
		AiGameModes_SetNPCWeapons( "npc_stalker", [ "mp_weapon_lstar", "mp_weapon_mastiff" ] )
	}
	else
	{
		AiGameModes_SetNPCWeapons( "npc_soldier", [ "mp_weapon_rocket_launcher" ] )
		AiGameModes_SetNPCWeapons( "npc_spectre", [ "mp_weapon_rocket_launcher" ] )
		AiGameModes_SetNPCWeapons( "npc_stalker", [ "mp_weapon_rocket_launcher" ] )
	}

	ScoreEvent_SetupEarnMeterValuesForMixedModes()

	//ClassicMP_ForceDisableEpilogue( true )
	Riff_ForceBoostAvailability( eBoostAvailability.Disabled )
	Riff_ForceTitanAvailability( eTitanAvailability.Never )

	file.levels[0] = GetConVarInt( "GRLEVEL_SPECTRES" )
	file.levels[1] = GetConVarInt( "GRLEVEL_SPECTRES" )

	// ------------------ HARDPOINT

	file.ampingEnabled = GetCurrentPlaylistVarInt( "cp_amped_capture_points", 1 ) == 1

	RegisterSignal( "HardpointCaptureStart" )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()

	AddCallback_OnPlayerKilled(GamemodeCP_OnPlayerKilled)
	AddCallback_EntitiesDidLoad( SpawnHardpoints )
	AddCallback_GameStateEnter( eGameState.Playing, StartHardpointThink )
	AddCallback_OnClientConnected(GamemodeCP_InitPlayer)
	AddCallback_OnClientDisconnected(GamemodeCP_RemovePlayer)

	ScoreEvent_SetEarnMeterValues("KillPilot",0.1,0.12)
	ScoreEvent_SetEarnMeterValues("KillTitan",0,0)
	ScoreEvent_SetEarnMeterValues("TitanKillTitan",0,0)
	ScoreEvent_SetEarnMeterValues("PilotBatteryStolen",0,35)
	ScoreEvent_SetEarnMeterValues("Headshot",0,0.02)
	ScoreEvent_SetEarnMeterValues("FirstStrike",0,0.05)

	ScoreEvent_SetEarnMeterValues("ControlPointCapture",0.1,0.1)
	ScoreEvent_SetEarnMeterValues("ControlPointHold",0.02,0.02)
	ScoreEvent_SetEarnMeterValues("ControlPointAmped",0.2,0.15)
	ScoreEvent_SetEarnMeterValues("ControlPointAmpedHold",0.05,0.05)

	ScoreEvent_SetEarnMeterValues("HardpointAssault",0.10,0.15)
	ScoreEvent_SetEarnMeterValues("HardpointDefense",0.5,0.10)
	ScoreEvent_SetEarnMeterValues("HardpointPerimeterDefense",0.1,0.12)
	ScoreEvent_SetEarnMeterValues("HardpointSiege",0.1,0.15)
	ScoreEvent_SetEarnMeterValues("HardpointSnipe",0.1,0.15)
}

void function OnPrematchStart()
{
	thread StratonHornetDogfightsIntense()
}

void function OnPlaying()
{
	// don't run spawning code if ains and nms aren't up to date
	if ( GetAINScriptVersion() == AIN_REV && GetNodeCount() != 0 )
	{
		thread SpawnIntroBatch( TEAM_MILITIA )
		thread SpawnIntroBatch( TEAM_IMC )
	}
}

void function SpawnIntroBatch( int team )
{
	if( GetMapName() != "mp_rise" && GetMapName() != "mp_wargames" && GetMapName() != "mp_crashsite3" )
	{
		array<entity> dropPodNodes = GetEntArrayByClass_Expensive( "info_spawnpoint_droppod_start" )
		array<entity> dropShipNodes = GetValidIntroDropShipSpawn( dropPodNodes )

		array<entity> podNodes
		array<entity> shipNodes

		// Sort per team
		foreach ( node in dropPodNodes )
		{
			if ( node.GetTeam() == team )
				podNodes.append( node )
		}

		// If for some reason we're missing team nodes
		// start spawner
		if( podNodes.len() == 0 )
		{
			waitthread Spawner( team )
			return
		}


		// Spawn logic
		int startIndex = 0
		bool first = true
		entity node

		int pods = RandomInt( podNodes.len() + 1 )

		int ships = shipNodes.len()

		for ( int i = 0; i < GetConVarInt( "GRTDM_SQUADS" ); i++ )
		{
			if ( pods != 0 || ships == 0 )
			{
				int index = i

				if ( index > podNodes.len() - 1 )
					index = RandomInt( podNodes.len() )

				node = podNodes[ index ]
				print("Spawned Initial Drop Pod")
				thread AiGameModes_SpawnDropPod( node.GetOrigin(), node.GetAngles(), team, "npc_soldier", SquadHandler)

				pods--
			}
			else
			{
				if ( startIndex == 0 )
				startIndex = i // save where we started

				node = shipNodes[ i - startIndex ]
				thread AiGameModes_SpawnDropShip( node.GetOrigin(), node.GetAngles(), team, 4, SquadHandler)

				ships--
			}

			// Vanilla has a delay after first spawn
			if ( first )
				wait 2

			first = false
		}

	wait 15
	}

	thread Spawner( team )
	thread SpawnerExtend( team )
	//thread SpawnerWeapons( team )
}

// Populates the match
void function Spawner( int team )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	int index = team == TEAM_MILITIA ? 0 : 1

	while( true )
	{
		if( GetGameState() == eGameState.Playing )
		{
			Escalate( team )

			// TODO: this should possibly not count scripted npc spawns, probably only the ones spawned by this script
			array<entity> npcs = GetNPCArrayOfTeam( team )
			int count = npcs.len()
			int reaperCount = GetNPCArrayEx( "npc_super_spectre", team, -1, <0,0,0>, -1 ).len()

			// REAPERS
			if ( file.reapers[ index ] )
			{
				array< entity > points = SpawnPoints_GetDropPod()
				if ( reaperCount < GetConVarInt( "GRTDM_REAPERS" ) )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					waitthread AiGameModes_SpawnReaper( node.GetOrigin(), node.GetAngles(), team, "npc_super_spectre_aitdm", ReaperHandler )
				}
			}

			// NORMAL SPAWNS
			if ( count < GetConVarInt( "GRTDM_SQUADS" ) * 4 - 2 )
			{
				string ent = file.podEntities[ index ][ RandomInt( file.podEntities[ index ].len() ) ]

				// Prefer dropship when spawning grunts
				if ( ent == "npc_soldier" )
				{
					array< entity > points = GetZiplineDropshipSpawns()
					if ( points.len() / 4 < 1 )
					{
						array< entity > points = SpawnPoints_GetDropPod()
						entity node = points[ GetSpawnPointIndex( points, team ) ]
						print("Spawned Failsafe Drop Pod " + count + " team NPCS")
						waitthread AiGameModes_SpawnDropPod( node.GetOrigin(), node.GetAngles(), team, ent, SquadHandler )
					}
					else if ( RandomInt( points.len() / 4 ) )
					{
						entity node = points[ GetSpawnPointIndex( points, team ) ]
						waitthread Aitdm_SpawnDropShip( node, team )
						continue
					}
				}
				array< entity > points = SpawnPoints_GetDropPod()
				entity node = points[ GetSpawnPointIndex( points, team ) ]
				print("Spawned Drop Pod with " + count + " team NPCS")
				waitthread AiGameModes_SpawnDropPod( node.GetOrigin(), node.GetAngles(), team, ent, SquadHandler )
			}
		}
		WaitFrame()
	}
}

void function Aitdm_SpawnDropShip( entity node, int team )
{
	thread AiGameModes_SpawnDropShip( node.GetOrigin(), node.GetAngles(), team, 4, SquadHandler )
	wait 20
}

void function SpawnerExtend( int team )
{
	//svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	int index = team == TEAM_MILITIA ? 0 : 1

	while( true )
	{
		if( GetGameState() == eGameState.Playing )
		{
			Escalate( team )

			int marvinCount = GetNPCArrayEx( "npc_marvin", team, -1, <0,0,0>, -1 ).len()
			int prowlerCount = GetNPCArrayEx( "npc_prowler", team, -1, <0,0,0>, -1 ).len()
			int stalkerCount = GetNPCArrayEx( "npc_stalker", team, -1, <0,0,0>, -1 ).len()
			int gunshipCount = GetNPCArrayEx( "npc_gunship", team, -1, <0,0,0>, -1 ).len()
	        int titanCount = GetNPCArrayEx( "npc_titan", team, -1, <0,0,0>, -1 ).len()
	        int pilotCount = GetNPCArrayEx( "npc_soldier", team, -1, <0,0,0>, -1 ).len() + GetNPCArrayEx( "npc_titan", team, -1, <0,0,0>, -1 ).len()


	        // GUNSHIPS
	        if ( file.gunships[ index ] )
			{
				array< entity > points = SpawnPoints_GetDropPod()
				if ( gunshipCount < GetConVarInt( "GRTDM_GUNSHIPS" ) )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					waitthread AiGameModes_SpawnGunShip( node.GetOrigin(), node.GetAngles(), team)
				}
			}

			// TITANS
			if ( file.titans[ index ] )
			{
				array< entity > points = SpawnPoints_GetTitan()
				if ( titanCount < GetConVarInt( "GRTDM_TITANS" ) )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					waitthread AiGameModes_SpawnTitanRandom( node.GetOrigin(), node.GetAngles(), team, TitanHandler )
				}
			}

			// PILOTS
			if ( file.pilots[ index ] )
			{
				array< entity > points = SpawnPoints_GetTitan()
				if ( pilotCount < GetConVarInt( "GRTDM_PILOTS" ) )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					//entity titan = AiGameModes_SpawnTitanRandom( node.GetOrigin(), node.GetAngles(), team, TitanHandler )
					waitthread AiGameModes_SpawnPilotCanEmbark( node.GetOrigin(), node.GetAngles(), team )
				}
			}

			// MARVINS
			if ( file.marvins[ index ] )
			{
				string ent = "npc_marvin"
				array< entity > points = SpawnPoints_GetDropPod()
				if ( marvinCount < GetConVarInt( "GRTDM_MRVNS" ) )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					//waitthread AiGameModes_SpawnDropPod( node.GetOrigin(), node.GetAngles(), team, ent )
					AiGameModes_SpawnNPC( node.GetOrigin(), node.GetAngles(), team, ent )

				}
			}

			// PROWLERS
			if ( file.prowlers[ index ] )
			{
				string ent = "npc_prowler"
				array< entity > points = SpawnPoints_GetDropPod()
				if ( prowlerCount < GetConVarInt( "GRTDM_PROWLERS" ) )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					//waitthread AiGameModes_SpawnDropPod( node.GetOrigin(), node.GetAngles(), team, ent )
					AiGameModes_SpawnNPC( node.GetOrigin(), node.GetAngles(), team, ent )

				}
			}
		}
		else
			break
		WaitFrame()
	}
}

// Based on points tries to balance match
void function Escalate( int team )
{
	int score = GameRules_GetTeamScore( team )
	int index = team == TEAM_MILITIA ? 1 : 0
	// This does the "Enemy x incoming" text
	//string defcon = team == TEAM_MILITIA ? "IMCdefcon" : "MILdefcon"

	if ( score < file.levels[ index ] )
		return

	switch ( file.levels[ index ] )
	{
		case GetConVarInt( "GRLEVEL_SPECTRES" ):
			file.levels[ index ] = GetConVarInt( "GRLEVEL_STALKERS" )
			file.marvins[ index ] = true
			file.podEntities[ index ].append( "npc_spectre" )
			//SetGlobalNetInt( defcon, 2 )
			return

		case GetConVarInt( "GRLEVEL_STALKERS" ):
			file.levels[ index ] = GetConVarInt( "GRLEVEL_REAPERS" )
			file.stalkers[ index ] = true
			file.marvins[ index ] = false
			file.weapondrops[ index ] = true
			file.prowlers[ index ] = true
			file.podEntities[ index ].append( "npc_stalker" )
			//SetGlobalNetInt( defcon, 3 )
			return

		case GetConVarInt( "GRLEVEL_REAPERS" ):
			file.levels[ index ] = GetConVarInt( "GRLEVEL_GUNSHIPS" )
			file.reapers[ index ] = true
			//SetGlobalNetInt( defcon, 4 )
			return

        case GetConVarInt( "GRLEVEL_GUNSHIPS" ):
			file.levels[ index ] = GetConVarInt( "GRLEVEL_TITANS" )
			file.gunships[ index ] = true
			//SetGlobalNetInt( defcon, 5 )
			return


		case GetConVarInt( "GRLEVEL_TITANS" ):
			file.levels[ index ] = 999999
			file.prowlers[ index ] = false
			file.pilots[ index ] = true
			file.titans[ index ] = true
			//SetGlobalNetInt( defcon, 6 )
			return
		default:
			return
	}

	unreachable // hopefully
}

//------------------------------------------------------

int function GetSpawnPointIndex( array< entity > points, int team )
{
	entity zone = DecideSpawnZone_Generic( points, team )

	if ( IsValid( zone ) )
	{
		// 20 Tries to get a random point close to the zone
		for ( int i = 0; i < 20; i++ )
		{
			int index = RandomInt( points.len() )

			if ( Distance2D( points[ index ].GetOrigin(), zone.GetOrigin() ) < 6000 )
				return index
		}
	}

	return RandomInt( points.len() )
}

//------------------------------------------------------

// tells infantry where to go
// In vanilla there seem to be preset paths ai follow to get to the other teams vone and capture it
// AI can also flee deeper into their zone suggesting someone spent way too much time on this
void function SquadHandler( array<entity> guys )
{
	// Not all maps have assaultpoints / have weird assault points ( looking at you ac )
	// So we use enemies with a large radius
	array< entity > points = GetNPCArrayOfEnemies( guys[0].GetTeam() )

	if ( points.len()  == 0 )
		return

	vector point
	point = points[ RandomInt( points.len() ) ].GetOrigin()

	array<entity> players = GetPlayerArrayOfEnemies( guys[0].GetTeam() )

	// Setup AI
	foreach ( guy in guys )
	{
		guy.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
		guy.AssaultPoint( point )
		guy.AssaultSetGoalRadius( 1600 ) // 1600 is minimum for npc_stalker, works fine for others

		// show on enemy radar
		foreach ( player in players )
			guy.Minimap_AlwaysShow( 0, player )


		//thread AITdm_CleanupBoredNPCThread( guy )
	}

	// Every 5 - 15 secs change AssaultPoint
	while ( true )
	{
		foreach ( guy in guys )
		{
			// Check if alive
			if ( !IsAlive( guy ) )
			{
				guys.removebyvalue( guy )
				continue
			}
			// Stop func if our squad has been killed off
			if ( guys.len() == 0 )
				return

			// Get point and send guy to it
			points = GetNPCArrayOfEnemies( guy.GetTeam() )
			if ( points.len() == 0 )
				WaitFrame()
				continue

			point = points[ RandomInt( points.len() ) ].GetOrigin()

			guy.AssaultPoint( point )
		}
		wait RandomFloatRange(5.0,15.0)
	}
}

void function TitanHandler( entity titan )
{
	array< entity > points = GetNPCArrayOfEnemies( titan.GetTeam() )

	if ( points.len()  == 0 )
		return

	vector point
	point = points[ RandomInt( points.len() ) ].GetOrigin()

	array<entity> players = GetPlayerArrayOfEnemies( titan.GetTeam() )

	// Setup AI
	titan.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
	//titan.SetNumRodeoSlots(0) Better method used
	titan.AssaultPoint( point )
	titan.AssaultSetGoalRadius( 1600 ) // 1600 is minimum for npc_stalker, works fine for others

	// show on enemy radar
	foreach ( player in players )
		titan.Minimap_AlwaysShow( 0, player )


	//thread AITdm_CleanupBoredNPCThread( guy )

	// Every 5 - 15 secs change AssaultPoint
	while ( true )
	{
		// Check if alive
		if ( !IsAlive( titan ) )
			return

		// Get point and send guy to it
		points = GetNPCArrayOfEnemies( titan.GetTeam() )
		if ( points.len() == 0 )
			continue

		point = points[ RandomInt( points.len() ) ].GetOrigin()

		titan.AssaultPoint( point )
		wait RandomFloatRange(5.0,15.0)
	}
}

// Award for hacking
void function OnSpectreLeeched( entity spectre, entity player )
{
	// Set Owner so we can filter in HandleScore
	spectre.SetOwner( player )
	// Add score + update network int to trigger the "Score +n" popup
	AddTeamScore( player.GetTeam(), 1 )
	player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 )
}

void function ReaperHandler( entity reaper )
{
	array<entity> players = GetPlayerArrayOfEnemies( reaper.GetTeam() )
	reaper.SetMaxHealth( 8000 )
	reaper.SetHealth( 8000 )
	foreach ( player in players )
		reaper.Minimap_AlwaysShow( 0, player )

	thread AITdm_CleanupBoredNPCThread( reaper )
}

void function AITdm_CleanupBoredNPCThread( entity guy )
{
	// track all ai that we spawn, ensure that they're never "bored" (i.e. stuck by themselves doing fuckall with nobody to see them) for too long
	// if they are, kill them so we can free up slots for more ai to spawn
	// we shouldn't ever kill ai if players would notice them die

	// NOTE: this partially covers up for the fact that we script ai alot less than vanilla probably does
	// vanilla probably messes more with making ai assaultpoint to fights when inactive and stuff like that, we don't do this so much

	guy.EndSignal( "OnDestroy" )
	wait 15.0 // cover spawning time from dropship/pod + before we start cleaning up

	int cleanupFailures = 0 // when this hits 2, cleanup the npc
	while ( cleanupFailures < 2 )
	{
		wait 10.0

		if ( guy.GetParent() != null )
			continue // never cleanup while spawning

		array<entity> otherGuys = GetPlayerArray()
		otherGuys.extend( GetNPCArrayOfTeam( GetOtherTeam( guy.GetTeam() ) ) )

		bool failedChecks = false

		foreach ( entity otherGuy in otherGuys )
		{
			// skip dead people
			if ( !IsAlive( otherGuy ) )
				continue

			failedChecks = false

			// don't kill if too close to anything
			if ( Distance( otherGuy.GetOrigin(), guy.GetOrigin() ) < 2000.0 )
				break

			// don't kill if ai or players can see them
			if ( otherGuy.IsPlayer() )
			{
				if ( PlayerCanSee( otherGuy, guy, true, 135 ) )
					break
			}
			else
			{
				if ( otherGuy.CanSee( guy ) )
					break
			}

			// don't kill if they can see any ai
			if ( guy.CanSee( otherGuy ) )
				break

			failedChecks = true
		}

		if ( failedChecks )
			cleanupFailures++
		else
			cleanupFailures--
	}

	print( "cleaning up bored npc: " + guy + " from team " + guy.GetTeam() )
	guy.Destroy()
}

//----------------------------------- HARDPOINT STUFF
void function GamemodeCP_OnPlayerKilled(entity victim, entity attacker, var damageInfo)
{
	HardpointStruct attackerCP
	HardpointStruct victimCP
	CP_PlayerStruct victimStruct
	if(!attacker.IsPlayer())
		return

	//hardpoint forever capped mitigation

	foreach(CP_PlayerStruct p in file.players)
		if(p.player==victim)
			victimStruct=p

	foreach(HardpointStruct hardpoint in file.hardpoints)
	{
		if(hardpoint.imcCappers.contains(victim))
		{
			victimCP = hardpoint
			thread removePlayerFromCapperArray_threaded(hardpoint.imcCappers,victim)
		}

		if(hardpoint.militiaCappers.contains(victim))
		{
			victimCP = hardpoint
			thread removePlayerFromCapperArray_threaded(hardpoint.militiaCappers,victim)
		}

		if(hardpoint.imcCappers.contains(attacker))
			attackerCP = hardpoint
		if(hardpoint.militiaCappers.contains(attacker))
			attackerCP = hardpoint

	}
	if(victimStruct.isOnHardpoint)
		victimStruct.isOnHardpoint = false

	//prevent medals form suicide
	if(attacker==victim)
		return

	if((victimCP.hardpoint!=null)&&(attackerCP.hardpoint!=null))
	{
		if(victimCP==attackerCP)
		{
			if(victimCP.hardpoint.GetTeam()==attacker.GetTeam())
			{
				AddPlayerScore( attacker , "HardpointDefense", victim )
				attacker.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_DEFENSE)
				attacker.AddToPlayerGameStat(PGS_ASSAULT_SCORE, 4 )
				SendScoreInfo( attacker, 4, true )
			}
			else if((victimCP.hardpoint.GetTeam()==victim.GetTeam())||(GetHardpointCappingTeam(victimCP)==victim.GetTeam()))
			{
				AddPlayerScore( attacker, "HardpointAssault", victim )
				attacker.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_ASSAULT)
				attacker.AddToPlayerGameStat(PGS_ASSAULT_SCORE, 3 )
				SendScoreInfo( attacker, 3, true )
			}
		}
	}
	else if((victimCP.hardpoint!=null))//siege or snipe
	{

		if(Distance(victim.GetOrigin(),attacker.GetOrigin())>=1875)//1875 inches(units) are 47.625 meters
		{
			AddPlayerScore( attacker , "HardpointSnipe", victim )
			attacker.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_SNIPE)
			attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 5 )
			SendScoreInfo( attacker, 5, true )
		}
		else{
			AddPlayerScore( attacker , "HardpointSiege", victim )
			attacker.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_SIEGE)
			attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 5 )
			SendScoreInfo( attacker, 5, true )
		}
	}
	else if(attackerCP.hardpoint!=null)//Perimeter Defense
	{
		if(attackerCP.hardpoint.GetTeam()==attacker.GetTeam())
			AddPlayerScore( attacker , "HardpointPerimeterDefense", victim)
			attacker.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_PERIMETER_DEFENSE)
			attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 3 )
			SendScoreInfo( attacker, 3, true )
	}

	foreach(CP_PlayerStruct player in file.players) //Reset Victim Holdtime Counter
	{
		if(player.player == victim)
			player.timeOnPoints = [0.0,0.0,0.0]
	}
}

void function removePlayerFromCapperArray_threaded(array<entity> capperArray,entity player)
{
	WaitFrame()
	FindAndRemove(capperArray,player)

}

void function RateSpawnpoints_CP( int checkClass, array<entity> spawnpoints, int team, entity player )
{
	if ( HasSwitchedSides() )
		team = GetOtherTeam( team )

	// check hardpoints, determine which ones we own
	array<entity> startSpawns = SpawnPoints_GetPilotStart( team )
	vector averageFriendlySpawns

	// average out startspawn positions
	foreach ( entity spawnpoint in startSpawns )
		averageFriendlySpawns += spawnpoint.GetOrigin()

	averageFriendlySpawns /= startSpawns.len()

	entity friendlyHardpoint // determine our furthest out hardpoint
	foreach ( entity hardpoint in HARDPOINTS )
	{
		if ( hardpoint.GetTeam() == player.GetTeam() && GetGlobalNetFloat( "objective" + GetHardpointGroup(hardpoint) + "Progress" ) >= 0.95 )
		{
			if ( IsValid( friendlyHardpoint ) )
			{
				if ( Distance2D( averageFriendlySpawns, hardpoint.GetOrigin() ) > Distance2D( averageFriendlySpawns, friendlyHardpoint.GetOrigin() ) )
					friendlyHardpoint = hardpoint
			}
			else
				friendlyHardpoint = hardpoint
		}
	}

	vector ratingPos
	if ( IsValid( friendlyHardpoint ) )
		ratingPos = friendlyHardpoint.GetOrigin()
	else
		ratingPos = averageFriendlySpawns

	foreach ( entity spawnpoint in spawnpoints )
	{
		// idk about magic number here really
		float rating = 1.0 - ( Distance2D( spawnpoint.GetOrigin(), ratingPos ) / 1000.0 )
		spawnpoint.CalculateRating( checkClass, player.GetTeam(), rating, rating )
	}
}

void function SpawnHardpoints()
{
	foreach ( entity spawnpoint in GetEntArrayByClass_Expensive( "info_hardpoint" ) )
	{
		if ( GameModeRemove( spawnpoint ) )
			continue

		// spawnpoints are CHardPoint entities
		// init the hardpoint ent
		int hardpointID = 0
		string group = GetHardpointGroup(spawnpoint)
			if ( group == "B" )
				hardpointID = 1
			else if ( group == "C" )
				hardpointID = 2

		spawnpoint.SetHardpointID( hardpointID )
		SpawnHardpointMinimapIcon( spawnpoint )

		HardpointStruct hardpointStruct
		hardpointStruct.hardpoint = spawnpoint
		hardpointStruct.prop = CreatePropDynamic( spawnpoint.GetModelName(), spawnpoint.GetOrigin(), spawnpoint.GetAngles(), 6 )
		thread PlayAnim( hardpointStruct.prop, "mh_inactive_idle" )

		entity trigger = GetEnt( expect string( spawnpoint.kv.triggerTarget ) )
		hardpointStruct.trigger = trigger

		file.hardpoints.append( hardpointStruct )
		HARDPOINTS.append( spawnpoint ) // for vo script
		spawnpoint.s.trigger <- trigger // also for vo script

		SetGlobalNetEnt( "objective" + group + "Ent", spawnpoint )

		// set up trigger functions
		trigger.SetEnterCallback( OnHardpointEntered )
		trigger.SetLeaveCallback( OnHardpointLeft )
	}
}

void function SpawnHardpointMinimapIcon( entity spawnpoint )
{
	// map hardpoint id to eMinimapObject_info_hardpoint enum id
	int miniMapObjectHardpoint = spawnpoint.GetHardpointID() + 1

	spawnpoint.Minimap_SetCustomState( miniMapObjectHardpoint )
	spawnpoint.Minimap_AlwaysShow( TEAM_MILITIA, null )
	spawnpoint.Minimap_AlwaysShow( TEAM_IMC, null )
	spawnpoint.Minimap_SetAlignUpright( true )

	SetTeam( spawnpoint, TEAM_UNASSIGNED )
}

// functions for handling hardpoint netvars
void function SetHardpointState( HardpointStruct hardpoint, int state )
{
	SetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "State", state )
	hardpoint.hardpoint.SetHardpointState( state )
}

int function GetHardpointState( HardpointStruct hardpoint )
{
	return GetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "State" )
}

void function SetHardpointCappingTeam( HardpointStruct hardpoint, int team )
{
	SetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "CappingTeam", team )
}

int function GetHardpointCappingTeam( HardpointStruct hardpoint )
{
	return GetGlobalNetInt( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "CappingTeam" )
}

void function SetHardpointCaptureProgress( HardpointStruct hardpoint, float progress )
{
	SetGlobalNetFloat( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "Progress", progress )
}

float function GetHardpointCaptureProgress( HardpointStruct hardpoint )
{
	return GetGlobalNetFloat( "objective" + GetHardpointGroup(hardpoint.hardpoint) + "Progress" )
}


void function StartHardpointThink()
{
	thread TrackChevronStates()

	foreach ( HardpointStruct hardpoint in file.hardpoints )
		thread HardpointThink( hardpoint )
}

void function CapturePointForTeam(HardpointStruct hardpoint, int Team)
{
	SetHardpointState(hardpoint,CAPTURE_POINT_STATE_CAPTURED)
	SetTeam( hardpoint.hardpoint, Team )
	SetTeam( hardpoint.prop, Team )
	EmitSoundOnEntityToTeamExceptPlayer( hardpoint.hardpoint, "hardpoint_console_captured", Team, null )
	GamemodeCP_VO_Captured( hardpoint.hardpoint )

	array<entity> allCappers
	allCappers.extend(hardpoint.militiaCappers)
	allCappers.extend(hardpoint.imcCappers)

	foreach(entity player in allCappers)
	{
		if(player.IsPlayer()){
			AddPlayerScore(player,"ControlPointCapture")
			player.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_CAPTURE)
			player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 5 )
			SendScoreInfo( player, 5, true )
		}
	}
}

void function GamemodeCP_InitPlayer(entity player)
{
	CP_PlayerStruct playerStruct
	playerStruct.player = player
	playerStruct.timeOnPoints = [0.0,0.0,0.0]
	playerStruct.isOnHardpoint = false
	file.players.append(playerStruct)
	thread PlayerThink(playerStruct)
}

void function GamemodeCP_RemovePlayer(entity player)
{

	foreach(index,CP_PlayerStruct playerStruct in file.players)
	{
		if(playerStruct.player==player)
			file.players.remove(index)
	}
}

void function PlayerThink(CP_PlayerStruct player)
{

	if(!IsValid(player.player))
		return

	if(!player.player.IsPlayer())
		return

	while(!GamePlayingOrSuddenDeath())
		WaitFrame()

	float lastTime = Time()
	WaitFrame()

	while(GamePlayingOrSuddenDeath()&&IsValid(player.player))
	{
		float currentTime = Time()
		float deltaTime = currentTime - lastTime

		if(player.isOnHardpoint)
		{
			bool hardpointBelongsToPlayerTeam = false

			foreach(index,HardpointStruct hardpoint in file.hardpoints)
			{
				if(GetHardpointState(hardpoint)>=CAPTURE_POINT_STATE_CAPTURED)
				{
					if((hardpoint.hardpoint.GetTeam()==TEAM_MILITIA)&&(hardpoint.militiaCappers.contains(player.player)))
						hardpointBelongsToPlayerTeam = true

					if((hardpoint.hardpoint.GetTeam()==TEAM_IMC)&&(hardpoint.imcCappers.contains(player.player)))
						hardpointBelongsToPlayerTeam = true
				}
				if(hardpointBelongsToPlayerTeam)
				{
					player.timeOnPoints[index] += deltaTime
					if(player.timeOnPoints[index]>=10)
					{
						player.timeOnPoints[index] -= 10
						if(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPED)
						{
							AddPlayerScore(player.player,"ControlPointAmpedHold")
							player.player.AddToPlayerGameStat( PGS_DEFENSE_SCORE, POINTVALUE_HARDPOINT_AMPED_HOLD )
							player.player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 2 )
							SendScoreInfo( player.player, 2, true )
						}
						else
						{
							AddPlayerScore(player.player,"ControlPointHold")
							player.player.AddToPlayerGameStat( PGS_DEFENSE_SCORE, POINTVALUE_HARDPOINT_HOLD )
							player.player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 2 )
							SendScoreInfo( player.player, 2, true )
						}
					}
					break
				}
			}
		}
		lastTime = currentTime
		WaitFrame()
	}
}

void function SetCapperAmount( table<int, table<string, int> > capStrength, array<entity> entities )
{
	foreach(entity p in entities)
	{
		if ( p.IsPlayer() && p.IsTitan() )
		{
			capStrength[p.GetTeam()]["titans"] += 1
		}
		else if ( p.IsPlayer() )
		{
			capStrength[p.GetTeam()]["pilots"] += 1
		}
		else if ( p.IsNPC() )
		{
			capStrength[p.GetTeam()]["grunts"] += 1
		}
	}
}

void function HardpointThink( HardpointStruct hardpoint )
{
	entity hardpointEnt = hardpoint.hardpoint

	float lastTime = Time()
	float lastScoreTime = Time()
	bool hasBeenAmped = false

	WaitFrame() // wait a frame so deltaTime is never zero

	while ( GamePlayingOrSuddenDeath() )
	{
		table<int, table<string, int> > capStrength = {
			[TEAM_IMC] = {
				pilots = 0,
				titans = 0,
				grunts = 0,
			},
			[TEAM_MILITIA] = {
				pilots = 0,
				titans = 0,
				grunts = 0,
			}
		}

		float currentTime = Time()
		float deltaTime = currentTime - lastTime

		SetCapperAmount( capStrength, hardpoint.militiaCappers )
		SetCapperAmount( capStrength, hardpoint.imcCappers )

		int imcPilotCappers = capStrength[TEAM_IMC]["pilots"]
		int imcTitanCappers = capStrength[TEAM_IMC]["titans"]
		int imcGruntCappers = capStrength[TEAM_IMC]["grunts"]

		int militiaPilotCappers = capStrength[TEAM_MILITIA]["pilots"]
		int militiaTitanCappers = capStrength[TEAM_MILITIA]["titans"]
		int militiaGruntCappers = capStrength[TEAM_MILITIA]["grunts"]


		int imcCappers = ( imcPilotCappers * 2 ) + imcGruntCappers //( imcTitanCappers + militiaTitanCappers ) > 0 ? imcTitanCappers : imcPilotCappers
		int militiaCappers = ( militiaPilotCappers * 2 ) + militiaGruntCappers //( imcTitanCappers + militiaTitanCappers ) <= 0 ? militiaPilotCappers : militiaTitanCappers

		int cappingTeam
		int capperAmount = 0
		bool hardpointBlocked = false

		if((imcCappers > 0) && (militiaCappers > 0))
		{
			hardpointBlocked = true
		}
		else if ( imcCappers > 0 )
		{
			cappingTeam = TEAM_IMC
			capperAmount = imcCappers
		}
		else if ( militiaCappers > 0 )
		{
			cappingTeam = TEAM_MILITIA
			capperAmount = militiaCappers
		}

		int MAX_CAPPERS = GetConVarInt( "MAX_CAPPERS" ) * 2
		float CAPTURE_TIME = CAPTURE_DURATION_CAPTURE * 2 //Double capture time as players count as double captures
		capperAmount = minint(capperAmount, MAX_CAPPERS)

		if(hardpointBlocked)
		{
			SetHardpointState(hardpoint,CAPTURE_POINT_STATE_HALTED)
		}
		else if(cappingTeam==TEAM_UNASSIGNED) // nobody on point
		{
			if((GetHardpointState(hardpoint)>=CAPTURE_POINT_STATE_AMPED) || (GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_SELF_UNAMPING))
			{
				if (GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED)
					SetHardpointState(hardpoint,CAPTURE_POINT_STATE_SELF_UNAMPING) // plays a pulsating effect on the UI only when the hardpoint is amped
				SetHardpointCappingTeam(hardpoint,hardpointEnt.GetTeam())
				SetHardpointCaptureProgress(hardpoint,max(1.0,GetHardpointCaptureProgress(hardpoint)-(deltaTime/HARDPOINT_AMPED_DELAY)))
				if(GetHardpointCaptureProgress(hardpoint)<=1.001) // unamp
				{
					if (GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED) // only play 2inactive animation if we were amped
						thread PlayAnim( hardpoint.prop, "mh_active_2_inactive" )
					SetHardpointState(hardpoint,CAPTURE_POINT_STATE_CAPTURED)
				}
			}
			if(GetHardpointState(hardpoint)>=CAPTURE_POINT_STATE_CAPTURED)
				SetHardpointCappingTeam(hardpoint,TEAM_UNASSIGNED)
		}
		else if(hardpointEnt.GetTeam()==TEAM_UNASSIGNED) // uncapped point
		{
			if(GetHardpointCappingTeam(hardpoint)==TEAM_UNASSIGNED) // uncapped point with no one inside
			{
				SetHardpointCaptureProgress( hardpoint, min(1.0,GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / CAPTURE_TIME * capperAmount) ) )
				SetHardpointCappingTeam(hardpoint,cappingTeam)
				if(GetHardpointCaptureProgress(hardpoint)>=1.0)
				{
					CapturePointForTeam(hardpoint,cappingTeam)
					hasBeenAmped = false
				}
			}
			else if(GetHardpointCappingTeam(hardpoint)==cappingTeam) // uncapped point with ally inside
			{
				SetHardpointCaptureProgress( hardpoint,min(1.0, GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / CAPTURE_TIME * capperAmount) ) )
				if(GetHardpointCaptureProgress(hardpoint)>=1.0)
				{
					CapturePointForTeam(hardpoint,cappingTeam)
					hasBeenAmped = false
				}
			}
			else // uncapped point with enemy inside
			{
				SetHardpointCaptureProgress( hardpoint,max(0.0, GetHardpointCaptureProgress( hardpoint ) - ( deltaTime / CAPTURE_TIME * capperAmount) ) )
				if(GetHardpointCaptureProgress(hardpoint)==0.0)
				{
					SetHardpointCappingTeam(hardpoint,cappingTeam)
					if(GetHardpointCaptureProgress(hardpoint)>=1)
					{
						CapturePointForTeam(hardpoint,cappingTeam)
						hasBeenAmped = false
					}
				}
			}
		}
		else if(hardpointEnt.GetTeam()!=cappingTeam) // capping enemy point
		{
			SetHardpointCappingTeam(hardpoint,cappingTeam)
			SetHardpointCaptureProgress( hardpoint,max(0.0, GetHardpointCaptureProgress( hardpoint ) - ( deltaTime / CAPTURE_TIME * capperAmount) ) )
			if(GetHardpointCaptureProgress(hardpoint)<=1.0)
			{
				if (GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED) // only play 2inactive animation if we were amped
					thread PlayAnim( hardpoint.prop, "mh_active_2_inactive" )
				SetHardpointState(hardpoint,CAPTURE_POINT_STATE_CAPTURED) // unamp
			}
			if(GetHardpointCaptureProgress(hardpoint)<=0.0)
			{
				SetHardpointCaptureProgress(hardpoint,1.0)
				CapturePointForTeam(hardpoint,cappingTeam)
				hasBeenAmped = false
			}
		}
		else if(hardpointEnt.GetTeam()==cappingTeam) // capping allied point
		{
			SetHardpointCappingTeam(hardpoint,cappingTeam)
			if(GetHardpointCaptureProgress(hardpoint)<1.0) // not amped
			{
				SetHardpointCaptureProgress(hardpoint,GetHardpointCaptureProgress(hardpoint)+( deltaTime / CAPTURE_TIME * capperAmount ))
			}
			else if(file.ampingEnabled)//amping or reamping
			{
				// i have no idea why but putting it CAPTURE_POINT_STATE_AMPING will say 'CONTESTED' on the UI
				// since whether the point is contested is checked above, putting the hardpoint state to a value of 8 fixes it somehow
				if(GetHardpointState(hardpoint)<=CAPTURE_POINT_STATE_AMPING)
					SetHardpointState( hardpoint, 8 )
				SetHardpointCaptureProgress( hardpoint, min( 2.0, GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / HARDPOINT_AMPED_DELAY * capperAmount ) ) )
				if(GetHardpointCaptureProgress(hardpoint)==2.0&&!(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPED))
				{
					SetHardpointState( hardpoint, CAPTURE_POINT_STATE_AMPED )
					// can't use the dialogue functions here because for some reason GamemodeCP_VO_Amped isn't global?
					PlayFactionDialogueToTeam( "amphp_youAmped" + GetHardpointGroup(hardpoint.hardpoint), cappingTeam )
					PlayFactionDialogueToTeam( "amphp_enemyAmped" + GetHardpointGroup(hardpoint.hardpoint), GetOtherTeam( cappingTeam ) )
					thread PlayAnim( hardpoint.prop, "mh_inactive_2_active" )

					if(!hasBeenAmped){
						hasBeenAmped=true

						array<entity> allCappers
						allCappers.extend(hardpoint.militiaCappers)
						allCappers.extend(hardpoint.imcCappers)

						foreach(entity player in allCappers)
						{
							if(player.IsPlayer())
							{
								AddPlayerScore(player,"ControlPointAmped")
								player.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_AMPED)
								player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 5 )
								SendScoreInfo( player, 5, true )
							}
						}
					}
				}
			}
		}

		if ( hardpointEnt.GetTeam() != TEAM_UNASSIGNED && GetHardpointState( hardpoint ) >= CAPTURE_POINT_STATE_CAPTURED && currentTime - lastScoreTime >= TEAM_OWNED_SCORE_FREQ && !hardpointBlocked&&!(cappingTeam==GetOtherTeam(hardpointEnt.GetTeam())))
		{
			lastScoreTime = currentTime
			if ( GetHardpointState( hardpoint ) == CAPTURE_POINT_STATE_AMPED )
				AddTeamScore( hardpointEnt.GetTeam(), 2 )
			else if( GetHardpointState( hardpoint) >= CAPTURE_POINT_STATE_CAPTURED)
				AddTeamScore( hardpointEnt.GetTeam(), 1 )
		}

		foreach(entity player in hardpoint.imcCappers)
		{
			if(DistanceSqr(player.GetOrigin(),hardpointEnt.GetOrigin())>1200000)
				FindAndRemove(hardpoint.imcCappers,player)
		}
		foreach(entity player in hardpoint.militiaCappers)
		{
			if(DistanceSqr(player.GetOrigin(),hardpointEnt.GetOrigin())>1200000)
				FindAndRemove(hardpoint.militiaCappers,player)
		}


		lastTime = currentTime
		WaitFrame()
	}
}

// doing this in HardpointThink is effort since it's for individual hardpoints
// so we do it here instead
void function TrackChevronStates()
{
	// you get 1 amped arrow for chevron / 4, 1 unamped arrow for every 1 the amped chevrons

	while ( true )
	{
		table <int, int> chevrons = {
			[TEAM_IMC] = 0,
			[TEAM_MILITIA] = 0,
		}

		foreach ( HardpointStruct hardpoint in file.hardpoints )
		{
			foreach ( k, v in chevrons )
			{
				if ( k == hardpoint.hardpoint.GetTeam() )
					chevrons[k] += ( hardpoint.hardpoint.GetHardpointState() == CAPTURE_POINT_STATE_AMPED ) ? 4 : 1
			}
		}

		SetGlobalNetInt( "imcChevronState", chevrons[TEAM_IMC] )
		SetGlobalNetInt( "milChevronState", chevrons[TEAM_MILITIA] )

		WaitFrame()
	}
}

void function OnHardpointEntered( entity trigger, entity player )
{
	HardpointStruct hardpoint
	foreach ( HardpointStruct hardpointStruct in file.hardpoints )
		if ( hardpointStruct.trigger == trigger )
			hardpoint = hardpointStruct

	if ( player.GetTeam() == TEAM_IMC )
		hardpoint.imcCappers.append( player )
	else
		hardpoint.militiaCappers.append( player )
	foreach(CP_PlayerStruct playerStruct in file.players)
		if(playerStruct.player == player)
		{
			playerStruct.isOnHardpoint = true
			player.SetPlayerNetInt( "playerHardpointID", hardpoint.hardpoint.GetHardpointID() )
		}
}

void function OnHardpointLeft( entity trigger, entity player )
{
	HardpointStruct hardpoint
	foreach ( HardpointStruct hardpointStruct in file.hardpoints )
		if ( hardpointStruct.trigger == trigger )
			hardpoint = hardpointStruct

	if ( player.GetTeam() == TEAM_IMC )
		FindAndRemove( hardpoint.imcCappers, player )
	else
		FindAndRemove( hardpoint.militiaCappers, player )
	foreach(CP_PlayerStruct playerStruct in file.players)
		if(playerStruct.player == player)
		{
			playerStruct.isOnHardpoint = false
			player.SetPlayerNetInt( "playerHardpointID", 69 ) // an arbitary number to remove the hud from the player
		}
}

string function CaptureStateToString( int state )
{
	switch ( state )
	{
		case CAPTURE_POINT_STATE_UNASSIGNED:
			return "UNASSIGNED"
		case CAPTURE_POINT_STATE_HALTED:
			return "HALTED"
		case CAPTURE_POINT_STATE_CAPTURED:
			return "CAPTURED"
		case CAPTURE_POINT_STATE_AMPING:
		case 8:
			return "AMPING"
		case CAPTURE_POINT_STATE_AMPED:
			return "AMPED"
	}
	return "UNKNOWN"
}

void function DEV_PrintHardpointsInfo()
{
	foreach (entity hardpoint in HARDPOINTS)
	{

		printt(
			"Hardpoint:", GetHardpointGroup(hardpoint),
			"|Team:", Dev_TeamIDToString(hardpoint.GetTeam()),
			"|State:", CaptureStateToString(hardpoint.GetHardpointState()),
			"|Progress:", GetGlobalNetFloat("objective" + GetHardpointGroup(hardpoint) + "Progress")
		)
	}
}

string function GetHardpointGroup(entity hardpoint) //Hardpoint Entity B on Homestead is missing the Hardpoint Group KeyValue
{
	if((GetMapName()=="mp_homestead")&&(!hardpoint.HasKey("hardpointGroup")))
		return "B"

	return string(hardpoint.kv.hardpointGroup)
}
