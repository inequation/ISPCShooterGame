#pragma once

#include "Engine/NetworkObjectList.h"
#include "Engine/World.h"

// @todo this is here only due to circular dependency to AIModule. To be removed
#include "Navigation/PathFollowingComponent.h"
#include "AI/Navigation/RecastNavMesh.h"
#include "AI/Navigation/AvoidanceManager.h"
#include "Components/BrushComponent.h"

DEFINE_LOG_CATEGORY_STATIC(LogUnrolledCharacterMovement, Log, All);
DEFINE_LOG_CATEGORY_STATIC(LogUnrolledNavMeshMovement, Log, All);

DECLARE_STATS_GROUP(TEXT("UnrCppChar"), STATGROUP_UnrCppChar, STATCAT_Advanced);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char Movement Total"), STAT_CharacterMovementTotal, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char Tick"), STAT_CharacterMovementTick, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char NonSimulated Time"), STAT_CharacterMovementNonSimulated, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char Simulated Time"), STAT_CharacterMovementSimulated, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char PerformMovement"), STAT_CharacterMovementPerformMovement, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char ReplicateMoveToServer"), STAT_CharacterMovementReplicateMoveToServer, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char CallServerMove"), STAT_CharacterMovementCallServerMove, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char ServerForcePositionUpdate"), STAT_CharacterMovementForcePositionUpdate, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char RootMotionSource Calculate"), STAT_CharacterMovementRootMotionSourceCalculate, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char RootMotionSource Apply"), STAT_CharacterMovementRootMotionSourceApply, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char ClientUpdatePositionAfterServerUpdate"), STAT_CharacterMovementClientUpdatePositionAfterServerUpdate, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char CombineNetMove"), STAT_CharacterMovementCombineNetMove, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char NetSmoothCorrection"), STAT_CharacterMovementSmoothCorrection, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char SmoothClientPosition"), STAT_CharacterMovementSmoothClientPosition, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char SmoothClientPosition_Interp"), STAT_CharacterMovementSmoothClientPosition_Interp, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char SmoothClientPosition_Visual"), STAT_CharacterMovementSmoothClientPosition_Visual, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char Physics Interation"), STAT_CharPhysicsInteraction, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char StepUp"), STAT_CharStepUp, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char FindFloor"), STAT_CharFindFloor, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char AdjustFloorHeight"), STAT_CharAdjustFloorHeight, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char Update Acceleration"), STAT_CharUpdateAcceleration, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char MoveUpdateDelegate"), STAT_CharMoveUpdateDelegate, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char PhysWalking"), STAT_CharPhysWalking, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char PhysFalling"), STAT_CharPhysFalling, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char PhysNavWalking"), STAT_CharPhysNavWalking, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char NavProjectPoint"), STAT_CharNavProjectPoint, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char NavProjectLocation"), STAT_CharNavProjectLocation, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char ProcessLanded"), STAT_CharProcessLanded, STATGROUP_UnrCppChar);
DECLARE_CYCLE_STAT(TEXT("UnrCpp Char HandleImpact"), STAT_CharHandleImpact, STATGROUP_UnrCppChar);

// MAGIC NUMBERS
const float MAX_STEP_SIDE_Z = 0.08f;	// maximum z value for the normal on the vertical side of steps
const float SWIMBOBSPEED = -80.f;
const float VERTICAL_SLOPE_NORMAL_Z = 0.001f; // Slope is vertical if Abs(Normal.Z) <= this threshold. Accounts for precision problems that sometimes angle normals slightly off horizontal for vertical surface.

namespace CVars
{
	static IConsoleVariable* MoveIgnoreFirstBlockingOverlap = nullptr;
	static IConsoleVariable* CharacterStuckWarningPeriod = nullptr;
	static IConsoleVariable* VisualizeMovement = nullptr;
}

static UShooterUnrolledCppMovementSystem* GetMovementSystem(UShooterUnrolledCppMovement* Comp)
{
	if (UWorld* World = Comp->GetWorld())
	{
		UClass* SystemClass = UShooterUnrolledCppMovementSystem::StaticClass();
		if (UObject** SysAsObj = World->ExtraReferencedObjects.FindByPredicate([SystemClass](const UObject* Obj) { return Obj->GetClass() == SystemClass; }))
		{
			return static_cast<UShooterUnrolledCppMovementSystem*>(*SysAsObj);
		}
		UShooterUnrolledCppMovementSystem* System = NewObject<UShooterUnrolledCppMovementSystem>(World, MakeUniqueObjectName(World, SystemClass));
		World->ExtraReferencedObjects.Add(System);
		System->Initialize();
		return System;
	}
	return nullptr;
}

UShooterUnrolledCppMovement::UShooterUnrolledCppMovement(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	bWantsInitializeComponent = true;
}

void UShooterUnrolledCppMovement::InitializeComponent()
{
	Super::InitializeComponent();

	if (UShooterUnrolledCppMovementSystem* System = GetMovementSystem(this))
	{
		System->RegisterComponent(this);
	}
}

void UShooterUnrolledCppMovement::UninitializeComponent()
{
	Super::UninitializeComponent();

	if (UShooterUnrolledCppMovementSystem* System = GetMovementSystem(this))
	{
		System->UnregisterComponent(this);
	}
}

void UShooterUnrolledCppMovement::TickComponent(float DeltaTime, enum ELevelTick TickType, FActorComponentTickFunction *ThisTickFunction)
{
	// ISPC: This is a copy-pasted version of UCharacterMovementComponent::TickComponent()
	// that doesn't call PerformMovement(), since that's taken care of by
	// UShooterUnrolledCppMovementSystem.

	SCOPED_NAMED_EVENT(UShooterUnrolledCppMovement_TickComponent, FColor::Yellow);
	SCOPE_CYCLE_COUNTER(STAT_CharacterMovementTotal);
	SCOPE_CYCLE_COUNTER(STAT_CharacterMovementTick);

	const FVector InputVector = ConsumeInputVector();
	if (!HasValidData() || ShouldSkipUpdate(DeltaTime))
	{
		return;
	}

	// ISPC: Skip the UCharacterMovementComponent implementation.
	UCharacterMovementComponent::Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	// Super tick may destroy/invalidate CharacterOwner or UpdatedComponent, so we need to re-check.
	if (!HasValidData())
	{
		return;
	}

	// See if we fell out of the world.
	const bool bIsSimulatingPhysics = UpdatedComponent->IsSimulatingPhysics();
	if (CharacterOwner->Role == ROLE_Authority && (!bCheatFlying || bIsSimulatingPhysics) && !CharacterOwner->CheckStillInWorld())
	{
		return;
	}

	// We don't update if simulating physics (eg ragdolls).
	if (bIsSimulatingPhysics)
	{
		// Update camera to ensure client gets updates even when physics move him far away from point where simulation started
		if (CharacterOwner->Role == ROLE_AutonomousProxy && IsNetMode(NM_Client))
		{
			APlayerController* PC = Cast<APlayerController>(CharacterOwner->GetController());
			APlayerCameraManager* PlayerCameraManager = (PC ? PC->PlayerCameraManager : NULL);
			if (PlayerCameraManager != NULL && PlayerCameraManager->bUseClientSideCameraUpdates)
			{
				PlayerCameraManager->bShouldSendClientSideCameraUpdate = true;
			}
		}

		ClearAccumulatedForces();
		return;
	}

	AvoidanceLockTimer -= DeltaTime;

	if (CharacterOwner->Role > ROLE_SimulatedProxy)
	{
		SCOPE_CYCLE_COUNTER(STAT_CharacterMovementNonSimulated);

		// If we are a client we might have received an update from the server.
		const bool bIsClient = (CharacterOwner->Role == ROLE_AutonomousProxy && IsNetMode(NM_Client));
		if (bIsClient)
		{
			ClientUpdatePositionAfterServerUpdate();
		}

		// Allow root motion to move characters that have no controller.
		if( CharacterOwner->IsLocallyControlled() || (!CharacterOwner->Controller && bRunPhysicsWithNoController) || (!CharacterOwner->Controller && CharacterOwner->IsPlayingRootMotion()) )
		{
			{
				SCOPE_CYCLE_COUNTER(STAT_CharUpdateAcceleration);

				// We need to check the jump state before adjusting input acceleration, to minimize latency
				// and to make sure acceleration respects our potentially new falling state.
				CharacterOwner->CheckJumpInput(DeltaTime);

				// apply input to acceleration
				Acceleration = ScaleInputAcceleration(ConstrainInputAcceleration(InputVector));
				AnalogInputModifier = ComputeAnalogInputModifier();
			}

			if (CharacterOwner->Role == ROLE_Authority)
			{
				// ISPC: No-op, taken care of by the system!
			}
			else if (bIsClient)
			{
#if 1	// TODO ISPC
				unimplemented();
#else
				ReplicateMoveToServer(DeltaTime, Acceleration);
#endif
			}
		}
		else if (CharacterOwner->GetRemoteRole() == ROLE_AutonomousProxy)
		{
#if 1	// TODO ISPC
			unimplemented();
#else
			// Server ticking for remote client.
			// Between net updates from the client we need to update position if based on another object,
			// otherwise the object will move on intermediate frames and we won't follow it.
			MaybeUpdateBasedMovement(DeltaTime);
			MaybeSaveBaseLocation();

			// Smooth on listen server for local view of remote clients. We may receive updates at a rate different than our own tick rate.
			if (CVars::NetEnableListenServerSmoothing->GetInt() && !bNetworkSmoothingComplete && IsNetMode(NM_ListenServer))
			{
				SmoothClientPosition(DeltaTime);
			}
#endif
		}
	}
	else if (CharacterOwner->Role == ROLE_SimulatedProxy)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		if (bShrinkProxyCapsule)
		{
			AdjustProxyCapsuleSize();
		}
		SimulatedTick(DeltaTime);
#endif
	}

	if (bUseRVOAvoidance)
	{
		UpdateDefaultAvoidance();
	}

	if (bEnablePhysicsInteraction)
	{
		SCOPE_CYCLE_COUNTER(STAT_CharPhysicsInteraction);
		ApplyDownwardForce(DeltaTime);
		ApplyRepulsionForce(DeltaTime);
	}

#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
	const bool bVisualizeMovement = CVars::VisualizeMovement->GetInt() > 0;
	if (bVisualizeMovement)
	{
		VisualizeMovement();
	}
#endif // !(UE_BUILD_SHIPPING || UE_BUILD_TEST)

}

void UShooterUnrolledCppMovement::VisualizeMovement() const
{
	Super::VisualizeMovement();

	if (CharacterOwner == nullptr)
	{
		return;
	}

#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
	const FVector TopOfCapsule = GetActorLocation() + FVector(0.f, 0.f, CharacterOwner->GetSimpleCollisionHalfHeight());
	float HeightOffset = -15.f;

	// Unrolled
	{
		const FColor DebugColor = FColor::White;
		const FVector DebugLocation = TopOfCapsule + FVector(0.f, 0.f, HeightOffset);
		FString DebugText = TEXT("Unrolled");
		DrawDebugString(GetWorld(), DebugLocation, DebugText, nullptr, DebugColor, 0.f, true);
	}
#endif // !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
}

void UShooterUnrolledCppMovement::PerformMovement(float DeltaTime)
{
	// This code should've been executed as UShooterUnrolledCppMovementSystem::Tick().
	checkNoEntry();
}

static void InitCollisionParams(UShooterUnrolledCppMovement* Comp, FCollisionQueryParams &OutParams, FCollisionResponseParams& OutResponseParam)
{
	if (Comp->UpdatedPrimitive)
	{
		// TODO ISPC: foreach_active
		Comp->UpdatedPrimitive->InitSweepCollisionParams(OutParams, OutResponseParam);
	}
}

void FSystemTickFunction::ExecuteTick(float DeltaTime, ELevelTick TickType, ENamedThreads::Type CurrentThread, const FGraphEventRef& MyCompletionGraphEvent)
{
	check(IsValid(System));	// Apparently, we can get here from a spurious tick?
	System->Tick(DeltaTime);
}

FString FSystemTickFunction::DiagnosticMessage()
{
	return FString(TEXT("ShooterBotMovementSystem"));
}

UShooterUnrolledCppMovementSystem::UShooterUnrolledCppMovementSystem(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	TickFunction.bCanEverTick = true;
	TickFunction.bStartWithTickEnabled = false;
	TickFunction.bAllowTickOnDedicatedServer = true;
	TickFunction.bHighPriority = true;
	TickFunction.TickGroup = TG_PrePhysics;
}

void UShooterUnrolledCppMovementSystem::Initialize()
{
	CVars::MoveIgnoreFirstBlockingOverlap = IConsoleManager::Get().FindConsoleVariable(TEXT("p.MoveIgnoreFirstBlockingOverlap"));
	CVars::CharacterStuckWarningPeriod = IConsoleManager::Get().FindConsoleVariable(TEXT("p.CharacterStuckWarningPeriod"));
	CVars::VisualizeMovement = IConsoleManager::Get().FindConsoleVariable(TEXT("p.VisualizeMovement"));

	TickFunction.System = this;
	if (!IsTemplate())
	{
		ULevel* Level = GetWorld()->PersistentLevel;
		TickFunction.SetTickFunctionEnable(true);
		TickFunction.RegisterTickFunction(Level);
	}
}

void UShooterUnrolledCppMovementSystem::Uninitialize()
{
	TickFunction.UnRegisterTickFunction();
}

void UShooterUnrolledCppMovementSystem::BeginDestroy()
{
	Uninitialize();
	Super::BeginDestroy();
}

void UShooterUnrolledCppMovementSystem::RegisterComponent(UShooterUnrolledCppMovement* Comp)
{
	Components.Add(Comp);
	Comp->PrimaryComponentTick.AddPrerequisite(this, TickFunction);
}

void UShooterUnrolledCppMovementSystem::UnregisterComponent(UShooterUnrolledCppMovement* Comp)
{
	Comp->PrimaryComponentTick.RemovePrerequisite(this, TickFunction);
	Components.Remove(Comp);
}
