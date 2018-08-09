#include "ShooterGame.h"
#include "Bots/ShooterUnrolledCppMovement.h"

#include "CppInterop.h"
#include "CppCallbacks.h"

// Also use this file to verify some assumptions about type equivalence.
#include "ShooterISPCMovementSystem.ispc.h"
static_assert(sizeof(ispc::FCollisionQueryParams) == sizeof(FCollisionQueryParams), "Type sizes don't match");
static_assert(sizeof(ispc::FCollisionResponseParams) == sizeof(FCollisionResponseParams), "Type sizes don't match");
static_assert(sizeof(ispc::FCollisionShape) == sizeof(FCollisionShape), "Type sizes don't match");
static_assert(sizeof(ispc::FHitResult) == sizeof(FHitResult), "Type sizes don't match")