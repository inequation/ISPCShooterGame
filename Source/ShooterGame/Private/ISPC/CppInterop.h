#pragma once

// Make mutual C++/ISPC parsing a bit easier.
#if !defined(ISPC) || defined(__INTELLISENSE__)
	#define export
	#define uniform
	#ifdef __INTELLISENSE__
		#define varying
	#else
		#define varying static_assert(false, "The 'varying' keyword should never appear in C++-visible code")
	#endif
#else
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

typedef int<3> FName;

typedef float<3> FVector;

#define FORCEINLINE	inline
#define INDEX_NONE -1
#else
#include "Engine/EngineTypes.h"
#endif

// The primary type we're working with.
struct FISPCMovementArrays
{
	// The Unreal components. Intentionally opaque, only used for calls back into C++.
	UShooterUnrolledCppMovement** Comp;

	USceneComponent** UpdatedComponent;
	ACharacter** CharacterOwner;
	EMovementMode* MovementMode;
#ifdef ISPC
	EComponentMobility
#else
	EComponentMobility::Type
#endif
		* UpdatedComponent_Mobility;
	bool* UpdatedComponent_IsSimulatingPhysics;
	bool* CharacterOwner_bClientUpdating;
	bool* CharacterOwner_IsPlayingRootMotion;
	bool* CharacterOwner_bServerMoveIgnoreRootMotion;
	bool* CharacterOwner_IsMatineeControlled;
	bool* CharacterOwner_HasAuthority;
	USkeletalMeshComponent** CharacterOwner_GetMesh;

	FVector* PendingImpulseToApply;
	FVector* PendingForceToApply;
	FVector* PendingLaunchVelocity;

	bool* bForceNextFloorCheck;

	FVector* LastUpdateLocation;

	bool* CurrentRootMotion_HasActiveRootMotionSources;

	bool* bDeferUpdateBasedMovement;

	UPrimitiveComponent** CharacterOwner_MovementBase;

	bool* RootMotionParams_bHasRootMotion;

	FVector* Velocity;
};
