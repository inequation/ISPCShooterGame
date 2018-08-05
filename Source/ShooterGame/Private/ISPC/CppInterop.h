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

typedef int<3> FName;

typedef float<2> FVector2D;
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
	const UShooterUnrolledCppMovement* const* Comp;

	const USceneComponent* const* UpdatedComponent;
	const ACharacter* const* CharacterOwner;
	EMovementMode* MovementMode;
	const
#ifdef ISPC
		EComponentMobility
#else
		EComponentMobility::Type
#endif
		* const UpdatedComponent_Mobility;
	const ENetRole* const CharacterOwner_Role;
	const bool* const UpdatedComponent_IsSimulatingPhysics;
	const bool* const CharacterOwner_bClientUpdating;
	const bool* const CharacterOwner_IsPlayingRootMotion;
	const bool* const CharacterOwner_bServerMoveIgnoreRootMotion;
	const bool* const CharacterOwner_IsMatineeControlled;
	const bool* const CharacterOwner_HasAuthority;
	bool* CharacterOwner_bIsCrouched;
	const bool* const NavAgentProps_bCanCrouch;
	const USkeletalMeshComponent* const* CharacterOwner_GetMesh;
	FVector* const CharacterOwner_CapsuleComponent_Size;	// x = Radius, y = HalfHeight, z = ShapeScale
	// Comp->CharacterOwner->GetClass()->GetDefaultObject<ACharacter>()->GetUnscaledCapsuleRadius/GetUnscaledCapsuleHalfHeight()
	const FVector2D* const DefaultCharacter_CapsuleComponent_UnscaledSize;

	const float* const CrouchedHalfHeight;

	FVector* PendingImpulseToApply;
	FVector* PendingForceToApply;
	FVector* PendingLaunchVelocity;

	bool* bForceNextFloorCheck;
	bool* bShrinkProxyCapsule;

	FVector* LastUpdateLocation;

	const bool* const CurrentRootMotion_HasActiveRootMotionSources;

	bool* bDeferUpdateBasedMovement;

	const UPrimitiveComponent* const* CharacterOwner_MovementBase;

	const bool* const RootMotionParams_bHasRootMotion;

	FVector* Velocity;
};
