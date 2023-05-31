global function OnProjectileCollision_weapon_frag_drone
global function OnProjectileExplode_weapon_frag_drone
global function OnWeaponAttemptOffhandSwitch_weapon_frag_drone
global function OnWeaponTossReleaseAnimEvent_weapon_frag_drone
global function MpWeaponFragDrone_Init

global table<entity, int> placedDrones

void function MpWeaponFragDrone_Init()
{
	RegisterSignal( "OnFragDroneCollision" )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.damagedef_frag_drone_throwable_PLAYER, FragDrone_OnDamagePlayerOrNPC )
		AddCallback_OnClientConnected( placedDronesInit )
		AddCallback_OnPlayerKilled( ResetDrones )
	#endif
}

void function placedDronesInit( entity player )
{
	placedDrones[player] <- 0
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
	print("Created placedDrones for " + player)
}

void function ResetDrones( entity victim, entity attacker, var damageInfo )
{
	placedDrones[victim] <- 0
}

void function OnProjectileCollision_weapon_frag_drone( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
		if ( hitEnt.GetClassName() != "func_brush" )
		{
			if ( projectile.proj.projectileBounceCount > 0 )
				return

			float dot = normal.Dot( Vector( 0, 0, 1 ) )

			if ( dot < 0.7 )
				return

			projectile.proj.projectileBounceCount += 1

 			thread DelayedExplode( projectile, 0.75 )
		}
	#endif
}


var function OnWeaponTossReleaseAnimEvent_weapon_frag_drone( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	Grenade_OnWeaponTossReleaseAnimEvent( weapon, attackParams )

	#if SERVER && MP // TODO: should be BURNCARDS
		if ( weapon.HasMod( "burn_card_weapon_mod" ) )
			TryUsingBurnCardWeapon( weapon, weapon.GetWeaponOwner() )
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}


void function OnProjectileExplode_weapon_frag_drone( entity projectile )
{
	#if SERVER

	if( projectile.ProjectileGetMods().contains( "drone_spawner" ) )
		return TicksToDrones( projectile )
	if( projectile.ProjectileGetMods().contains( "cloak_drone_spawner" ) )
		return TicksToCloak( projectile )

		vector origin = projectile.GetOrigin()
		entity owner = projectile.GetThrower()

		if ( !IsValid( owner ) )
			return

		int team = owner.GetTeam()

		entity drone = CreateFragDroneCan( team, origin, < 0, projectile.GetAngles().y, 0 > )
		SetSpawnOption_AISettings( drone, "npc_frag_drone_throwable" )
		DispatchSpawn( drone )

		vector ornull clampedPos = NavMesh_ClampPointForAIWithExtents( origin, drone, < 20, 20, 36 > )
		if ( clampedPos != null )
		{
			expect vector( clampedPos )
			drone.SetOrigin( clampedPos )
		}
		else
		{
			projectile.GrenadeExplode( Vector( 0, 0, 0 ) )
			drone.Signal( "SuicideSpectreExploding" )
			return
		}

		int followBehavior = GetDefaultNPCFollowBehavior( drone )
		if ( owner.IsPlayer() )
		{
			drone.SetBossPlayer( owner )
			UpdateEnemyMemoryWithinRadius( drone, 1000 )
		}
		else if ( owner.IsNPC() )
		{
			entity enemy = owner.GetEnemy()
			if ( IsAlive( enemy ) )
				drone.SetEnemy( enemy )
		}

		if ( IsSingleplayer() && IsAlive( owner ) )
		{
			drone.InitFollowBehavior( owner, followBehavior )
			drone.EnableBehavior( "Follow" )
		}
		else
		{
			drone.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_NEW_ENEMY_FROM_SOUND )
		}

		thread FragDroneDeplyAnimation( drone, 0.0, 0.1 )
		thread WaitForEnemyNotification( drone )
	#endif
}

#if SERVER
void function FragDroneLifetime( entity drone )
{
	drone.EndSignal( "OnDestroy" )
	drone.EndSignal( "OnDeath" )

	EmitSoundOnEntity( drone, "weapon_sentryfragdrone_emit_loop" )
	wait 15.0
	drone.Signal( "SuicideSpectreExploding" )
}

void function FragKill( entity drone )
{
	drone.EndSignal( "OnDestroy" )
	drone.EndSignal( "OnDeath" )

	drone.Signal( "SuicideSpectreExploding" )
}

void function DelayedExplode( entity projectile, float delay )
{
	projectile.Signal( "OnFragDroneCollision" )
	projectile.EndSignal( "OnFragDroneCollision" )
	projectile.EndSignal( "OnDestroy" )

	wait delay
	while( TraceLineSimple( projectile.GetOrigin(), projectile.GetOrigin() - <0,0,15>, projectile ) == 1.0 )
		wait 0.25

	projectile.GrenadeExplode( Vector( 0, 0, 0 ) )
}

void function WaitForEnemyNotification( entity drone )
{
	drone.EndSignal( "OnDeath" )

	entity owner
	entity currentTarget

	while ( true )
	{
		//----------------------------------
		// Get owner and current enemy
		//----------------------------------
		currentTarget = drone.GetEnemy()
		owner = drone.GetFollowTarget()

		//----------------------------------
		// Free roam if owner is dead or HasEnemy
		//----------------------------------
		if ( !IsAlive( owner ) || currentTarget != null )
		{
			drone.DisableBehavior( "Follow" )
		}
		else
		{
			drone.ClearEnemy()
			drone.EnableBehavior( "Follow" )
		}

		wait 0.25
	}

}

void function FragDrone_OnDamagePlayerOrNPC( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

	if ( ent != attacker )
		return

	DamageInfo_SetDamage( damageInfo, 0.0 )
}
#endif

bool function OnWeaponAttemptOffhandSwitch_weapon_frag_drone( entity weapon )
{
	entity weaponOwner = weapon.GetOwner()
	if ( weaponOwner.IsPhaseShifted() )
		return false

	return true
}


#if SERVER
void function TicksToDrones( entity tick )
{
	entity tickowner = tick.GetThrower()
	if (placedDrones[ tickowner ] != 2)
	{
		thread TicksToDronesThreaded( tick )
	}
}

void function TicksToCloak( entity tick )
{
	thread TicksToCloakThreaded( tick )
}

void function TicksToDronesThreaded( entity tick )
{
	entity tickowner = tick.GetThrower()
	vector tickpos = tick.GetOrigin() + Vector(0,0,50)
	vector tickang = tick.GetAngles()
	int tickteam = tick.GetTeam()

	int randomdrone = RandomInt(3)
	string dronename = "npc_drone_worker"
	switch( randomdrone )
	{
		case 0:
			dronename = "npc_drone_beam"
			break
		case 1:
			dronename = "npc_drone_rocket"
			break
		case 2:
			dronename = "npc_drone_plasma"
			break
		default:
			break
	}

	entity drone = CreateNPC("npc_drone" , tickteam , tickpos, tickang )
	SetSpawnOption_AISettings( drone, dronename )
	DispatchSpawn( drone )

	drone.SetOwner( tickowner )
	drone.SetBossPlayer( tickowner )
	drone.SetMaxHealth( 100 )
	drone.SetHealth( 100 )
	entity weapon = drone.GetActiveWeapon()
	string classname = weapon.GetWeaponClassName()
	print( "Drone's Active Weapon is " + classname )
	drone.TakeWeaponNow( classname )
	drone.GiveWeapon( classname, ["npc_elite_weapon"] )
	drone.SetActiveWeaponByName( classname )
	NPCFollowsPlayer( drone, tickowner )

	/*
	int followBehavior = GetDefaultNPCFollowBehavior( drone )
    drone.InitFollowBehavior( tickowner, followBehavior )
    drone.EnableBehavior( "Follow" )
    */
   	placedDrones[tickowner] = placedDrones[tickowner] + 1
	print("Player has " + placedDrones[tickowner] + " drones")
}

void function TicksToCloakThreaded( entity tick )
{
	entity tickowner = tick.GetThrower()
	vector tickpos = tick.GetOrigin() + Vector(0,0,50)
	vector tickang = tick.GetAngles()
	int tickteam = tick.GetTeam()

	string dronename = "npc_drone_cloaked"

	entity drone = CreateNPC("npc_drone" , tickteam , tickpos, tickang )
	SetSpawnOption_AISettings( drone, dronename )
	DispatchSpawn( drone )

	drone.SetOwner( tickowner )
	drone.SetBossPlayer( tickowner )
	drone.SetMaxHealth( 100 )
	drone.SetHealth( 100 )
	string weapon = "mp_weapon_deployable_cloakfield"
	drone.GiveWeapon( weapon )
	drone.SetActiveWeaponByName( weapon )
	NPCFollowsPlayer( drone, tickowner )

	/*
	int followBehavior = GetDefaultNPCFollowBehavior( drone )
    drone.InitFollowBehavior( tickowner, followBehavior )
    drone.EnableBehavior( "Follow" )
    */
}
#endif