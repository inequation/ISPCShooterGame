#pragma once

// Only pointers of these types are used in ISPC. Intentionally opaque.
class UShooterUnrolledCppMovement;
class USceneComponent;
class ACharacter;
class USkeletalMeshComponent;
class USceneComponent;
class UPrimitiveComponent;

// Define a bunch of types for ISPC.
#ifdef ISPC
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

typedef int<3> FName;

typedef float<2> FVector2D;
typedef float<3> FVector;
typedef float<4> FQuat;

#define FORCEINLINE	inline
#define INDEX_NONE -1
#else
#include "Engine/EngineTypes.h"
#endif
