// Shut up some IntelliNonsense.
#ifdef __INTELLISENSE__
	#define foreach(...) while (true)
	#define ISPC
	#define unimplemented()	void
#else
	#define unimplemented() check(false)
#endif
#define check(...)	assert(__VA_ARGS__)

// TODO ISPC: Feed these back to C++?
#define SCOPE_CYCLE_COUNTER(...)

#include "CppInterop.h"

struct FISPCMovementContext
{
	uniform FISPCMovementArrays* Arrays;
	varying int Index;
};

#define CtxAccess(Field)	(Ctx.Arrays->Field[Ctx.Index])

#include "CppCallbacks.h"

// MAGIC NUMBERS
const uniform float MAX_STEP_SIDE_Z = 0.08f;	// maximum z value for the normal on the vertical side of steps
const uniform float SWIMBOBSPEED = -80.f;
const uniform float VERTICAL_SLOPE_NORMAL_Z = 0.001f; // Slope is vertical if Abs(Normal.Z) <= this threshold. Accounts for precision problems that sometimes angle normals slightly off horizontal for vertical surface.
#define SMALL_NUMBER		(1.e-8f)

const uniform FVector FVector_ZeroVector = { 0, 0, 0 };

#define UNIMPLEMENTED_CODE	0

bool FVector_Equal(FVector A, FVector B)
{
	return A.x == B.x && A.y == B.y && A.z == B.z;
}

FVector GetUpdatedComponentLocation(FISPCMovementContext Ctx)
{
	unimplemented();
}

bool IsValid(const ACharacter* Test)
{
	// TODO ISPC: Implement IsPendingKill()? Probably needs a callback to C++.
	return Test;// && !IsPendingKill(Test);
}

bool HasValidData(const varying FISPCMovementContext Ctx)
{
	bool bIsValid = CtxAccess(UpdatedComponent) && IsValid(CtxAccess(CharacterOwner));
#if ENABLE_NAN_DIAGNOSTIC
	if (bIsValid)
	{
		// NaN-checking updates
		if (Comp->Velocity.ContainsNaN())
		{
			logOrEnsureNanError(TEXT("UCharacterMovementComponent::HasValidData() detected NaN/INF for (%s) in Velocity:\n%s"), *GetPathNameSafe(Comp), *Comp->Velocity.ToString());
			Comp->Velocity = FVector_ZeroVector;
		}
		if (!Comp->UpdatedComponent->GetComponentTransform().IsValid())
		{
			logOrEnsureNanError(TEXT("UCharacterMovementComponent::HasValidData() detected NaN/INF for (%s) in UpdatedComponent->ComponentTransform:\n%s"), *GetPathNameSafe(Comp), *Comp->UpdatedComponent->GetComponentTransform().ToHumanReadableString());
		}
		if (Comp->UpdatedComponent->GetComponentRotation().ContainsNaN())
		{
			logOrEnsureNanError(TEXT("UCharacterMovementComponent::HasValidData() detected NaN/INF for (%s) in UpdatedComponent->GetComponentRotation():\n%s"), *GetPathNameSafe(Comp), *Comp->UpdatedComponent->GetComponentRotation().ToString());
		}
	}
#endif
	return bIsValid;
}

bool IsMovingOnGround(FISPCMovementContext Ctx)
{
	return ((CtxAccess(MovementMode) == MOVE_Walking) || (CtxAccess(MovementMode) == MOVE_NavWalking)) && CtxAccess(UpdatedComponent);
}

bool HasRootMotionSources(FISPCMovementContext Ctx)
{
	return CtxAccess(CurrentRootMotion_HasActiveRootMotionSources) || (CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner_IsPlayingRootMotion) && CtxAccess(CharacterOwner_GetMesh));
}

bool HasAnimRootMotion(FISPCMovementContext Ctx)
{
	return CtxAccess(RootMotionParams_bHasRootMotion);
}

void ClearAccumulatedForces(FISPCMovementContext Ctx)
{
	CtxAccess(PendingImpulseToApply) = FVector_ZeroVector;
	CtxAccess(PendingForceToApply) = FVector_ZeroVector;
	CtxAccess(PendingLaunchVelocity) = FVector_ZeroVector;
}

void ApplyAccumulatedForces(FISPCMovementContext Ctx, float DeltaSeconds)
{
#if 1	// TODO ISPC Actual
	unimplemented();
#else
	if (CtxAccess(PendingImpulseToApply).z != 0.f || CtxAccess(PendingForceToApply).z != 0.f)
	{
		// check to see if applied momentum is enough to overcome gravity
		if ( IsMovingOnGround(Ctx) && (CtxAccess(PendingImpulseToApply).z + (CtxAccess(PendingForceToApply).z * DeltaSeconds) + (GetGravityZ(Ctx) * DeltaSeconds) > SMALL_NUMBER))
		{
			SetMovementMode(Comp, MOVE_Falling);
		}
	}

	Comp->Velocity += Comp->PendingImpulseToApply + (Comp->PendingForceToApply * DeltaSeconds);
	
	// Don't call ClearAccumulatedForces() because it could affect launch velocity
	Comp->PendingImpulseToApply = FVector_ZeroVector;
	Comp->PendingForceToApply = FVector_ZeroVector;
#endif
}

bool MovementBaseUtility_UseRelativeLocation(UPrimitiveComponent*)
{
	unimplemented();
	return false;
}

void MaybeUpdateBasedMovement(FISPCMovementContext Ctx, float DeltaSeconds)
{
	CtxAccess(bDeferUpdateBasedMovement) = false;

	UPrimitiveComponent* MovementBase = CtxAccess(CharacterOwner_MovementBase);
	if (MovementBaseUtility_UseRelativeLocation(MovementBase))
	{
#if 1	// TODO ISPC Actual
		unimplemented();
#else
		const bool bBaseIsSimulatingPhysics = MovementBase->IsSimulatingPhysics();
		
		// Temporarily disabling deferred tick on skeletal mesh components that sim physics.
		// We need to be consistent on when we read the bone locations for those, and while this reads
		// the wrong location, the relative changes (which is what we care about) will be accurate.
		// TODO ISPC: Support the post-physics tick group.
		const bool bAllowDefer = false && (bBaseIsSimulatingPhysics && !Cast<USkeletalMeshComponent>(MovementBase));
		
		if (!bBaseIsSimulatingPhysics || !bAllowDefer)
		{
			Comp->bDeferUpdateBasedMovement = false;
			UpdateBasedMovement(Comp, DeltaSeconds);
			// If previously simulated, go back to using normal tick dependencies.
#if 0	// TODO ISPC
			if (PostPhysicsTickFunction.IsTickFunctionEnabled())
			{
				PostPhysicsTickFunction.SetTickFunctionEnable(false);
				MovementBaseUtility::AddTickDependency(PrimaryComponentTick, MovementBase);
			}
#endif
		}
		else
		{
			// defer movement base update until after physics
			Comp->bDeferUpdateBasedMovement = true;
			// If previously not simulating, remove tick dependencies and use post physics tick function.
#if 0	// TODO ISPC
			if (!PostPhysicsTickFunction.IsTickFunctionEnabled())
			{
				PostPhysicsTickFunction.SetTickFunctionEnable(true);
				MovementBaseUtility::RemoveTickDependency(PrimaryComponentTick, MovementBase);
			}
#endif
		}
#endif
	}
}

#if UNIMPLEMENTED_CODE
static bool IsWalkable(const FHitResult& Hit, const float WalkableFloorZ)
{
	if (!Hit.IsValidBlockingHit())
	{
		// No hit, or starting in penetration
		return false;
	}

	// Never walk up vertical surfaces.
	if (Hit.ImpactNormal.Z < KINDA_SMALL_NUMBER)
	{
		return false;
	}

	float TestWalkableZ = WalkableFloorZ;

	// See if this component overrides the walkable floor z.
	const UPrimitiveComponent* HitComponent = Hit.Component.Get();
	if (HitComponent)
	{
		const FWalkableSlopeOverride& SlopeOverride = HitComponent->GetWalkableSlopeOverride();
		TestWalkableZ = SlopeOverride.ModifyWalkableFloorZ(TestWalkableZ);
	}

	// Can't walk on this surface if it is too steep.
	if (Hit.ImpactNormal.Z < TestWalkableZ)
	{
		return false;
	}

	return true;
}

static bool IsWithinEdgeTolerance(const FVector& CapsuleLocation, const FVector& TestImpactPoint, const float CapsuleRadius)
{
	const float DistFromCenterSq = (TestImpactPoint - CapsuleLocation).SizeSquared2D();
	const float ReducedRadiusSq = FMath::Square(FMath::Max(UCharacterMovementComponent::SWEEP_EDGE_REJECT_DISTANCE + KINDA_SMALL_NUMBER, CapsuleRadius - UCharacterMovementComponent::SWEEP_EDGE_REJECT_DISTANCE));
	return DistFromCenterSq < ReducedRadiusSq;
}

static void InitCollisionParams(FISPCMovementContext Ctx, FCollisionQueryParams &OutParams, FCollisionResponseParams& OutResponseParam)
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

UShooterUnrolledCppMovementSystem(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	TickFunction.bCanEverTick = true;
	TickFunction.bStartWithTickEnabled = false;
	TickFunction.bAllowTickOnDedicatedServer = true;
	TickFunction.bHighPriority = true;
	TickFunction.TickGroup = TG_PrePhysics;
}

void Initialize()
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

void Uninitialize()
{
	TickFunction.UnRegisterTickFunction();
}

void BeginDestroy()
{
	Uninitialize();
	Super::BeginDestroy();
}

void RegisterComponent(FISPCMovementContext Ctx)
{
	Components.Add(Comp);
	Comp->PrimaryComponentTick.AddPrerequisite(this, TickFunction);
}

void UnregisterComponent(FISPCMovementContext Ctx)
{
	Comp->PrimaryComponentTick.RemovePrerequisite(this, TickFunction);
	Components.Remove(Comp);
}

void SetUpdatedComponent(FISPCMovementContext Ctx, USceneComponent* NewUpdatedComponent)
{
	if (NewUpdatedComponent)
	{
		const ACharacter* NewCharacterOwner = Cast<ACharacter>(NewUpdatedComponent->GetOwner());
		if (NewCharacterOwner == NULL)
		{
			UE_LOG(LogUnrolledCharacterMovement, Error, TEXT("%s owned by %s must update a component owned by a Character"), *Comp->GetName(), *GetNameSafe(NewUpdatedComponent->GetOwner()));
			return;
		}

		// check that UpdatedComponent is a Capsule
		if (Cast<UCapsuleComponent>(NewUpdatedComponent) == NULL)
		{
			UE_LOG(LogUnrolledCharacterMovement, Error, TEXT("%s owned by %s must update a capsule component"), *Comp->GetName(), *GetNameSafe(NewUpdatedComponent->GetOwner()));
			return;
		}
	}

	if ( Comp->bMovementInProgress )
	{
#if 0	// TODO ISPC
		unimplemented();
#else
		// failsafe to avoid crashes in CharacterMovement. 
		Comp->bDeferUpdateMoveComponent = true;
		Comp->DeferredUpdatedMoveComponent = NewUpdatedComponent;
		return;
#endif
	}
	Comp->bDeferUpdateMoveComponent = false;
	Comp->DeferredUpdatedMoveComponent = NULL;

	USceneComponent* OldUpdatedComponent = Comp->UpdatedComponent;
	UPrimitiveComponent* OldPrimitive = Cast<UPrimitiveComponent>(Comp->UpdatedComponent);
	if (IsValid(OldPrimitive) && OldPrimitive->OnComponentBeginOverlap.IsBound())
	{
#if 1	// TODO ISPC: Member is private.
		unimplemented();
#else
		OldPrimitive->OnComponentBeginOverlap.RemoveDynamic(Comp, &UCharacterMovementComponent::CapsuleTouched);
#endif
	}
	
	{
		// ISPC: Inlined call to UPawnMovementComponent::SetUpdatedComponent().
		if (NewUpdatedComponent)
		{
			if (!ensureMsgf(Cast<APawn>(NewUpdatedComponent->GetOwner()), TEXT("%s must update a component owned by a Pawn"), *GetName()))
			{
				return;
			}
		}

		{
			// ISPC: Inlined call to UMovementComponent::SetUpdatedComponent().
			if (Comp->UpdatedComponent && Comp->UpdatedComponent != NewUpdatedComponent)
			{
				Comp->UpdatedComponent->bShouldUpdatePhysicsVolume = false;
				if (!Comp->UpdatedComponent->IsPendingKill())
				{
					Comp->UpdatedComponent->SetPhysicsVolume(NULL, true);
					Comp->UpdatedComponent->PhysicsVolumeChangedDelegate.RemoveDynamic(Comp, &UMovementComponent::PhysicsVolumeChanged);
				}

				// remove from tick prerequisite
				Comp->UpdatedComponent->PrimaryComponentTick.RemovePrerequisite(Comp, Comp->PrimaryComponentTick);
			}

			// Don't assign pending kill components, but allow those to null out previous UpdatedComponent.
			Comp->UpdatedComponent = IsValid(NewUpdatedComponent) ? NewUpdatedComponent : NULL;
			Comp->UpdatedPrimitive = Cast<UPrimitiveComponent>(Comp->UpdatedComponent);

			// Assign delegates
			if (Comp->UpdatedComponent && !Comp->UpdatedComponent->IsPendingKill())
			{
				Comp->UpdatedComponent->bShouldUpdatePhysicsVolume = true;
				Comp->UpdatedComponent->PhysicsVolumeChangedDelegate.AddUniqueDynamic(Comp, &UMovementComponent::PhysicsVolumeChanged);

	#if 0	// TODO ISPC
				if (!Comp->bInOnRegister && !Comp->bInInitializeComponent)
	#endif
				{
					// UpdateOverlaps() in component registration will take care of this.
					Comp->UpdatedComponent->UpdatePhysicsVolume(true);
				}

				// force ticks after movement component updates
				Comp->UpdatedComponent->PrimaryComponentTick.AddPrerequisite(Comp, Comp->PrimaryComponentTick);
			}

			Comp->UpdateTickRegistration();

			if (Comp->bSnapToPlaneAtStart)
			{
				SnapUpdatedComponentToPlane(Comp);
			}
		}

		Comp->PawnOwner = NewUpdatedComponent ? CastChecked<APawn>(NewUpdatedComponent->GetOwner()) : NULL;
	}
	Comp->CharacterOwner = Cast<ACharacter>(Comp->PawnOwner);

	if (Comp->UpdatedComponent != OldUpdatedComponent)
	{
		ClearAccumulatedForces(Comp);
	}

	if (Comp->UpdatedComponent == NULL)
	{
		StopActiveMovement(Comp);
	}

	const bool bValidUpdatedPrimitive = IsValid(Comp->UpdatedPrimitive);

	if (bValidUpdatedPrimitive && Comp->bEnablePhysicsInteraction)
	{
#if 1	// TODO ISPC: Member is private.
		unimplemented();
#else
		Comp->UpdatedPrimitive->OnComponentBeginOverlap.AddUniqueDynamic(Comp, &UCharacterMovementComponent::CapsuleTouched);
#endif
	}

#if 0	// TODO ISPC: Member is private.
	if (Comp->bNeedsSweepWhileWalkingUpdate)
	{
		Comp->bSweepWhileNavWalking = bValidUpdatedPrimitive ? Comp->UpdatedPrimitive->bGenerateOverlapEvents : false;
		Comp->bNeedsSweepWhileWalkingUpdate = false;
	}
#endif

	if (Comp->bUseRVOAvoidance && IsValid(NewUpdatedComponent))
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		UAvoidanceManager* AvoidanceManager = GetWorld()->GetAvoidanceManager();
		if (AvoidanceManager)
		{
			AvoidanceManager->RegisterMovementComponent(Comp, Comp->AvoidanceWeight);
		}
#endif
	}
}
#endif

void PerformMovement(FISPCMovementContext Ctx, float DeltaSeconds)
{
	SCOPE_CYCLE_COUNTER(STAT_CharacterMovementPerformMovement);

	if (!HasValidData(Ctx))
	{
		return;
	}

	// no movement if we can't move, or if currently doing physical simulation on UpdatedComponent
	if (CtxAccess(MovementMode) == MOVE_None || CtxAccess(UpdatedComponent_Mobility) != EComponentMobility_Movable || CtxAccess(UpdatedComponent_IsSimulatingPhysics))
	{
		if (!CtxAccess(CharacterOwner_bClientUpdating) && CtxAccess(CharacterOwner_IsPlayingRootMotion) && CtxAccess(CharacterOwner_GetMesh) && !CtxAccess(CharacterOwner_bServerMoveIgnoreRootMotion))
		{
			ConsumeRootMotion(CtxAccess(Comp), DeltaSeconds);
		}
		// Clear pending physics forces
		ClearAccumulatedForces(Ctx);
		return;
	}

	// Force floor update if we've moved outside of CharacterMovement since last update.
	CtxAccess(bForceNextFloorCheck) |= (IsMovingOnGround(Ctx) && !FVector_Equal(GetUpdatedComponentLocation(Ctx), CtxAccess(LastUpdateLocation)));

	// Update saved LastPreAdditiveVelocity with any external changes to character Velocity that happened since last update.
#if 1	// TODO ISPC
	check(!HasRootMotionSources(Ctx));
#else
	if (Comp->CurrentRootMotion.HasAdditiveVelocity())
	{
		const FVector Adjustment = (Comp->Velocity - Comp->LastUpdateVelocity);
		Comp->CurrentRootMotion.LastPreAdditiveVelocity += Adjustment;

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			if (!Adjustment.IsNearlyZero())
			{
				FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement HasAdditiveVelocity LastUpdateVelocityAdjustment LastPreAdditiveVelocity(%s) Adjustment(%s)"),
					*Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString(), *Adjustment.ToCompactString());
				RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
			}
		}
#endif
	}
#endif

	FVector OldVelocity;
	FVector OldLocation;

	// Scoped updates can improve performance of multiple MoveComponent calls.
	{
#if 0	// TODO ISPC
		FScopedMovementUpdate ScopedMovementUpdate(Comp->UpdatedComponent, Comp->bEnableScopedMovementUpdates ? EScopedUpdate::DeferredUpdates : EScopedUpdate::ImmediateUpdates);
#endif

		MaybeUpdateBasedMovement(Ctx, DeltaSeconds);

#if 1	// TODO ISPC
		check(!HasRootMotionSources(Ctx));
#else
		// Clean up invalid RootMotion Sources.
		// This includes RootMotion sources that ended naturally.
		// They might want to perform a clamp on velocity or an override, 
		// so we want this to happen before ApplyAccumulatedForces and HandlePendingLaunch as to not clobber these.
		const bool bHasRootMotionSources = HasRootMotionSources(Ctx);
		if (bHasRootMotionSources && !CtxAccess(CharacterOwner_bClientUpdating) && !CtxAccess(CharacterOwner_bServerMoveIgnoreRootMotion))
		{
			SCOPE_CYCLE_COUNTER(STAT_CharacterMovementRootMotionSourceCalculate);

			const FVector VelocityBeforeCleanup = Comp->Velocity;
			Comp->CurrentRootMotion.CleanUpInvalidRootMotion(DeltaSeconds, *Comp->CharacterOwner, *Comp);

#if ROOT_MOTION_DEBUG
			if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
			{
				if (Comp->Velocity != VelocityBeforeCleanup)
				{
					const FVector Adjustment = Comp->Velocity - VelocityBeforeCleanup;
					FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement CleanUpInvalidRootMotion Velocity(%s) VelocityBeforeCleanup(%s) Adjustment(%s)"),
						*Comp->Velocity.ToCompactString(), *VelocityBeforeCleanup.ToCompactString(), *Adjustment.ToCompactString());
					RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
				}
			}
#endif
		}
#endif	// TODO ISPC

		OldVelocity = CtxAccess(Velocity);
		OldLocation = GetUpdatedComponentLocation(Ctx);

		ApplyAccumulatedForces(Ctx, DeltaSeconds);

#if UNIMPLEMENTED_CODE	// TODO ISPC Actual
		// Update the character state before we do our movement
		UpdateCharacterStateBeforeMovement(Ctx);

		if (CtxAccess(MovementMode) == MOVE_NavWalking && CtxAccess(bWantsToLeaveNavWalking))
		{
#if 1	// TODO ISPC
			unimplemented();
#else
			Comp->TryToLeaveNavWalking();
#endif
		}

		// Character::LaunchCharacter() has been deferred until now.
		HandlePendingLaunch(Ctx);
		ClearAccumulatedForces(Ctx);

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			if (OldVelocity != Comp->Velocity)
			{
				const FVector Adjustment = Comp->Velocity - OldVelocity;
				FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement ApplyAccumulatedForces+HandlePendingLaunch Velocity(%s) OldVelocity(%s) Adjustment(%s)"),
					*Comp->Velocity.ToCompactString(), *OldVelocity.ToCompactString(), *Adjustment.ToCompactString());
				RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
			}
		}
#endif

#if 1	// TODO ISPC
		check(!HasRootMotionSources(Ctx));
#else
		// Update saved LastPreAdditiveVelocity with any external changes to character Velocity that happened due to ApplyAccumulatedForces/HandlePendingLaunch
		if (Comp->CurrentRootMotion.HasAdditiveVelocity())
		{
			const FVector Adjustment = (Comp->Velocity - OldVelocity);
			Comp->CurrentRootMotion.LastPreAdditiveVelocity += Adjustment;

#if ROOT_MOTION_DEBUG
			if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
			{
				if (!Adjustment.IsNearlyZero())
				{
					FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement HasAdditiveVelocity AccumulatedForces LastPreAdditiveVelocity(%s) Adjustment(%s)"),
						*Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString(), *Adjustment.ToCompactString());
					RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
				}
			}
#endif
		}

		// Prepare Root Motion (generate/accumulate from root motion sources to be used later)
		if (bHasRootMotionSources && !Comp->CharacterOwner_bClientUpdating && !Comp->CharacterOwner_bServerMoveIgnoreRootMotion)
		{
			// Animation root motion - If using animation RootMotion, tick animations before running physics.
			if (Comp->CharacterOwner_IsPlayingRootMotion && Comp->CharacterOwner_GetMesh)
			{
#if 1	// TODO ISPC
				unimplemented();
#else
				Comp->TickCharacterPose(DeltaSeconds);

				// Make sure animation didn't trigger an event that destroyed us
				if (!HasValidData(Comp))
				{
					return;
				}

				// For local human clients, save off root motion data so it can be used by movement networking code.
				if (Comp->CharacterOwner->IsLocallyControlled() && (Comp->CharacterOwner->Role == ROLE_AutonomousProxy) && Comp->CharacterOwner->IsPlayingNetworkedRootMotionMontage())
				{
					Comp->CharacterOwner->ClientRootMotionParams = Comp->RootMotionParams;
				}
#endif
			}

			// Generates root motion to be used this frame from sources other than animation
			{
				SCOPE_CYCLE_COUNTER(STAT_CharacterMovementRootMotionSourceCalculate);
				Comp->CurrentRootMotion.PrepareRootMotion(DeltaSeconds, *Comp->CharacterOwner, *Comp, true);
			}

			// For local human clients, save off root motion data so it can be used by movement networking code.
			if (Comp->CharacterOwner->IsLocallyControlled() && (Comp->CharacterOwner->Role == ROLE_AutonomousProxy))
			{
				Comp->CharacterOwner->SavedRootMotion = Comp->CurrentRootMotion;
			}
		}

		// Apply Root Motion to Velocity
		if (Comp->CurrentRootMotion.HasOverrideVelocity() || HasAnimRootMotion(Comp))
		{
			// Animation root motion overrides Velocity and currently doesn't allow any other root motion sources
			if (HasAnimRootMotion(Comp))
			{
				// Convert to world space (animation root motion is always local)
				USkeletalMeshComponent * SkelMeshComp = Comp->CharacterOwner_GetMesh;
				if (SkelMeshComp)
				{
					// Convert Local Space Root Motion to world space. Do it right before used by physics to make sure we use up to date transforms, as translation is relative to rotation.
					Comp->RootMotionParams.Set(ConvertLocalRootMotionToWorld(Comp, Comp->RootMotionParams.GetRootMotionTransform()));
				}

				// Then turn root motion to velocity to be used by various physics modes.
				if (DeltaSeconds > 0.f)
				{
					Comp->AnimRootMotionVelocity = Comp->CalcAnimRootMotionVelocity(Comp->RootMotionParams.GetRootMotionTransform().GetTranslation(), DeltaSeconds, Comp->Velocity);
					Comp->Velocity = Comp->ConstrainAnimRootMotionVelocity(Comp->AnimRootMotionVelocity, Comp->Velocity);
				}

				UE_LOG(LogRootMotion, Log, TEXT("PerformMovement WorldSpaceRootMotion Translation: %s, Rotation: %s, Actor Facing: %s, Velocity: %s")
					, *Comp->RootMotionParams.GetRootMotionTransform().GetTranslation().ToCompactString()
					, *Comp->RootMotionParams.GetRootMotionTransform().GetRotation().Rotator().ToCompactString()
					, *Comp->CharacterOwner->GetActorForwardVector().ToCompactString()
					, *Comp->Velocity.ToCompactString()
				);
			}
			else
			{
				// We don't have animation root motion so we apply other sources
				if (DeltaSeconds > 0.f)
				{
					SCOPE_CYCLE_COUNTER(STAT_CharacterMovementRootMotionSourceApply);

					const FVector VelocityBeforeOverride = Comp->Velocity;
					FVector NewVelocity = Comp->Velocity;
					Comp->CurrentRootMotion.AccumulateOverrideRootMotionVelocity(DeltaSeconds, *Comp->CharacterOwner, *Comp, NewVelocity);
					Comp->Velocity = NewVelocity;

#if ROOT_MOTION_DEBUG
					if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
					{
						if (VelocityBeforeOverride != Comp->Velocity)
						{
							FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement AccumulateOverrideRootMotionVelocity Velocity(%s) VelocityBeforeOverride(%s)"),
								*Comp->Velocity.ToCompactString(), *VelocityBeforeOverride.ToCompactString());
							RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
						}
					}
#endif
				}
			}
		}

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement Velocity(%s) OldVelocity(%s)"),
				*Comp->Velocity.ToCompactString(), *OldVelocity.ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
		}
#endif
#endif	// TODO ISPC

		// NaN tracking
		checkCode(ensureMsgf(!Comp->Velocity.ContainsNaN(), TEXT("UCharacterMovementComponent::PerformMovement: Velocity contains NaN (%s)\n%s"), *GetPathNameSafe(Comp), *Comp->Velocity.ToString()));

		// Clear jump input now, to allow movement events to trigger it for next update.
		Comp->CharacterOwner->ClearJumpInput();

		// change position
		StartNewPhysics(Ctx, DeltaSeconds, 0);

		if (!HasValidData(Ctx))
		{
			return;
		}

		// Update character state based on change from movement
		UpdateCharacterStateAfterMovement(Ctx);

		if ((CtxAccess(bAllowPhysicsRotationDuringAnimRootMotion) || !HasAnimRootMotion(Ctx)) && !CtxAccess(CharacterOwner_IsMatineeControlled))
		{
			PhysicsRotation(Ctx, DeltaSeconds);
		}

		// Apply Root Motion rotation after movement is complete.
		if (HasAnimRootMotion(Ctx))
		{
#if 1	// TODO ISPC
			unimplemented();
#else
			const FQuat OldActorRotationQuat = Comp->UpdatedComponent->GetComponentQuat();
			const FQuat RootMotionRotationQuat = Comp->RootMotionParams.GetRootMotionTransform().GetRotation();
			if (!RootMotionRotationQuat.IsIdentity())
			{
				const FQuat NewActorRotationQuat = RootMotionRotationQuat * OldActorRotationQuat;
				Comp->MoveUpdatedComponent(FVector_ZeroVector, NewActorRotationQuat, true);
			}

#if !(UE_BUILD_SHIPPING)
			// debug
			if (false)
			{
				const FRotator OldActorRotation = OldActorRotationQuat.Rotator();
				const FVector ResultingLocation = GetUpdatedComponentLocation(Ctx);
				const FRotator ResultingRotation = Comp->UpdatedComponent->GetComponentRotation();

				// Show current position
				DrawDebugCoordinateSystem(GetWorld(), Comp->CharacterOwner_GetMesh->GetComponentLocation() + FVector(0, 0, 1), ResultingRotation, 50.f, false);

				// Show resulting delta move.
				DrawDebugLine(GetWorld(), OldLocation, ResultingLocation, FColor::Red, true, 10.f);

				// Log details.
				UE_LOG(LogRootMotion, Warning, TEXT("PerformMovement Resulting DeltaMove Translation: %s, Rotation: %s, MovementBase: %s"),
					*(ResultingLocation - OldLocation).ToCompactString(), *(ResultingRotation - OldActorRotation).GetNormalized().ToCompactString(), *GetNameSafe(Comp->CharacterOwner->GetMovementBase()));

				const FVector RMTranslation = Comp->RootMotionParams.GetRootMotionTransform().GetTranslation();
				const FRotator RMRotation = Comp->RootMotionParams.GetRootMotionTransform().GetRotation().Rotator();
				UE_LOG(LogRootMotion, Warning, TEXT("PerformMovement Resulting DeltaError Translation: %s, Rotation: %s"),
					*(ResultingLocation - OldLocation - RMTranslation).ToCompactString(), *(ResultingRotation - OldActorRotation - RMRotation).GetNormalized().ToCompactString());
			}
#endif // !(UE_BUILD_SHIPPING)

			// Root Motion has been used, clear
			Comp->RootMotionParams.Clear();
#endif	// TODO ISPC
		}

		// consume path following requested velocity
		CtxAccess(bHasRequestedVelocity) = false;

#if 0	// TODO ISPC: This is an empty method, don't call at all for now.
		Comp->OnMovementUpdated(DeltaSeconds, OldLocation, OldVelocity);
#endif
#endif	// TODO ISPC Actual
	} // End scoped movement update

#if UNIMPLEMENTED_CODE	// TODO ISPC Actual
	// Call external post-movement events. These happen after the scoped movement completes in case the events want to use the current state of overlaps etc.
	CallMovementUpdateDelegate(Ctx, DeltaSeconds, OldLocation, OldVelocity);

	MaybeSaveBaseLocation(Ctx);
	UpdateComponentVelocity(Ctx);

	const bool bHasAuthority = CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner_HasAuthority);

	// TODO ISPC: Uniformize UNetDriver::IsAdaptiveNetUpdateFrequencyEnabled() and foreach_active this entire if.
	// If we move we want to avoid a long delay before replication catches up to notice this change, especially if it's throttling our rate.
	if (bHasAuthority && UNetDriver::IsAdaptiveNetUpdateFrequencyEnabled() && Comp->UpdatedComponent)
	{
		const UWorld* MyWorld = GetWorld();
		if (MyWorld)
		{
			UNetDriver* NetDriver = MyWorld->GetNetDriver();
			if (NetDriver && NetDriver->IsServer())
			{
				FNetworkObjectInfo* NetActor = NetDriver->FindOrAddNetworkObjectInfo(Comp->CharacterOwner);

				if (NetActor && MyWorld->GetTimeSeconds() <= NetActor->NextUpdateTime && NetDriver->IsNetworkActorUpdateFrequencyThrottled(*NetActor))
				{
					if (Comp->ShouldCancelAdaptiveReplication())
					{
						NetDriver->CancelAdaptiveReplication(*NetActor);
					}
				}
			}
		}
	}

	const FVector NewLocation = Comp->UpdatedComponent ? GetUpdatedComponentLocation(Ctx) : FVector_ZeroVector;
	const FQuat NewRotation = Comp->UpdatedComponent ? Comp->UpdatedComponent->GetComponentQuat() : FQuat::Identity;

	if (bHasAuthority && Comp->UpdatedComponent && !Comp->IsNetMode(NM_Client))
	{
		const bool bLocationChanged = (NewLocation != Comp->LastUpdateLocation);
		const bool bRotationChanged = (NewRotation != Comp->LastUpdateRotation);
		if (bLocationChanged || bRotationChanged)
		{
			const UWorld* MyWorld = GetWorld();
			Comp->ServerLastTransformUpdateTimeStamp = MyWorld ? MyWorld->GetTimeSeconds() : 0.f;
		}
	}

	CtxAccess(LastUpdateLocation) = NewLocation;
	CtxAccess(LastUpdateRotation) = NewRotation;
	CtxAccess(LastUpdateVelocity) = CtxAccess(Velocity);
#endif	// TODO ISPC Actual
}

#if UNIMPLEMENTED_CODE
void CallMovementUpdateDelegate(FISPCMovementContext Ctx, float DeltaTime, const FVector& OldLocation, const FVector& OldVelocity)
{
	SCOPE_CYCLE_COUNTER(STAT_CharMoveUpdateDelegate);

	// Update component velocity in case events want to read it
	UpdateComponentVelocity(Comp);

	// Delegate (for blueprints)
	if (Comp->CharacterOwner)
	{
		// TODO ISPC: foreach_active
		Comp->CharacterOwner->OnCharacterMovementUpdated.Broadcast(DeltaTime, OldLocation, OldVelocity);
	}
}

void UpdateCharacterStateBeforeMovement(FISPCMovementContext Ctx)
{
	// Check for a change in crouch state. Players toggle crouch by changing bWantsToCrouch.
	const bool bAllowedToCrouch = CanCrouchInCurrentState(Comp);
	if ((!bAllowedToCrouch || !Comp->bWantsToCrouch) && IsCrouching(Comp))
	{
		UnCrouch(Comp, false);
	}
	else if (Comp->bWantsToCrouch && bAllowedToCrouch && !IsCrouching(Comp))
	{
		Crouch(Comp, false);
	}
}

void UpdateCharacterStateAfterMovement(FISPCMovementContext Ctx)
{
	// Uncrouch if no longer allowed to be crouched
	if (IsCrouching(Comp) && !CanCrouchInCurrentState(Comp))
	{
		UnCrouch(Comp, false);
	}
}

void StartNewPhysics(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	if ((deltaTime < UCharacterMovementComponent::MIN_TICK_TIME) || (Iterations >= Comp->MaxSimulationIterations) || !HasValidData(Comp))
	{
		return;
	}

	if (Comp->UpdatedComponent_IsSimulatingPhysics)
	{
		UE_LOG(LogUnrolledCharacterMovement, Log, TEXT("UCharacterMovementComponent::StartNewPhysics: UpdateComponent (%s) is simulating physics - aborting."), *Comp->UpdatedComponent->GetPathName());
		return;
	}

	const bool bSavedMovementInProgress = Comp->bMovementInProgress;
	Comp->bMovementInProgress = true;

	switch (Comp->MovementMode)
	{
	case MOVE_None:
		break;
	case MOVE_Walking:
		PhysWalking(Comp, deltaTime, Iterations);
		break;
	case MOVE_NavWalking:
		PhysNavWalking(Comp, deltaTime, Iterations);
		break;
	case MOVE_Falling:
		PhysFalling(Comp, deltaTime, Iterations);
		break;
	case MOVE_Flying:
		PhysFlying(Comp, deltaTime, Iterations);
		break;
	case MOVE_Swimming:
		PhysSwimming(Comp, deltaTime, Iterations);
		break;
	case MOVE_Custom:
		PhysCustom(Comp, deltaTime, Iterations);
		break;
	default:
		UE_LOG(LogUnrolledCharacterMovement, Warning, TEXT("%s has unsupported movement mode %d"), *Comp->CharacterOwner->GetName(), int32(Comp->MovementMode));
		SetMovementMode(Comp, MOVE_None);
		break;
	}

	Comp->bMovementInProgress = bSavedMovementInProgress;
	if (Comp->bDeferUpdateMoveComponent)
	{
		SetUpdatedComponent(Comp, Comp->DeferredUpdatedMoveComponent);
	}
}

bool IsFlying(FISPCMovementContext Ctx) const
{
	return (Comp->MovementMode == MOVE_Flying) && Comp->UpdatedComponent;
}

bool IsFalling(FISPCMovementContext Ctx) const
{
	return (Comp->MovementMode == MOVE_Falling) && Comp->UpdatedComponent;
}

bool IsSwimming(FISPCMovementContext Ctx) const
{
	return (Comp->MovementMode == MOVE_Swimming) && Comp->UpdatedComponent;
}

bool IsCrouching(FISPCMovementContext Ctx) const
{
	return Comp->CharacterOwner && Comp->CharacterOwner->bIsCrouched;
}

APhysicsVolume* GetPhysicsVolume(FISPCMovementContext Ctx) const
{
	if (Comp->UpdatedComponent)
	{
		return Comp->UpdatedComponent->GetPhysicsVolume();
	}

	return GetWorld()->GetDefaultPhysicsVolume();
}

float GetGravityZ(FISPCMovementContext Ctx) const
{
	return (GetPhysicsVolume(Comp)->GetGravityZ()) * Comp->GravityScale;
}

float GetMaxSpeed(FISPCMovementContext Ctx) const
{
	switch(Comp->MovementMode)
	{
	case MOVE_Walking:
	case MOVE_NavWalking:
		return IsCrouching(Comp) ? Comp->MaxWalkSpeedCrouched : Comp->MaxWalkSpeed;
	case MOVE_Falling:
		return Comp->MaxWalkSpeed;
	case MOVE_Swimming:
		return Comp->MaxSwimSpeed;
	case MOVE_Flying:
		return Comp->MaxFlySpeed;
	case MOVE_Custom:
		return Comp->MaxCustomMovementSpeed;
	case MOVE_None:
	default:
		return 0.f;
	}
}

float GetMaxBrakingDeceleration(FISPCMovementContext Ctx) const
{
	switch (Comp->MovementMode)
	{
		case MOVE_Walking:
		case MOVE_NavWalking:
			return Comp->BrakingDecelerationWalking;
		case MOVE_Falling:
			return Comp->BrakingDecelerationFalling;
		case MOVE_Swimming:
			return Comp->BrakingDecelerationSwimming;
		case MOVE_Flying:
			return Comp->BrakingDecelerationFlying;
		case MOVE_Custom:
			return 0.f;
		case MOVE_None:
		default:
			return 0.f;
	}
}

float GetMinAnalogSpeed(FISPCMovementContext Ctx) const
{
	switch (Comp->MovementMode)
	{
	case MOVE_Walking:
	case MOVE_NavWalking:
	case MOVE_Falling:
		return Comp->MinAnalogWalkSpeed;
	default:
		return 0.f;
	}
}

float GetMaxAcceleration(FISPCMovementContext Ctx) const
{
	return Comp->MaxAcceleration;
}

float GetPerchRadiusThreshold(FISPCMovementContext Ctx) const
{
	// Don't allow negative values.
	return FMath::Max(0.f, Comp->PerchRadiusThreshold);
}

float GetValidPerchRadius(FISPCMovementContext Ctx) const
{
	if (Comp->CharacterOwner)
	{
		const float PawnRadius = Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleRadius();
		return FMath::Clamp(PawnRadius - GetPerchRadiusThreshold(Comp), 0.1f, PawnRadius);
	}
	return 0.f;
}

bool IsInWater(FISPCMovementContext Ctx) const
{
	const APhysicsVolume* PhysVolume = GetPhysicsVolume(Comp);
	return PhysVolume && PhysVolume->bWaterVolume;
}

bool IsValidLandingSpot(FISPCMovementContext Ctx, const FVector& CapsuleLocation, const FHitResult& Hit) const
{
	if (!Hit.bBlockingHit)
	{
		return false;
	}

	// Skip some checks if penetrating. Penetration will be handled by the FindFloor call (using a smaller capsule)
	if (!Hit.bStartPenetrating)
	{
		// Reject unwalkable floor normals.
		if (!IsWalkable(Hit, Comp->GetWalkableFloorZ()))
		{
			return false;
		}

		float PawnRadius, PawnHalfHeight;
		Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

		// Reject hits that are above our lower hemisphere (can happen when sliding down a vertical surface).
		const float LowerHemisphereZ = Hit.Location.Z - PawnHalfHeight + PawnRadius;
		if (Hit.ImpactPoint.Z >= LowerHemisphereZ)
		{
			return false;
		}

		// Reject hits that are barely on the cusp of the radius of the capsule
		if (!IsWithinEdgeTolerance(Hit.Location, Hit.ImpactPoint, PawnRadius))
		{
			return false;
		}
	}
	else
	{
		// Penetrating
		if (Hit.Normal.Z < KINDA_SMALL_NUMBER)
		{
			// Normal is nearly horizontal or downward, that's a penetration adjustment next to a vertical or overhanging wall. Don't pop to the floor.
			return false;
		}
	}

	FFindFloorResult FloorResult;
	FindFloor(Comp, CapsuleLocation, FloorResult, false, &Hit);

	if (!FloorResult.IsWalkableFloor())
	{
		return false;
	}

	return true;
}

bool ShouldCheckForValidLandingSpot(FISPCMovementContext Ctx, float DeltaTime, const FVector& Delta, const FHitResult& Hit) const
{
	// See if we hit an edge of a surface on the lower portion of the capsule.
	// In this case the normal will not equal the impact normal, and a downward sweep may find a walkable surface on top of the edge.
	if (Hit.Normal.Z > KINDA_SMALL_NUMBER && !Hit.Normal.Equals(Hit.ImpactNormal))
	{
		const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);
		if (IsWithinEdgeTolerance(PawnLocation, Hit.ImpactPoint, Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleRadius()))
		{
			return true;
		}
	}

	return false;
}

FVector GetFallingLateralAcceleration(FISPCMovementContext Ctx, float DeltaTime)
{
	// No acceleration in Z
	FVector FallAcceleration = FVector(Comp->Acceleration.X, Comp->Acceleration.Y, 0.f);

	// bound acceleration, falling object has minimal ability to impact acceleration
	if (!HasAnimRootMotion(Comp) && FallAcceleration.SizeSquared2D() > 0.f)
	{
		FallAcceleration = GetAirControl(Comp, DeltaTime, Comp->AirControl, FallAcceleration);
		FallAcceleration = FallAcceleration.GetClampedToMaxSize(GetMaxAcceleration(Comp));
	}

	return FallAcceleration;
}

static uint32 s_WarningCount = 0;
float GetSimulationTimeStep(FISPCMovementContext Ctx, float RemainingTime, int32 Iterations) const
{
	// TODO ISPC: Move MaxSimulation* to system and/or make uniform.
	if (RemainingTime > Comp->MaxSimulationTimeStep)
	{
		if (Iterations < Comp->MaxSimulationIterations)
		{
			// Subdivide moves to be no longer than MaxSimulationTimeStep seconds
			RemainingTime = FMath::Min(Comp->MaxSimulationTimeStep, RemainingTime * 0.5f);
		}
		else
		{
			// If this is the last iteration, just use all the remaining time. This is usually better than cutting things short, as the simulation won't move far enough otherwise.
			// Print a throttled warning.
#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
			if ((s_WarningCount++ < 100) || (GFrameCounter & 15) == 0)
			{
				UE_LOG(LogUnrolledCharacterMovement, Warning, TEXT("GetSimulationTimeStep() - Max iterations %d hit while remaining time %.6f > MaxSimulationTimeStep (%.3f) for '%s', movement '%s'"), Comp->MaxSimulationIterations, RemainingTime, Comp->MaxSimulationTimeStep, *GetNameSafe(Comp->CharacterOwner), *GetMovementName(Comp));
			}
#endif
		}
	}

	// no less than MIN_TICK_TIME (to avoid potential divide-by-zero during simulation).
	return FMath::Max(UCharacterMovementComponent::MIN_TICK_TIME, RemainingTime);
}

void CalcVelocity(FISPCMovementContext Ctx, float DeltaTime, float Friction, bool bFluid, float BrakingDeceleration)
{
	// Do not update velocity when using root motion or when SimulatedProxy - SimulatedProxy are repped their Velocity
	if (!HasValidData(Comp) || HasAnimRootMotion(Comp) || DeltaTime < UCharacterMovementComponent::MIN_TICK_TIME || (Comp->CharacterOwner && Comp->CharacterOwner->Role == ROLE_SimulatedProxy))
	{
		return;
	}

	Friction = FMath::Max(0.f, Friction);
	const float MaxAccel = GetMaxAcceleration(Comp);
	float MaxSpeed = GetMaxSpeed(Comp);
	
	// Check if path following requested movement
	bool bZeroRequestedAcceleration = true;
	FVector RequestedAcceleration = FVector_ZeroVector;
	float RequestedSpeed = 0.0f;
	if (ApplyRequestedMove(Comp, DeltaTime, MaxAccel, MaxSpeed, Friction, BrakingDeceleration, RequestedAcceleration, RequestedSpeed))
	{
		RequestedAcceleration = RequestedAcceleration.GetClampedToMaxSize(MaxAccel);
		bZeroRequestedAcceleration = false;
	}

	if (Comp->bForceMaxAccel)
	{
		// Force acceleration at full speed.
		// In consideration order for direction: Acceleration, then Velocity, then Pawn's rotation.
		if (Comp->Acceleration.SizeSquared() > SMALL_NUMBER)
		{
			Comp->Acceleration = Comp->Acceleration.GetSafeNormal() * MaxAccel;
		}
		else 
		{
			Comp->Acceleration = MaxAccel * (Comp->Velocity.SizeSquared() < SMALL_NUMBER ? Comp->UpdatedComponent->GetForwardVector() : Comp->Velocity.GetSafeNormal());
		}

		Comp->AnalogInputModifier = 1.f;
	}

	// Path following above didn't care about the analog modifier, but we do for everything else below, so get the fully modified value.
	// Use max of requested speed and max speed if we modified the speed in ApplyRequestedMove above.
	MaxSpeed = FMath::Max3(RequestedSpeed, MaxSpeed * Comp->AnalogInputModifier, GetMinAnalogSpeed(Comp));

	// Apply braking or deceleration
	const bool bZeroAcceleration = Comp->Acceleration.IsZero();
	const bool bVelocityOverMax = IsExceedingMaxSpeed(Comp, MaxSpeed);
	
	// Only apply braking if there is no acceleration, or we are over our max speed and need to slow down to it.
	if ((bZeroAcceleration && bZeroRequestedAcceleration) || bVelocityOverMax)
	{
		const FVector OldVelocity = Comp->Velocity;

		const float ActualBrakingFriction = (Comp->bUseSeparateBrakingFriction ? Comp->BrakingFriction : Friction);
		ApplyVelocityBraking(Comp, DeltaTime, ActualBrakingFriction, BrakingDeceleration);
	
		// Don't allow braking to lower us below max speed if we started above it.
		if (bVelocityOverMax && Comp->Velocity.SizeSquared() < FMath::Square(MaxSpeed) && FVector::DotProduct(Comp->Acceleration, OldVelocity) > 0.0f)
		{
			Comp->Velocity = OldVelocity.GetSafeNormal() * MaxSpeed;
		}
	}
	else if (!bZeroAcceleration)
	{
		// Friction affects our ability to change direction. This is only done for input acceleration, not path following.
		const FVector AccelDir = Comp->Acceleration.GetSafeNormal();
		const float VelSize = Comp->Velocity.Size();
		Comp->Velocity = Comp->Velocity - (Comp->Velocity - AccelDir * VelSize) * FMath::Min(DeltaTime * Friction, 1.f);
	}

	// Apply fluid friction
	if (bFluid)
	{
		Comp->Velocity = Comp->Velocity * (1.f - FMath::Min(Friction * DeltaTime, 1.f));
	}

	// Apply acceleration
	const float NewMaxSpeed = (IsExceedingMaxSpeed(Comp, MaxSpeed)) ? Comp->Velocity.Size() : MaxSpeed;
	Comp->Velocity += Comp->Acceleration * DeltaTime;
	Comp->Velocity += RequestedAcceleration * DeltaTime;
	Comp->Velocity = Comp->Velocity.GetClampedToMaxSize(NewMaxSpeed);

	if (Comp->bUseRVOAvoidance)
	{
		//CalcAvoidanceVelocity(Comp->DeltaTime);	// TODO ISPC
		unimplemented();
	}
}

void PhysWalking(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	SCOPE_CYCLE_COUNTER(STAT_CharPhysWalking);


	if (deltaTime < UCharacterMovementComponent::MIN_TICK_TIME)
	{
		return;
	}

	if (!Comp->CharacterOwner || (!Comp->CharacterOwner->Controller && !Comp->bRunPhysicsWithNoController && !HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity() && (Comp->CharacterOwner->Role != ROLE_SimulatedProxy)))
	{
		Comp->Acceleration = FVector_ZeroVector;
		Comp->Velocity = FVector_ZeroVector;
		return;
	}

	if (!Comp->UpdatedComponent->IsQueryCollisionEnabled())
	{
		SetMovementMode(Comp, MOVE_Walking);
		return;
	}

	checkCode(ensureMsgf(!Comp->Velocity.ContainsNaN(), TEXT("PhysWalking: Velocity contains NaN before Iteration (%s)\n%s"), *GetPathNameSafe(Comp), *Comp->Velocity.ToString()));

	Comp->bJustTeleported = false;
	bool bCheckedFall = false;
	bool bTriedLedgeMove = false;
	float remainingTime = deltaTime;

	// Perform the move
	while ((remainingTime >= UCharacterMovementComponent::MIN_TICK_TIME) && (Iterations < Comp->MaxSimulationIterations) && Comp->CharacterOwner && (Comp->CharacterOwner->Controller || Comp->bRunPhysicsWithNoController || HasAnimRootMotion(Comp) || Comp->CurrentRootMotion.HasOverrideVelocity() || (Comp->CharacterOwner->Role == ROLE_SimulatedProxy)))
	{
		Iterations++;
		Comp->bJustTeleported = false;
		const float timeTick = GetSimulationTimeStep(Comp, remainingTime, Iterations);
		remainingTime -= timeTick;

		// Save current values
		UPrimitiveComponent * const OldBase = GetMovementBase(Comp);
		const FVector PreviousBaseLocation = (OldBase != NULL) ? OldBase->GetComponentLocation() : FVector_ZeroVector;
		const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
		const FFindFloorResult OldFloor = Comp->CurrentFloor;

		RestorePreAdditiveRootMotionVelocity(Comp);

		// Ensure velocity is horizontal.
		MaintainHorizontalGroundVelocity(Comp);
		const FVector OldVelocity = Comp->Velocity;
		Comp->Acceleration.Z = 0.f;

		// Apply acceleration
		if (!HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity())
		{
			CalcVelocity(Comp, timeTick, Comp->GroundFriction, false, GetMaxBrakingDeceleration(Comp));
			checkCode(ensureMsgf(!Comp->Velocity.ContainsNaN(), TEXT("PhysWalking: Velocity contains NaN after CalcVelocity (%s)\n%s"), *GetPathNameSafe(Comp), *Comp->Velocity.ToString()));
		}

		ApplyRootMotionToVelocity(Comp, timeTick);
		checkCode(ensureMsgf(!Comp->Velocity.ContainsNaN(), TEXT("PhysWalking: Velocity contains NaN after Root Motion application (%s)\n%s"), *GetPathNameSafe(Comp), *Comp->Velocity.ToString()));

		if (IsFalling(Comp))
		{
			// Root motion could have put us into Falling.
			// No movement has taken place this movement tick so we pass on full time/past iteration count
			StartNewPhysics(Comp, remainingTime + timeTick, Iterations - 1);
			return;
		}

		// Compute move parameters
		const FVector MoveVelocity = Comp->Velocity;
		const FVector Delta = timeTick * MoveVelocity;
		const bool bZeroDelta = Delta.IsNearlyZero();
		UCharacterMovementComponent::FStepDownResult StepDownResult;

		if (bZeroDelta)
		{
			remainingTime = 0.f;
		}
		else
		{
			// try to move forward
			MoveAlongFloor(Comp, MoveVelocity, timeTick, &StepDownResult);

			if (IsFalling(Comp))
			{
				// pawn decided to jump up
				const float DesiredDist = Delta.Size();
				if (DesiredDist > KINDA_SMALL_NUMBER)
				{
					const float ActualDist = (GetUpdatedComponentLocation(Ctx) - OldLocation).Size2D();
					remainingTime += timeTick * (1.f - FMath::Min(1.f, ActualDist / DesiredDist));
				}
				StartNewPhysics(Comp, remainingTime, Iterations);
				return;
			}
			else if (IsSwimming(Comp)) //just entered water
			{
				StartSwimming(Comp, OldLocation, OldVelocity, timeTick, remainingTime, Iterations);
				return;
			}
		}

		// Update floor.
		// StepUp might have already done it for us.
		if (StepDownResult.bComputedFloor)
		{
			Comp->CurrentFloor = StepDownResult.FloorResult;
		}
		else
		{
			FindFloor(Comp, GetUpdatedComponentLocation(Ctx), Comp->CurrentFloor, bZeroDelta, NULL);
		}

		// check for ledges here
		const bool bCheckLedges = !CanWalkOffLedges(Comp);
		if (bCheckLedges && !Comp->CurrentFloor.IsWalkableFloor())
		{
			// calculate possible alternate movement
			const FVector GravDir = FVector(0.f, 0.f, -1.f);
			const FVector NewDelta = bTriedLedgeMove ? FVector_ZeroVector : GetLedgeMove(Comp, OldLocation, Delta, GravDir);
			if (!NewDelta.IsZero())
			{
				// first revert this move
				RevertMove(Comp, OldLocation, OldBase, PreviousBaseLocation, OldFloor, false);

				// avoid repeated ledge moves if the first one fails
				bTriedLedgeMove = true;

				// Try new movement direction
				Comp->Velocity = NewDelta / timeTick;
				remainingTime += timeTick;
				continue;
			}
			else
			{
				// see if it is OK to jump
				// @todo collision : only thing that can be problem is that oldbase has world collision on
				bool bMustJump = bZeroDelta || (OldBase == NULL || (!OldBase->IsQueryCollisionEnabled() && MovementBaseUtility::IsDynamicBase(OldBase)));
				if ((bMustJump || !bCheckedFall) && CheckFall(Comp, OldFloor, Comp->CurrentFloor.HitResult, Delta, OldLocation, remainingTime, timeTick, Iterations, bMustJump))
				{
					return;
				}
				bCheckedFall = true;

				// revert this move
				RevertMove(Comp, OldLocation, OldBase, PreviousBaseLocation, OldFloor, true);
				remainingTime = 0.f;
				break;
			}
		}
		else
		{
			// Validate the floor check
			if (Comp->CurrentFloor.IsWalkableFloor())
			{
				if (Comp->ShouldCatchAir(OldFloor, Comp->CurrentFloor))
				{
					Comp->CharacterOwner->OnWalkingOffLedge(OldFloor.HitResult.ImpactNormal, OldFloor.HitResult.Normal, OldLocation, timeTick);
					if (IsMovingOnGround(Comp))
					{
						// If still walking, then fall. If not, assume the user set a different mode they want to keep.
						StartFalling(Comp, Iterations, remainingTime, timeTick, Delta, OldLocation);
					}
					return;
				}

				AdjustFloorHeight(Comp);
				SetBase(Comp, Comp->CurrentFloor.HitResult.Component.Get(), Comp->CurrentFloor.HitResult.BoneName);
			}
			else if (Comp->CurrentFloor.HitResult.bStartPenetrating && remainingTime <= 0.f)
			{
				// The floor check failed because it started in penetration
				// We do not want to try to move downward because the downward sweep failed, rather we'd like to try to pop out of the floor.
				FHitResult Hit(Comp->CurrentFloor.HitResult);
				Hit.TraceEnd = Hit.TraceStart + FVector(0.f, 0.f, UCharacterMovementComponent::MAX_FLOOR_DIST);
				const FVector RequestedAdjustment = GetPenetrationAdjustment(Comp, Hit);
				Comp->ResolvePenetration(RequestedAdjustment, Hit, Comp->UpdatedComponent->GetComponentQuat());
				Comp->bForceNextFloorCheck = true;
			}

			// check if just entered water
			if (IsSwimming(Comp))
			{
				StartSwimming(Comp, OldLocation, Comp->Velocity, timeTick, remainingTime, Iterations);
				return;
			}

			// See if we need to start falling.
			if (!Comp->CurrentFloor.IsWalkableFloor() && !Comp->CurrentFloor.HitResult.bStartPenetrating)
			{
				const bool bMustJump = Comp->bJustTeleported || bZeroDelta || (OldBase == NULL || (!OldBase->IsQueryCollisionEnabled() && MovementBaseUtility::IsDynamicBase(OldBase)));
				if ((bMustJump || !bCheckedFall) && CheckFall(Comp, OldFloor, Comp->CurrentFloor.HitResult, Delta, OldLocation, remainingTime, timeTick, Iterations, bMustJump))
				{
					return;
				}
				bCheckedFall = true;
			}
		}


		// Allow overlap events and such to change physics state and velocity
		if (IsMovingOnGround(Comp))
		{
			// Make velocity reflect actual move
			if (!Comp->bJustTeleported && !HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity() && timeTick >= UCharacterMovementComponent::MIN_TICK_TIME)
			{
				// TODO-RootMotionSource: Allow this to happen during partial override Velocity, but only set allowed axes?
				Comp->Velocity = (GetUpdatedComponentLocation(Ctx) - OldLocation) / timeTick;
			}
		}

		// If we didn't move at all this iteration then abort (since future iterations will also be stuck).
		if (GetUpdatedComponentLocation(Ctx) == OldLocation)
		{
			remainingTime = 0.f;
			break;
		}
	}

	if (IsMovingOnGround(Comp))
	{
		MaintainHorizontalGroundVelocity(Comp);
	}
}

void PhysNavWalking(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	unimplemented();
#if 0	// TODO ISPC
	SCOPE_CYCLE_COUNTER(STAT_CharPhysNavWalking);

	if (deltaTime < UCharacterMovementComponent::MIN_TICK_TIME)
	{
		return;
	}

	if ((!Comp->CharacterOwner || !Comp->CharacterOwner->Controller) && !Comp->bRunPhysicsWithNoController && !HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity())
	{
		Comp->Acceleration = FVector_ZeroVector;
		Comp->Velocity = FVector_ZeroVector;
		return;
	}

	RestorePreAdditiveRootMotionVelocity(Comp);

	// Ensure velocity is horizontal.
	MaintainHorizontalGroundVelocity(Comp);
	checkCode(ensureMsgf(!Comp->Velocity.ContainsNaN(), TEXT("PhysNavWalking: Velocity contains NaN before CalcVelocity (%s)\n%s"), *GetPathNameSafe(Comp), *Comp->Velocity.ToString()));

	//bound acceleration
	Comp->Acceleration.Z = 0.f;
	if (!HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity())
	{
		CalcVelocity(Comp, deltaTime, Comp->GroundFriction, false, GetMaxBrakingDeceleration(Comp));
		checkCode(ensureMsgf(!Comp->Velocity.ContainsNaN(), TEXT("PhysNavWalking: Velocity contains NaN after CalcVelocity (%s)\n%s"), *GetPathNameSafe(Comp), *Comp->Velocity.ToString()));
	}

	ApplyRootMotionToVelocity(Comp, deltaTime);

	if( IsFalling(Comp) )
	{
		// Root motion could have put us into Falling
		StartNewPhysics(Comp, deltaTime, Iterations);
		return;
	}

	Iterations++;

	FVector DesiredMove = Comp->Velocity;
	DesiredMove.Z = 0.f;

	const FVector OldLocation = GetActorFeetLocation(Comp);
	const FVector DeltaMove = DesiredMove * deltaTime;

	FVector AdjustedDest = OldLocation + DeltaMove;
	FNavLocation DestNavLocation;

	bool bSameNavLocation = false;
	if (Comp->CachedNavLocation.NodeRef != INVALID_NAVNODEREF)
	{
		if (Comp->bProjectNavMeshWalking)
		{
			const float DistSq2D = (OldLocation - Comp->CachedNavLocation.Location).SizeSquared2D();
			const float DistZ = FMath::Abs(OldLocation.Z - Comp->CachedNavLocation.Location.Z);

			const float TotalCapsuleHeight = Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleHalfHeight() * 2.0f;
			const float ProjectionScale = (OldLocation.Z > Comp->CachedNavLocation.Location.Z) ? Comp->NavMeshProjectionHeightScaleUp : Comp->NavMeshProjectionHeightScaleDown;
			const float DistZThr = TotalCapsuleHeight * FMath::Max(0.f, ProjectionScale);

			bSameNavLocation = (DistSq2D <= KINDA_SMALL_NUMBER) && (DistZ < DistZThr);
		}
		else
		{
			bSameNavLocation = Comp->CachedNavLocation.Location.Equals(OldLocation);
		}
	}
		

	if (DeltaMove.IsNearlyZero() && bSameNavLocation)
	{
		DestNavLocation = Comp->CachedNavLocation;
		UE_LOG(LogUnrolledNavMeshMovement, VeryVerbose, TEXT("%s using cached navmesh location! (bProjectNavMeshWalking = %d)"), *GetNameSafe(Comp->CharacterOwner), Comp->bProjectNavMeshWalking);
	}
	else
	{
		SCOPE_CYCLE_COUNTER(STAT_CharNavProjectPoint);

		// Start the trace from the Z location of the last valid trace.
		// Otherwise if we are projecting our location to the underlying geometry and it's far above or below the navmesh,
		// we'll follow that geometry's plane out of range of valid navigation.
		if (bSameNavLocation && Comp->bProjectNavMeshWalking)
		{
			AdjustedDest.Z = Comp->CachedNavLocation.Location.Z;
		}

		// Find the point on the NavMesh
		const bool bHasNavigationData = FindNavFloor(Comp, AdjustedDest, DestNavLocation);
		if (!bHasNavigationData)
		{
			SetMovementMode(Comp, MOVE_Walking);
			return;
		}

		Comp->CachedNavLocation = DestNavLocation;
	}

	if (DestNavLocation.NodeRef != INVALID_NAVNODEREF)
	{
		FVector NewLocation(AdjustedDest.X, AdjustedDest.Y, DestNavLocation.Location.Z);
		if (Comp->bProjectNavMeshWalking)
		{
			SCOPE_CYCLE_COUNTER(STAT_CharNavProjectLocation);
			const float TotalCapsuleHeight = Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleHalfHeight() * 2.0f;
			const float UpOffset = TotalCapsuleHeight * FMath::Max(0.f, Comp->NavMeshProjectionHeightScaleUp);
			const float DownOffset = TotalCapsuleHeight * FMath::Max(0.f, Comp->NavMeshProjectionHeightScaleDown);
			NewLocation = ProjectLocationFromNavMesh(Comp-> deltaTime, OldLocation, NewLocation, UpOffset, DownOffset);
		}

		FVector AdjustedDelta = NewLocation - OldLocation;

		if (!AdjustedDelta.IsNearlyZero())
		{
			FHitResult HitResult;
			const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
			SafeMoveUpdatedComponent(Comp, AdjustedDelta, UpdatedComponent->GetComponentQuat(), bSweepWhileNavWalking, HitResult);
		}

		// Update velocity to reflect actual move
		if (!bJustTeleported && !HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasVelocity())
		{
			Comp->Velocity = (GetActorFeetLocation(Comp) - OldLocation) / deltaTime;
			MaintainHorizontalGroundVelocity(Comp);
		}

		bJustTeleported = false;
	}
	else
	{
		StartFalling(Comp, Iterations, deltaTime, deltaTime, DeltaMove, OldLocation);
	}
#endif	// TODO ISPC
}

void PhysFlying(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	unimplemented();
}

void PhysSwimming(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	unimplemented();
}

void PhysCustom(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	unimplemented();
}

void PhysFalling(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	SCOPE_CYCLE_COUNTER(STAT_CharPhysFalling);

	if (deltaTime < UCharacterMovementComponent::MIN_TICK_TIME)
	{
		return;
	}

	FVector FallAcceleration = GetFallingLateralAcceleration(Comp, deltaTime);
	FallAcceleration.Z = 0.f;
	const bool bHasAirControl = (FallAcceleration.SizeSquared2D() > 0.f);

	float remainingTime = deltaTime;
	while( (remainingTime >= UCharacterMovementComponent::MIN_TICK_TIME) && (Iterations < Comp->MaxSimulationIterations) )
	{
		Iterations++;
		const float timeTick = GetSimulationTimeStep(Comp, remainingTime, Iterations);
		remainingTime -= timeTick;
		
		const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
		const FQuat PawnRotation = Comp->UpdatedComponent->GetComponentQuat();
		Comp->bJustTeleported = false;

		RestorePreAdditiveRootMotionVelocity(Comp);

		FVector OldVelocity = Comp->Velocity;
		FVector VelocityNoAirControl = Comp->Velocity;

		// Apply input
		if (!HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity())
		{
			const float MaxDecel = GetMaxBrakingDeceleration(Comp);
			// Compute VelocityNoAirControl
			if (bHasAirControl)
			{
				// Find velocity *without* acceleration.
				TGuardValue<FVector> RestoreAcceleration(Comp->Acceleration, FVector_ZeroVector);
				TGuardValue<FVector> RestoreVelocity(Comp->Velocity, Comp->Velocity);
				Comp->Velocity.Z = 0.f;
				CalcVelocity(Comp, timeTick, Comp->FallingLateralFriction, false, MaxDecel);
				VelocityNoAirControl = FVector(Comp->Velocity.X, Comp->Velocity.Y, OldVelocity.Z);
			}

			// Compute Velocity
			{
				// Acceleration = FallAcceleration for CalcVelocity(), but we restore it after using it.
				TGuardValue<FVector> RestoreAcceleration(Comp->Acceleration, FallAcceleration);
				Comp->Velocity.Z = 0.f;
				CalcVelocity(Comp, timeTick, Comp->FallingLateralFriction, false, MaxDecel);
				Comp->Velocity.Z = OldVelocity.Z;
			}

			// Just copy Velocity to VelocityNoAirControl if they are the same (ie no acceleration).
			if (!bHasAirControl)
			{
				VelocityNoAirControl = Comp->Velocity;
			}
		}

		// Apply gravity
		const FVector Gravity(0.f, 0.f, GetGravityZ(Comp));
		Comp->Velocity = NewFallVelocity(Comp, Comp->Velocity, Gravity, timeTick);
		VelocityNoAirControl = NewFallVelocity(Comp, VelocityNoAirControl, Gravity, timeTick);
		const FVector AirControlAccel = (Comp->Velocity - VelocityNoAirControl) / timeTick;

		ApplyRootMotionToVelocity(Comp, timeTick);

		if( Comp->bNotifyApex && Comp->CharacterOwner->Controller && (Comp->Velocity.Z <= 0.f) )
		{
			// Just passed jump apex since now going down
			Comp->bNotifyApex = false;
			NotifyJumpApex(Comp);
		}


		// Move
		FHitResult Hit(1.f);
		FVector Adjusted = 0.5f*(OldVelocity + Comp->Velocity) * timeTick;
		const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
		SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, Adjusted, PawnRotation, true, Hit);
		
		if (!HasValidData(Comp))
		{
			return;
		}
		
		float LastMoveTimeSlice = timeTick;
		float subTimeTickRemaining = timeTick * (1.f - Hit.Time);
		
		if ( IsSwimming(Comp) ) //just entered water
		{
			remainingTime += subTimeTickRemaining;
			StartSwimming(Comp, OldLocation, OldVelocity, timeTick, remainingTime, Iterations);
			return;
		}
		else if ( Hit.bBlockingHit )
		{
			if (IsValidLandingSpot(Comp, GetUpdatedComponentLocation(Ctx), Hit))
			{
				remainingTime += subTimeTickRemaining;
				ProcessLanded(Comp, Hit, remainingTime, Iterations);
				return;
			}
			else
			{
				// Compute impact deflection based on final velocity, not integration step.
				// This allows us to compute a new velocity from the deflected vector, and ensures the full gravity effect is included in the slide result.
				Adjusted = Comp->Velocity * timeTick;

				// See if we can convert a normally invalid landing spot (based on the hit result) to a usable one.
				if (!Hit.bStartPenetrating && ShouldCheckForValidLandingSpot(Comp, timeTick, Adjusted, Hit))
				{
					const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);
					FFindFloorResult FloorResult;
					FindFloor(Comp, PawnLocation, FloorResult, false);
					if (FloorResult.IsWalkableFloor() && IsValidLandingSpot(Comp, PawnLocation, FloorResult.HitResult))
					{
						remainingTime += subTimeTickRemaining;
						ProcessLanded(Comp, FloorResult.HitResult, remainingTime, Iterations);
						return;
					}
				}

				HandleImpact(Comp, Hit, LastMoveTimeSlice, Adjusted);
				
				// If we've changed physics mode, abort.
				if (!HasValidData(Comp) || !IsFalling(Comp))
				{
					return;
				}

				// Limit air control based on what we hit.
				// We moved to the impact point using air control, but may want to deflect from there based on a limited air control acceleration.
				if (bHasAirControl)
				{
					const bool bCheckLandingSpot = false; // we already checked above.
					const FVector AirControlDeltaV = LimitAirControl(Comp, LastMoveTimeSlice, AirControlAccel, Hit, bCheckLandingSpot) * LastMoveTimeSlice;
					Adjusted = (VelocityNoAirControl + AirControlDeltaV) * LastMoveTimeSlice;
				}

				const FVector OldHitNormal = Hit.Normal;
				const FVector OldHitImpactNormal = Hit.ImpactNormal;				
				FVector Delta = ComputeSlideVector(Comp, Adjusted, 1.f - Hit.Time, OldHitNormal, Hit);

				// Compute velocity after deflection (only gravity component for RootMotion)
				if (subTimeTickRemaining > KINDA_SMALL_NUMBER && !Comp->bJustTeleported)
				{
					const FVector NewVelocity = (Delta / subTimeTickRemaining);
					Comp->Velocity = HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity() ? FVector(Comp->Velocity.X, Comp->Velocity.Y, NewVelocity.Z) : NewVelocity;
				}

				if (subTimeTickRemaining > KINDA_SMALL_NUMBER && (Delta | Adjusted) > 0.f)
				{
					// Move in deflected direction.
					SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, Delta, PawnRotation, true, Hit);
					
					if (Hit.bBlockingHit)
					{
						// hit second wall
						LastMoveTimeSlice = subTimeTickRemaining;
						subTimeTickRemaining = subTimeTickRemaining * (1.f - Hit.Time);

						if (IsValidLandingSpot(Comp, GetUpdatedComponentLocation(Ctx), Hit))
						{
							remainingTime += subTimeTickRemaining;
							ProcessLanded(Comp, Hit, remainingTime, Iterations);
							return;
						}

						HandleImpact(Comp, Hit, LastMoveTimeSlice, Delta);

						// If we've changed physics mode, abort.
						if (!HasValidData(Comp) || !IsFalling(Comp))
						{
							return;
						}

						// Act as if there was no air control on the last move when computing new deflection.
						if (bHasAirControl && Hit.Normal.Z > VERTICAL_SLOPE_NORMAL_Z)
						{
							const FVector LastMoveNoAirControl = VelocityNoAirControl * LastMoveTimeSlice;
							Delta = ComputeSlideVector(Comp, LastMoveNoAirControl, 1.f, OldHitNormal, Hit);
						}

						FVector PreTwoWallDelta = Delta;
						TwoWallAdjust(Comp, Delta, Hit, OldHitNormal);

						// Limit air control, but allow a slide along the second wall.
						if (bHasAirControl)
						{
							const bool bCheckLandingSpot = false; // we already checked above.
							const FVector AirControlDeltaV = LimitAirControl(Comp, subTimeTickRemaining, AirControlAccel, Hit, bCheckLandingSpot) * subTimeTickRemaining;

							// Only allow if not back in to first wall
							if (FVector::DotProduct(AirControlDeltaV, OldHitNormal) > 0.f)
							{
								Delta += (AirControlDeltaV * subTimeTickRemaining);
							}
						}

						// Compute velocity after deflection (only gravity component for RootMotion)
						if (subTimeTickRemaining > KINDA_SMALL_NUMBER && !Comp->bJustTeleported)
						{
							const FVector NewVelocity = (Delta / subTimeTickRemaining);
							Comp->Velocity = HasAnimRootMotion(Comp) && !Comp->CurrentRootMotion.HasOverrideVelocity() ? FVector(Comp->Velocity.X, Comp->Velocity.Y, NewVelocity.Z) : NewVelocity;
						}

						// bDitch=true means that pawn is straddling two slopes, neither of which he can stand on
						bool bDitch = ( (OldHitImpactNormal.Z > 0.f) && (Hit.ImpactNormal.Z > 0.f) && (FMath::Abs(Delta.Z) <= KINDA_SMALL_NUMBER) && ((Hit.ImpactNormal | OldHitImpactNormal) < 0.f) );
						SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, Delta, PawnRotation, true, Hit);
						if ( Hit.Time == 0.f )
						{
							// if we are stuck then try to side step
							FVector SideDelta = (OldHitNormal + Hit.ImpactNormal).GetSafeNormal2D();
							if ( SideDelta.IsNearlyZero() )
							{
								SideDelta = FVector(OldHitNormal.Y, -OldHitNormal.X, 0).GetSafeNormal();
							}
							SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, SideDelta, PawnRotation, true, Hit);
						}
							
						if ( bDitch || IsValidLandingSpot(Comp, GetUpdatedComponentLocation(Ctx), Hit) || Hit.Time == 0.f  )
						{
							remainingTime = 0.f;
							ProcessLanded(Comp, Hit, remainingTime, Iterations);
							return;
						}
						else if (GetPerchRadiusThreshold(Comp) > 0.f && Hit.Time == 1.f && OldHitImpactNormal.Z >= Comp->GetWalkableFloorZ())
						{
							// We might be in a virtual 'ditch' within our perch radius. This is rare.
							const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);
							const float ZMovedDist = FMath::Abs(PawnLocation.Z - OldLocation.Z);
							const float MovedDist2DSq = (PawnLocation - OldLocation).SizeSquared2D();
							if (ZMovedDist <= 0.2f * timeTick && MovedDist2DSq <= 4.f * timeTick)
							{
								Comp->Velocity.X += 0.25f * GetMaxSpeed(Comp) * (FMath::FRand() - 0.5f);
								Comp->Velocity.Y += 0.25f * GetMaxSpeed(Comp) * (FMath::FRand() - 0.5f);
								Comp->Velocity.Z = FMath::Max<float>(Comp->JumpZVelocity * 0.25f, 1.f);
								Delta = Comp->Velocity * timeTick;
								SafeMoveUpdatedComponent(Comp, bMoveIgnoreFirstBlockingOverlap, Delta, PawnRotation, true, Hit);
							}
						}
					}
				}
			}
		}

		if (Comp->Velocity.SizeSquared2D() <= KINDA_SMALL_NUMBER * 10.f)
		{
			Comp->Velocity.X = 0.f;
			Comp->Velocity.Y = 0.f;
		}
	}
}

void SetMovementMode(FISPCMovementContext Ctx, EMovementMode NewMovementMode, uint8 NewCustomMode)
{
	if (NewMovementMode != MOVE_Custom)
	{
		NewCustomMode = 0;
	}

	// If trying to use NavWalking but there is no navmesh, use walking instead.
	if (NewMovementMode == MOVE_NavWalking)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		if (Comp->GetNavData() == nullptr)
		{
			NewMovementMode = MOVE_Walking;
		}
#endif
	}

	// Do nothing if nothing is changing.
	if (Comp->MovementMode == NewMovementMode)
	{
		// Allow changes in custom sub-mode.
		if ((NewMovementMode != MOVE_Custom) || (NewCustomMode == Comp->CustomMovementMode))
		{
			return;
		}
	}

	const EMovementMode PrevMovementMode = Comp->MovementMode;
	const uint8 PrevCustomMode = Comp->CustomMovementMode;

	Comp->MovementMode = NewMovementMode;
	Comp->CustomMovementMode = NewCustomMode;

	// We allow setting movement mode before we have a component to update, in case this happens at startup.
	if (!HasValidData(Comp))
	{
		return;
	}
	
	// Handle change in movement mode
	OnMovementModeChanged(Comp, PrevMovementMode, PrevCustomMode);

	// @todo UE4 do we need to disable ragdoll physics here? Should this function do nothing if in ragdoll?
}

void SetGroundMovementMode(FISPCMovementContext Ctx, EMovementMode NewGroundMovementMode)
{
#if 1	// TODO ISPC: GroundMovementMode is private, but we should be able to work around that.
	Comp->SetGroundMovementMode(NewGroundMovementMode);
#else
	// Enforce restriction that it's either Walking or NavWalking.
	if (NewGroundMovementMode != MOVE_Walking && NewGroundMovementMode != MOVE_NavWalking)
	{
		return;
	}

	// Set new value
	Comp->GroundMovementMode = NewGroundMovementMode;

	// Possibly change movement modes if already on ground and choosing the other ground mode.
	const bool bOnGround = (Comp->MovementMode == MOVE_Walking || Comp->MovementMode == MOVE_NavWalking);
	if (bOnGround && Comp->MovementMode != NewGroundMovementMode)
	{
		SetMovementMode(Comp, NewGroundMovementMode);
	}
#endif
}

void SetDefaultMovementMode(FISPCMovementContext Ctx)
{
	// check for water volume
	if (CanEverSwim(Comp) && IsInWater(Comp))
	{
		SetMovementMode(Comp, Comp->DefaultWaterMovementMode);
	}
	else if ( !Comp->CharacterOwner || Comp->MovementMode != Comp->DefaultLandMovementMode )
	{
		const float SavedVelocityZ = Comp->Velocity.Z;
		SetMovementMode(Comp, Comp->DefaultLandMovementMode);

		// Avoid 1-frame delay if trying to walk but walking fails at this location.
		if (Comp->MovementMode == MOVE_Walking && GetMovementBase(Comp) == NULL)
		{
			Comp->Velocity.Z = SavedVelocityZ; // Prevent temporary walking state from zeroing Z velocity.
			SetMovementMode(Comp, MOVE_Falling);
		}
	}
}

void OnMovementModeChanged(FISPCMovementContext Ctx, EMovementMode PreviousMovementMode, uint8 PreviousCustomMode)
{
	if (!HasValidData(Comp))
	{
		return;
	}

	// Update collision settings if needed
	if (Comp->MovementMode == MOVE_NavWalking)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		Comp->SetNavWalkingPhysics(true);
		SetGroundMovementMode(Comp, Comp->MovementMode);
		// Walking uses only XY velocity
		Comp->Velocity.Z = 0.f;
#endif
	}
	else if (PreviousMovementMode == MOVE_NavWalking)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		if (Comp->MovementMode == Comp->DefaultLandMovementMode || Comp->IsWalking())
		{
			const bool bSucceeded = Comp->TryToLeaveNavWalking();
			if (!bSucceeded)
			{
				return;
			}
		}
		else
		{
			Comp->SetNavWalkingPhysics(false);
		}
#endif
	}

	// React to changes in the movement mode.
	if (Comp->MovementMode == MOVE_Walking)
	{
		// Walking uses only XY velocity, and must be on a walkable floor, with a Base.
		Comp->Velocity.Z = 0.f;
		Comp->bCrouchMaintainsBaseLocation = true;
		SetGroundMovementMode(Comp, Comp->MovementMode);

		// make sure we update our new floor/base on initial entry of the walking physics
		FindFloor(Comp, GetUpdatedComponentLocation(Ctx), Comp->CurrentFloor, false);
		AdjustFloorHeight(Comp);
		SetBaseFromFloor(Comp, Comp->CurrentFloor);
	}
	else
	{
		Comp->CurrentFloor.Clear();
		Comp->bCrouchMaintainsBaseLocation = false;

		if (Comp->MovementMode == MOVE_Falling)
		{
			Comp->Velocity += GetImpartedMovementBaseVelocity(Comp);
			// TODO ISPC: foreach_active?
			Comp->CharacterOwner->Falling();
		}

		SetBase(Comp, NULL);

		if (Comp->MovementMode == MOVE_None)
		{
			// Kill velocity and clear queued up events
			StopMovementKeepPathing(Comp);
			Comp->CharacterOwner->ClearJumpInput();
			ClearAccumulatedForces(Comp);
		}
	}

	if (Comp->MovementMode == MOVE_Falling && PreviousMovementMode != MOVE_Falling && Comp->PathFollowingComp.IsValid())
	{
		// TODO ISPC: foreach_active?
		Comp->PathFollowingComp->OnStartedFalling();
	}

	// TODO ISPC: foreach_active?
	Comp->CharacterOwner->OnMovementModeChanged(PreviousMovementMode, PreviousCustomMode);
	ensureMsgf(Comp->GetGroundMovementMode() == MOVE_Walking || Comp->GetGroundMovementMode() == MOVE_NavWalking, TEXT("Invalid GroundMovementMode %d. MovementMode: %d, PreviousMovementMode: %d"), Comp->GetGroundMovementMode(), Comp->MovementMode.GetValue(), PreviousMovementMode);
};

bool CheckLedgeDirection(FISPCMovementContext Ctx, const FVector& OldLocation, const FVector& SideStep, const FVector& GravDir) const
{
	const FVector SideDest = OldLocation + SideStep;
	FCollisionQueryParams CapsuleParams(SCENE_QUERY_STAT(CheckLedgeDirection), false, Comp->CharacterOwner);
	FCollisionResponseParams ResponseParam;
	InitCollisionParams(Comp, CapsuleParams, ResponseParam);
	// ISPC: This can be cached, no point in unrolling.
	const FCollisionShape CapsuleShape = Comp->GetPawnCapsuleCollisionShape(UCharacterMovementComponent::EShrinkCapsuleExtent::SHRINK_None);
	const ECollisionChannel CollisionChannel = Comp->UpdatedComponent->GetCollisionObjectType();
	FHitResult Result(1.f);
	GetWorld()->SweepSingleByChannel(Result, OldLocation, SideDest, FQuat::Identity, CollisionChannel, CapsuleShape, CapsuleParams, ResponseParam);

	if ( !Result.bBlockingHit || IsWalkable(Result, Comp->GetWalkableFloorZ()) )
	{
		if ( !Result.bBlockingHit )
		{
			GetWorld()->SweepSingleByChannel(Result, SideDest, SideDest + GravDir * (Comp->MaxStepHeight + Comp->LedgeCheckThreshold), FQuat::Identity, CollisionChannel, CapsuleShape, CapsuleParams, ResponseParam);
		}
		if ( (Result.Time < 1.f) && IsWalkable(Result, Comp->GetWalkableFloorZ()) )
		{
			return true;
		}
	}
	return false;
}

FVector GetLedgeMove(FISPCMovementContext Ctx, const FVector& OldLocation, const FVector& Delta, const FVector& GravDir) const
{
	if (!HasValidData(Comp) || Delta.IsZero())
	{
		return FVector_ZeroVector;
	}

	FVector SideDir(Delta.Y, -1.f * Delta.X, 0.f);
		
	// try left
	if ( CheckLedgeDirection(Comp, OldLocation, SideDir, GravDir) )
	{
		return SideDir;
	}

	// try right
	SideDir *= -1.f;
	if ( CheckLedgeDirection(Comp, OldLocation, SideDir, GravDir) )
	{
		return SideDir;
	}
	
	return FVector_ZeroVector;
}

bool CanWalkOffLedges(FISPCMovementContext Ctx) const
{
	if (!Comp->bCanWalkOffLedgesWhenCrouching && IsCrouching(Comp))
	{
		return false;
	}	

	return Comp->bCanWalkOffLedges;
}

bool CheckFall(FISPCMovementContext Ctx, const FFindFloorResult& OldFloor, const FHitResult& Hit, const FVector& Delta, const FVector& OldLocation, float remainingTime, float timeTick, int32 Iterations, bool bMustJump)
{
	if (!HasValidData(Comp))
	{
		return false;
	}

	if (bMustJump || CanWalkOffLedges(Comp))
	{
		Comp->CharacterOwner->OnWalkingOffLedge(OldFloor.HitResult.ImpactNormal, OldFloor.HitResult.Normal, OldLocation, timeTick);
		if (IsMovingOnGround(Comp))
		{
			// If still walking, then fall. If not, assume the user set a different mode they want to keep.
			StartFalling(Comp, Iterations, remainingTime, timeTick, Delta, OldLocation);
		}
		return true;
	}
	return false;
}

void StartSwimming(FISPCMovementContext Ctx, FVector OldLocation, FVector OldVelocity, float timeTick, float remainingTime, int32 Iterations)
{
	unimplemented();
}

void StartFalling(FISPCMovementContext Ctx, int32 Iterations, float remainingTime, float timeTick, const FVector& Delta, const FVector& subLoc)
{
	// start falling 
	const float DesiredDist = Delta.Size();
	const float ActualDist = (GetUpdatedComponentLocation(Ctx) - subLoc).Size2D();
	remainingTime = (DesiredDist < KINDA_SMALL_NUMBER) 
					? 0.f
					: remainingTime + timeTick * (1.f - FMath::Min(1.f,ActualDist/DesiredDist));

	if (IsMovingOnGround(Comp) )
	{
		// This is to catch cases where the first frame of PIE is executed, and the
		// level is not yet visible. In those cases, the player will fall out of the
		// world... So, don't set MOVE_Falling straight away.
		if ( !GIsEditor || (GetWorld()->HasBegunPlay() && (GetWorld()->GetTimeSeconds() >= 1.f)) )
		{
			SetMovementMode(Comp, MOVE_Falling); //default behavior if script didn't change physics
		}
		else
		{
			// Make sure that the floor check code continues processing during this delay.
			Comp->bForceNextFloorCheck = true;
		}
	}
	StartNewPhysics(Comp,remainingTime,Iterations);
}

void FindFloor(FISPCMovementContext Ctx, const FVector& CapsuleLocation, FFindFloorResult& OutFloorResult, bool bZeroDelta, const FHitResult* DownwardSweepResult) const
{
	SCOPE_CYCLE_COUNTER(STAT_CharFindFloor);

	// No collision, no floor...
	if (!HasValidData(Comp) || !Comp->UpdatedComponent->IsQueryCollisionEnabled())
	{
		OutFloorResult.Clear();
		return;
	}

	UE_LOG(LogUnrolledCharacterMovement, VeryVerbose, TEXT("[Role:%d] FindFloor: %s at location %s"), (int32)Comp->CharacterOwner->Role, *GetNameSafe(Comp->CharacterOwner), *CapsuleLocation.ToString());
	check(Comp->CharacterOwner->GetCapsuleComponent());

	// Increase height check slightly if walking, to prevent floor height adjustment from later invalidating the floor result.
	const float HeightCheckAdjust = (IsMovingOnGround(Comp) ? UCharacterMovementComponent::MAX_FLOOR_DIST + KINDA_SMALL_NUMBER : -UCharacterMovementComponent::MAX_FLOOR_DIST);

	float FloorSweepTraceDist = FMath::Max(UCharacterMovementComponent::MAX_FLOOR_DIST, Comp->MaxStepHeight + HeightCheckAdjust);
	float FloorLineTraceDist = FloorSweepTraceDist;
	bool bNeedToValidateFloor = true;

	// Sweep floor
	if (FloorLineTraceDist > 0.f || FloorSweepTraceDist > 0.f)
	{
		if (Comp->bAlwaysCheckFloor || !bZeroDelta || Comp->bForceNextFloorCheck || Comp->bJustTeleported)
		{
			Comp->bForceNextFloorCheck = false;
			ComputeFloorDist(Comp, CapsuleLocation, FloorLineTraceDist, FloorSweepTraceDist, OutFloorResult, Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleRadius(), DownwardSweepResult);
		}
		else
		{
			// Force floor check if base has collision disabled or if it does not block us.
			UPrimitiveComponent* MovementBase = Comp->CharacterOwner->GetMovementBase();
			const AActor* BaseActor = MovementBase ? MovementBase->GetOwner() : NULL;
			const ECollisionChannel CollisionChannel = Comp->UpdatedComponent->GetCollisionObjectType();

			if (MovementBase != NULL)
			{
				Comp->bForceNextFloorCheck = !MovementBase->IsQueryCollisionEnabled()
					|| MovementBase->GetCollisionResponseToChannel(CollisionChannel) != ECR_Block
					|| MovementBaseUtility::IsDynamicBase(MovementBase);
			}

			const bool IsActorBasePendingKill = BaseActor && BaseActor->IsPendingKill();

			if (!Comp->bForceNextFloorCheck && !IsActorBasePendingKill && MovementBase)
			{
				//UE_LOG(LogUnrolledCharacterMovement, Log, TEXT("%s SKIP check for floor"), *CharacterOwner->GetName());
				OutFloorResult = Comp->CurrentFloor;
				bNeedToValidateFloor = false;
			}
			else
			{
				Comp->bForceNextFloorCheck = false;
				ComputeFloorDist(Comp, CapsuleLocation, FloorLineTraceDist, FloorSweepTraceDist, OutFloorResult, Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleRadius(), DownwardSweepResult);
			}
		}
	}

	// OutFloorResult.HitResult is now the result of the vertical floor check.
	// See if we should try to "perch" at this location.
	if (bNeedToValidateFloor && OutFloorResult.bBlockingHit && !OutFloorResult.bLineTrace)
	{
		const bool bCheckRadius = true;
		if (ShouldComputePerchResult(Comp, OutFloorResult.HitResult, bCheckRadius))
		{
			float MaxPerchFloorDist = FMath::Max(UCharacterMovementComponent::MAX_FLOOR_DIST, Comp->MaxStepHeight + HeightCheckAdjust);
			if (IsMovingOnGround(Comp))
			{
				MaxPerchFloorDist += FMath::Max(0.f, Comp->PerchAdditionalHeight);
			}

			FFindFloorResult PerchFloorResult;
			if (ComputePerchResult(Comp, GetValidPerchRadius(Comp), OutFloorResult.HitResult, MaxPerchFloorDist, PerchFloorResult))
			{
				// Don't allow the floor distance adjustment to push us up too high, or we will move beyond the perch distance and fall next time.
				const float AvgFloorDist = (UCharacterMovementComponent::MIN_FLOOR_DIST + UCharacterMovementComponent::MAX_FLOOR_DIST) * 0.5f;
				const float MoveUpDist = (AvgFloorDist - OutFloorResult.FloorDist);
				if (MoveUpDist + PerchFloorResult.FloorDist >= MaxPerchFloorDist)
				{
					OutFloorResult.FloorDist = AvgFloorDist;
				}

				// If the regular capsule is on an unwalkable surface but the perched one would allow us to stand, override the normal to be one that is walkable.
				if (!OutFloorResult.bWalkableFloor)
				{
					OutFloorResult.SetFromLineTrace(PerchFloorResult.HitResult, OutFloorResult.FloorDist, FMath::Min(PerchFloorResult.FloorDist, PerchFloorResult.LineDist), true);
				}
			}
			else
			{
				// We had no floor (or an invalid one because it was unwalkable), and couldn't perch here, so invalidate floor (which will cause us to start falling).
				OutFloorResult.bWalkableFloor = false;
			}
		}
	}
}
#endif

#if UNIMPLEMENTED_CODE
void ComputeFloorDist(FISPCMovementContext Ctx, const FVector& CapsuleLocation, float LineDistance, float SweepDistance, FFindFloorResult& OutFloorResult, float SweepRadius, const FHitResult* DownwardSweepResult) const
{
	UE_LOG(LogUnrolledCharacterMovement, VeryVerbose, TEXT("[Role:%d] ComputeFloorDist: %s at location %s"), (int32)Comp->CharacterOwner->Role, *GetNameSafe(Comp->CharacterOwner), *CapsuleLocation.ToString());
	OutFloorResult.Clear();

	float PawnRadius, PawnHalfHeight;
	Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

	bool bSkipSweep = false;
	if (DownwardSweepResult != NULL && DownwardSweepResult->IsValidBlockingHit())
	{
		// Only if the supplied sweep was vertical and downward.
		if ((DownwardSweepResult->TraceStart.Z > DownwardSweepResult->TraceEnd.Z) &&
			(DownwardSweepResult->TraceStart - DownwardSweepResult->TraceEnd).SizeSquared2D() <= KINDA_SMALL_NUMBER)
		{
			// Reject hits that are barely on the cusp of the radius of the capsule
			if (IsWithinEdgeTolerance(DownwardSweepResult->Location, DownwardSweepResult->ImpactPoint, PawnRadius))
			{
				// Don't try a redundant sweep, regardless of whether this sweep is usable.
				bSkipSweep = true;

				const bool bIsWalkable = IsWalkable(*DownwardSweepResult, Comp->GetWalkableFloorZ());
				const float FloorDist = (CapsuleLocation.Z - DownwardSweepResult->Location.Z);
				OutFloorResult.SetFromSweep(*DownwardSweepResult, FloorDist, bIsWalkable);

				if (bIsWalkable)
				{
					// Use the supplied downward sweep as the floor hit result.			
					return;
				}
			}
		}
	}

	// We require the sweep distance to be >= the line distance, otherwise the HitResult can't be interpreted as the sweep result.
	if (SweepDistance < LineDistance)
	{
		ensure(SweepDistance >= LineDistance);
		return;
	}

	bool bBlockingHit = false;
	FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(ComputeFloorDist), false, Comp->CharacterOwner);
	FCollisionResponseParams ResponseParam;
	InitCollisionParams(Comp, QueryParams, ResponseParam);
	const ECollisionChannel CollisionChannel = Comp->UpdatedComponent->GetCollisionObjectType();

	// Sweep test
	if (!bSkipSweep && SweepDistance > 0.f && SweepRadius > 0.f)
	{
		// Use a shorter height to avoid sweeps giving weird results if we start on a surface.
		// This also allows us to adjust out of penetrations.
		const float ShrinkScale = 0.9f;
		const float ShrinkScaleOverlap = 0.1f;
		float ShrinkHeight = (PawnHalfHeight - PawnRadius) * (1.f - ShrinkScale);
		float TraceDist = SweepDistance + ShrinkHeight;
		FCollisionShape CapsuleShape = FCollisionShape::MakeCapsule(SweepRadius, PawnHalfHeight - ShrinkHeight);

		FHitResult Hit(1.f);
		bBlockingHit = FloorSweepTest(Comp, Hit, CapsuleLocation, CapsuleLocation + FVector(0.f, 0.f, -TraceDist), CollisionChannel, CapsuleShape, QueryParams, ResponseParam);

		if (bBlockingHit)
		{
			// Reject hits adjacent to us, we only care about hits on the bottom portion of our capsule.
			// Check 2D distance to impact point, reject if within a tolerance from radius.
			if (Hit.bStartPenetrating || !IsWithinEdgeTolerance(CapsuleLocation, Hit.ImpactPoint, CapsuleShape.Capsule.Radius))
			{
				// Use a capsule with a slightly smaller radius and shorter height to avoid the adjacent object.
				// Capsule must not be nearly zero or the trace will fall back to a line trace from the start point and have the wrong length.
				CapsuleShape.Capsule.Radius = FMath::Max(0.f, CapsuleShape.Capsule.Radius - UCharacterMovementComponent::SWEEP_EDGE_REJECT_DISTANCE - KINDA_SMALL_NUMBER);
				if (!CapsuleShape.IsNearlyZero())
				{
					ShrinkHeight = (PawnHalfHeight - PawnRadius) * (1.f - ShrinkScaleOverlap);
					TraceDist = SweepDistance + ShrinkHeight;
					CapsuleShape.Capsule.HalfHeight = FMath::Max(PawnHalfHeight - ShrinkHeight, CapsuleShape.Capsule.Radius);
					Hit.Reset(1.f, false);

					bBlockingHit = FloorSweepTest(Comp, Hit, CapsuleLocation, CapsuleLocation + FVector(0.f, 0.f, -TraceDist), CollisionChannel, CapsuleShape, QueryParams, ResponseParam);
				}
			}

			// Reduce hit distance by ShrinkHeight because we shrank the capsule for the trace.
			// We allow negative distances here, because this allows us to pull out of penetrations.
			const float MaxPenetrationAdjust = FMath::Max(UCharacterMovementComponent::MAX_FLOOR_DIST, PawnRadius);
			const float SweepResult = FMath::Max(-MaxPenetrationAdjust, Hit.Time * TraceDist - ShrinkHeight);

			OutFloorResult.SetFromSweep(Hit, SweepResult, false);
			if (Hit.IsValidBlockingHit() && IsWalkable(Hit, Comp->GetWalkableFloorZ()))
			{
				if (SweepResult <= SweepDistance)
				{
					// Hit within test distance.
					OutFloorResult.bWalkableFloor = true;
					return;
				}
			}
		}
	}

	// Since we require a longer sweep than line trace, we don't want to run the line trace if the sweep missed everything.
	// We do however want to try a line trace if the sweep was stuck in penetration.
	if (!OutFloorResult.bBlockingHit && !OutFloorResult.HitResult.bStartPenetrating)
	{
		OutFloorResult.FloorDist = SweepDistance;
		return;
	}

	// Line trace
	if (LineDistance > 0.f)
	{
		const float ShrinkHeight = PawnHalfHeight;
		const FVector LineTraceStart = CapsuleLocation;
		const float TraceDist = LineDistance + ShrinkHeight;
		const FVector Down = FVector(0.f, 0.f, -TraceDist);
		QueryParams.TraceTag = SCENE_QUERY_STAT_NAME_ONLY(FloorLineTrace);

		FHitResult Hit(1.f);
		bBlockingHit = GetWorld()->LineTraceSingleByChannel(Hit, LineTraceStart, LineTraceStart + Down, CollisionChannel, QueryParams, ResponseParam);

		if (bBlockingHit)
		{
			if (Hit.Time > 0.f)
			{
				// Reduce hit distance by ShrinkHeight because we started the trace higher than the base.
				// We allow negative distances here, because this allows us to pull out of penetrations.
				const float MaxPenetrationAdjust = FMath::Max(UCharacterMovementComponent::MAX_FLOOR_DIST, PawnRadius);
				const float LineResult = FMath::Max(-MaxPenetrationAdjust, Hit.Time * TraceDist - ShrinkHeight);

				OutFloorResult.bBlockingHit = true;
				if (LineResult <= LineDistance && IsWalkable(Hit, Comp->GetWalkableFloorZ()))
				{
					OutFloorResult.SetFromLineTrace(Hit, OutFloorResult.FloorDist, LineResult, true);
					return;
				}
			}
		}
	}

	// No hits were acceptable.
	OutFloorResult.bWalkableFloor = false;
	OutFloorResult.FloorDist = SweepDistance;
}

bool FloorSweepTest(
	FISPCMovementContext Ctx,
	FHitResult& OutHit,
	const FVector& Start,
	const FVector& End,
	ECollisionChannel TraceChannel,
	const struct FCollisionShape& CollisionShape,
	const struct FCollisionQueryParams& Params,
	const struct FCollisionResponseParams& ResponseParam
	) const
{
	bool bBlockingHit = false;

	if (!Comp->bUseFlatBaseForFloorChecks)
	{
		bBlockingHit = GetWorld()->SweepSingleByChannel(OutHit, Start, End, FQuat::Identity, TraceChannel, CollisionShape, Params, ResponseParam);
	}
	else
	{
		// Test with a box that is enclosed by the capsule.
		const float CapsuleRadius = CollisionShape.GetCapsuleRadius();
		const float CapsuleHeight = CollisionShape.GetCapsuleHalfHeight();
		const FCollisionShape BoxShape = FCollisionShape::MakeBox(FVector(CapsuleRadius * 0.707f, CapsuleRadius * 0.707f, CapsuleHeight));

		// First test with the box rotated so the corners are along the major axes (ie rotated 45 degrees).
		bBlockingHit = GetWorld()->SweepSingleByChannel(OutHit, Start, End, FQuat(FVector(0.f, 0.f, -1.f), PI * 0.25f), TraceChannel, BoxShape, Params, ResponseParam);

		if (!bBlockingHit)
		{
			// Test again with the same box, not rotated.
			OutHit.Reset(1.f, false);
			bBlockingHit = GetWorld()->SweepSingleByChannel(OutHit, Start, End, FQuat::Identity, TraceChannel, BoxShape, Params, ResponseParam);
		}
	}

	return bBlockingHit;
}

void RevertMove(FISPCMovementContext Ctx, const FVector& OldLocation, UPrimitiveComponent* OldBase, const FVector& PreviousBaseLocation, const FFindFloorResult& OldFloor, bool bFailMove)
{
	//UE_LOG(LogUnrolledCharacterMovement, Log, TEXT("RevertMove from %f %f %f to %f %f %f"), CharacterOwner->Location.X, CharacterOwner->Location.Y, CharacterOwner->Location.Z, OldLocation.X, OldLocation.Y, OldLocation.Z);
	// TODO ISPC: foreach_active?
	Comp->UpdatedComponent->SetWorldLocation(OldLocation, false);

	//UE_LOG(LogUnrolledCharacterMovement, Log, TEXT("Now at %f %f %f"), CharacterOwner->Location.X, CharacterOwner->Location.Y, CharacterOwner->Location.Z);
	Comp->bJustTeleported = false;
	// if our previous base couldn't have moved or changed in any physics-affecting way, restore it
	if (IsValid(OldBase) &&
		(!MovementBaseUtility::IsDynamicBase(OldBase) ||
		(OldBase->Mobility == EComponentMobility::Static) ||
			(OldBase->GetComponentLocation() == PreviousBaseLocation)
			)
		)
	{
		Comp->CurrentFloor = OldFloor;
		SetBase(Comp, OldBase, OldFloor.HitResult.BoneName);
	}
	else
	{
		SetBase(Comp, NULL);
	}

	if (bFailMove)
	{
		// end movement now
		Comp->Velocity = FVector_ZeroVector;
		Comp->Acceleration = FVector_ZeroVector;
		//UE_LOG(LogUnrolledCharacterMovement, Log, TEXT("%s FAILMOVE RevertMove"), *CharacterOwner->GetName());
	}
}

FVector ComputeGroundMovementDelta(FISPCMovementContext Ctx, const FVector& Delta, const FHitResult& RampHit, const bool bHitFromLineTrace) const
{
	const FVector FloorNormal = RampHit.ImpactNormal;
	const FVector ContactNormal = RampHit.Normal;

	if (FloorNormal.Z < (1.f - KINDA_SMALL_NUMBER) && FloorNormal.Z > KINDA_SMALL_NUMBER && ContactNormal.Z > KINDA_SMALL_NUMBER && !bHitFromLineTrace && IsWalkable(RampHit, Comp->GetWalkableFloorZ()))
	{
		// Compute a vector that moves parallel to the surface, by projecting the horizontal movement direction onto the ramp.
		const float FloorDotDelta = (FloorNormal | Delta);
		FVector RampMovement(Delta.X, Delta.Y, -FloorDotDelta / FloorNormal.Z);
		
		if (Comp->bMaintainHorizontalGroundVelocity)
		{
			return RampMovement;
		}
		else
		{
			return RampMovement.GetSafeNormal() * Delta.Size();
		}
	}

	return Delta;
}

void OnCharacterStuckInGeometry(FISPCMovementContext Ctx, const FHitResult* Hit)
{
	const int32 StuckWarningPeriod = CVars::CharacterStuckWarningPeriod->GetInt();
	if (StuckWarningPeriod >= 0)
	{
		UWorld* MyWorld = GetWorld();
		const float RealTimeSeconds = MyWorld->GetRealTimeSeconds();
		if ((RealTimeSeconds - Comp->LastStuckWarningTime) >= StuckWarningPeriod)
		{
			Comp->LastStuckWarningTime = RealTimeSeconds;
			if (Hit == nullptr)
			{
				UE_LOG(LogUnrolledCharacterMovement, Log, TEXT("%s is stuck and failed to move! (%d other events since notify)"), *Comp->CharacterOwner->GetName(), Comp->StuckWarningCountSinceNotify);
			}
			else
			{
				UE_LOG(LogUnrolledCharacterMovement, Log, TEXT("%s is stuck and failed to move! Velocity: X=%3.2f Y=%3.2f Z=%3.2f Location: X=%3.2f Y=%3.2f Z=%3.2f Normal: X=%3.2f Y=%3.2f Z=%3.2f PenetrationDepth:%.3f Actor:%s Component:%s BoneName:%s (%d other events since notify)"),
					   *GetNameSafe(Comp->CharacterOwner),
					   Comp->Velocity.X, Comp->Velocity.Y, Comp->Velocity.Z,
					   Hit->Location.X, Hit->Location.Y, Hit->Location.Z,
					   Hit->Normal.X, Hit->Normal.Y, Hit->Normal.Z,
					   Hit->PenetrationDepth,
					   *GetNameSafe(Hit->GetActor()),
					   *GetNameSafe(Hit->GetComponent()),
					   Hit->BoneName.IsValid() ? *Hit->BoneName.ToString() : TEXT("None"),
					   Comp->StuckWarningCountSinceNotify
					   );
			}
			Comp->StuckWarningCountSinceNotify = 0;
		}
		else
		{
			Comp->StuckWarningCountSinceNotify += 1;
		}
	}

	// Don't update velocity based on our (failed) change in position this update since we're stuck.
	Comp->bJustTeleported = true;
}

void MoveAlongFloor(FISPCMovementContext Ctx, const FVector& InVelocity, float DeltaSeconds, UCharacterMovementComponent::FStepDownResult* OutStepDownResult)
{
	if (!Comp->CurrentFloor.IsWalkableFloor())
	{
		return;
	}

	// Move along the current floor
	const FVector Delta = FVector(InVelocity.X, InVelocity.Y, 0.f) * DeltaSeconds;
	FHitResult Hit(1.f);
	FVector RampVector = ComputeGroundMovementDelta(Comp, Delta, Comp->CurrentFloor.HitResult, Comp->CurrentFloor.bLineTrace);
	const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
	SafeMoveUpdatedComponent(Comp, bMoveIgnoreFirstBlockingOverlap, RampVector, Comp->UpdatedComponent->GetComponentQuat(), true, Hit);
	float LastMoveTimeSlice = DeltaSeconds;
	
	if (Hit.bStartPenetrating)
	{
		// Allow this hit to be used as an impact we can deflect off, otherwise we do nothing the rest of the update and appear to hitch.
		HandleImpact(Comp, Hit);
		SlideAlongSurface(Comp, Delta, 1.f, Hit.Normal, Hit, true);

		if (Hit.bStartPenetrating)
		{
			OnCharacterStuckInGeometry(Comp, &Hit);
		}
	}
	else if (Hit.IsValidBlockingHit())
	{
		// We impacted something (most likely another ramp, but possibly a barrier).
		float PercentTimeApplied = Hit.Time;
		if ((Hit.Time > 0.f) && (Hit.Normal.Z > KINDA_SMALL_NUMBER) && IsWalkable(Hit, Comp->GetWalkableFloorZ()))
		{
			// Another walkable ramp.
			const float InitialPercentRemaining = 1.f - PercentTimeApplied;
			RampVector = ComputeGroundMovementDelta(Comp, Delta * InitialPercentRemaining, Hit, false);
			LastMoveTimeSlice = InitialPercentRemaining * LastMoveTimeSlice;
			SafeMoveUpdatedComponent(Comp, bMoveIgnoreFirstBlockingOverlap, RampVector, Comp->UpdatedComponent->GetComponentQuat(), true, Hit);

			const float SecondHitPercent = Hit.Time * InitialPercentRemaining;
			PercentTimeApplied = FMath::Clamp(PercentTimeApplied + SecondHitPercent, 0.f, 1.f);
		}

		if (Hit.IsValidBlockingHit())
		{
			if (CanStepUp(Comp, Hit) || (Comp->CharacterOwner->GetMovementBase() != NULL && Comp->CharacterOwner->GetMovementBase()->GetOwner() == Hit.GetActor()))
			{
				// hit a barrier, try to step up
				const FVector GravDir(0.f, 0.f, -1.f);
				if (!StepUp(Comp, GravDir, Delta * (1.f - PercentTimeApplied), Hit, OutStepDownResult))
				{
					UE_LOG(LogUnrolledCharacterMovement, Verbose, TEXT("- StepUp (ImpactNormal %s, Normal %s"), *Hit.ImpactNormal.ToString(), *Hit.Normal.ToString());
					HandleImpact(Comp, Hit, LastMoveTimeSlice, RampVector);
					SlideAlongSurface(Comp, Delta, 1.f - PercentTimeApplied, Hit.Normal, Hit, true);
				}
				else
				{
					// Don't recalculate velocity based on this height adjustment, if considering vertical adjustments.
					UE_LOG(LogUnrolledCharacterMovement, Verbose, TEXT("+ StepUp (ImpactNormal %s, Normal %s"), *Hit.ImpactNormal.ToString(), *Hit.Normal.ToString());
					Comp->bJustTeleported |= !Comp->bMaintainHorizontalGroundVelocity;
				}
			}
			else if ( Hit.Component.IsValid() && !Hit.Component.Get()->CanCharacterStepUp(Comp->CharacterOwner) )
			{
				HandleImpact(Comp, Hit, LastMoveTimeSlice, RampVector);
				SlideAlongSurface(Comp, Delta, 1.f - PercentTimeApplied, Hit.Normal, Hit, true);
			}
		}
	}
}

void MaintainHorizontalGroundVelocity(FISPCMovementContext Ctx)
{
	if (Comp->Velocity.Z != 0.f)
	{
		if (Comp->bMaintainHorizontalGroundVelocity)
		{
			// Ramp movement already maintained the velocity, so we just want to remove the vertical component.
			Comp->Velocity.Z = 0.f;
		}
		else
		{
			// Rescale velocity to be horizontal but maintain magnitude of last update.
			Comp->Velocity = Comp->Velocity.GetSafeNormal2D() * Comp->Velocity.Size();
		}
	}
}

FVector GetPenetrationAdjustment(FISPCMovementContext Ctx, const FHitResult& Hit) const
{
	if (!Hit.bStartPenetrating)
	{
		return FVector_ZeroVector;
	}

	static auto* CVarPenetrationPullbackDistance = IConsoleManager::Get().FindConsoleVariable(TEXT("p.PenetrationPullbackDistance"))->AsVariableFloat();

	FVector Result;
	const float PullBackDistance = FMath::Abs(CVarPenetrationPullbackDistance->GetValueOnGameThread());
	const float PenetrationDepth = (Hit.PenetrationDepth > 0.f ? Hit.PenetrationDepth : 0.125f);

	Result = Hit.Normal * (PenetrationDepth + PullBackDistance);

	Result = ConstrainDirectionToPlane(Comp, Result);

	if (Comp->CharacterOwner)
	{
		const bool bIsProxy = (Comp->CharacterOwner->Role == ROLE_SimulatedProxy);
		float MaxDistance = bIsProxy ? Comp->MaxDepenetrationWithGeometryAsProxy : Comp->MaxDepenetrationWithGeometry;
		const AActor* HitActor = Hit.GetActor();
		if (Cast<APawn>(HitActor))
		{
			MaxDistance = bIsProxy ? Comp->MaxDepenetrationWithPawnAsProxy : Comp->MaxDepenetrationWithPawn;
		}

		Result = Result.GetClampedToMaxSize(MaxDistance);
	}

	return Result;
}

bool ShouldComputePerchResult(FISPCMovementContext Ctx, const FHitResult& InHit, bool bCheckRadius) const
{
	if (!InHit.IsValidBlockingHit())
	{
		return false;
	}

	// Don't try to perch if the edge radius is very small.
	if (GetPerchRadiusThreshold(Comp) <= UCharacterMovementComponent::SWEEP_EDGE_REJECT_DISTANCE)
	{
		return false;
	}

	if (bCheckRadius)
	{
		const float DistFromCenterSq = (InHit.ImpactPoint - InHit.Location).SizeSquared2D();
		const float StandOnEdgeRadius = GetValidPerchRadius(Comp);
		if (DistFromCenterSq <= FMath::Square(StandOnEdgeRadius))
		{
			// Already within perch radius.
			return false;
		}
	}
	
	return true;
}

bool ComputePerchResult(FISPCMovementContext Ctx, const float TestRadius, const FHitResult& InHit, const float InMaxFloorDist, FFindFloorResult& OutPerchFloorResult) const
{
	if (InMaxFloorDist <= 0.f)
	{
		return 0.f;
	}

	// Sweep further than actual requested distance, because a reduced capsule radius means we could miss some hits that the normal radius would contact.
	float PawnRadius, PawnHalfHeight;
	Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

	const float InHitAboveBase = FMath::Max(0.f, InHit.ImpactPoint.Z - (InHit.Location.Z - PawnHalfHeight));
	const float PerchLineDist = FMath::Max(0.f, InMaxFloorDist - InHitAboveBase);
	const float PerchSweepDist = FMath::Max(0.f, InMaxFloorDist);

	const float ActualSweepDist = PerchSweepDist + PawnRadius;
	ComputeFloorDist(Comp, InHit.Location, PerchLineDist, ActualSweepDist, OutPerchFloorResult, TestRadius);

	if (!OutPerchFloorResult.IsWalkableFloor())
	{
		return false;
	}
	else if (InHitAboveBase + OutPerchFloorResult.FloorDist > InMaxFloorDist)
	{
		// Hit something past max distance
		OutPerchFloorResult.bWalkableFloor = false;
		return false;
	}

	return true;
}

bool CanStepUp(FISPCMovementContext Ctx, const FHitResult& Hit) const
{
	if (!Hit.IsValidBlockingHit() || !HasValidData(Comp) || Comp->MovementMode == MOVE_Falling)
	{
		return false;
	}

	// No component for "fake" hits when we are on a known good base.
	const UPrimitiveComponent* HitComponent = Hit.Component.Get();
	if (!HitComponent)
	{
		return true;
	}

	if (!HitComponent->CanCharacterStepUp(Comp->CharacterOwner))
	{
		return false;
	}

	// No actor for "fake" hits when we are on a known good base.
	const AActor* HitActor = Hit.GetActor();
	if (!HitActor)
	{
		 return true;
	}

	if (!HitActor->CanBeBaseForCharacter(Comp->CharacterOwner))
	{
		return false;
	}

	return true;
}


bool StepUp(FISPCMovementContext Ctx, const FVector& GravDir, const FVector& Delta, const FHitResult &InHit, UCharacterMovementComponent::FStepDownResult* OutStepDownResult)
{
	SCOPE_CYCLE_COUNTER(STAT_CharStepUp);

	if (!CanStepUp(Comp, InHit) || Comp->MaxStepHeight <= 0.f)
	{
		return false;
	}

	const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
	float PawnRadius, PawnHalfHeight;
	Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

	// Don't bother stepping up if top of capsule is hitting something.
	const float InitialImpactZ = InHit.ImpactPoint.Z;
	if (InitialImpactZ > OldLocation.Z + (PawnHalfHeight - PawnRadius))
	{
		return false;
	}

	if (GravDir.IsZero())
	{
		return false;
	}

	// Gravity should be a normalized direction
	ensure(GravDir.IsNormalized());

	float StepTravelUpHeight = Comp->MaxStepHeight;
	float StepTravelDownHeight = StepTravelUpHeight;
	const float StepSideZ = -1.f * FVector::DotProduct(InHit.ImpactNormal, GravDir);
	float PawnInitialFloorBaseZ = OldLocation.Z - PawnHalfHeight;
	float PawnFloorPointZ = PawnInitialFloorBaseZ;

	if (IsMovingOnGround(Comp) && Comp->CurrentFloor.IsWalkableFloor())
	{
		// Since we float a variable amount off the floor, we need to enforce max step height off the actual point of impact with the floor.
		const float FloorDist = FMath::Max(0.f, Comp->CurrentFloor.GetDistanceToFloor());
		PawnInitialFloorBaseZ -= FloorDist;
		StepTravelUpHeight = FMath::Max(StepTravelUpHeight - FloorDist, 0.f);
		StepTravelDownHeight = (Comp->MaxStepHeight + UCharacterMovementComponent::MAX_FLOOR_DIST*2.f);

		const bool bHitVerticalFace = !IsWithinEdgeTolerance(InHit.Location, InHit.ImpactPoint, PawnRadius);
		if (!Comp->CurrentFloor.bLineTrace && !bHitVerticalFace)
		{
			PawnFloorPointZ = Comp->CurrentFloor.HitResult.ImpactPoint.Z;
		}
		else
		{
			// Base floor point is the base of the capsule moved down by how far we are hovering over the surface we are hitting.
			PawnFloorPointZ -= Comp->CurrentFloor.FloorDist;
		}
	}

	// Don't step up if the impact is below us, accounting for distance from floor.
	if (InitialImpactZ <= PawnInitialFloorBaseZ)
	{
		return false;
	}

	// Scope our movement updates, and do not apply them until all intermediate moves are completed.
	// TODO ISPC
	FScopedMovementUpdate ScopedStepUpMovement(Comp->UpdatedComponent, EScopedUpdate::DeferredUpdates);

	// step up - treat as vertical wall
	FHitResult SweepUpHit(1.f);
	const FQuat PawnRotation = Comp->UpdatedComponent->GetComponentQuat();
	MoveUpdatedComponent(Comp, -GravDir * StepTravelUpHeight, PawnRotation, true, &SweepUpHit);

	if (SweepUpHit.bStartPenetrating)
	{
		// Undo movement
		ScopedStepUpMovement.RevertMove();
		return false;
	}

	// step fwd
	FHitResult Hit(1.f);
	MoveUpdatedComponent( Comp, Delta, PawnRotation, true, &Hit);

	// Check result of forward movement
	if (Hit.bBlockingHit)
	{
		if (Hit.bStartPenetrating)
		{
			// Undo movement
			ScopedStepUpMovement.RevertMove();
			return false;
		}

		// If we hit something above us and also something ahead of us, we should notify about the upward hit as well.
		// The forward hit will be handled later (in the bSteppedOver case below).
		// In the case of hitting something above but not forward, we are not blocked from moving so we don't need the notification.
		if (SweepUpHit.bBlockingHit && Hit.bBlockingHit)
		{
			HandleImpact(Comp, SweepUpHit);
		}

		// pawn ran into a wall
		HandleImpact(Comp, Hit);
		if (IsFalling(Comp))
		{
			return true;
		}

		// adjust and try again
		const float ForwardHitTime = Hit.Time;
		const float ForwardSlideAmount = SlideAlongSurface(Comp, Delta, 1.f - Hit.Time, Hit.Normal, Hit, true);
		
		if (IsFalling(Comp))
		{
			ScopedStepUpMovement.RevertMove();
			return false;
		}

		// If both the forward hit and the deflection got us nowhere, there is no point in this step up.
		if (ForwardHitTime == 0.f && ForwardSlideAmount == 0.f)
		{
			ScopedStepUpMovement.RevertMove();
			return false;
		}
	}
	
	// Step down
	MoveUpdatedComponent(Comp, GravDir * StepTravelDownHeight, Comp->UpdatedComponent->GetComponentQuat(), true, &Hit);

	// If step down was initially penetrating abort the step up
	if (Hit.bStartPenetrating)
	{
		ScopedStepUpMovement.RevertMove();
		return false;
	}

	UCharacterMovementComponent::FStepDownResult StepDownResult;
	if (Hit.IsValidBlockingHit())
	{	
		// See if this step sequence would have allowed us to travel higher than our max step height allows.
		const float DeltaZ = Hit.ImpactPoint.Z - PawnFloorPointZ;
		if (DeltaZ > Comp->MaxStepHeight)
		{
			//UE_LOG(LogCharacterMovement, VeryVerbose, TEXT("- Reject StepUp (too high Height %.3f) up from floor base %f to %f"), DeltaZ, PawnInitialFloorBaseZ, NewLocation.Z);
			ScopedStepUpMovement.RevertMove();
			return false;
		}

		// Reject unwalkable surface normals here.
		if (!IsWalkable(Hit, Comp->GetWalkableFloorZ()))
		{
			// Reject if normal opposes movement direction
			const bool bNormalTowardsMe = (Delta | Hit.ImpactNormal) < 0.f;
			if (bNormalTowardsMe)
			{
				//UE_LOG(LogCharacterMovement, VeryVerbose, TEXT("- Reject StepUp (unwalkable normal %s opposed to movement)"), *Hit.ImpactNormal.ToString());
				ScopedStepUpMovement.RevertMove();
				return false;
			}

			// Also reject if we would end up being higher than our starting location by stepping down.
			// It's fine to step down onto an unwalkable normal below us, we will just slide off. Rejecting those moves would prevent us from being able to walk off the edge.
			if (Hit.Location.Z > OldLocation.Z)
			{
				//UE_LOG(LogCharacterMovement, VeryVerbose, TEXT("- Reject StepUp (unwalkable normal %s above old position)"), *Hit.ImpactNormal.ToString());
				ScopedStepUpMovement.RevertMove();
				return false;
			}
		}

		// Reject moves where the downward sweep hit something very close to the edge of the capsule. This maintains consistency with FindFloor as well.
		if (!IsWithinEdgeTolerance(Hit.Location, Hit.ImpactPoint, PawnRadius))
		{
			//UE_LOG(LogCharacterMovement, VeryVerbose, TEXT("- Reject StepUp (outside edge tolerance)"));
			ScopedStepUpMovement.RevertMove();
			return false;
		}

		// Don't step up onto invalid surfaces if traveling higher.
		if (DeltaZ > 0.f && !CanStepUp(Comp, Hit))
		{
			//UE_LOG(LogCharacterMovement, VeryVerbose, TEXT("- Reject StepUp (up onto surface with !CanStepUp())"));
			ScopedStepUpMovement.RevertMove();
			return false;
		}

		// See if we can validate the floor as a result of this step down. In almost all cases this should succeed, and we can avoid computing the floor outside this method.
		if (OutStepDownResult != NULL)
		{
			FindFloor(Comp, GetUpdatedComponentLocation(Ctx), StepDownResult.FloorResult, false, &Hit);

			// Reject unwalkable normals if we end up higher than our initial height.
			// It's fine to walk down onto an unwalkable surface, don't reject those moves.
			if (Hit.Location.Z > OldLocation.Z)
			{
				// We should reject the floor result if we are trying to step up an actual step where we are not able to perch (this is rare).
				// In those cases we should instead abort the step up and try to slide along the stair.
				if (!StepDownResult.FloorResult.bBlockingHit && StepSideZ < MAX_STEP_SIDE_Z)
				{
					ScopedStepUpMovement.RevertMove();
					return false;
				}
			}

			StepDownResult.bComputedFloor = true;
		}
	}
	
	// Copy step down result.
	if (OutStepDownResult != NULL)
	{
		*OutStepDownResult = StepDownResult;
	}

	// Don't recalculate velocity based on this height adjustment, if considering vertical adjustments.
	Comp->bJustTeleported |= !Comp->bMaintainHorizontalGroundVelocity;

	return true;
}

FVector GetImpartedMovementBaseVelocity(FISPCMovementContext Ctx) const
{
	FVector Result = FVector_ZeroVector;
	if (Comp->CharacterOwner)
	{
		UPrimitiveComponent* MovementBase = Comp->CharacterOwner->GetMovementBase();
		if (MovementBaseUtility::IsDynamicBase(MovementBase))
		{
			FVector BaseVelocity = MovementBaseUtility::GetMovementBaseVelocity(MovementBase, Comp->CharacterOwner->GetBasedMovement().BoneName);
			
			if (Comp->bImpartBaseAngularVelocity)
			{
				const FVector CharacterBasePosition = (GetUpdatedComponentLocation(Ctx) - FVector(0.f, 0.f, Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleHalfHeight()));
				const FVector BaseTangentialVel = MovementBaseUtility::GetMovementBaseTangentialVelocity(MovementBase, Comp->CharacterOwner->GetBasedMovement().BoneName, CharacterBasePosition);
				BaseVelocity += BaseTangentialVel;
			}

			if (Comp->bImpartBaseVelocityX)
			{
				Result.X = BaseVelocity.X;
			}
			if (Comp->bImpartBaseVelocityY)
			{
				Result.Y = BaseVelocity.Y;
			}
			if (Comp->bImpartBaseVelocityZ)
			{
				Result.Z = BaseVelocity.Z;
			}
		}
	}
	
	return Result;
}

bool HandlePendingLaunch(FISPCMovementContext Ctx)
{
	if (!Comp->PendingLaunchVelocity.IsZero() && HasValidData(Comp))
	{
		Comp->Velocity = Comp->PendingLaunchVelocity;
		SetMovementMode(Comp, MOVE_Falling);
		Comp->PendingLaunchVelocity = FVector_ZeroVector;
		return true;
	}

	return false;
}

void AdjustFloorHeight(FISPCMovementContext Ctx)
{
	SCOPE_CYCLE_COUNTER(STAT_CharAdjustFloorHeight);

	// If we have a floor check that hasn't hit anything, don't adjust height.
	if (!Comp->CurrentFloor.IsWalkableFloor())
	{
		return;
	}

	float OldFloorDist = Comp->CurrentFloor.FloorDist;
	if (Comp->CurrentFloor.bLineTrace)
	{
		if (OldFloorDist < UCharacterMovementComponent::MIN_FLOOR_DIST && Comp->CurrentFloor.LineDist >= UCharacterMovementComponent::MIN_FLOOR_DIST)
		{
			// This would cause us to scale unwalkable walls
			UE_LOG(LogUnrolledCharacterMovement, VeryVerbose, TEXT("Adjust floor height aborting due to line trace with small floor distance (line: %.2f, sweep: %.2f)"), Comp->CurrentFloor.LineDist, Comp->CurrentFloor.FloorDist);
			return;
		}
		else
		{
			// Falling back to a line trace means the sweep was unwalkable (or in penetration). Use the line distance for the vertical adjustment.
			OldFloorDist = Comp->CurrentFloor.LineDist;
		}
	}

	// Move up or down to maintain floor height.
	if (OldFloorDist < UCharacterMovementComponent::MIN_FLOOR_DIST || OldFloorDist > UCharacterMovementComponent::MAX_FLOOR_DIST)
	{
		FHitResult AdjustHit(1.f);
		const float InitialZ = GetUpdatedComponentLocation(Ctx).Z;
		const float AvgFloorDist = (UCharacterMovementComponent::MIN_FLOOR_DIST + UCharacterMovementComponent::MAX_FLOOR_DIST) * 0.5f;
		const float MoveDist = AvgFloorDist - OldFloorDist;
		
		const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
		SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, FVector(0.f,0.f,MoveDist), Comp->UpdatedComponent->GetComponentQuat(), true, AdjustHit );
		UE_LOG(LogUnrolledCharacterMovement, VeryVerbose, TEXT("Adjust floor height %.3f (Hit = %d)"), MoveDist, AdjustHit.bBlockingHit);

		if (!AdjustHit.IsValidBlockingHit())
		{
			Comp->CurrentFloor.FloorDist += MoveDist;
		}
		else if (MoveDist > 0.f)
		{
			const float CurrentZ = GetUpdatedComponentLocation(Ctx).Z;
			Comp->CurrentFloor.FloorDist += CurrentZ - InitialZ;
		}
		else
		{
			checkSlow(MoveDist < 0.f);
			const float CurrentZ = GetUpdatedComponentLocation(Ctx).Z;
			Comp->CurrentFloor.FloorDist = CurrentZ - AdjustHit.Location.Z;
			if (IsWalkable(AdjustHit, Comp->GetWalkableFloorZ()))
			{
				Comp->CurrentFloor.SetFromSweep(AdjustHit, Comp->CurrentFloor.FloorDist, true);
			}
		}

		// Don't recalculate velocity based on this height adjustment, if considering vertical adjustments.
		// Also avoid it if we moved out of penetration
		Comp->bJustTeleported |= !Comp->bMaintainHorizontalGroundVelocity || (OldFloorDist < 0.f);
		
		// If something caused us to adjust our height (especially a depentration) we should ensure another check next frame or we will keep a stale result.
		Comp->bForceNextFloorCheck = true;
	}
}

UPrimitiveComponent* GetMovementBase(FISPCMovementContext Ctx) const
{
	return Comp->CharacterOwner ? Comp->CharacterOwner->GetMovementBase() : nullptr;
}

void SetBase( FISPCMovementContext Ctx, UPrimitiveComponent* NewBase, FName BoneName, bool bNotifyActor )
{
	// prevent from changing Base while server is NavWalking (no Base in that mode), so both sides are in sync
	// otherwise it will cause problems with position smoothing

	if (Comp->CharacterOwner && !Comp->bIsNavWalkingOnServer)
	{
		Comp->CharacterOwner->SetBase(NewBase, NewBase ? BoneName : NAME_None, bNotifyActor);
	}
}

void SetBaseFromFloor(FISPCMovementContext Ctx, const FFindFloorResult& FloorResult)
{
	if (FloorResult.IsWalkableFloor())
	{
		SetBase(Comp, FloorResult.HitResult.GetComponent(), FloorResult.HitResult.BoneName);
	}
	else
	{
		SetBase(Comp, nullptr);
	}
}

void MaybeSaveBaseLocation(FISPCMovementContext Ctx)
{
	if (!Comp->bDeferUpdateBasedMovement)
	{
		SaveBaseLocation(Comp);
	}
	else { unimplemented(); }	// TODO ISPC
}

void SaveBaseLocation(FISPCMovementContext Ctx)
{
	if (!HasValidData(Comp))
	{
		return;
	}

	const UPrimitiveComponent* MovementBase = Comp->CharacterOwner->GetMovementBase();
	if (MovementBaseUtility::UseRelativeLocation(MovementBase) && !Comp->CharacterOwner->IsMatineeControlled())
	{
		// Read transforms into OldBaseLocation, OldBaseQuat
		MovementBaseUtility::GetMovementBaseTransform(MovementBase, Comp->CharacterOwner->GetBasedMovement().BoneName, Comp->OldBaseLocation, Comp->OldBaseQuat);

		// Location
		const FVector RelativeLocation = GetUpdatedComponentLocation(Ctx) - Comp->OldBaseLocation;

		// Rotation
		// TODO ISPC: foreach_active
		if (Comp->bIgnoreBaseRotation)
		{
			// Absolute rotation
			Comp->CharacterOwner->SaveRelativeBasedMovement(RelativeLocation, Comp->UpdatedComponent->GetComponentRotation(), false);
		}
		else
		{
			// Relative rotation
			const FRotator RelativeRotation = (FQuatRotationMatrix(Comp->UpdatedComponent->GetComponentQuat()) * FQuatRotationMatrix(Comp->OldBaseQuat).GetTransposed()).Rotator();
			Comp->CharacterOwner->SaveRelativeBasedMovement(RelativeLocation, RelativeRotation, true);
		}
	}
}

bool CanCrouchInCurrentState(FISPCMovementContext Ctx) const
{
	if (!Comp->NavAgentProps.bCanCrouch)	// ISPC: Inlined call to UNavMovementComponent::CanEverCrouch().
	{
		return false;
	}

	return IsFalling(Comp) || IsMovingOnGround(Comp);
}


void Crouch(FISPCMovementContext Ctx, bool bClientSimulation)
{
	if (!HasValidData(Comp))
	{
		return;
	}

	if (!bClientSimulation && !CanCrouchInCurrentState(Comp))
	{
		return;
	}

	// See if collision is already at desired size.
	if (Comp->CharacterOwner->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight() == Comp->CrouchedHalfHeight)
	{
		if (!bClientSimulation)
		{
			Comp->CharacterOwner->bIsCrouched = true;
		}
		// TODO ISPC: foreach_active
		Comp->CharacterOwner->OnStartCrouch( 0.f, 0.f );
		return;
	}

	if (bClientSimulation && Comp->CharacterOwner->Role == ROLE_SimulatedProxy)
	{
		// restore collision size before crouching
		// TODO ISPC: Cache this.
		ACharacter* DefaultCharacter = Comp->CharacterOwner->GetClass()->GetDefaultObject<ACharacter>();
		// TODO ISPC: foreach_active
		Comp->CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleRadius(), DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight());
		Comp->bShrinkProxyCapsule = true;
	}

	// Change collision size to crouching dimensions
	const float ComponentScale = Comp->CharacterOwner->GetCapsuleComponent()->GetShapeScale();
	const float OldUnscaledHalfHeight = Comp->CharacterOwner->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight();
	const float OldUnscaledRadius = Comp->CharacterOwner->GetCapsuleComponent()->GetUnscaledCapsuleRadius();
	// Height is not allowed to be smaller than radius.
	const float ClampedCrouchedHalfHeight = FMath::Max3(0.f, OldUnscaledRadius, Comp->CrouchedHalfHeight);
	Comp->CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(OldUnscaledRadius, ClampedCrouchedHalfHeight);
	float HalfHeightAdjust = (OldUnscaledHalfHeight - ClampedCrouchedHalfHeight);
	float ScaledHalfHeightAdjust = HalfHeightAdjust * ComponentScale;

	if( !bClientSimulation )
	{
		// Crouching to a larger height? (this is rare)
		if (ClampedCrouchedHalfHeight > OldUnscaledHalfHeight)
		{
			FCollisionQueryParams CapsuleParams(SCENE_QUERY_STAT(CrouchTrace), false, Comp->CharacterOwner);
			FCollisionResponseParams ResponseParam;
			InitCollisionParams(Comp, CapsuleParams, ResponseParam);
			const bool bEncroached = GetWorld()->OverlapBlockingTestByChannel(GetUpdatedComponentLocation(Ctx) - FVector(0.f,0.f,ScaledHalfHeightAdjust), FQuat::Identity,
				Comp->UpdatedComponent->GetCollisionObjectType(), Comp->GetPawnCapsuleCollisionShape(UCharacterMovementComponent::EShrinkCapsuleExtent::SHRINK_None), CapsuleParams, ResponseParam);

			// If encroached, cancel
			if( bEncroached )
			{
				Comp->CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(OldUnscaledRadius, OldUnscaledHalfHeight);
				return;
			}
		}

		if (Comp->bCrouchMaintainsBaseLocation)
		{
			// Intentionally not using MoveUpdatedComponent, where a horizontal plane constraint would prevent the base of the capsule from staying at the same spot.
			Comp->UpdatedComponent->MoveComponent(FVector(0.f, 0.f, -ScaledHalfHeightAdjust), Comp->UpdatedComponent->GetComponentQuat(), true, nullptr, EMoveComponentFlags::MOVECOMP_NoFlags, ETeleportType::TeleportPhysics);
		}

		Comp->CharacterOwner->bIsCrouched = true;
	}

	Comp->bForceNextFloorCheck = true;

	// OnStartCrouch takes the change from the Default size, not the current one (though they are usually the same).
	const float MeshAdjust = ScaledHalfHeightAdjust;
	// TODO ISPC: Cache this.
	ACharacter* DefaultCharacter = Comp->CharacterOwner->GetClass()->GetDefaultObject<ACharacter>();
	HalfHeightAdjust = (DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight() - ClampedCrouchedHalfHeight);
	ScaledHalfHeightAdjust = HalfHeightAdjust * ComponentScale;

#if 0	// TODO ISPC
	AdjustProxyCapsuleSize(Comp);
#endif
	// TODO ISPC: foreach_active
	Comp->CharacterOwner->OnStartCrouch( HalfHeightAdjust, ScaledHalfHeightAdjust );

	// Don't smooth this change in mesh position
	if (bClientSimulation && Comp->CharacterOwner->Role == ROLE_SimulatedProxy)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		FNetworkPredictionData_Client_Character* ClientData = GetPredictionData_Client_Character();
		if (ClientData && ClientData->MeshTranslationOffset.Z != 0.f)
		{
			ClientData->MeshTranslationOffset -= FVector(0.f, 0.f, MeshAdjust);
			ClientData->OriginalMeshTranslationOffset = ClientData->MeshTranslationOffset;
		}
#endif
	}
}


void UnCrouch(FISPCMovementContext Ctx, bool bClientSimulation)
{
	if (!HasValidData(Comp))
	{
		return;
	}

	// TODO ISPC: Cache this.
	ACharacter* DefaultCharacter = Comp->CharacterOwner->GetClass()->GetDefaultObject<ACharacter>();

	// See if collision is already at desired size.
	if( Comp->CharacterOwner->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight() == DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight() )
	{
		if (!bClientSimulation)
		{
			Comp->CharacterOwner->bIsCrouched = false;
		}
		Comp->CharacterOwner->OnEndCrouch( 0.f, 0.f );
		return;
	}

	const float CurrentCrouchedHalfHeight = Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleHalfHeight();

	const float ComponentScale = Comp->CharacterOwner->GetCapsuleComponent()->GetShapeScale();
	const float OldUnscaledHalfHeight = Comp->CharacterOwner->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight();
	const float HalfHeightAdjust = DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight() - OldUnscaledHalfHeight;
	const float ScaledHalfHeightAdjust = HalfHeightAdjust * ComponentScale;
	const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);

	// Grow to uncrouched size.
	check(Comp->CharacterOwner->GetCapsuleComponent());

	if( !bClientSimulation )
	{
		// Try to stay in place and see if the larger capsule fits. We use a slightly taller capsule to avoid penetration.
		const float SweepInflation = KINDA_SMALL_NUMBER * 10.f;
		FCollisionQueryParams CapsuleParams(SCENE_QUERY_STAT(CrouchTrace), false, Comp->CharacterOwner);
		FCollisionResponseParams ResponseParam;
		InitCollisionParams(Comp, CapsuleParams, ResponseParam);

		// Compensate for the difference between current capsule size and standing size
		const FCollisionShape StandingCapsuleShape = Comp->GetPawnCapsuleCollisionShape(UCharacterMovementComponent::EShrinkCapsuleExtent::SHRINK_HeightCustom, -SweepInflation - ScaledHalfHeightAdjust); // Shrink by negative amount, so actually grow it.
		const ECollisionChannel CollisionChannel = Comp->UpdatedComponent->GetCollisionObjectType();
		bool bEncroached = true;

		if (!Comp->bCrouchMaintainsBaseLocation)
		{
			// Expand in place
			bEncroached = GetWorld()->OverlapBlockingTestByChannel(PawnLocation, FQuat::Identity, CollisionChannel, StandingCapsuleShape, CapsuleParams, ResponseParam);
		
			if (bEncroached)
			{
				// Try adjusting capsule position to see if we can avoid encroachment.
				if (ScaledHalfHeightAdjust > 0.f)
				{
					// Shrink to a short capsule, sweep down to base to find where that would hit something, and then try to stand up from there.
					float PawnRadius, PawnHalfHeight;
					Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);
					const float ShrinkHalfHeight = PawnHalfHeight - PawnRadius;
					const float TraceDist = PawnHalfHeight - ShrinkHalfHeight;
					const FVector Down = FVector(0.f, 0.f, -TraceDist);

					FHitResult Hit(1.f);
					const FCollisionShape ShortCapsuleShape = Comp->GetPawnCapsuleCollisionShape(UCharacterMovementComponent::EShrinkCapsuleExtent::SHRINK_HeightCustom, ShrinkHalfHeight);
					const bool bBlockingHit = GetWorld()->SweepSingleByChannel(Hit, PawnLocation, PawnLocation + Down, FQuat::Identity, CollisionChannel, ShortCapsuleShape, CapsuleParams);
					if (Hit.bStartPenetrating)
					{
						bEncroached = true;
					}
					else
					{
						// Compute where the base of the sweep ended up, and see if we can stand there
						const float DistanceToBase = (Hit.Time * TraceDist) + ShortCapsuleShape.Capsule.HalfHeight;
						const FVector NewLoc = FVector(PawnLocation.X, PawnLocation.Y, PawnLocation.Z - DistanceToBase + PawnHalfHeight + SweepInflation + UCharacterMovementComponent::MIN_FLOOR_DIST / 2.f);
						bEncroached = GetWorld()->OverlapBlockingTestByChannel(NewLoc, FQuat::Identity, CollisionChannel, StandingCapsuleShape, CapsuleParams, ResponseParam);
						if (!bEncroached)
						{
							// Intentionally not using MoveUpdatedComponent, where a horizontal plane constraint would prevent the base of the capsule from staying at the same spot.
							Comp->UpdatedComponent->MoveComponent(NewLoc - PawnLocation, Comp->UpdatedComponent->GetComponentQuat(), false, nullptr, EMoveComponentFlags::MOVECOMP_NoFlags, ETeleportType::TeleportPhysics);
						}
					}
				}
			}
		}
		else
		{
			// Expand while keeping base location the same.
			FVector StandingLocation = PawnLocation + FVector(0.f, 0.f, StandingCapsuleShape.GetCapsuleHalfHeight() - CurrentCrouchedHalfHeight);
			bEncroached = GetWorld()->OverlapBlockingTestByChannel(StandingLocation, FQuat::Identity, CollisionChannel, StandingCapsuleShape, CapsuleParams, ResponseParam);

			if (bEncroached)
			{
				if (IsMovingOnGround(Comp))
				{
					// Something might be just barely overhead, try moving down closer to the floor to avoid it.
					const float MinFloorDist = KINDA_SMALL_NUMBER * 10.f;
					if (Comp->CurrentFloor.bBlockingHit && Comp->CurrentFloor.FloorDist > MinFloorDist)
					{
						StandingLocation.Z -= Comp->CurrentFloor.FloorDist - MinFloorDist;
						bEncroached = GetWorld()->OverlapBlockingTestByChannel(StandingLocation, FQuat::Identity, CollisionChannel, StandingCapsuleShape, CapsuleParams, ResponseParam);
					}
				}				
			}

			if (!bEncroached)
			{
				// Commit the change in location.
				Comp->UpdatedComponent->MoveComponent(StandingLocation - PawnLocation, Comp->UpdatedComponent->GetComponentQuat(), false, nullptr, EMoveComponentFlags::MOVECOMP_NoFlags, ETeleportType::TeleportPhysics);
				Comp->bForceNextFloorCheck = true;
			}
		}

		// If still encroached then abort.
		if (bEncroached)
		{
			return;
		}

		Comp->CharacterOwner->bIsCrouched = false;
	}	
	else
	{
		Comp->bShrinkProxyCapsule = true;
	}

	// Now call SetCapsuleSize() to cause touch/untouch events and actually grow the capsule
	Comp->CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleRadius(), DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight(), true);

	const float MeshAdjust = ScaledHalfHeightAdjust;
#if 0	// TODO ISPC
	AdjustProxyCapsuleSize(Comp);
#endif
	Comp->CharacterOwner->OnEndCrouch( HalfHeightAdjust, ScaledHalfHeightAdjust );

	// Don't smooth this change in mesh position
	if (bClientSimulation && Comp->CharacterOwner->Role == ROLE_SimulatedProxy)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		FNetworkPredictionData_Client_Character* ClientData = GetPredictionData_Client_Character();
		if (ClientData && ClientData->MeshTranslationOffset.Z != 0.f)
		{
			ClientData->MeshTranslationOffset += FVector(0.f, 0.f, MeshAdjust);
			ClientData->OriginalMeshTranslationOffset = ClientData->MeshTranslationOffset;
		}
#endif
	}
}

// @todo UE4 - handle lift moving up and down through encroachment
void UpdateBasedMovement(FISPCMovementContext Ctx, float DeltaSeconds)
{
	if (!HasValidData(Comp))
	{
		return;
	}

	const UPrimitiveComponent* MovementBase = Comp->CharacterOwner->GetMovementBase();
	if (!MovementBaseUtility::UseRelativeLocation(MovementBase))
	{
		return;
	}

	if (!IsValid(MovementBase) || !IsValid(MovementBase->GetOwner()))
	{
		SetBase(Comp, NULL);
		return;
	}

	// Ignore collision with bases during these movements.
	TGuardValue<EMoveComponentFlags> ScopedFlagRestore(Comp->MoveComponentFlags, Comp->MoveComponentFlags | MOVECOMP_IgnoreBases);

	FQuat DeltaQuat = FQuat::Identity;
	FVector DeltaPosition = FVector_ZeroVector;

	FQuat NewBaseQuat;
	FVector NewBaseLocation;
	if (!MovementBaseUtility::GetMovementBaseTransform(MovementBase, Comp->CharacterOwner->GetBasedMovement().BoneName, NewBaseLocation, NewBaseQuat))
	{
		return;
	}

	// Find change in rotation
	const bool bRotationChanged = !Comp->OldBaseQuat.Equals(NewBaseQuat, 1e-8f);
	if (bRotationChanged)
	{
		DeltaQuat = NewBaseQuat * Comp->OldBaseQuat.Inverse();
	}

	// only if base moved
	if (bRotationChanged || (Comp->OldBaseLocation != NewBaseLocation))
	{
		// Calculate new transform matrix of base actor (ignoring scale).
		const FQuatRotationTranslationMatrix OldLocalToWorld(Comp->OldBaseQuat, Comp->OldBaseLocation);
		const FQuatRotationTranslationMatrix NewLocalToWorld(NewBaseQuat, NewBaseLocation);

		if( Comp->CharacterOwner->IsMatineeControlled() )
		{
			FRotationTranslationMatrix HardRelMatrix(Comp->CharacterOwner->GetBasedMovement().Rotation, Comp->CharacterOwner->GetBasedMovement().Location);
			const FMatrix NewWorldTM = HardRelMatrix * NewLocalToWorld;
			const FQuat NewWorldRot = Comp->bIgnoreBaseRotation ? Comp->UpdatedComponent->GetComponentQuat() : NewWorldTM.ToQuat();
			MoveUpdatedComponent( Comp, NewWorldTM.GetOrigin() - GetUpdatedComponentLocation(Ctx), NewWorldRot, true );
		}
		else
		{
			FQuat FinalQuat = Comp->UpdatedComponent->GetComponentQuat();
			
			if (bRotationChanged && !Comp->bIgnoreBaseRotation)
			{
				// Apply change in rotation and pipe through FaceRotation to maintain axis restrictions
				const FQuat PawnOldQuat = Comp->UpdatedComponent->GetComponentQuat();
				const FQuat TargetQuat = DeltaQuat * FinalQuat;
				FRotator TargetRotator(TargetQuat);
				Comp->CharacterOwner->FaceRotation(TargetRotator, 0.f);
				FinalQuat = Comp->UpdatedComponent->GetComponentQuat();

				if (PawnOldQuat.Equals(FinalQuat, 1e-6f))
				{
					// Nothing changed. This means we probably are using another rotation mechanism (bOrientToMovement etc). We should still follow the base object.
					// @todo: This assumes only Yaw is used, currently a valid assumption. This is the only reason FaceRotation() is used above really, aside from being a virtual hook.
					if (Comp->bOrientRotationToMovement || (Comp->bUseControllerDesiredRotation && Comp->CharacterOwner->Controller))
					{
						TargetRotator.Pitch = 0.f;
						TargetRotator.Roll = 0.f;
						MoveUpdatedComponent(Comp, FVector_ZeroVector, TargetRotator.Quaternion(), false);
						FinalQuat = Comp->UpdatedComponent->GetComponentQuat();
					}
				}

				// Pipe through ControlRotation, to affect camera.
				if (Comp->CharacterOwner->Controller)
				{
					const FQuat PawnDeltaRotation = FinalQuat * PawnOldQuat.Inverse();
					FRotator FinalRotation = FinalQuat.Rotator();
					UpdateBasedRotation(Comp, FinalRotation, PawnDeltaRotation.Rotator());
					FinalQuat = Comp->UpdatedComponent->GetComponentQuat();
				}
			}

			// We need to offset the base of the character here, not its origin, so offset by half height
			float HalfHeight, Radius;
			Comp->CharacterOwner->GetCapsuleComponent()->GetScaledCapsuleSize(Radius, HalfHeight);

			FVector const BaseOffset(0.0f, 0.0f, HalfHeight);
			FVector const LocalBasePos = OldLocalToWorld.InverseTransformPosition(GetUpdatedComponentLocation(Ctx) - BaseOffset);
			FVector const NewWorldPos = ConstrainLocationToPlane(Comp, NewLocalToWorld.TransformPosition(LocalBasePos) + BaseOffset);
			DeltaPosition = ConstrainDirectionToPlane(Comp, NewWorldPos - GetUpdatedComponentLocation(Ctx));

			// move attached actor
			if (Comp->bFastAttachedMove)
			{
				// we're trusting no other obstacle can prevent the move here
				// TODO ISPC: foreach_active
				Comp->UpdatedComponent->SetWorldLocationAndRotation(NewWorldPos, FinalQuat, false);
			}
			else
			{
				// hack - transforms between local and world space introducing slight error FIXMESTEVE - discuss with engine team: just skip the transforms if no rotation?
				FVector BaseMoveDelta = NewBaseLocation - Comp->OldBaseLocation;
				if (!bRotationChanged && (BaseMoveDelta.X == 0.f) && (BaseMoveDelta.Y == 0.f))
				{
					DeltaPosition.X = 0.f;
					DeltaPosition.Y = 0.f;
				}

				FHitResult MoveOnBaseHit(1.f);
				const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
				MoveUpdatedComponent(Comp, DeltaPosition, FinalQuat, true, &MoveOnBaseHit);
				if ((GetUpdatedComponentLocation(Ctx) - (OldLocation + DeltaPosition)).IsNearlyZero() == false)
				{
#if 0	// TODO ISPC: This is empty in all implementations that concern us.
					Comp->OnUnableToFollowBaseMove(DeltaPosition, OldLocation, MoveOnBaseHit);
#endif
				}
			}
		}

		if (MovementBase->IsSimulatingPhysics() && Comp->CharacterOwner_GetMesh)
		{
			// TODO ISPC: foreach_active
			Comp->CharacterOwner_GetMesh->ApplyDeltaToAllPhysicsTransforms(DeltaPosition, DeltaQuat);
		}
	}
}

void UpdateBasedRotation(FISPCMovementContext Ctx, FRotator& FinalRotation, const FRotator& ReducedRotation)
{
	AController* Controller = Comp->CharacterOwner ? Comp->CharacterOwner->Controller : NULL;
	float ControllerRoll = 0.f;
	if (Controller && !Comp->bIgnoreBaseRotation)
	{
		FRotator const ControllerRot = Controller->GetControlRotation();
		ControllerRoll = ControllerRot.Roll;
		Controller->SetControlRotation(ControllerRot + ReducedRotation);
	}

	// Remove roll
	FinalRotation.Roll = 0.f;
	if (Controller)
	{
		FinalRotation.Roll = Comp->UpdatedComponent->GetComponentRotation().Roll;
		FRotator NewRotation = Controller->GetControlRotation();
		NewRotation.Roll = ControllerRoll;
		Controller->SetControlRotation(NewRotation);
	}
}

bool SafeMoveUpdatedComponent(FISPCMovementContext Ctx, const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap, const FVector& Delta, const FQuat& NewRotation, bool bSweep, FHitResult& OutHit, ETeleportType Teleport)
{
	if (Comp->UpdatedComponent == NULL)
	{
		OutHit.Reset(1.f);
		return false;
	}

	bool bMoveResult = false;

	// Scope for move flags
	{
		// Conditionally ignore blocking overlaps (based on CVar)
		const EMoveComponentFlags IncludeBlockingOverlapsWithoutEvents = (MOVECOMP_NeverIgnoreBlockingOverlaps | MOVECOMP_DisableBlockingOverlapDispatch);
		TGuardValue<EMoveComponentFlags> ScopedFlagRestore(Comp->MoveComponentFlags, bMoveIgnoreFirstBlockingOverlap ? Comp->MoveComponentFlags : (Comp->MoveComponentFlags | IncludeBlockingOverlapsWithoutEvents));
		bMoveResult = MoveUpdatedComponent(Comp, Delta, NewRotation, bSweep, &OutHit, Teleport);
	}

	// Handle initial penetrations
	if (OutHit.bStartPenetrating && Comp->UpdatedComponent)
	{
		const FVector RequestedAdjustment = GetPenetrationAdjustment(Comp, OutHit);
		if (ResolvePenetration(Comp, RequestedAdjustment, OutHit, NewRotation))
		{
			// Retry original move
			bMoveResult = MoveUpdatedComponent(Comp, Delta, NewRotation, bSweep, &OutHit, Teleport);
		}
	}

	return bMoveResult;
}

bool ResolvePenetration(FISPCMovementContext Ctx, const FVector& ProposedAdjustment, const FHitResult& Hit, const FQuat& NewRotation)
{
	// If movement occurs, mark that we teleported, so we don't incorrectly adjust velocity based on a potentially very different movement than our movement direction.

	// SceneComponent can't be in penetration, so this function really only applies to PrimitiveComponent.
	const FVector Adjustment = ConstrainDirectionToPlane(Comp, ProposedAdjustment);
	if (!Adjustment.IsZero() && Comp->UpdatedPrimitive)
	{
		// See if we can fit at the adjusted location without overlapping anything.
		AActor* ActorOwner = Comp->UpdatedComponent->GetOwner();
		if (!ActorOwner)
		{
			return Comp->bJustTeleported;
		}

		UE_LOG(LogUnrolledCharacterMovement, Verbose, TEXT("ResolvePenetration: %s.%s at location %s inside %s.%s at location %s by %.3f (netmode: %d)"),
			*ActorOwner->GetName(),
			*Comp->UpdatedComponent->GetName(),
			*GetUpdatedComponentLocation(Ctx).ToString(),
			*GetNameSafe(Hit.GetActor()),
			*GetNameSafe(Hit.GetComponent()),
			Hit.Component.IsValid() ? *Hit.GetComponent()->GetComponentLocation().ToString() : TEXT("<unknown>"),
			Hit.PenetrationDepth,
			(uint32)Comp->GetNetMode());

		static auto* CVarPenetrationOverlapCheckInflation = IConsoleManager::Get().FindConsoleVariable(TEXT("p.PenetrationOverlapCheckInflation"))->AsVariableFloat();
		// We really want to make sure that precision differences or differences between the overlap test and sweep tests don't put us into another overlap,
		// so make the overlap test a bit more restrictive.
		const float OverlapInflation = CVarPenetrationOverlapCheckInflation->GetValueOnGameThread();
		bool bEncroached = OverlapTest(Comp, Hit.TraceStart + Adjustment, NewRotation, Comp->UpdatedPrimitive->GetCollisionObjectType(), Comp->UpdatedPrimitive->GetCollisionShape(OverlapInflation), ActorOwner);
		if (!bEncroached)
		{
			// Move without sweeping.
			MoveUpdatedComponent(Comp, Adjustment, NewRotation, false, nullptr, ETeleportType::TeleportPhysics);
			UE_LOG(LogUnrolledCharacterMovement, Verbose, TEXT("ResolvePenetration:   teleport by %s"), *Adjustment.ToString());
			Comp->bJustTeleported = true;
			return Comp->bJustTeleported;
		}
		else
		{
			// Disable MOVECOMP_NeverIgnoreBlockingOverlaps if it is enabled, otherwise we wouldn't be able to sweep out of the object to fix the penetration.
			TGuardValue<EMoveComponentFlags> ScopedFlagRestore(Comp->MoveComponentFlags, EMoveComponentFlags(Comp->MoveComponentFlags & (~MOVECOMP_NeverIgnoreBlockingOverlaps)));

			// Try sweeping as far as possible...
			FHitResult SweepOutHit(1.f);
			bool bMoved = MoveUpdatedComponent(Comp, Adjustment, NewRotation, true, &SweepOutHit, ETeleportType::TeleportPhysics);
			UE_LOG(LogUnrolledCharacterMovement, Verbose, TEXT("ResolvePenetration:   sweep by %s (success = %d)"), *Adjustment.ToString(), bMoved);

			// Still stuck?
			if (!bMoved && SweepOutHit.bStartPenetrating)
			{
				// Combine two MTD results to get a new direction that gets out of multiple surfaces.
				const FVector SecondMTD = GetPenetrationAdjustment(Comp, SweepOutHit);
				const FVector CombinedMTD = Adjustment + SecondMTD;
				if (SecondMTD != Adjustment && !CombinedMTD.IsZero())
				{
					bMoved = MoveUpdatedComponent(Comp, CombinedMTD, NewRotation, true, nullptr, ETeleportType::TeleportPhysics);
					UE_LOG(LogUnrolledCharacterMovement, Verbose, TEXT("ResolvePenetration:   sweep by %s (MTD combo success = %d)"), *CombinedMTD.ToString(), bMoved);
				}
			}

			// Still stuck?
			if (!bMoved)
			{
				// Try moving the proposed adjustment plus the attempted move direction. This can sometimes get out of penetrations with multiple objects
				const FVector MoveDelta = ConstrainDirectionToPlane(Comp, Hit.TraceEnd - Hit.TraceStart);
				if (!MoveDelta.IsZero())
				{
					bMoved = MoveUpdatedComponent(Comp, Adjustment + MoveDelta, NewRotation, true, nullptr, ETeleportType::TeleportPhysics);
					UE_LOG(LogUnrolledCharacterMovement, Verbose, TEXT("ResolvePenetration:   sweep by %s (adjusted attempt success = %d)"), *(Adjustment + MoveDelta).ToString(), bMoved);
				}
			}

			Comp->bJustTeleported |= bMoved;
			return Comp->bJustTeleported;
		}
	}

	return Comp->bJustTeleported;
}

bool MoveUpdatedComponent(FISPCMovementContext Ctx, const FVector& Delta, const FQuat& NewRotation, bool bSweep, FHitResult* OutHit, ETeleportType Teleport)
{
	if (Comp->UpdatedComponent)
	{
		const FVector NewDelta = ConstrainDirectionToPlane(Comp, Delta);
		// TODO ISPC: foreach_active
		return Comp->UpdatedComponent->MoveComponent(NewDelta, NewRotation, bSweep, OutHit, Comp->MoveComponentFlags, Teleport);
	}

	return false;
}

FVector ConstrainDirectionToPlane(FISPCMovementContext Ctx, FVector Direction) const
{
	if (Comp->bConstrainToPlane)
	{
		Direction = FVector::VectorPlaneProject(Direction, Comp->PlaneConstraintNormal);
	}

	return Direction;
}

FVector ConstrainLocationToPlane(FISPCMovementContext Ctx, FVector Location) const
{
	if (Comp->bConstrainToPlane)
	{
		Location = FVector::PointPlaneProject(Location, Comp->PlaneConstraintOrigin, Comp->PlaneConstraintNormal);
	}

	return Location;
}

FVector ConstrainNormalToPlane(FISPCMovementContext Ctx, FVector Normal) const
{
	if (Comp->bConstrainToPlane)
	{
		Normal = FVector::VectorPlaneProject(Normal, Comp->PlaneConstraintNormal).GetSafeNormal();
	}

	return Normal;
}

void SnapUpdatedComponentToPlane(FISPCMovementContext Ctx)
{
	if (Comp->UpdatedComponent && Comp->bConstrainToPlane)
	{
		Comp->UpdatedComponent->SetWorldLocation( ConstrainLocationToPlane(Comp, GetUpdatedComponentLocation(Ctx)) );
	}
}

bool OverlapTest(FISPCMovementContext Ctx, const FVector& Location, const FQuat& RotationQuat, const ECollisionChannel CollisionChannel, const FCollisionShape& CollisionShape, const AActor* IgnoreActor) const
{
	FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(MovementOverlapTest), false, IgnoreActor);
	FCollisionResponseParams ResponseParam;
	// TODO ISPC: Fold these two calls together?
	InitCollisionParams(Comp, QueryParams, ResponseParam);
	return GetWorld()->OverlapBlockingTestByChannel(Location, RotationQuat, CollisionChannel, CollisionShape, QueryParams, ResponseParam);
}

bool IsExceedingMaxSpeed(FISPCMovementContext Ctx, float MaxSpeed) const
{
	MaxSpeed = FMath::Max(0.f, MaxSpeed);
	const float MaxSpeedSquared = FMath::Square(MaxSpeed);
	
	// Allow 1% error tolerance, to account for numeric imprecision.
	const float OverVelocityPercent = 1.01f;
	return (Comp->Velocity.SizeSquared() > MaxSpeedSquared * OverVelocityPercent);
}

void RestorePreAdditiveRootMotionVelocity(FISPCMovementContext Ctx)
{
	// Restore last frame's pre-additive Velocity if we had additive applied 
	// so that we're not adding more additive velocity than intended
	if( Comp->CurrentRootMotion.bIsAdditiveVelocityApplied )
	{
#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			FString AdjustedDebugString = FString::Printf(TEXT("RestorePreAdditiveRootMotionVelocity Velocity(%s) LastPreAdditiveVelocity(%s)"), 
				*Comp->Velocity.ToCompactString(), *Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
		}
#endif

		Comp->Velocity = Comp->CurrentRootMotion.LastPreAdditiveVelocity;
		Comp->CurrentRootMotion.bIsAdditiveVelocityApplied = false;
	}
}

void ApplyRootMotionToVelocity(FISPCMovementContext Ctx, float deltaTime)
{
#if 1	// TODO_ISPC
	check(!HasRootMotionSources(Comp));
#else
	SCOPE_CYCLE_COUNTER(STAT_CharacterMovementRootMotionSourceApply);

	// Animation root motion is distinct from root motion sources right now and takes precedence
	if( HasAnimRootMotion(Comp) && deltaTime > 0.f )
	{
		Comp->Velocity = ConstrainAnimRootMotionVelocity(Comp, Comp->AnimRootMotionVelocity, Comp->Velocity);
		return;
	}

	const FVector OldVelocity = Comp->Velocity;

	bool bAppliedRootMotion = false;

	// Apply override velocity
	if( Comp->CurrentRootMotion.HasOverrideVelocity() )
	{
		Comp->CurrentRootMotion.AccumulateOverrideRootMotionVelocity(deltaTime, *Comp->CharacterOwner, *Comp, Comp->Velocity);
		bAppliedRootMotion = true;

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			FString AdjustedDebugString = FString::Printf(TEXT("ApplyRootMotionToVelocity HasOverrideVelocity Velocity(%s)"),
				*Comp->Velocity.ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
		}
#endif
	}

	// Next apply additive root motion
	if( Comp->CurrentRootMotion.HasAdditiveVelocity() )
	{
		Comp->CurrentRootMotion.LastPreAdditiveVelocity = Comp->Velocity; // Save off pre-additive Velocity for restoration next tick
		Comp->CurrentRootMotion.AccumulateAdditiveRootMotionVelocity(deltaTime, *Comp->CharacterOwner, *Comp, Comp->Velocity);
		Comp->CurrentRootMotion.bIsAdditiveVelocityApplied = true; // Remember that we have it applied
		bAppliedRootMotion = true;

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			FString AdjustedDebugString = FString::Printf(TEXT("ApplyRootMotionToVelocity HasAdditiveVelocity Velocity(%s) LastPreAdditiveVelocity(%s)"),
				*Comp->Velocity.ToCompactString(), *Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*Comp->CharacterOwner, AdjustedDebugString);
		}
#endif
	}

	// Switch to Falling if we have vertical velocity from root motion so we can lift off the ground
	const FVector AppliedVelocityDelta = Comp->Velocity - OldVelocity;
	if( bAppliedRootMotion && AppliedVelocityDelta.Z != 0.f && IsMovingOnGround(Comp) )
	{
		float LiftoffBound;
		if( Comp->CurrentRootMotion.LastAccumulatedSettings.HasFlag(ERootMotionSourceSettingsFlags::UseSensitiveLiftoffCheck) )
		{
			// Sensitive bounds - "any positive force"
			LiftoffBound = SMALL_NUMBER;
		}
		else
		{
			// Default bounds - the amount of force gravity is applying this tick
			LiftoffBound = FMath::Max(GetGravityZ(Comp) * deltaTime, SMALL_NUMBER);
		}

		if( AppliedVelocityDelta.Z > LiftoffBound )
		{
			SetMovementMode(Comp, MOVE_Falling);
		}
	}
#endif	// TODO_ISPC
}

FVector ConstrainAnimRootMotionVelocity(FISPCMovementContext Ctx, const FVector& RootMotionVelocity, const FVector& CurrentVelocity) const
{
	FVector Result = RootMotionVelocity;

	// Do not override Velocity.Z if in falling physics, we want to keep the effect of gravity.
	if (IsFalling(Comp))
	{
		Result.Z = CurrentVelocity.Z;
	}

	return Result;
}

void ApplyVelocityBraking(FISPCMovementContext Ctx, float DeltaTime, float Friction, float BrakingDeceleration)
{
	if (Comp->Velocity.IsZero() || !HasValidData(Comp) || HasAnimRootMotion(Comp) || DeltaTime < UCharacterMovementComponent::MIN_TICK_TIME)
	{
		return;
	}

	const float FrictionFactor = FMath::Max(0.f, Comp->BrakingFrictionFactor);
	Friction = FMath::Max(0.f, Friction * FrictionFactor);
	BrakingDeceleration = FMath::Max(0.f, BrakingDeceleration);
	const bool bZeroFriction = (Friction == 0.f);
	const bool bZeroBraking = (BrakingDeceleration == 0.f);

	if (bZeroFriction && bZeroBraking)
	{
		return;
	}

	const FVector OldVel = Comp->Velocity;

	// subdivide braking to get reasonably consistent results at lower frame rates
	// (important for packet loss situations w/ networking)
	float RemainingTime = DeltaTime;
	const float MaxTimeStep = (1.0f / 33.0f);

	// Decelerate to brake to a stop
	const FVector RevAccel = (bZeroBraking ? FVector_ZeroVector : (-BrakingDeceleration * Comp->Velocity.GetSafeNormal()));
	while( RemainingTime >= UCharacterMovementComponent::MIN_TICK_TIME )
	{
		// Zero friction uses constant deceleration, so no need for iteration.
		const float dt = ((RemainingTime > MaxTimeStep && !bZeroFriction) ? FMath::Min(MaxTimeStep, RemainingTime * 0.5f) : RemainingTime);
		RemainingTime -= dt;

		// apply friction and braking
		Comp->Velocity = Comp->Velocity + ((-Friction) * Comp->Velocity + RevAccel) * dt ;
		
		// Don't reverse direction
		if ((Comp->Velocity | OldVel) <= 0.f)
		{
			Comp->Velocity = FVector_ZeroVector;
			return;
		}
	}

	// Clamp to zero if nearly zero, or if below min threshold and braking.
	const float VSizeSq = Comp->Velocity.SizeSquared();
	if (VSizeSq <= KINDA_SMALL_NUMBER || (!bZeroBraking && VSizeSq <= FMath::Square(UCharacterMovementComponent::BRAKE_TO_STOP_VELOCITY)))
	{
		Comp->Velocity = FVector_ZeroVector;
	}
}

void NotifyJumpApex(FISPCMovementContext Ctx)
{
	if( Comp->CharacterOwner )
	{
		// TODO ISPC: foreach_active
		Comp->CharacterOwner->NotifyJumpApex();
	}
}

FVector NewFallVelocity(FISPCMovementContext Ctx, const FVector& InitialVelocity, const FVector& Gravity, float DeltaTime) const
{
	FVector Result = InitialVelocity;

	if (!Gravity.IsZero() && (Comp->bApplyGravityWhileJumping || !(Comp->CharacterOwner && Comp->CharacterOwner->IsJumpProvidingForce())))
	{
		// Apply gravity.
		Result += Gravity * DeltaTime;

		const FVector GravityDir = Gravity.GetSafeNormal();
		const float TerminalLimit = FMath::Abs(GetPhysicsVolume(Comp)->TerminalVelocity);

		// Don't exceed terminal velocity.
		if ((Result | GravityDir) > TerminalLimit)
		{
			Result = FVector::PointPlaneProject(Result, FVector_ZeroVector, GravityDir) + GravityDir * TerminalLimit;
		}
	}

	return Result;
}

void StopActiveMovement(FISPCMovementContext Ctx)
{ 
	// ISPC: Inlined Super::StopActiveMovement().
	{
		if (Comp->PathFollowingComp.IsValid() && Comp->bStopMovementAbortPaths)
		{
			// TODO ISPC: foreach_active
			Comp->PathFollowingComp->AbortMove(*this, FPathFollowingResultFlags::MovementStop);
		}
	}

	Comp->Acceleration = FVector_ZeroVector; 
	Comp->bHasRequestedVelocity = false;
	Comp->RequestedVelocity = FVector_ZeroVector;
}

void ProcessLanded(FISPCMovementContext Ctx, const FHitResult& Hit, float remainingTime, int32 Iterations)
{
	SCOPE_CYCLE_COUNTER(STAT_CharProcessLanded);

	if( Comp->CharacterOwner && Comp->CharacterOwner->ShouldNotifyLanded(Hit) )
	{
		Comp->CharacterOwner->Landed(Hit);
	}
	if( IsFalling(Comp) )
	{
		if (Comp->GetGroundMovementMode() == MOVE_NavWalking)
		{
			// verify navmesh projection and current floor
			// otherwise movement will be stuck in infinite loop:
			// navwalking -> (no navmesh) -> falling -> (standing on something) -> navwalking -> ....

			const FVector TestLocation = GetActorFeetLocation(Comp);
			FNavLocation NavLocation;

			const bool bHasNavigationData = FindNavFloor(Comp, TestLocation, NavLocation);
			if (!bHasNavigationData || NavLocation.NodeRef == INVALID_NAVNODEREF)
			{
				SetGroundMovementMode(Comp, MOVE_Walking);
				UE_LOG(LogUnrolledNavMeshMovement, Verbose, TEXT("ProcessLanded(): %s tried to go to NavWalking but couldn't find NavMesh! Using Walking instead."), *GetNameSafe(Comp->CharacterOwner));
			}
		}

		SetPostLandedPhysics(Comp, Hit);
	}
	// TODO ISPC: foreach_active?
	if (Comp->PathFollowingComp.IsValid())
	{
		Comp->PathFollowingComp->OnLanded();
	}

	StartNewPhysics(Comp, remainingTime, Iterations);
}

void SetPostLandedPhysics(FISPCMovementContext Ctx, const FHitResult& Hit)
{
	if( Comp->CharacterOwner )
	{
		if (CanEverSwim(Comp) && IsInWater(Comp))
		{
			SetMovementMode(Comp, MOVE_Swimming);
		}
		else
		{
			const FVector PreImpactAccel = Comp->Acceleration + (IsFalling(Comp) ? FVector(0.f, 0.f, GetGravityZ(Comp)) : FVector_ZeroVector);
			const FVector PreImpactVelocity = Comp->Velocity;

			if (Comp->DefaultLandMovementMode == MOVE_Walking ||
				Comp->DefaultLandMovementMode == MOVE_NavWalking ||
				Comp->DefaultLandMovementMode == MOVE_Falling)
			{
				SetMovementMode(Comp, Comp->GetGroundMovementMode());
			}
			else
			{
				SetDefaultMovementMode(Comp);
			}
			
			ApplyImpactPhysicsForces(Comp, Hit, PreImpactAccel, PreImpactVelocity);
		}
	}
}

void HandleImpact(FISPCMovementContext Ctx, const FHitResult& Impact, float TimeSlice, const FVector& MoveDelta)
{
	SCOPE_CYCLE_COUNTER(STAT_CharHandleImpact);

	if (Comp->CharacterOwner)
	{
		Comp->CharacterOwner->MoveBlockedBy(Impact);
	}

	if (Comp->PathFollowingComp.IsValid())
	{	// Also notify path following!
		// TODO_ISPC: foreach_active
		Comp->PathFollowingComp->OnMoveBlockedBy(Impact);
	}

	APawn* OtherPawn = Cast<APawn>(Impact.GetActor());
	if (OtherPawn)
	{
		NotifyBumpedPawn(Comp, OtherPawn);
	}

	if (Comp->bEnablePhysicsInteraction)
	{
		const FVector ForceAccel = Comp->Acceleration + (IsFalling(Comp) ? FVector(0.f, 0.f, GetGravityZ(Comp)) : FVector_ZeroVector);
		ApplyImpactPhysicsForces(Comp, Impact, ForceAccel, Comp->Velocity);
	}
}

void UpdateComponentVelocity(FISPCMovementContext Ctx)
{
	if ( Comp->UpdatedComponent )
	{
		Comp->UpdatedComponent->ComponentVelocity = Comp->Velocity;
	}
}

void ApplyImpactPhysicsForces(FISPCMovementContext Ctx, const FHitResult& Impact, const FVector& ImpactAcceleration, const FVector& ImpactVelocity)
{
	if (Comp->bEnablePhysicsInteraction && Impact.bBlockingHit )
	{
		if (UPrimitiveComponent* ImpactComponent = Impact.GetComponent())
		{
			FBodyInstance* BI = ImpactComponent->GetBodyInstance(Impact.BoneName);
			if(BI != nullptr && BI->IsInstanceSimulatingPhysics())
			{
				FVector ForcePoint = Impact.ImpactPoint;

				const float BodyMass = FMath::Max(BI->GetBodyMass(), 1.0f);

				if(Comp->bPushForceUsingZOffset)
				{
					FBox Bounds = BI->GetBodyBounds();

					FVector Center, Extents;
					Bounds.GetCenterAndExtents(Center, Extents);

					if (!Extents.IsNearlyZero())
					{
						ForcePoint.Z = Center.Z + Extents.Z * Comp->PushForcePointZOffsetFactor;
					}
				}

				FVector Force = Impact.ImpactNormal * -1.0f;

				float PushForceModificator = 1.0f;

				const FVector ComponentVelocity = ImpactComponent->GetPhysicsLinearVelocity();
				const FVector VirtualVelocity = ImpactAcceleration.IsZero() ? ImpactVelocity : ImpactAcceleration.GetSafeNormal() * GetMaxSpeed(Comp);

				float Dot = 0.0f;

				if (Comp->bScalePushForceToVelocity && !ComponentVelocity.IsNearlyZero())
				{			
					Dot = ComponentVelocity | VirtualVelocity;

					if (Dot > 0.0f && Dot < 1.0f)
					{
						PushForceModificator *= Dot;
					}
				}

				if (Comp->bPushForceScaledToMass)
				{
					PushForceModificator *= BodyMass;
				}

				Force *= PushForceModificator;

				if (ComponentVelocity.IsNearlyZero())
				{
					Force *= Comp->InitialPushForceFactor;
					ImpactComponent->AddImpulseAtLocation(Force, ForcePoint, Impact.BoneName);
				}
				else
				{
					Force *= Comp->PushForceFactor;
					ImpactComponent->AddForceAtLocation(Force, ForcePoint, Impact.BoneName);
				}
			}
		}
	}
}

bool FindNavFloor(FISPCMovementContext Ctx, const FVector& TestLocation, FNavLocation& NavFloorLocation) const
{
#if 1	// TODO ISPC
	unimplemented();
	return false;
#else
	const ANavigationData* NavData = Comp->GetNavData();
	if (NavData == nullptr)
	{
		return false;
	}

	INavAgentInterface* MyNavAgent = CastChecked<INavAgentInterface>(Comp->CharacterOwner);
	float SearchRadius = 0.0f;
	float SearchHeight = 100.0f;
	if (MyNavAgent)
	{
		const FNavAgentProperties& AgentProps = MyNavAgent->GetNavAgentPropertiesRef();
		SearchRadius = AgentProps.AgentRadius * 2.0f;
		SearchHeight = AgentProps.AgentHeight * AgentProps.NavWalkingSearchHeightScale;
	}

	return NavData->ProjectPoint(TestLocation, NavFloorLocation, FVector(SearchRadius, SearchRadius, SearchHeight));
#endif
}

float SlideAlongSurface(FISPCMovementContext Ctx, const FVector& Delta, float Time, const FVector& InNormal, FHitResult& Hit, bool bHandleImpact)
{
	if (!Hit.bBlockingHit)
	{
		return 0.f;
	}

	FVector Normal(InNormal);
	if (IsMovingOnGround(Comp))
	{
		// We don't want to be pushed up an unwalkable surface.
		if (Normal.Z > 0.f)
		{
			if (!IsWalkable(Hit, Comp->GetWalkableFloorZ()))
			{
				Normal = Normal.GetSafeNormal2D();
			}
		}
		else if (Normal.Z < -KINDA_SMALL_NUMBER)
		{
			// Don't push down into the floor when the impact is on the upper portion of the capsule.
			if (Comp->CurrentFloor.FloorDist < UCharacterMovementComponent::MIN_FLOOR_DIST && Comp->CurrentFloor.bBlockingHit)
			{
				const FVector FloorNormal = Comp->CurrentFloor.HitResult.Normal;
				const bool bFloorOpposedToMovement = (Delta | FloorNormal) < 0.f && (FloorNormal.Z < 1.f - DELTA);
				if (bFloorOpposedToMovement)
				{
					Normal = FloorNormal;
				}
				
				Normal = Normal.GetSafeNormal2D();
			}
		}
	}

	// ISPC: Inlined call to Super::SlideAlongSurface().
	{
		if (!Hit.bBlockingHit)
		{
			return 0.f;
		}

		float PercentTimeApplied = 0.f;
		const FVector OldHitNormal = Normal;

		FVector SlideDelta = ComputeSlideVector(Comp, Delta, Time, Normal, Hit);

		if ((SlideDelta | Delta) > 0.f)
		{
			const FQuat Rotation = Comp->UpdatedComponent->GetComponentQuat();
			const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
			SafeMoveUpdatedComponent(Comp, bMoveIgnoreFirstBlockingOverlap, SlideDelta, Rotation, true, Hit);

			const float FirstHitPercent = Hit.Time;
			PercentTimeApplied = FirstHitPercent;
			if (Hit.IsValidBlockingHit())
			{
				// Notify first impact
				if (bHandleImpact)
				{
					HandleImpact(Comp, Hit, FirstHitPercent * Time, SlideDelta);
				}

				// Compute new slide normal when hitting multiple surfaces.
				TwoWallAdjust(Comp, SlideDelta, Hit, OldHitNormal);

				// Only proceed if the new direction is of significant length and not in reverse of original attempted move.
				if (!SlideDelta.IsNearlyZero(1e-3f) && (SlideDelta | Delta) > 0.f)
				{
					// Perform second move
					SafeMoveUpdatedComponent(Comp, bMoveIgnoreFirstBlockingOverlap, SlideDelta, Rotation, true, Hit);
					const float SecondHitPercent = Hit.Time * (1.f - FirstHitPercent);
					PercentTimeApplied += SecondHitPercent;

					// Notify second impact
					if (bHandleImpact && Hit.bBlockingHit)
					{
						HandleImpact(Comp, Hit, SecondHitPercent * Time, SlideDelta);
					}
				}
			}

			return FMath::Clamp(PercentTimeApplied, 0.f, 1.f);
		}

		return 0.f;
	}
}

void TwoWallAdjust(FISPCMovementContext Ctx, FVector& InOutDelta, const FHitResult& Hit, const FVector& OldHitNormal) const
{
	const FVector InDelta = InOutDelta;
	
	// ISPC: Inlined Super::TwoWallAdjust().
	{
		FVector Delta = InOutDelta;
		const FVector HitNormal = Hit.Normal;

		if ((OldHitNormal | HitNormal) <= 0.f) //90 or less corner, so use cross product for direction
		{
			const FVector DesiredDir = Delta;
			FVector NewDir = (HitNormal ^ OldHitNormal);
			NewDir = NewDir.GetSafeNormal();
			Delta = (Delta | NewDir) * (1.f - Hit.Time) * NewDir;
			if ((DesiredDir | Delta) < 0.f)
			{
				Delta = -1.f * Delta;
			}
		}
		else //adjust to new wall
		{
			const FVector DesiredDir = Delta;
			Delta = ComputeSlideVector(Comp, Delta, 1.f - Hit.Time, HitNormal, Hit);
			if ((Delta | DesiredDir) <= 0.f)
			{
				Delta = FVector_ZeroVector;
			}
			else if (FMath::Abs((HitNormal | OldHitNormal) - 1.f) < KINDA_SMALL_NUMBER)
			{
				// we hit the same wall again even after adjusting to move along it the first time
				// nudge away from it (this can happen due to precision issues)
				Delta += HitNormal * 0.01f;
			}
		}

		InOutDelta = Delta;
	}

	if (IsMovingOnGround(Comp))
	{
		// Allow slides up walkable surfaces, but not unwalkable ones (treat those as vertical barriers).
		if (InOutDelta.Z > 0.f)
		{
			if ((Hit.Normal.Z >= Comp->GetWalkableFloorZ() || IsWalkable(Hit, Comp->GetWalkableFloorZ())) && Hit.Normal.Z > KINDA_SMALL_NUMBER)
			{
				// Maintain horizontal velocity
				const float Time = (1.f - Hit.Time);
				const FVector ScaledDelta = InOutDelta.GetSafeNormal() * InDelta.Size();
				InOutDelta = FVector(InDelta.X, InDelta.Y, ScaledDelta.Z / Hit.Normal.Z) * Time;
			}
			else
			{
				InOutDelta.Z = 0.f;
			}
		}
		else if (InOutDelta.Z < 0.f)
		{
			// Don't push down into the floor.
			if (Comp->CurrentFloor.FloorDist < UCharacterMovementComponent::MIN_FLOOR_DIST && Comp->CurrentFloor.bBlockingHit)
			{
				InOutDelta.Z = 0.f;
			}
		}
	}
}

FVector Super_ComputeSlideVector(FISPCMovementContext Ctx, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit) const
{
	if (!Comp->bConstrainToPlane)
	{
		return FVector::VectorPlaneProject(Delta, Normal) * Time;
	}
	else
	{
		const FVector ProjectedNormal = ConstrainNormalToPlane(Comp, Normal);
		return FVector::VectorPlaneProject(Delta, ProjectedNormal) * Time;
	}
}

FVector ComputeSlideVector(FISPCMovementContext Ctx, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit) const
{
	FVector Result = Super_ComputeSlideVector(Comp, Delta, Time, Normal, Hit);

	// prevent boosting up slopes
	if (IsFalling(Comp))
	{
		Result = HandleSlopeBoosting(Comp, Result, Delta, Time, Normal, Hit);
	}

	return Result;
}

FVector HandleSlopeBoosting(FISPCMovementContext Ctx, const FVector& SlideResult, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit) const
{
	FVector Result = SlideResult;

	if (Result.Z > 0.f)
	{
		// Don't move any higher than we originally intended.
		const float ZLimit = Delta.Z * Time;
		if (Result.Z - ZLimit > KINDA_SMALL_NUMBER)
		{
			if (ZLimit > 0.f)
			{
				// Rescale the entire vector (not just the Z component) otherwise we change the direction and likely head right back into the impact.
				const float UpPercent = ZLimit / Result.Z;
				Result *= UpPercent;
			}
			else
			{
				// We were heading down but were going to deflect upwards. Just make the deflection horizontal.
				Result = FVector_ZeroVector;
			}

			// Make remaining portion of original result horizontal and parallel to impact normal.
			const FVector RemainderXY = (SlideResult - Result) * FVector(1.f, 1.f, 0.f);
			const FVector NormalXY = Normal.GetSafeNormal2D();
			const FVector Adjust = Super_ComputeSlideVector(Comp, RemainderXY, 1.f, NormalXY, Hit);
			Result += Adjust;
		}
	}

	return Result;
}

FVector LimitAirControl(FISPCMovementContext Ctx, float DeltaTime, const FVector& FallAcceleration, const FHitResult& HitResult, bool bCheckForValidLandingSpot)
{
	FVector Result(FallAcceleration);

	if (HitResult.IsValidBlockingHit() && HitResult.Normal.Z > VERTICAL_SLOPE_NORMAL_Z)
	{
		if (!bCheckForValidLandingSpot || !IsValidLandingSpot(Comp, HitResult.Location, HitResult))
		{
			// If acceleration is into the wall, limit contribution.
			if (FVector::DotProduct(FallAcceleration, HitResult.Normal) < 0.f)
			{
				// Allow movement parallel to the wall, but not into it because that may push us up.
				const FVector Normal2D = HitResult.Normal.GetSafeNormal2D();
				Result = FVector::VectorPlaneProject(FallAcceleration, Normal2D);
			}
		}
	}
	else if (HitResult.bStartPenetrating)
	{
		// Allow movement out of penetration.
		return (FVector::DotProduct(Result, HitResult.Normal) > 0.f ? Result : FVector_ZeroVector);
	}

	return Result;
}

FVector GetAirControl(FISPCMovementContext Ctx, float DeltaTime, float TickAirControl, const FVector& FallAcceleration)
{
	// Boost
	if (TickAirControl != 0.f)
	{
		// ISPC: Inlined call to BoostAirControl().
		// Allow a burst of initial acceleration
		if (Comp->AirControlBoostMultiplier > 0.f && Comp->Velocity.SizeSquared2D() < FMath::Square(Comp->AirControlBoostVelocityThreshold))
		{
			TickAirControl = FMath::Min(1.f, Comp->AirControlBoostMultiplier * TickAirControl);
		}
	}

	return TickAirControl * FallAcceleration;
}

FString GetMovementName(FISPCMovementContext Ctx) const
{
	// TODO ISPC: foreach_active?
	if( Comp->CharacterOwner )
	{
		if ( Comp->CharacterOwner->GetRootComponent() && Comp->CharacterOwner->GetRootComponent()->IsSimulatingPhysics() )
		{
			return TEXT("Rigid Body");
		}
		else if ( Comp->CharacterOwner->IsMatineeControlled() )
		{
			return TEXT("Matinee");
		}
	}

	// Using character movement
	switch( Comp->MovementMode )
	{
		case MOVE_None:				return TEXT("NULL"); break;
		case MOVE_Walking:			return TEXT("Walking"); break;
		case MOVE_NavWalking:		return TEXT("NavWalking"); break;
		case MOVE_Falling:			return TEXT("Falling"); break;
		case MOVE_Swimming:			return TEXT("Swimming"); break;
		case MOVE_Flying:			return TEXT("Flying"); break;
		case MOVE_Custom:			return TEXT("Custom"); break;
		default:					break;
	}
	return TEXT("Unknown");
}

void NotifyBumpedPawn(FISPCMovementContext Ctx, APawn* BumpedPawn)
{
	{
		// ISPC: Inlined call to Super::NotifyBumpedPawn()... which is empty.
	}

#if 0	// TODO ISPC
#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
	UAvoidanceManager* Avoidance = GetWorld()->GetAvoidanceManager();
	const bool bShowDebug = Avoidance && Avoidance->IsDebugEnabled(AvoidanceUID);
	if (bShowDebug)
	{
		DrawDebugLine(GetWorld(), GetActorFeetLocation(), GetActorFeetLocation() + FVector(0,0,500), (AvoidanceLockTimer > 0) ? FColor(255,64,64) : FColor(64,64,255), true, 2.0f, SDPG_MAX, 20.0f);
	}
#endif
#endif	// TODO ISPC

	// Unlock avoidance move. This mostly happens when two pawns who are locked into avoidance moves collide with each other.
	Comp->AvoidanceLockTimer = 0.0f;
}

void StopMovementImmediately(FISPCMovementContext Ctx)
{
	Comp->Velocity = FVector_ZeroVector;
	UpdateComponentVelocity(Comp);
	StopActiveMovement(Comp);
}

void StopMovementKeepPathing(FISPCMovementContext Ctx)
{
	Comp->bStopMovementAbortPaths = false;
	StopMovementImmediately(Comp);
	Comp->bStopMovementAbortPaths = true;
}

bool ApplyRequestedMove(FISPCMovementContext Ctx, float DeltaTime, float MaxAccel, float MaxSpeed, float Friction, float BrakingDeceleration, FVector& OutAcceleration, float& OutRequestedSpeed)
{
	if (Comp->bHasRequestedVelocity)
	{
		const float RequestedSpeedSquared = Comp->RequestedVelocity.SizeSquared();
		if (RequestedSpeedSquared < KINDA_SMALL_NUMBER)
		{
			return false;
		}

		// Compute requested speed from path following
		float RequestedSpeed = FMath::Sqrt(RequestedSpeedSquared);
		const FVector RequestedMoveDir = Comp->RequestedVelocity / RequestedSpeed;
		RequestedSpeed = (Comp->bRequestedMoveWithMaxSpeed ? MaxSpeed : FMath::Min(MaxSpeed, RequestedSpeed));
		
		// Compute actual requested velocity
		const FVector MoveVelocity = RequestedMoveDir * RequestedSpeed;
		
		// Compute acceleration. Use MaxAccel to limit speed increase, 1% buffer.
		FVector NewAcceleration = FVector_ZeroVector;
		const float CurrentSpeedSq = Comp->Velocity.SizeSquared();
		if (Comp->bRequestedMoveUseAcceleration && CurrentSpeedSq < FMath::Square(RequestedSpeed * 1.01f))
		{
			// Turn in the same manner as with input acceleration.
			const float VelSize = FMath::Sqrt(CurrentSpeedSq);
			Comp->Velocity = Comp->Velocity - (Comp->Velocity - RequestedMoveDir * VelSize) * FMath::Min(DeltaTime * Friction, 1.f);

			// How much do we need to accelerate to get to the new velocity?
			NewAcceleration = ((MoveVelocity - Comp->Velocity) / DeltaTime);
			NewAcceleration = NewAcceleration.GetClampedToMaxSize(MaxAccel);
		}
		else
		{
			// Just set velocity directly.
			// If decelerating we do so instantly, so we don't slide through the destination if we can't brake fast enough.
			Comp->Velocity = MoveVelocity;
		}

		// Copy to out params
		OutRequestedSpeed = RequestedSpeed;
		OutAcceleration = NewAcceleration;
		return true;
	}

	return false;
}

float GetAxisDeltaRotation(float InAxisRotationRate, float DeltaTime)
{
	return (InAxisRotationRate >= 0.f) ? (InAxisRotationRate * DeltaTime) : 360.f;
}

FRotator GetDeltaRotation(FISPCMovementContext Ctx, float DeltaTime) const
{
	return FRotator(GetAxisDeltaRotation(Comp->RotationRate.Pitch, DeltaTime), GetAxisDeltaRotation(Comp->RotationRate.Yaw, DeltaTime), GetAxisDeltaRotation(Comp->RotationRate.Roll, DeltaTime));
}

FRotator ComputeOrientToMovementRotation(FISPCMovementContext Ctx, const FRotator& CurrentRotation, float DeltaTime, FRotator& DeltaRotation) const
{
	if (Comp->Acceleration.SizeSquared() < KINDA_SMALL_NUMBER)
	{
		// AI path following request can orient us in that direction (it's effectively an acceleration)
		if (Comp->bHasRequestedVelocity && Comp->RequestedVelocity.SizeSquared() > KINDA_SMALL_NUMBER)
		{
			return Comp->RequestedVelocity.GetSafeNormal().Rotation();
		}

		// Don't change rotation if there is no acceleration.
		return CurrentRotation;
	}

	// Rotate toward direction of acceleration.
	return Comp->Acceleration.GetSafeNormal().Rotation();
}

bool ShouldRemainVertical(FISPCMovementContext Ctx) const
{
	// Always remain vertical when walking or falling.
	return IsMovingOnGround(Comp) || IsFalling(Comp);
}

void PhysicsRotation(FISPCMovementContext Ctx, float DeltaTime)
{
	if (!(Comp->bOrientRotationToMovement || Comp->bUseControllerDesiredRotation))
	{
		return;
	}

	if (!HasValidData(Comp) || (!Comp->CharacterOwner->Controller && !Comp->bRunPhysicsWithNoController))
	{
		return;
	}

	FRotator CurrentRotation = Comp->UpdatedComponent->GetComponentRotation(); // Normalized
	CurrentRotation.DiagnosticCheckNaN(TEXT("CharacterMovementComponent::PhysicsRotation(): CurrentRotation"));

	FRotator DeltaRot = GetDeltaRotation(Comp, DeltaTime);
	DeltaRot.DiagnosticCheckNaN(TEXT("CharacterMovementComponent::PhysicsRotation(): GetDeltaRotation"));

	FRotator DesiredRotation = CurrentRotation;
	if (Comp->bOrientRotationToMovement)
	{
		DesiredRotation = ComputeOrientToMovementRotation(Comp, CurrentRotation, DeltaTime, DeltaRot);
	}
	else if (Comp->CharacterOwner->Controller && Comp->bUseControllerDesiredRotation)
	{
		DesiredRotation = Comp->CharacterOwner->Controller->GetDesiredRotation();
	}
	else
	{
		return;
	}

	if (ShouldRemainVertical(Comp))
	{
		DesiredRotation.Pitch = 0.f;
		DesiredRotation.Yaw = FRotator::NormalizeAxis(DesiredRotation.Yaw);
		DesiredRotation.Roll = 0.f;
	}
	else
	{
		DesiredRotation.Normalize();
	}
	
	// Accumulate a desired new rotation.
	const float AngleTolerance = 1e-3f;

	if (!CurrentRotation.Equals(DesiredRotation, AngleTolerance))
	{
		// PITCH
		if (!FMath::IsNearlyEqual(CurrentRotation.Pitch, DesiredRotation.Pitch, AngleTolerance))
		{
			DesiredRotation.Pitch = FMath::FixedTurn(CurrentRotation.Pitch, DesiredRotation.Pitch, DeltaRot.Pitch);
		}

		// YAW
		if (!FMath::IsNearlyEqual(CurrentRotation.Yaw, DesiredRotation.Yaw, AngleTolerance))
		{
			DesiredRotation.Yaw = FMath::FixedTurn(CurrentRotation.Yaw, DesiredRotation.Yaw, DeltaRot.Yaw);
		}

		// ROLL
		if (!FMath::IsNearlyEqual(CurrentRotation.Roll, DesiredRotation.Roll, AngleTolerance))
		{
			DesiredRotation.Roll = FMath::FixedTurn(CurrentRotation.Roll, DesiredRotation.Roll, DeltaRot.Roll);
		}

		// Set the new rotation.
		DesiredRotation.DiagnosticCheckNaN(TEXT("CharacterMovementComponent::PhysicsRotation(): DesiredRotation"));
		MoveUpdatedComponent( Comp, FVector_ZeroVector, DesiredRotation.Quaternion(), true );
	}
}

#endif

export void Tick(uniform float DeltaSeconds, uniform FISPCMovementArrays* uniform Arrays, uniform int Count)
{
	FISPCMovementContext Ctx;
	Ctx.Arrays = Arrays;
	foreach (Index = 0 ... Count)
	{
		Ctx.Index = Index;
		PerformMovement(Ctx, DeltaSeconds);
	}
}
