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

inline void* uniform extract(void* varying x, uniform int i)
{
	return (void* uniform)extract((unsigned int64)x, i);
}
inline const void* uniform extract(const void* varying x, uniform int i)
{
	return (const void* uniform)extract((unsigned int64)x, i);
}
inline bool uniform extract(bool varying x, uniform int i)
{
	return (uniform bool)extract((int8)x, i);
}
inline uniform int<3> extract(varying int<3> v, uniform int i)
{
	uniform int<3> u;
	u.x = extract(v.x, i);
	u.y = extract(v.y, i);
	u.z = extract(v.z, i);
	return v;
}
inline uniform float<4> extract(varying float<4> v, uniform int i)
{
	uniform float<4> u;
	u.x = extract(v.x, i);
	u.y = extract(v.y, i);
	u.z = extract(v.z, i);
	u.w = extract(v.w, i);
	return v;
}

inline varying bool insert(varying bool v, uniform int32 index, uniform bool u)
{
	return (varying bool)insert((varying int8)v, index, (uniform int8)u);
}
inline varying float<3> insert(varying float<3> v, uniform int32 index, uniform float<3> u)
{
	v.x = insert(v.x, index, u.x);
	v.y = insert(v.y, index, u.y);
	v.z = insert(v.z, index, u.z);
	return v;
}
#endif

#include "UnrealTypesForISPC.h"

// The primary type we're working with.
struct FISPCMovementArrays
{
	// The Unreal components. Intentionally opaque, only used for calls back into C++.
	const UShooterUnrolledCppMovement* const* Comp;

	const USceneComponent* const* UpdatedComponent;
	const UPrimitiveComponent* const* UpdatedPrimitive;
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
	
	const ECollisionChannel* const UpdatedComponent_CollisionObjectType;
	const FCollisionShape* const PawnCapsuleCollisionShape_ShrinkCapsuleExtent_None;
	const FCollisionShape* const PawnCapsuleCollisionShape_ShrinkCapsuleExtent_HeightCustom;

	const bool* const bCrouchMaintainsBaseLocation;
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
