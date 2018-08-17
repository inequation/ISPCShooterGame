#pragma once

// Shut up some IntelliNonsense.
#ifdef __INTELLISENSE__
	#define foreach(...) while (true)
	#define ISPC
	#define unimplemented()	void
#else
	#define unimplemented() check(false)
#endif
#define check(...)	assert(__VA_ARGS__)
#ifndef NDEBUG
	#define checkCode(Code)	do { Code } while (false);
#else
	#define checkCode(Code)
#endif
#define ensureMsgf(...)	// FIXME ISPC

// TODO ISPC: Feed these back to C++?
#define SCOPE_CYCLE_COUNTER(...)

#include "CppInterop.h"

struct FISPCMovementContext
{
	uniform FISPCMovementArrays* Arrays;
	varying int Index;
};

#define CtxAccess(Field)	(Ctx.Arrays->Field[Ctx.Index])

#include "CppCallbacks.inl"

#define UNIMPLEMENTED_CODE	0

// MAGIC NUMBERS
const uniform float MIN_TICK_TIME = 1e-6f;
const uniform float MIN_FLOOR_DIST = 1.9f;
const uniform float MAX_FLOOR_DIST = 2.4f;
const uniform float BRAKE_TO_STOP_VELOCITY = 10.f;
const uniform float SWEEP_EDGE_REJECT_DISTANCE = 0.15f;
const uniform float MAX_STEP_SIDE_Z = 0.08f;	// maximum z value for the normal on the vertical side of steps
const uniform float SWIMBOBSPEED = -80.f;
const uniform float VERTICAL_SLOPE_NORMAL_Z = 0.001f; // Slope is vertical if Abs(Normal.Z) <= this threshold. Accounts for precision problems that sometimes angle normals slightly off horizontal for vertical surface.
#define SMALL_NUMBER		(1.e-8f)
#define KINDA_SMALL_NUMBER	(1.e-4f)

const uniform FVector FVector_ZeroVector = { 0, 0, 0 };
const uniform FQuat FQuat_Identity = { 0, 0, 0, 1 };
static const uniform FCollisionResponseParams FCollisionResponseParams_DefaultResponseParam;	// FIXME ISPC
inline FVector2D MakeFVector2D(float X, float Y) { FVector2D V = { X, Y }; return V; }
inline FVector MakeFVector(float X, float Y, float Z) { FVector V = { X, Y, Z }; return V; }
inline bool FVector_Equal(FVector A, FVector B) { return A.x == B.x && A.y == B.y && A.z == B.z; }
inline bool FVector_IsZero(FVector A) { return A.x == 0.f && A.y == 0.f && A.z == 0.f; }
inline bool FQuat_Equal(FQuat A, FQuat B) { return A.x == B.x && A.y == B.y && A.z == B.z && A.w == B.w; }

inline FHitResult MakeFHitResult()
{
	FHitResult Result;
	memset(&Result, 0, sizeof(Result));
	Result.Time = 1.f;
	return Result;
}
inline FHitResult MakeFHitResult(float Time)
{
	FHitResult Result = MakeFHitResult();
	Result.Time = Time;
	return Result;
}
inline bool FHitResult_bBlockingHit(const FHitResult& Hit)
{
	return 0 != (Hit.bBlockingHit_bStartPenetrating & 0b01);
}
inline bool FHitResult_bStartPenetrating(const FHitResult& Hit)
{
	return 0 != (Hit.bBlockingHit_bStartPenetrating & 0b10);
}
/** Return true if there was a blocking hit that was not caused by starting in penetration. */
inline bool FHitResult_IsValidBlockingHit(const FHitResult& Hit)
{
	return Hit.bBlockingHit_bStartPenetrating == 0b01;
}
inline bool FFindFloorResult_bBlockingHit(const FFindFloorResult* Floor)
{
	return 0 != (Floor->bBlockingHit_bWalkableFloor_bLineTrace & 0b001);
}
inline bool FFindFloorResult_bWalkableFloor(const FFindFloorResult* Floor)
{
	return 0 != (Floor->bBlockingHit_bWalkableFloor_bLineTrace & 0b010);
}
inline bool FFindFloorResult_bLineTrace(const FFindFloorResult* Floor)
{
	return 0 != (Floor->bBlockingHit_bWalkableFloor_bLineTrace & 0b100);
}


FVector GetUpdatedComponentLocation(FISPCMovementContext Ctx)
{
	return GetUpdatedComponentLocation(CtxAccess(Comp));
}

// Forward declarations.
bool HasValidData(const varying FISPCMovementContext Ctx);
void StartNewPhysics(FISPCMovementContext Ctx, float deltaTime, int32 Iterations);
void SetMovementMode(FISPCMovementContext Ctx, EMovementMode NewMovementMode);
void ClearAccumulatedForces(FISPCMovementContext Ctx);
bool IsFlying(FISPCMovementContext Ctx);
bool IsMovingOnGround(FISPCMovementContext Ctx);
bool IsFalling(FISPCMovementContext Ctx);
bool IsSwimming(FISPCMovementContext Ctx);
bool IsCrouching(FISPCMovementContext Ctx);
bool HasRootMotionSources(FISPCMovementContext Ctx);
bool HasAnimRootMotion(FISPCMovementContext Ctx);
void MaybeUpdateBasedMovement(FISPCMovementContext Ctx, float DeltaSeconds);
void ApplyAccumulatedForces(FISPCMovementContext Ctx, float DeltaSeconds);
void UpdateCharacterStateBeforeMovement(FISPCMovementContext Ctx);
void UpdateCharacterStateAfterMovement(FISPCMovementContext Ctx);
bool HandlePendingLaunch(FISPCMovementContext Ctx);
void PhysicsRotation(FISPCMovementContext Ctx, float DeltaTime);
bool CanCrouchInCurrentState(FISPCMovementContext Ctx);
void Crouch(FISPCMovementContext Ctx, bool bClientSimulation);
void UnCrouch(FISPCMovementContext Ctx, bool bClientSimulation);
const uint8* GetPathName(const void* _Object);
const uint8* GetName(const void* _Object);
void PhysWalking(FISPCMovementContext Ctx, float deltaTime, int32 Iterations);
void PhysNavWalking(FISPCMovementContext Ctx, float deltaTime, int32 Iterations);
void PhysFalling(FISPCMovementContext Ctx, float deltaTime, int32 Iterations);
void PhysFlying(FISPCMovementContext Ctx, float deltaTime, int32 Iterations);
void PhysSwimming(FISPCMovementContext Ctx, float deltaTime, int32 Iterations);
void PhysCustom(FISPCMovementContext Ctx, float deltaTime, int32 Iterations);
void SetUpdatedComponent(FISPCMovementContext Ctx, const /*USceneComponent**/void* NewUpdatedComponent);
void CallMovementUpdateDelegate(FISPCMovementContext Ctx, float DeltaTime, const FVector OldLocation, const FVector OldVelocity);
void MaybeSaveBaseLocation(FISPCMovementContext Ctx);
void SaveBaseLocation(FISPCMovementContext Ctx);
void UpdateComponentVelocity(FISPCMovementContext Ctx);

#define TEXT(x)	x
// FIXME ISPC: Redirect to the actual Unreal log.
#define UE_LOG(Channel, Severity, Format, ...)	print("[" #Channel "][" #Severity "] " Format, __VA_ARGS__)

bool IsValid(const /*UObject**/void* Test)
{
	if (Test)
	{
		return !IsPendingKill(Test);
	}
}

bool MovementBaseUtility_UseRelativeLocation(const void* MovementBase)
{
	unimplemented();
	return false;
}
