untyped
global function GamemodeAITdm_Init

const SQUADS_PER_TEAM = 3
const REAPERS_PER_TEAM = 2

const MARVINS_PER_TEAM = 0
const PROWLERS_PER_TEAM = 4
const PILOTS_PER_TEAM = 2

const TITANS_PER_TEAM = 0
const GUNSHIPS_PER_TEAM = 2

const LEVEL_SPECTRES = 0
const LEVEL_STALKERS = 50
const LEVEL_REAPERS = 125
const LEVEL_GUNSHIPS = 200
const LEVEL_TITANS = 250

const array<string> WEAPONS = [ "mp_weapon_alternator_smg", "mp_weapon_arc_launcher", "mp_weapon_autopistol", "mp_weapon_car", "mp_weapon_defender", "mp_weapon_dmr", "mp_weapon_doubletake", "mp_weapon_epg", "mp_weapon_esaw", "mp_weapon_g2", "mp_weapon_hemlok", "mp_weapon_hemlok_smg", "mp_weapon_lmg", "mp_weapon_lstar", "mp_weapon_mastiff", "mp_weapon_mgl", "mp_weapon_pulse_lmg", "mp_weapon_r97", "mp_weapon_rocket_launcher", "mp_weapon_rspn101", "mp_weapon_rspn101_og", "mp_weapon_semipistol", "mp_weapon_shotgun", "mp_weapon_shotgun_pistol", "mp_weapon_smart_pistol", "mp_weapon_smr", "mp_weapon_sniper", "mp_weapon_softball", "mp_weapon_vinson", "mp_weapon_wingman", "mp_weapon_wingman_n" ]
const array<string> MODS = [ "pas_run_and_gun", "threat_scope", "pas_fast_ads", "pas_fast_reload", "extended_ammo", "pas_fast_swap" ]

struct
{
	// Due to team based escalation everything is an array
	array< int > levels = [ LEVEL_SPECTRES, LEVEL_SPECTRES ]
	array< array< string > > podEntities = [ [ "npc_spectre", "npc_spectre", "npc_stalker" ], [ "npc_spectre", "npc_spectre", "npc_stalker" ] ]
	array< bool > reapers = [ false, false ]

	array< bool > marvins = [ false, false ]
	array< bool > prowlers = [ false, false ]
	array< bool > weapondrops = [ false, false ]

	array< bool > gunships = [ false, false ]
	array< bool > pilots = [ false, false ]
	array< bool > titans = [ false, false ]
} file


void function GamemodeAITdm_Init()
{
	SetSpawnpointGamemodeOverride( ATTRITION ) // use bounty hunt spawns as vanilla game has no spawns explicitly defined for aitdm

	AddCallback_GameStateEnter( eGameState.Prematch, OnPrematchStart )
	AddCallback_GameStateEnter( eGameState.Playing, OnPlaying )

	AddCallback_OnNPCKilled( HandleScoreEvent )
	AddCallback_OnPlayerKilled( HandleScoreEvent )

	AddCallback_OnClientConnected( OnPlayerConnected )

	AddCallback_NPCLeeched( OnSpectreLeeched )

	if ( GetCurrentPlaylistVarInt( "aitdm_archer_grunts", 0 ) == 0 )
	{
		AiGameModes_SetGruntWeapons( [ "mp_weapon_alternator_smg", "mp_weapon_r97", "mp_weapon_car", "mp_weapon_vinson", "mp_weapon_rspn101_og" ] )
		AiGameModes_SetSpectreWeapons( [ "mp_weapon_defender", "mp_weapon_sniper", "mp_weapon_doubletake", "mp_weapon_hemlok_smg" ] )
	}
	else
	{
		AiGameModes_SetGruntWeapons( [ "mp_weapon_rocket_launcher" ] )
		AiGameModes_SetSpectreWeapons( [ "mp_weapon_rocket_launcher" ] )
	}

	ScoreEvent_SetupEarnMeterValuesForMixedModes()

	//ClassicMP_ForceDisableEpilogue( true )
	Riff_ForceBoostAvailability( eBoostAvailability.Disabled )
	Riff_ForceTitanAvailability( eTitanAvailability.Never )
}

//------------------------------------------------------

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

void function OnPlayerConnected( entity player )
{
	Remote_CallFunction_NonReplay( player, "ServerCallback_AITDM_OnPlayerConnected" )
}

//------------------------------------------------------

void function HandleScoreEvent( entity victim, entity attacker, var damageInfo )
{
	if ( !( victim != attacker && attacker.IsPlayer() || attacker.IsTitan() && attacker.GetBossPlayer() != null && GetGameState() == eGameState.Playing ) ) //add getowner to this since it crash my game everytime when am trying to deploy a npctitan without a owner
		return

	int score
	string eventName

	//if ( victim.IsNPC() && victim.GetClassName() != "npc_marvin" )
	//{
	//	eventName = ScoreEventForNPCKilled( victim, damageInfo )
	//	if ( eventName != "KillNPCTitan"  && eventName != "" )
	//		score = ScoreEvent_GetPointValue( GetScoreEvent( eventName ) )
	//}

	if ( victim.IsPlayer() )
		score = 3

	if ( victim.GetClassName() == "npc_marvin" )
		score = 1

	if ( victim.GetClassName() == "npc_prowler" )
		score = 2

	if ( victim.GetClassName() == "npc_spectre" )
		score = 2

	if ( victim.GetClassName() == "npc_stalker" )
		score = 2

	if ( victim.GetClassName() == "npc_super_spectre" )
		score = 5

	if ( victim.GetClassName() == "npc_soldier" )
		score = 5
	
	if ( victim.GetClassName() == "npc_drone" )
		score = 0

	if ( victim.GetClassName() == "npc_gunship" )
		score = 5

	if( victim.GetModelName() == $"models/humans/grunts/imc_grunt_shield_captain.mdl" || victim.GetModelName() == $"models/humans/pilots/pilot_light_ged_m.mdl" )
		score = 5

	// Player ejecting triggers this without the extra check
	if ( victim.IsTitan() && victim.GetBossPlayer() != attacker )
		score += 10

	// make npc able to earn score?
	AddTeamScore( attacker.GetTeam(), score )
	if( !attacker.IsNPC() )
	{
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, score )
		attacker.SetPlayerNetInt( "AT_bonusPoints", attacker.GetPlayerGameStat( PGS_ASSAULT_SCORE ) )
	}
}

//------------------------------------------------------

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

		for ( int i = 0; i < SQUADS_PER_TEAM; i++ )
		{
			if ( pods != 0 || ships == 0 )
			{
				int index = i

				if ( index > podNodes.len() - 1 )
					index = RandomInt( podNodes.len() )

				node = podNodes[ index ]
				thread AiGameModes_SpawnDropPod( node.GetOrigin(), node.GetAngles(), team, "npc_spectre", SquadHandler )

				pods--
			}
			else
			{
				if ( startIndex == 0 )
				startIndex = i // save where we started

				node = shipNodes[ i - startIndex ]
				thread AiGameModes_SpawnDropShip( node.GetOrigin(), node.GetAngles(), team, 4, SquadHandler )

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
	thread SpawnerWeapons( team )
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
				if ( reaperCount < REAPERS_PER_TEAM )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					waitthread AiGameModes_SpawnReaper( node.GetOrigin(), node.GetAngles(), team, "npc_super_spectre_aitdm", ReaperHandler )
				}
			}

			// NORMAL SPAWNS
			if ( count < SQUADS_PER_TEAM * 4 - 2 )
			{
				string ent = file.podEntities[ index ][ RandomInt( file.podEntities[ index ].len() ) ]

				// Prefer dropship when spawning grunts
				if ( ent == "npc_soldier" )
				{
					array< entity > points = GetZiplineDropshipSpawns()
					if ( RandomInt( points.len() / 4 ) )
					{
						entity node = points[ GetSpawnPointIndex( points, team ) ]
						waitthread AiGameModes_SpawnDropShip( node.GetOrigin(), node.GetAngles(), team, 4, SquadHandler )
						continue
					}
				}

				array< entity > points = SpawnPoints_GetDropPod()
				entity node = points[ GetSpawnPointIndex( points, team ) ]
				thread AiGameModes_SpawnDropPod( node.GetOrigin(), node.GetAngles(), team, ent, SquadHandler )
			}
		}
		else
			break
		WaitFrame()
	}
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
			int gunshipCount = GetNPCArrayEx( "npc_gunship", team, -1, <0,0,0>, -1 ).len()
	        int titanCount = GetNPCArrayEx( "npc_titan", team, -1, <0,0,0>, -1 ).len()
	        int pilotCount = GetNPCArrayEx( "npc_soldier", team, -1, <0,0,0>, -1 ).len() + GetNPCArrayEx( "npc_titan", team, -1, <0,0,0>, -1 ).len()


	        // GUNSHIPS
	        if ( file.gunships[ index ] )
			{
				array< entity > points = SpawnPoints_GetDropPod()
				if ( gunshipCount < GUNSHIPS_PER_TEAM )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					waitthread AiGameModes_SpawnGunShip( node.GetOrigin(), node.GetAngles(), team)
				}
			}

			// TITANS
			if ( file.titans[ index ] )
			{
				array< entity > points = SpawnPoints_GetDropPod()
				if ( titanCount < TITANS_PER_TEAM )
				{
					entity node = points[ GetSpawnPointIndex( points, team ) ]
					waitthread AiGameModes_SpawnTitanRandom( node.GetOrigin(), node.GetAngles(), team, TitanHandler )
				}
			}

			// PILOTS
			if ( file.pilots[ index ] )
			{
				array< entity > points = SpawnPoints_GetDropPod()
				if ( pilotCount < PILOTS_PER_TEAM )
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
				if ( marvinCount < MARVINS_PER_TEAM )
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
				if ( prowlerCount < PROWLERS_PER_TEAM )
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

void function SpawnerWeapons( int team )
{
	//svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	while( true )
	{
		wait 40
		if( GetGameState() == eGameState.Playing )
		{

			foreach( entity player in GetPlayerArray() )
			{
				if( IsValid(player) )
					SendHudMessage(player, "Delivering Care Package",  -1, 0.3, 255, 255, 0, 255, 0.15, 3, 1)
			}
			array< entity > points = SpawnPoints_GetDropPod()

			entity node = points[ GetSpawnPointIndex( points, team ) ]
			//waitthread SpawnReaperDorpsWeapons( node.GetOrigin(), node.GetAngles(), WEAPONS, MODS )
			AiGameModes_SpawnDropPodToGetWeapons( node.GetOrigin(), node.GetAngles() )
		}
		else
			break
	}
}

// Based on points tries to balance match
void function Escalate( int team )
{
	int score = GameRules_GetTeamScore( team )
	int index = team == TEAM_MILITIA ? 1 : 0
	// This does the "Enemy x incoming" text
	string defcon = team == TEAM_MILITIA ? "IMCdefcon" : "MILdefcon"

	if ( score < file.levels[ index ] )
		return

	switch ( file.levels[ index ] )
	{
		case LEVEL_SPECTRES:
			file.levels[ index ] = LEVEL_STALKERS
			file.marvins[ index ] = true
			//file.podEntities[ index ].append( "npc_spectre" )
			SetGlobalNetInt( defcon, 2 )
			return

		case LEVEL_STALKERS:
			file.levels[ index ] = LEVEL_REAPERS
			file.marvins[ index ] = false
			file.weapondrops[ index ] = true
			file.prowlers[ index ] = true
			//file.podEntities[ index ].append( "npc_stalker" )
			SetGlobalNetInt( defcon, 3 )
			return

		case LEVEL_REAPERS:
			file.levels[ index ] = LEVEL_GUNSHIPS
			file.reapers[ index ] = true
			SetGlobalNetInt( defcon, 4 )
			return

        case LEVEL_GUNSHIPS:
			file.levels[ index ] = LEVEL_TITANS
			file.gunships[ index ] = true
			SetGlobalNetInt( defcon, 5 )
			return


		case LEVEL_TITANS:
			file.levels[ index ] = 9999
			file.prowlers[ index ] = false
			file.pilots[ index ] = true
			file.titans[ index ] = true
			SetGlobalNetInt( defcon, 6 )
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
	player.SetPlayerNetInt("AT_bonusPoints", player.GetPlayerGameStat( PGS_ASSAULT_SCORE ) )
}

void function ReaperHandler( entity reaper )
{
	array<entity> players = GetPlayerArrayOfEnemies( reaper.GetTeam() )
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