#include "ShooterGame.h"
#include "Bots/ShooterUnrolledCppMovement.h"

#include "CppInterop.h"

// Also use this file to verify some assumptions about type equivalence.
#include "ShooterISPCMovementSystem.ispc.h"
static_assert(sizeof(ispc::float2) == sizeof(FVector2D), "Vector sizes don't match");
static_assert(sizeof(ispc::float3) == sizeof(FVector), "Vector sizes don't match");
static_assert(sizeof(ispc::float4) == sizeof(FVector4), "Vector sizes don't match");
// FIXME
/*static_assert(sizeof(ispc::FCollisionQueryParams) == sizeof(FCollisionQueryParams), "Type sizes don't match");
static_assert(sizeof(ispc::FCollisionResponseParams) == sizeof(FCollisionResponseParams), "Type sizes don't match");*/
static_assert(sizeof(ispc::FCollisionShape) == sizeof(FCollisionShape), "Type sizes don't match");
static_assert(offsetof(ispc::FHitResult, FaceIndex) == offsetof(FHitResult, FaceIndex), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, Time) == offsetof(FHitResult, Time), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, Distance) == offsetof(FHitResult, Distance), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, Location) == offsetof(FHitResult, Location), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, ImpactPoint) == offsetof(FHitResult, ImpactPoint), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, Normal) == offsetof(FHitResult, Normal), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, ImpactNormal) == offsetof(FHitResult, ImpactNormal), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, TraceStart) == offsetof(FHitResult, TraceStart), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, TraceEnd) == offsetof(FHitResult, TraceEnd), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, PenetrationDepth) == offsetof(FHitResult, PenetrationDepth), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, Item) == offsetof(FHitResult, Item), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, PhysMaterial) == offsetof(FHitResult, PhysMaterial), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, Actor) == offsetof(FHitResult, Actor), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, Component) == offsetof(FHitResult, Component), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, BoneName) == offsetof(FHitResult, BoneName), "Type binary layouts don't match");
static_assert(offsetof(ispc::FHitResult, MyBoneName) == offsetof(FHitResult, MyBoneName), "Type binary layouts don't match");
static_assert(sizeof(ispc::FHitResult) == sizeof(FHitResult), "Type sizes don't match")

#include "CppCallbacks.h"
