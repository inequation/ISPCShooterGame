#pragma once

// HACK!!!
#ifdef ISPC
#define class struct
#endif

// Only pointers of these types are used in ISPC. Intentionally opaque.
class UShooterUnrolledCppMovement;
class USceneComponent;
class ACharacter;
class USkeletalMeshComponent;
class USceneComponent;
class UPrimitiveComponent;

// Define a bunch of types for ISPC.
#ifdef ISPC

typedef int<3> FName;
typedef int<2> FWeakObjectPtr;

typedef float<2> FVector2D;
typedef float<3> FVector;
typedef float<4> FQuat;

typedef unsigned int8 uint8;
typedef unsigned int32 uint32;

// NOTE: Must be identical to the definition in EngineTypes.h!
enum EMovementMode
{
	/** None (movement is disabled). */
	MOVE_None,

	/** Walking on a surface. */
	MOVE_Walking,

	/**
	* Simplified walking on navigation data (e.g. navmesh).
	* If bGenerateOverlapEvents is true, then we will perform sweeps with each navmesh move.
	* If bGenerateOverlapEvents is false then movement is cheaper but characters can overlap other objects without some extra process to repel/resolve their collisions.
	*/
	MOVE_NavWalking,

	/** Falling under the effects of gravity, such as after jumping or walking off the edge of a surface. */
	MOVE_Falling,

	/** Swimming through a fluid volume, under the effects of gravity and buoyancy. */
	MOVE_Swimming,

	/** Flying, ignoring the effects of gravity. Affected by the current physics volume's fluid friction. */
	MOVE_Flying,

	/** User-defined custom movement mode, including many possible sub-modes. */
	MOVE_Custom,

	MOVE_MAX,
};

enum EComponentMobility
{
	/**
	 * Static objects cannot be moved or changed in game.
	 * - Allows baked lighting
	 * - Fastest rendering
	 */
	EComponentMobility_Static,

	/**
	 * A stationary light will only have its shadowing and bounced lighting from static geometry baked by Lightmass, all other lighting will be dynamic.
	 * - It can change color and intensity in game.
	 * - Can't move
	 * - Allows partial baked lighting
	 * - Dynamic shadows
	 */
	EComponentMobility_Stationary,

	/**
	 * Movable objects can be moved and changed in game.
	 * - Totally dynamic
	 * - Can cast dynamic shadows
	 * - Slowest rendering
	 */
	EComponentMobility_Movable
};

enum ENetRole
{
	/** No role at all. */
	ROLE_None,
	/** Locally simulated proxy of this actor. */
	ROLE_SimulatedProxy,
	/** Locally autonomous proxy of this actor. */
	ROLE_AutonomousProxy,
	/** Authoritative control over the actor. */
	ROLE_Authority,
	ROLE_MAX,
};

enum ECollisionChannel
{

	ECC_WorldStatic,
	ECC_WorldDynamic,
	ECC_Pawn,
	ECC_Visibility,
	ECC_Camera,
	ECC_PhysicsBody,
	ECC_Vehicle,
	ECC_Destructible,

	/** Reserved for gizmo collision */
	ECC_EngineTraceChannel1,

	ECC_EngineTraceChannel2,
	ECC_EngineTraceChannel3,
	ECC_EngineTraceChannel4,
	ECC_EngineTraceChannel5,
	ECC_EngineTraceChannel6,

	ECC_GameTraceChannel1,
	ECC_GameTraceChannel2,
	ECC_GameTraceChannel3,
	ECC_GameTraceChannel4,
	ECC_GameTraceChannel5,
	ECC_GameTraceChannel6,
	ECC_GameTraceChannel7,
	ECC_GameTraceChannel8,
	ECC_GameTraceChannel9,
	ECC_GameTraceChannel10,
	ECC_GameTraceChannel11,
	ECC_GameTraceChannel12,
	ECC_GameTraceChannel13,
	ECC_GameTraceChannel14,
	ECC_GameTraceChannel15,
	ECC_GameTraceChannel16,
	ECC_GameTraceChannel17,
	ECC_GameTraceChannel18,

	/** Add new serializeable channels above here (i.e. entries that exist in FCollisionResponseContainer) */
	/** Add only nonserialized/transient flags below */

	// NOTE!!!! THESE ARE BEING DEPRECATED BUT STILL THERE FOR BLUEPRINT. PLEASE DO NOT USE THEM IN CODE

	ECC_OverlapAll_Deprecated,
	ECC_MAX,
};

enum ECollisionShape
{
	Line,
	Box,
	Sphere,
	Capsule
};

//
// MoveComponent options.
//
enum EMoveComponentFlags
{
	// Bitflags.
	MOVECOMP_NoFlags						= 0x0000,	// no flags
	MOVECOMP_IgnoreBases					= 0x0001,	// ignore collisions with things the Actor is based on
	MOVECOMP_SkipPhysicsMove				= 0x0002,	// when moving this component, do not move the physics representation. Used internally to avoid looping updates when syncing with physics.
	MOVECOMP_NeverIgnoreBlockingOverlaps	= 0x0004,	// never ignore initial blocking overlaps during movement, which are usually ignored when moving out of an object. MOVECOMP_IgnoreBases is still respected.
	MOVECOMP_DisableBlockingOverlapDispatch	= 0x0008,	// avoid dispatching blocking hit events when the hit started in penetration (and is not ignored, see MOVECOMP_NeverIgnoreBlockingOverlaps).
};

/** Whether to teleport physics body or not */
enum ETeleportType
{
	/** Do not teleport physics body. This means velocity will reflect the movement between initial and final position, and collisions along the way will occur */
	None,
	/** Teleport physics body so that velocity remains the same and no collision occurs */
	TeleportPhysics
};

/**
 * The network mode the game is currently running.
 * @see https://docs.unrealengine.com/latest/INT/Gameplay/Networking/Overview/
 */
enum ENetMode
{
	/** Standalone: a game without networking, with one or more local players. Still considered a server because it has all server functionality. */
	NM_Standalone,

	/** Dedicated server: server with no local players. */
	NM_DedicatedServer,

	/** Listen server: a server that also has a local player who is hosting the game, available to other players on the network. */
	NM_ListenServer,

	/**
	 * Network client: client connected to a remote server.
	 * Note that every mode less than this value is a kind of server, so checking NetMode < NM_Client is always some variety of server.
	 */
	NM_Client,

	NM_MAX,
};

struct FCollisionShape
{
	ECollisionShape ShapeType;

	float HalfExtentX;
	float HalfExtentY;
	float HalfExtentZ;
};

// Replicating this on the ISPC side is not practical.
struct FCollisionQueryParams
{
	int8 _Dummy[128];
};

// Replicating this on the ISPC side is not practical.
struct FCollisionResponseParams
{
	int8 _Dummy[128];
};

struct FHitResult
{
	// ISPC: This is a bitfield on uint8 on the C++ side!
	uint8 bBlockingHit_bStartPenetrating;

	/** Face index we hit (for complex hits with triangle meshes). */
	int32 FaceIndex;

	/**
	 * 'Time' of impact along trace direction (ranging from 0.0 to 1.0) if there is a hit, indicating time between TraceStart and TraceEnd.
	 * For swept movement (but not queries) this may be pulled back slightly from the actual time of impact, to prevent precision problems with adjacent geometry.
	 */
	float Time;
	 
	/** The distance from the TraceStart to the Location in world space. This value is 0 if there was an initial overlap (trace started inside another colliding object). */
	float Distance; 
	
	/**
	 * The location in world space where the moving shape would end up against the impacted object, if there is a hit. Equal to the point of impact for line tests.
	 * Example: for a sphere trace test, this is the point where the center of the sphere would be located when it touched the other object.
	 * For swept movement (but not queries) this may not equal the final location of the shape since hits are pulled back slightly to prevent precision issues from overlapping another surface.
	 */
	/*FVector*/float Location[3];

	/**
	 * Location in world space of the actual contact of the trace shape (box, sphere, ray, etc) with the impacted object.
	 * Example: for a sphere trace test, this is the point where the surface of the sphere touches the other object.
	 * @note: In the case of initial overlap (bStartPenetrating=true), ImpactPoint will be the same as Location because there is no meaningful single impact point to report.
	 */
	/*FVector*/float ImpactPoint[3];

	/**
	 * Normal of the hit in world space, for the object that was swept. Equal to ImpactNormal for line tests.
	 * This is computed for capsules and spheres, otherwise it will be the same as ImpactNormal.
	 * Example: for a sphere trace test, this is a normalized vector pointing in towards the center of the sphere at the point of impact.
	 */
	/*FVector*/float Normal[3];

	/**
	 * Normal of the hit in world space, for the object that was hit by the sweep, if any.
	 * For example if a box hits a flat plane, this is a normalized vector pointing out from the plane.
	 * In the case of impact with a corner or edge of a surface, usually the "most opposing" normal (opposed to the query direction) is chosen.
	 */
	/*FVector*/float ImpactNormal[3];

	/**
	 * Start location of the trace.
	 * For example if a sphere is swept against the world, this is the starting location of the center of the sphere.
	 */
	/*FVector*/float TraceStart[3];

	/**
	 * End location of the trace; this is NOT where the impact occurred (if any), but the furthest point in the attempted sweep.
	 * For example if a sphere is swept against the world, this would be the center of the sphere if there was no blocking hit.
	 */
	/*FVector*/float TraceEnd[3];

	/**
	  * If this test started in penetration (bStartPenetrating is true) and a depenetration vector can be computed,
	  * this value is the distance along Normal that will result in moving out of penetration.
	  * If the distance cannot be computed, this distance will be zero.
	  */
	float PenetrationDepth;

	/** Extra data about item that was hit (hit primitive specific). */
	int32 Item;

	/**
	 * Physical material that was hit.
	 * @note Must set bReturnPhysicalMaterial on the swept PrimitiveComponent or in the query params for this to be returned.
	 */
	/*TWeakObjectPtr<class UPhysicalMaterial>*/int PhysMaterial[2];

	/** Actor hit by the trace. */
	/*TWeakObjectPtr<class AActor>*/int Actor[2];

	/** PrimitiveComponent hit by the trace. */
	/*TWeakObjectPtr<class UPrimitiveComponent>*/int Component[2];

	/** Name of bone we hit (for skeletal meshes). */
	/*FName*/int BoneName[3];

	/** Name of the _my_ bone which took part in hit event (in case of two skeletal meshes colliding). */
	/*FName*/int MyBoneName[3];
};

struct FFindFloorResult
{
	// ISPC: This is a bitfield on uint32 on the C++ side!
	/**
	* True if there was a blocking hit in the floor test that was NOT in initial penetration.
	* The HitResult can give more info about other circumstances.
	*/
	/** True if the hit found a valid walkable floor. */
	/** True if the hit found a valid walkable floor using a line trace (rather than a sweep test, which happens when the sweep test fails to yield a walkable surface). */
	uint32 bBlockingHit_bWalkableFloor_bLineTrace;

	/** The distance to the floor, computed from the swept capsule trace. */
	float FloorDist;
	
	/** The distance to the floor, computed from the trace. Only valid if bLineTrace is true. */
	float LineDist;

	/** Hit result of the test that found a floor. Includes more specific data about the point of impact and surface normal at that point. */
	FHitResult HitResult;
};

#define FORCEINLINE	inline
#define INDEX_NONE -1
#else
#include "Engine/EngineTypes.h"
#endif
