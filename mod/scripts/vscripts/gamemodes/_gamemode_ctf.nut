untyped
// this needs a refactor lol

global function CaptureTheFlag_Init
global function RateSpawnpoints_CTF

const array<string> SWAP_FLAG_MAPS = [
	"mp_forwardbase_kodai",
	"mp_lf_meadow"
]

struct {
	entity imcFlagSpawn
	entity imcFlag
	entity imcFlagReturnTrigger

	entity militiaFlagSpawn
	entity militiaFlag
	entity militiaFlagReturnTrigger

	array<entity> imcCaptureAssistList
	array<entity> militiaCaptureAssistList

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

void function CaptureTheFlag_Init()
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

    // ------------------ CTF
	PrecacheModel( CTF_FLAG_MODEL )
	PrecacheModel( CTF_FLAG_BASE_MODEL )
	PrecacheParticleSystem( FLAG_FX_FRIENDLY )
	PrecacheParticleSystem( FLAG_FX_ENEMY )

	CaptureTheFlagShared_Init()
	SetSwitchSidesBased( true )
	SetSuddenDeathBased( true )
	SetShouldUseRoundWinningKillReplay( true )
	SetRoundWinningKillReplayKillClasses( false, false ) // make these fully manual

	AddCallback_OnClientConnected( CTFInitPlayer )

	AddCallback_GameStateEnter( eGameState.Prematch, CreateFlags )
	AddCallback_GameStateEnter( eGameState.Epilogue, RemoveFlags )
	AddCallback_OnTouchHealthKit( "item_flag", OnFlagCollected )
	AddCallback_OnPlayerKilled( OnPlayerKilled )
	AddCallback_OnPilotBecomesTitan( DropFlagForBecomingTitan )

	SetSpawnZoneRatingFunc( DecideSpawnZone_CTF )
	AddSpawnpointValidationRule( VerifyCTFSpawnpoint )

	RegisterSignal( "FlagReturnEnded" )
	RegisterSignal( "ResetDropTimeout" )

	// setup stuff for the functions in sh_gamemode_ctf
	// don't really like using level for stuff but just how it be
	level.teamFlags <- {}

	// setup score event earnmeter values
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.05, 0.20 )
	ScoreEvent_SetEarnMeterValues( "Headshot", 0.0, 0.02 )
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.0, 0.05 )
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.0, 0.25 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.35 )

	ScoreEvent_SetEarnMeterValues( "FlagCarrierKill", 0.0, 0.20 )
	ScoreEvent_SetEarnMeterValues( "FlagTaken", 0.0, 0.10 )
	ScoreEvent_SetEarnMeterValues( "FlagCapture", 0.0, 0.30 )
	ScoreEvent_SetEarnMeterValues( "FlagCaptureAssist", 0.0, 0.20 )
	ScoreEvent_SetEarnMeterValues( "FlagReturn", 0.0, 0.20 )
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
				array< entity > points = SpawnPoints_GetDropPod()
				if ( titanCount < GetConVarInt( "GRTDM_TITANS" ) )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					waitthread AiGameModes_SpawnTitanRandom( node.GetOrigin(), node.GetAngles(), team, TitanHandler )
				}
			}

			// PILOTS
			if ( file.pilots[ index ] )
			{
				array< entity > points = SpawnPoints_GetDropPod()
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

//----------------------------------- CTF STUFF
void function RateSpawnpoints_CTF( int checkClass, array<entity> spawnpoints, int team, entity player )
{
	RateSpawnpoints_SpawnZones( checkClass, spawnpoints, team, player )
}

bool function VerifyCTFSpawnpoint( entity spawnpoint, int team )
{
	// ensure spawnpoints aren't too close to enemy base
	vector allyFlagSpot
	vector enemyFlagSpot
	foreach ( entity spawn in GetEntArrayByClass_Expensive( "info_spawnpoint_flag" ) )
	{
		if( spawn.GetTeam() == team )
			allyFlagSpot = spawn.GetOrigin()
		else
			enemyFlagSpot = spawn.GetOrigin()
	}

	if( Distance2D( spawnpoint.GetOrigin(), allyFlagSpot ) > Distance2D( spawnpoint.GetOrigin(), enemyFlagSpot ) )
		return false

	return true
}

void function CTFInitPlayer( entity player )
{
	if ( !IsValid( file.imcFlagSpawn ) )
		return

	vector imcSpawn = file.imcFlagSpawn.GetOrigin()
	Remote_CallFunction_NonReplay( player, "ServerCallback_SetFlagHomeOrigin", TEAM_IMC, imcSpawn.x, imcSpawn.y, imcSpawn.z )

	vector militiaSpawn = file.militiaFlagSpawn.GetOrigin()
	Remote_CallFunction_NonReplay( player, "ServerCallback_SetFlagHomeOrigin", TEAM_MILITIA, militiaSpawn.x, militiaSpawn.y, militiaSpawn.z )
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( GetFlagForTeam( GetOtherTeam( victim.GetTeam() ) ) ) ) // getting a crash idk
		return
	if ( GetFlagForTeam( GetOtherTeam( victim.GetTeam() ) ).GetParent() == victim )
	{
		if ( victim != attacker && attacker.IsPlayer() )
			AddPlayerScore( attacker, "FlagCarrierKill", victim )

		DropFlag( victim )
	}
}

void function CreateFlags()
{
	if ( IsValid( file.imcFlagSpawn ) )
	{
		file.imcFlagSpawn.Destroy()
		file.imcFlag.Destroy()
		file.imcFlagReturnTrigger.Destroy()

		file.militiaFlagSpawn.Destroy()
		file.militiaFlag.Destroy()
		file.militiaFlagReturnTrigger.Destroy()
	}

	foreach ( entity spawn in GetEntArrayByClass_Expensive( "info_spawnpoint_flag" ) )
	{
		// on some maps flags are on the opposite side from what they should be
		// likely this is because respawn uses distance checks from spawns to check this in official
		// but i don't like doing that so just using a list of maps to swap them on lol
		bool switchedSides = HasSwitchedSides() == 1

		// i dont know why this works and whatever we had before didn't, but yeah
		bool shouldSwap = switchedSides
		if (!shouldSwap && SWAP_FLAG_MAPS.contains( GetMapName() ))
			shouldSwap = !shouldSwap


		int flagTeam = spawn.GetTeam()
		if ( shouldSwap )
		{
			flagTeam = GetOtherTeam( flagTeam )
			SetTeam( spawn, flagTeam )
		}

		// create flag base
		entity base = CreatePropDynamic( CTF_FLAG_BASE_MODEL, spawn.GetOrigin(), spawn.GetAngles(), 0 )
		SetTeam( base, spawn.GetTeam() )
		svGlobal.flagSpawnPoints[ flagTeam ] = base

		// create flag
		entity flag = CreateEntity( "item_flag" )
		flag.SetValueForModelKey( CTF_FLAG_MODEL )
		SetTeam( flag, flagTeam )
		flag.MarkAsNonMovingAttachment()
		flag.Minimap_AlwaysShow( TEAM_IMC, null ) // show flag icon on minimap
		flag.Minimap_AlwaysShow( TEAM_MILITIA, null )
		flag.Minimap_SetAlignUpright( true )
		DispatchSpawn( flag )
		flag.SetModel( CTF_FLAG_MODEL )
		flag.SetOrigin( spawn.GetOrigin() + < 0, 0, base.GetBoundingMaxs().z * 2 > ) // ensure flag doesn't spawn clipped into geometry
		flag.SetVelocity( < 0, 0, 1 > )

		flag.s.canTake <- true
		flag.s.playersReturning <- []

		level.teamFlags[ flag.GetTeam() ] <- flag

		entity returnTrigger = CreateEntity( "trigger_cylinder" )
		SetTeam( returnTrigger, flagTeam )
		returnTrigger.SetRadius( CTF_GetFlagReturnRadius() )
		returnTrigger.SetAboveHeight( CTF_GetFlagReturnRadius() )
		returnTrigger.SetBelowHeight( CTF_GetFlagReturnRadius() )

		returnTrigger.SetEnterCallback( OnPlayerEntersFlagReturnTrigger )
		returnTrigger.SetLeaveCallback( OnPlayerExitsFlagReturnTrigger )

		DispatchSpawn( returnTrigger )

		thread TrackFlagReturnTrigger( flag, returnTrigger )

		if ( flagTeam == TEAM_IMC )
		{
			file.imcFlagSpawn = base
			file.imcFlag = flag
			file.imcFlagReturnTrigger = returnTrigger

			SetGlobalNetEnt( "imcFlag", file.imcFlag )
			SetGlobalNetEnt( "imcFlagHome", file.imcFlagSpawn )
		}
		else
		{
			file.militiaFlagSpawn = base
			file.militiaFlag = flag
			file.militiaFlagReturnTrigger = returnTrigger

			SetGlobalNetEnt( "milFlag", file.militiaFlag )
			SetGlobalNetEnt( "milFlagHome", file.militiaFlagSpawn )
		}
	}

	// reset the flag states, prevents issues where flag is home but doesnt think it's home when halftime goes
	SetFlagStateForTeam( TEAM_MILITIA, eFlagState.None )
	SetFlagStateForTeam( TEAM_IMC, eFlagState.None )

	foreach ( entity player in GetPlayerArray() )
		CTFInitPlayer( player )
}

void function RemoveFlags()
{
	// destroy all the flag related things
	if ( IsValid( file.imcFlagSpawn ) )
	{
		file.imcFlagSpawn.Destroy()
		file.imcFlag.Destroy()
		file.imcFlagReturnTrigger.Destroy()
	}
	if ( IsValid( file.militiaFlagSpawn ) )
	{
		file.militiaFlagSpawn.Destroy()
		file.militiaFlag.Destroy()
		file.militiaFlagReturnTrigger.Destroy()
	}

	// unsure if this is needed, since the flags are destroyed? idk
	SetFlagStateForTeam( TEAM_MILITIA, eFlagState.None )
	SetFlagStateForTeam( TEAM_IMC, eFlagState.None )
}

void function TrackFlagReturnTrigger( entity flag, entity returnTrigger )
{
	// this is a bit of a hack, it seems parenting the return trigger to the flag actually sets the pickup radius of the flag to be the same as the trigger
	// this isn't wanted since only pickups should use that additional radius
	flag.EndSignal( "OnDestroy" )

	while ( true )
	{
		returnTrigger.SetOrigin( flag.GetOrigin() )
		WaitFrame()
	}
}

void function SetFlagStateForTeam( int team, int state )
{
	if ( state == eFlagState.Away ) // we tell the client the flag is the player carrying it if they're carrying it
		SetGlobalNetEnt( team == TEAM_IMC ? "imcFlag" : "milFlag", ( team == TEAM_IMC ? file.imcFlag : file.militiaFlag ).GetParent() )
	else
		SetGlobalNetEnt( team == TEAM_IMC ? "imcFlag" : "milFlag", team == TEAM_IMC ? file.imcFlag : file.militiaFlag )

	SetGlobalNetInt( team == TEAM_IMC ? "imcFlagState" : "milFlagState", state )
}

bool function OnFlagCollected( entity player, entity flag )
{
	if ( !IsAlive( player ) || flag.GetParent() != null || player.IsTitan() || player.IsPhaseShifted() )
		return false

	if ( player.GetTeam() != flag.GetTeam() && flag.s.canTake )
		GiveFlag( player, flag ) // pickup enemy flag
	else if ( player.GetTeam() == flag.GetTeam() && IsFlagHome( flag ) && PlayerHasEnemyFlag( player ) )
		CaptureFlag( player, GetFlagForTeam( GetOtherTeam( flag.GetTeam() ) ) ) // cap the flag

	return false // don't wanna delete the flag entity
}

void function GiveFlag( entity player, entity flag )
{
	print( player + " picked up the flag!" )
	flag.Signal( "ResetDropTimeout" )

	flag.SetParent( player, "FLAG" )
	thread DropFlagIfPhased( player, flag )

	// do notifications
	MessageToPlayer( player, eEventNotifications.YouHaveTheEnemyFlag )
	EmitSoundOnEntityOnlyToPlayer( player, player, "UI_CTF_1P_GrabFlag" )
	AddPlayerScore( player, "FlagTaken", player )
	PlayFactionDialogueToPlayer( "ctf_flagPickupYou", player )

	MessageToTeam( player.GetTeam(), eEventNotifications.PlayerHasEnemyFlag, player, player )
	EmitSoundOnEntityToTeamExceptPlayer( flag, "UI_CTF_3P_TeamGrabFlag", player.GetTeam(), player )
	PlayFactionDialogueToTeamExceptPlayer( "ctf_flagPickupFriendly", player.GetTeam(), player )

	MessageToTeam( flag.GetTeam(), eEventNotifications.PlayerHasFriendlyFlag, player, player )
	EmitSoundOnEntityToTeam( flag, "UI_CTF_3P_EnemyGrabFlag", flag.GetTeam() )

	SetFlagStateForTeam( flag.GetTeam(), eFlagState.Away ) // used for held
}

void function DropFlagIfPhased( entity player, entity flag )
{
	player.EndSignal( "StartPhaseShift" )
	player.EndSignal( "OnDestroy" )

	OnThreadEnd( function() : ( player )
	{
		if (GetGameState() == eGameState.Playing || GetGameState() == eGameState.SuddenDeath)
			DropFlag( player, true )
	})
	// the IsValid check is purely to prevent a crash due to a destroyed flag (epilogue)
	while( IsValid(flag) && flag.GetParent() == player )
		WaitFrame()
}

void function DropFlagForBecomingTitan( entity pilot, entity titan )
{
	DropFlag( pilot, true )
}

void function DropFlag( entity player, bool realDrop = true )
{
	entity flag = GetFlagForTeam( GetOtherTeam( player.GetTeam() ) )

	if ( flag.GetParent() != player )
		return

	print( player + " dropped the flag!" )

	flag.ClearParent()
	flag.SetAngles( < 0, 0, 0 > )
	flag.SetVelocity( < 0, 0, 0 > )

	if ( realDrop )
	{
		// start drop timeout countdown
		thread TrackFlagDropTimeout( flag )

		// add to capture assists
		if ( player.GetTeam() == TEAM_IMC )
			file.imcCaptureAssistList.append( player )
		else
			file.militiaCaptureAssistList.append( player )

		// do notifications
		MessageToPlayer( player, eEventNotifications.YouDroppedTheEnemyFlag )
		EmitSoundOnEntityOnlyToPlayer( player, player, "UI_CTF_1P_FlagDrop" )

		MessageToTeam( player.GetTeam(), eEventNotifications.PlayerDroppedEnemyFlag, player, player )
		// todo need a sound here maybe
		MessageToTeam( GetOtherTeam( player.GetTeam() ), eEventNotifications.PlayerDroppedFriendlyFlag, player, player )
		// todo need a sound here maybe
	}

	SetFlagStateForTeam( flag.GetTeam(), eFlagState.Home ) // used for return prompt
}

void function TrackFlagDropTimeout( entity flag )
{
	flag.EndSignal( "ResetDropTimeout" )

	wait CTF_GetDropTimeout()

	ResetFlag( flag )
}

void function ResetFlag( entity flag )
{
	// prevents crash when flag is reset after it's been destroyed due to epilogue
	if (!IsValid(flag))
		return
	// ensure we can't pickup the flag after it's been dropped but before it's been reset
	flag.s.canTake = false

	if ( flag.GetParent() != null )
		DropFlag( flag.GetParent(), false )

	entity spawn
	if ( flag.GetTeam() == TEAM_IMC )
		spawn = file.imcFlagSpawn
	else
		spawn = file.militiaFlagSpawn

	flag.SetOrigin( spawn.GetOrigin() + < 0, 0, spawn.GetBoundingMaxs().z + 1 > )

	// we can take it again now
	flag.s.canTake = true

	SetFlagStateForTeam( flag.GetTeam(), eFlagState.None ) // used for home

	flag.Signal( "ResetDropTimeout" )
}

void function CaptureFlag( entity player, entity flag )
{
	// can only capture flags during normal play or sudden death
	if (GetGameState() != eGameState.Playing && GetGameState() != eGameState.SuddenDeath)
	{
		printt( player + " tried to capture the flag, but the game state was " + GetGameState() + " not " + eGameState.Playing + " or " + eGameState.SuddenDeath)
		return
	}
	// reset flag
	ResetFlag( flag )

	print( player + " captured the flag!" )

	// score
	int team = player.GetTeam()
	AddTeamScore( team, 1 )
	AddPlayerScore( player, "FlagCapture", player )
	player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 ) // add 1 to captures on scoreboard
	SetRoundWinningKillReplayAttacker( player ) // set attacker for last cap replay

	array<entity> assistList
	if ( player.GetTeam() == TEAM_IMC )
		assistList = file.imcCaptureAssistList
	else
		assistList = file.militiaCaptureAssistList

	foreach( entity assistPlayer in assistList )
	{
		if ( player != assistPlayer )
			AddPlayerScore( assistPlayer, "FlagCaptureAssist", player )
		if( !HasPlayerCompletedMeritScore( assistPlayer ) )
		{
			AddPlayerScore( assistPlayer, "ChallengeCTFCapAssist" )
			SetPlayerChallengeMeritScore( assistPlayer )
		}
	}

	assistList.clear()

	// notifs
	MessageToPlayer( player, eEventNotifications.YouCapturedTheEnemyFlag )
	EmitSoundOnEntityOnlyToPlayer( player, player, "UI_CTF_1P_PlayerScore" )

	if( !HasPlayerCompletedMeritScore( player ) )
	{
		AddPlayerScore( player, "ChallengeCTFRetAssist" )
		SetPlayerChallengeMeritScore( player )
	}

	MessageToTeam( team, eEventNotifications.PlayerCapturedEnemyFlag, player, player )
	EmitSoundOnEntityToTeamExceptPlayer( flag, "UI_CTF_3P_TeamScore", player.GetTeam(), player )

	MessageToTeam( GetOtherTeam( team ), eEventNotifications.PlayerCapturedFriendlyFlag, player, player )
	EmitSoundOnEntityToTeam( flag, "UI_CTF_3P_EnemyScores", flag.GetTeam() )

	if ( GameRules_GetTeamScore( team ) == GameMode_GetRoundScoreLimit( GAMETYPE ) - 1 )
	{
		PlayFactionDialogueToTeam( "ctf_notifyWin1more", team )
		PlayFactionDialogueToTeam( "ctf_notifyLose1more", GetOtherTeam( team ) )
	}
}

void function OnPlayerEntersFlagReturnTrigger( entity trigger, entity player )
{
	entity flag
	if ( trigger.GetTeam() == TEAM_IMC )
		flag = file.imcFlag
	else
		flag = file.militiaFlag

	if( !IsValid( flag ) || !IsValid( player ) )
		return

	if ( !player.IsPlayer() || player.IsTitan() || player.GetTeam() != flag.GetTeam() || IsFlagHome( flag ) || flag.GetParent() != null )
		return

	thread TryReturnFlag( player, flag )
}

void function OnPlayerExitsFlagReturnTrigger( entity trigger, entity player )
{
	entity flag
	if ( trigger.GetTeam() == TEAM_IMC )
		flag = file.imcFlag
	else
		flag = file.militiaFlag

	if ( !player.IsPlayer() || player.IsTitan() || player.GetTeam() != flag.GetTeam() || IsFlagHome( flag ) || flag.GetParent() != null )
		return

	player.Signal( "FlagReturnEnded" )
}

void function TryReturnFlag( entity player, entity flag )
{
	// start return progress bar
	Remote_CallFunction_NonReplay( player, "ServerCallback_CTF_StartReturnFlagProgressBar", Time() + CTF_GetFlagReturnTime() )
	EmitSoundOnEntityOnlyToPlayer( player, player, "UI_CTF_1P_FlagReturnMeter" )

	OnThreadEnd( function() : ( player )
	{
		// cleanup
		Remote_CallFunction_NonReplay( player, "ServerCallback_CTF_StopReturnFlagProgressBar" )
		StopSoundOnEntity( player, "UI_CTF_1P_FlagReturnMeter" )
	})

	player.EndSignal( "FlagReturnEnded" )
	flag.EndSignal( "FlagReturnEnded" ) // avoid multiple players to return one flag at once
	player.EndSignal( "OnDeath" )

	wait CTF_GetFlagReturnTime()

	// flag return succeeded
	// return flag
	ResetFlag( flag )
	flag.Signal( "FlagReturnEnded" )

	// do notifications for return
	MessageToPlayer( player, eEventNotifications.YouReturnedFriendlyFlag )
	AddPlayerScore( player, "FlagReturn", player )
	player.AddToPlayerGameStat( PGS_DEFENSE_SCORE, 1 )

	if( !HasPlayerCompletedMeritScore( player ) )
	{
		AddPlayerScore( player, "ChallengeCTFRetAssist" )
		SetPlayerChallengeMeritScore( player )
	}

	MessageToTeam( flag.GetTeam(), eEventNotifications.PlayerReturnedFriendlyFlag, null, player )
	EmitSoundOnEntityToTeam( flag, "UI_CTF_3P_TeamReturnsFlag", flag.GetTeam() )
	PlayFactionDialogueToTeam( "ctf_flagReturnedFriendly", flag.GetTeam() )

	MessageToTeam( GetOtherTeam( flag.GetTeam() ), eEventNotifications.PlayerReturnedEnemyFlag, null, player )
	EmitSoundOnEntityToTeam( flag, "UI_CTF_3P_EnemyReturnsFlag", GetOtherTeam( flag.GetTeam() ) )
	PlayFactionDialogueToTeam( "ctf_flagReturnedEnemy", GetOtherTeam( flag.GetTeam() ) )
}