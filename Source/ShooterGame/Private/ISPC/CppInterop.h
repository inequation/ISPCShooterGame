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
	#include "ISPCOverloads.h"
#endif

#include "UnrealTypesForISPC.h"

// The primary type we're working with.
struct FISPCMovementArrays
{
	// The Unreal objects. Intentionally opaque, only used for calls back into C++.
	const /*UShooterUnrolledCppMovement**/void* const* Comp;
	const /*USceneComponent**/void* const* UpdatedComponent;
	const /*USceneComponent**/void* const* DeferredUpdatedMoveComponent;
	const /*UPrimitiveComponent**/void* const* UpdatedPrimitive;
	const /*ACharacter**/void* const* CharacterOwner;
	const /*UPrimitiveComponent**/void* const* CharacterOwner_MovementBase;

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
	const /*USkeletalMeshComponent**/void* const* CharacterOwner_GetMesh;
	const bool* const NavAgentProps_bCanCrouch;
	const FVector2D* const DefaultCharacter_CapsuleComponent_UnscaledSize;	// Comp->CharacterOwner->GetClass()->GetDefaultObject<ACharacter>()->GetUnscaledCapsuleRadius/GetUnscaledCapsuleHalfHeight()
	const ECollisionChannel* const UpdatedComponent_CollisionObjectType;
	const FCollisionShape* const PawnCapsuleCollisionShape_ShrinkCapsuleExtent_None;
	const bool* const CurrentRootMotion_HasActiveRootMotionSources;
	const bool* const RootMotionParams_bHasRootMotion;

	const bool* const bCrouchMaintainsBaseLocation;
	const bool* const bWantsToCrouch;
	const bool* const bWantsToLeaveNavWalking;
	const bool* const bAllowPhysicsRotationDuringAnimRootMotion;
	const float* const CrouchedHalfHeight;
	const int32* const MaxSimulationIterations;
	FFindFloorResult* CurrentFloor;
	
	EMovementMode* MovementMode;
	bool* CharacterOwner_bIsCrouched;
	FVector* const CharacterOwner_CapsuleComponent_Size;	// x = Radius, y = HalfHeight, z = ShapeScale
	FQuat* const UpdatedComponent_ComponentQuat;

	FVector* PendingImpulseToApply;
	FVector* PendingForceToApply;
	FVector* PendingLaunchVelocity;

	bool* bForceNextFloorCheck;
	bool* bShrinkProxyCapsule;
	bool* bDeferUpdateBasedMovement;
	bool* bDeferUpdateMoveComponent;
	bool* bHasRequestedVelocity;
	bool* bMovementInProgress;

	FVector* LastUpdateLocation;
	FVector* Velocity;
};
