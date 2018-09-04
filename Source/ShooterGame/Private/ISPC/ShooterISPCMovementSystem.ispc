#include "ShooterISPCMovementSystem_Boilerplate.inl"

static bool IsWalkable(const FHitResult& Hit, const float WalkableFloorZ)
{
	if (!FHitResult_IsValidBlockingHit(Hit))
	{
		// No hit, or starting in penetration
		return false;
	}

	// Never walk up vertical surfaces.
	if (Hit.ImpactNormal[2] < KINDA_SMALL_NUMBER)
	{
		return false;
	}

	varying float TestWalkableZ = WalkableFloorZ;

	// See if this component overrides the walkable floor z.
	FWeakObjectPtr HitComponent = { Hit.Component[0], Hit.Component[1] };
	TestWalkableZ = MaybeModifyWalkableFloorZ(HitComponent, TestWalkableZ);

	// Can't walk on this surface if it is too steep.
	if (Hit.ImpactNormal[2] < TestWalkableZ)
	{
		return false;
	}

	return true;
}

static bool IsWithinEdgeTolerance(const FVector& CapsuleLocation, const FVector& TestImpactPoint, const float CapsuleRadius)
{
	FVector FromCenter = TestImpactPoint - CapsuleLocation;
	const float DistFromCenterSq = FromCenter.x * FromCenter.x + FromCenter.y * FromCenter.y;
	float ReducedRadiusSq = max(SWEEP_EDGE_REJECT_DISTANCE + KINDA_SMALL_NUMBER, CapsuleRadius - SWEEP_EDGE_REJECT_DISTANCE);
	ReducedRadiusSq *= ReducedRadiusSq;
	return DistFromCenterSq < ReducedRadiusSq;
}

#if UNIMPLEMENTED_CODE
void SetUpdatedComponent(FISPCMovementContext Ctx, const /*USceneComponent**/void* NewUpdatedComponent)
{
	if (NewUpdatedComponent)
	{
		const ACharacter* NewCharacterOwner = Cast<ACharacter>(NewUpdatedComponent->GetOwner());
		if (NewCharacterOwner == NULL)
		{
			UE_LOG(LogISPCCharacterMovement, Error, TEXT("%s owned by %s must update a component owned by a Character"), *Comp->GetName(), *GetNameSafe(NewUpdatedComponent->GetOwner()));
			return;
		}

		// check that UpdatedComponent is a Capsule
		if (Cast<UCapsuleComponent>(NewUpdatedComponent) == NULL)
		{
			UE_LOG(LogISPCCharacterMovement, Error, TEXT("%s owned by %s must update a capsule component"), *Comp->GetName(), *GetNameSafe(NewUpdatedComponent->GetOwner()));
			return;
		}
	}

	if ( CtxAccess(bMovementInProgress) )
	{
#if 0	// TODO ISPC
		unimplemented();
#else
		// failsafe to avoid crashes in CharacterMovement. 
		CtxAccess(bDeferUpdateMoveComponent) = true;
		CtxAccess(DeferredUpdatedMoveComponent) = NewUpdatedComponent;
		return;
#endif
	}
	CtxAccess(bDeferUpdateMoveComponent) = false;
	CtxAccess(DeferredUpdatedMoveComponent) = NULL;

	USceneComponent* OldUpdatedComponent = CtxAccess(UpdatedComponent);
	UPrimitiveComponent* OldPrimitive = Cast<UPrimitiveComponent>(CtxAccess(UpdatedComponent));
	if (IsValid(OldPrimitive) && OldPrimitive->OnComponentBeginOverlap.IsBound())
	{
#if 1	// TODO ISPC: Member is private.
		unimplemented();
#else
		OldPrimitive->OnComponentBeginOverlap.RemoveDynamic(Ctx, &UCharacterMovementComponent::CapsuleTouched);
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
			if (CtxAccess(UpdatedComponent) && CtxAccess(UpdatedComponent) != NewUpdatedComponent)
			{
				CtxAccess(UpdatedComponent)->bShouldUpdatePhysicsVolume = false;
				if (!CtxAccess(UpdatedComponent)->IsPendingKill())
				{
					CtxAccess(UpdatedComponent)->SetPhysicsVolume(NULL, true);
					CtxAccess(UpdatedComponent)->PhysicsVolumeChangedDelegate.RemoveDynamic(Ctx, &UMovementComponent::PhysicsVolumeChanged);
				}

				// remove from tick prerequisite
				CtxAccess(UpdatedComponent)->PrimaryComponentTick.RemovePrerequisite(Ctx, Comp->PrimaryComponentTick);
			}

			// Don't assign pending kill components, but allow those to null out previous UpdatedComponent.
			CtxAccess(UpdatedComponent) = IsValid(NewUpdatedComponent) ? NewUpdatedComponent : NULL;
			Comp->UpdatedPrimitive = Cast<UPrimitiveComponent>(CtxAccess(UpdatedComponent));

			// Assign delegates
			if (CtxAccess(UpdatedComponent) && !CtxAccess(UpdatedComponent)->IsPendingKill())
			{
				CtxAccess(UpdatedComponent)->bShouldUpdatePhysicsVolume = true;
				CtxAccess(UpdatedComponent)->PhysicsVolumeChangedDelegate.AddUniqueDynamic(Ctx, &UMovementComponent::PhysicsVolumeChanged);

	#if 0	// TODO ISPC
				if (!Comp->bInOnRegister && !Comp->bInInitializeComponent)
	#endif
				{
					// UpdateOverlaps() in component registration will take care of this.
					CtxAccess(UpdatedComponent)->UpdatePhysicsVolume(true);
				}

				// force ticks after movement component updates
				CtxAccess(UpdatedComponent)->PrimaryComponentTick.AddPrerequisite(Ctx, Comp->PrimaryComponentTick);
			}

			Comp->UpdateTickRegistration();

			if (Comp->bSnapToPlaneAtStart)
			{
				SnapUpdatedComponentToPlane(Ctx);
			}
		}

		Comp->PawnOwner = NewUpdatedComponent ? CastChecked<APawn>(NewUpdatedComponent->GetOwner()) : NULL;
	}
	CtxAccess(CharacterOwner) = Cast<ACharacter>(Comp->PawnOwner);

	if (CtxAccess(UpdatedComponent) != OldUpdatedComponent)
	{
		ClearAccumulatedForces(Ctx);
	}

	if (CtxAccess(UpdatedComponent) == NULL)
	{
		StopActiveMovement(Ctx);
	}

	const bool bValidUpdatedPrimitive = IsValid(Comp->UpdatedPrimitive);

	if (bValidUpdatedPrimitive && Comp->bEnablePhysicsInteraction)
	{
#if 1	// TODO ISPC: Member is private.
		unimplemented();
#else
		Comp->UpdatedPrimitive->OnComponentBeginOverlap.AddUniqueDynamic(Ctx, &UCharacterMovementComponent::CapsuleTouched);
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
			AvoidanceManager->RegisterMovementComponent(Ctx, Comp->AvoidanceWeight);
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
		const FVector Adjustment = (CtxAccess(Velocity) - Comp->LastUpdateVelocity);
		Comp->CurrentRootMotion.LastPreAdditiveVelocity += Adjustment;

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			if (!Adjustment.IsNearlyZero())
			{
				FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement HasAdditiveVelocity LastUpdateVelocityAdjustment LastPreAdditiveVelocity(%s) Adjustment(%s)"),
					*Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString(), *Adjustment.ToCompactString());
				RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
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
		FScopedMovementUpdate ScopedMovementUpdate(CtxAccess(UpdatedComponent), Comp->bEnableScopedMovementUpdates ? EScopedUpdate::DeferredUpdates : EScopedUpdate::ImmediateUpdates);
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

			const FVector VelocityBeforeCleanup = CtxAccess(Velocity);
			Comp->CurrentRootMotion.CleanUpInvalidRootMotion(DeltaSeconds, *CtxAccess(CharacterOwner), *Comp);

#if ROOT_MOTION_DEBUG
			if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
			{
				if (CtxAccess(Velocity) != VelocityBeforeCleanup)
				{
					const FVector Adjustment = CtxAccess(Velocity) - VelocityBeforeCleanup;
					FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement CleanUpInvalidRootMotion Velocity(%s) VelocityBeforeCleanup(%s) Adjustment(%s)"),
						*CtxAccess(Velocity).ToCompactString(), *VelocityBeforeCleanup.ToCompactString(), *Adjustment.ToCompactString());
					RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
				}
			}
#endif
		}
#endif	// TODO ISPC

		OldVelocity = CtxAccess(Velocity);
		OldLocation = GetUpdatedComponentLocation(Ctx);

		ApplyAccumulatedForces(Ctx, DeltaSeconds);

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
			if (OldVelocity != CtxAccess(Velocity))
			{
				const FVector Adjustment = CtxAccess(Velocity) - OldVelocity;
				FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement ApplyAccumulatedForces+HandlePendingLaunch Velocity(%s) OldVelocity(%s) Adjustment(%s)"),
					*CtxAccess(Velocity).ToCompactString(), *OldVelocity.ToCompactString(), *Adjustment.ToCompactString());
				RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
			}
		}
#endif

#if 1	// TODO ISPC
		check(!HasRootMotionSources(Ctx));
#else
		// Update saved LastPreAdditiveVelocity with any external changes to character Velocity that happened due to ApplyAccumulatedForces/HandlePendingLaunch
		if (Comp->CurrentRootMotion.HasAdditiveVelocity())
		{
			const FVector Adjustment = (CtxAccess(Velocity) - OldVelocity);
			Comp->CurrentRootMotion.LastPreAdditiveVelocity += Adjustment;

#if ROOT_MOTION_DEBUG
			if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
			{
				if (!Adjustment.IsNearlyZero())
				{
					FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement HasAdditiveVelocity AccumulatedForces LastPreAdditiveVelocity(%s) Adjustment(%s)"),
						*Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString(), *Adjustment.ToCompactString());
					RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
				}
			}
#endif
		}

		// Prepare Root Motion (generate/accumulate from root motion sources to be used later)
		if (bHasRootMotionSources && !CtxAccess(CharacterOwner)_bClientUpdating && !CtxAccess(CharacterOwner)_bServerMoveIgnoreRootMotion)
		{
			// Animation root motion - If using animation RootMotion, tick animations before running physics.
			if (CtxAccess(CharacterOwner)_IsPlayingRootMotion && CtxAccess(CharacterOwner)_GetMesh)
			{
#if 1	// TODO ISPC
				unimplemented();
#else
				Comp->TickCharacterPose(DeltaSeconds);

				// Make sure animation didn't trigger an event that destroyed us
				if (!HasValidData(Ctx))
				{
					return;
				}

				// For local human clients, save off root motion data so it can be used by movement networking code.
				if (CtxAccess(CharacterOwner)->IsLocallyControlled() && (CtxAccess(CharacterOwner_Role) == ROLE_AutonomousProxy) && CtxAccess(CharacterOwner)->IsPlayingNetworkedRootMotionMontage())
				{
					CtxAccess(CharacterOwner)->ClientRootMotionParams = Comp->RootMotionParams;
				}
#endif
			}

			// Generates root motion to be used this frame from sources other than animation
			{
				SCOPE_CYCLE_COUNTER(STAT_CharacterMovementRootMotionSourceCalculate);
				Comp->CurrentRootMotion.PrepareRootMotion(DeltaSeconds, *CtxAccess(CharacterOwner), *Comp, true);
			}

			// For local human clients, save off root motion data so it can be used by movement networking code.
			if (CtxAccess(CharacterOwner)->IsLocallyControlled() && (CtxAccess(CharacterOwner_Role) == ROLE_AutonomousProxy))
			{
				CtxAccess(CharacterOwner)->SavedRootMotion = Comp->CurrentRootMotion;
			}
		}

		// Apply Root Motion to Velocity
		if (Comp->CurrentRootMotion.HasOverrideVelocity() || HasAnimRootMotion(Ctx))
		{
			// Animation root motion overrides Velocity and currently doesn't allow any other root motion sources
			if (HasAnimRootMotion(Ctx))
			{
				// Convert to world space (animation root motion is always local)
				USkeletalMeshComponent * SkelMeshComp = CtxAccess(CharacterOwner)_GetMesh;
				if (SkelMeshComp)
				{
					// Convert Local Space Root Motion to world space. Do it right before used by physics to make sure we use up to date transforms, as translation is relative to rotation.
					Comp->RootMotionParams.Set(ConvertLocalRootMotionToWorld(Ctx, Comp->RootMotionParams.GetRootMotionTransform()));
				}

				// Then turn root motion to velocity to be used by various physics modes.
				if (DeltaSeconds > 0.f)
				{
					Comp->AnimRootMotionVelocity = Comp->CalcAnimRootMotionVelocity(Comp->RootMotionParams.GetRootMotionTransform().GetTranslation(), DeltaSeconds, CtxAccess(Velocity));
					CtxAccess(Velocity) = Comp->ConstrainAnimRootMotionVelocity(Comp->AnimRootMotionVelocity, CtxAccess(Velocity));
				}

				UE_LOG(LogRootMotion, Log, TEXT("PerformMovement WorldSpaceRootMotion Translation: %s, Rotation: %s, Actor Facing: %s, Velocity: %s")
					, *Comp->RootMotionParams.GetRootMotionTransform().GetTranslation().ToCompactString()
					, *Comp->RootMotionParams.GetRootMotionTransform().GetRotation().Rotator().ToCompactString()
					, *CtxAccess(CharacterOwner)->GetActorForwardVector().ToCompactString()
					, *CtxAccess(Velocity).ToCompactString()
				);
			}
			else
			{
				// We don't have animation root motion so we apply other sources
				if (DeltaSeconds > 0.f)
				{
					SCOPE_CYCLE_COUNTER(STAT_CharacterMovementRootMotionSourceApply);

					const FVector VelocityBeforeOverride = CtxAccess(Velocity);
					FVector NewVelocity = CtxAccess(Velocity);
					Comp->CurrentRootMotion.AccumulateOverrideRootMotionVelocity(DeltaSeconds, *CtxAccess(CharacterOwner), *Comp, NewVelocity);
					CtxAccess(Velocity) = NewVelocity;

#if ROOT_MOTION_DEBUG
					if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
					{
						if (VelocityBeforeOverride != CtxAccess(Velocity))
						{
							FString AdjustedDebugString = FString::Printf(TEXT("PerformMovement AccumulateOverrideRootMotionVelocity Velocity(%s) VelocityBeforeOverride(%s)"),
								*CtxAccess(Velocity).ToCompactString(), *VelocityBeforeOverride.ToCompactString());
							RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
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
				*CtxAccess(Velocity).ToCompactString(), *OldVelocity.ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
		}
#endif
#endif	// TODO ISPC

		// NaN tracking
		checkCode(ensureMsgf(!CtxAccess(Velocity).ContainsNaN(), TEXT("UCharacterMovementComponent::PerformMovement: Velocity contains NaN (%s)\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(Velocity).ToString()));

		// Clear jump input now, to allow movement events to trigger it for next update.
		ClearJumpInput(CtxAccess(CharacterOwner));

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
			const FQuat OldActorRotationQuat = CtxAccess(UpdatedComponent_ComponentQuat);
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
				const FRotator ResultingRotation = CtxAccess(UpdatedComponent)->GetComponentRotation();

				// Show current position
				DrawDebugCoordinateSystem(GetWorld(), CtxAccess(CharacterOwner)_GetMesh->GetComponentLocation() + FVector(0, 0, 1), ResultingRotation, 50.f, false);

				// Show resulting delta move.
				DrawDebugLine(GetWorld(), OldLocation, ResultingLocation, FColor::Red, true, 10.f);

				// Log details.
				UE_LOG(LogRootMotion, Warning, TEXT("PerformMovement Resulting DeltaMove Translation: %s, Rotation: %s, MovementBase: %s"),
					*(ResultingLocation - OldLocation).ToCompactString(), *(ResultingRotation - OldActorRotation).GetNormalized().ToCompactString(), *GetNameSafe(CtxAccess(CharacterOwner_MovementBase)));

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
	} // End scoped movement update

	// Call external post-movement events. These happen after the scoped movement completes in case the events want to use the current state of overlaps etc.
	CallMovementUpdateDelegate(Ctx, DeltaSeconds, OldLocation, OldVelocity);

	MaybeSaveBaseLocation(Ctx);
	UpdateComponentVelocity(Ctx);

	const bool bHasAuthority = CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner_HasAuthority);

	// If we move we want to avoid a long delay before replication catches up to notice this change, especially if it's throttling our rate.
	if (bHasAuthority && Ctx.Arrays->UNetDriver_IsAdaptiveNetUpdateFrequencyEnabled && CtxAccess(UpdatedComponent))
	{
		CancelAdaptiveReplication(CtxAccess(Comp));
	}

	const FVector NewLocation = CtxAccess(UpdatedComponent) ? GetUpdatedComponentLocation(Ctx) : FVector_ZeroVector;
	const FQuat NewRotation = CtxAccess(UpdatedComponent) ? CtxAccess(UpdatedComponent_ComponentQuat) : FQuat_Identity;

	if (bHasAuthority && CtxAccess(UpdatedComponent) && !CtxAccess(NetMode) == NM_Client)
	{
		const bool bLocationChanged = !FVector_Equal(NewLocation, CtxAccess(LastUpdateLocation));
		const bool bRotationChanged = !FQuat_Equal(NewRotation, CtxAccess(LastUpdateRotation));
		if (bLocationChanged || bRotationChanged)
		{
			CtxAccess(ServerLastTransformUpdateTimeStamp) = Ctx.Arrays->WorldTimeSeconds;
		}
	}

	CtxAccess(LastUpdateLocation) = NewLocation;
	CtxAccess(LastUpdateRotation) = NewRotation;
	CtxAccess(LastUpdateVelocity) = CtxAccess(Velocity);
}

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

void CallMovementUpdateDelegate(FISPCMovementContext Ctx, float DeltaTime, const FVector OldLocation, const FVector OldVelocity)
{
	SCOPE_CYCLE_COUNTER(STAT_CharMoveUpdateDelegate);

	// Update component velocity in case events want to read it
	UpdateComponentVelocity(Ctx);

	// Delegate (for blueprints)
	if (CtxAccess(CharacterOwner))
	{
		OnCharacterMovementUpdated(CtxAccess(CharacterOwner), DeltaTime, OldLocation, OldVelocity);
	}
}

void UpdateCharacterStateBeforeMovement(FISPCMovementContext Ctx)
{
	// Check for a change in crouch state. Players toggle crouch by changing bWantsToCrouch.
	const bool bAllowedToCrouch = CanCrouchInCurrentState(Ctx);
	if ((!bAllowedToCrouch || !CtxAccess(bWantsToCrouch)) && IsCrouching(Ctx))
	{
		UnCrouch(Ctx, false);
	}
	else if (CtxAccess(bWantsToCrouch) && bAllowedToCrouch && !IsCrouching(Ctx))
	{
		Crouch(Ctx, false);
	}
}

void UpdateCharacterStateAfterMovement(FISPCMovementContext Ctx)
{
	// Uncrouch if no longer allowed to be crouched
	if (IsCrouching(Ctx) && !CanCrouchInCurrentState(Ctx))
	{
		UnCrouch(Ctx, false);
	}
}

void StartNewPhysics(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	if ((deltaTime < MIN_TICK_TIME) || (Iterations >= CtxAccess(MaxSimulationIterations)) || !HasValidData(Ctx))
	{
		return;
	}

	if (CtxAccess(UpdatedComponent_IsSimulatingPhysics))
	{
		UE_LOG(LogISPCCharacterMovement, Log, TEXT("UCharacterMovementComponent::StartNewPhysics: UpdateComponent (%s) is simulating physics - aborting."), GetPathName(CtxAccess(UpdatedComponent)));
		return;
	}

	const bool bSavedMovementInProgress = CtxAccess(bMovementInProgress);
	CtxAccess(bMovementInProgress) = true;

	switch (CtxAccess(MovementMode))
	{
	case MOVE_None:
		break;
	case MOVE_Walking:
		PhysWalking(Ctx, deltaTime, Iterations);
		break;
	case MOVE_NavWalking:
		PhysNavWalking(Ctx, deltaTime, Iterations);
		break;
	case MOVE_Falling:
		PhysFalling(Ctx, deltaTime, Iterations);
		break;
	case MOVE_Flying:
		PhysFlying(Ctx, deltaTime, Iterations);
		break;
	case MOVE_Swimming:
		PhysSwimming(Ctx, deltaTime, Iterations);
		break;
	case MOVE_Custom:
		PhysCustom(Ctx, deltaTime, Iterations);
		break;
	default:
		UE_LOG(LogISPCCharacterMovement, Warning, TEXT("% has unsupported movement mode %"), GetName(CtxAccess(CharacterOwner)), (uint8)CtxAccess(MovementMode));
		SetMovementMode(Ctx, MOVE_None);
		break;
	}

	CtxAccess(bMovementInProgress) = bSavedMovementInProgress;
	if (CtxAccess(bDeferUpdateMoveComponent))
	{
		SetUpdatedComponent(Ctx, CtxAccess(DeferredUpdatedMoveComponent));
	}
}

bool IsFlying(FISPCMovementContext Ctx)
{
	return (CtxAccess(MovementMode) == MOVE_Flying) && CtxAccess(UpdatedComponent);
}

bool IsMovingOnGround(FISPCMovementContext Ctx)
{
	return ((CtxAccess(MovementMode) == MOVE_Walking) || (CtxAccess(MovementMode) == MOVE_NavWalking)) && CtxAccess(UpdatedComponent);
}

bool IsFalling(FISPCMovementContext Ctx)
{
	return (CtxAccess(MovementMode) == MOVE_Falling) && CtxAccess(UpdatedComponent);
}

bool IsSwimming(FISPCMovementContext Ctx)
{
	return (CtxAccess(MovementMode) == MOVE_Swimming) && CtxAccess(UpdatedComponent);
}

bool IsCrouching(FISPCMovementContext Ctx)
{
	return CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner_bIsCrouched);
}

#if UNIMPLEMENTED_CODE
APhysicsVolume* GetPhysicsVolume(FISPCMovementContext Ctx)
{
	if (CtxAccess(UpdatedComponent))
	{
		return CtxAccess(UpdatedComponent)->GetPhysicsVolume();
	}

	return GetWorld()->GetDefaultPhysicsVolume();
}
#endif

float GetGravityZ(FISPCMovementContext Ctx)
{
	return GetPhysicsVolume_GetGravityZ(CtxAccess(UpdatedComponent)) * CtxAccess(GravityScale);
}

FVector GetPawnCapsuleExtent(FISPCMovementContext Ctx, const FVector2D CustomShrinkAmount)
{
	check(CtxAccess(CharacterOwner));

	FVector CapsuleExtent = MakeFVector(
		CtxAccess(CharacterOwner_CapsuleComponent_Size).x * CtxAccess(CharacterOwner_CapsuleComponent_Size).z,
		CtxAccess(CharacterOwner_CapsuleComponent_Size).x * CtxAccess(CharacterOwner_CapsuleComponent_Size).z,
		CtxAccess(CharacterOwner_CapsuleComponent_Size).y * CtxAccess(CharacterOwner_CapsuleComponent_Size).z
	);

	// Don't shrink to zero extent.
	const float MinExtent = KINDA_SMALL_NUMBER * 10.f;
	CapsuleExtent.x = max(CapsuleExtent.x - CustomShrinkAmount.x, MinExtent);
	CapsuleExtent.y = CapsuleExtent.x;
	CapsuleExtent.z = max(CapsuleExtent.z - CustomShrinkAmount.y, MinExtent);

	return CapsuleExtent;
}

#if UNIMPLEMENTED_CODE

float GetMaxSpeed(FISPCMovementContext Ctx)
{
	switch(CtxAccess(MovementMode))
	{
	case MOVE_Walking:
	case MOVE_NavWalking:
		return IsCrouching(Ctx) ? Comp->MaxWalkSpeedCrouched : Comp->MaxWalkSpeed;
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

float GetMaxBrakingDeceleration(FISPCMovementContext Ctx)
{
	switch (CtxAccess(MovementMode))
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

float GetMinAnalogSpeed(FISPCMovementContext Ctx)
{
	switch (CtxAccess(MovementMode))
	{
	case MOVE_Walking:
	case MOVE_NavWalking:
	case MOVE_Falling:
		return Comp->MinAnalogWalkSpeed;
	default:
		return 0.f;
	}
}

float GetMaxAcceleration(FISPCMovementContext Ctx)
{
	return Comp->MaxAcceleration;
}

float GetPerchRadiusThreshold(FISPCMovementContext Ctx)
{
	// Don't allow negative values.
	return max(0.f, Comp->PerchRadiusThreshold);
}

float GetValidPerchRadius(FISPCMovementContext Ctx)
{
	if (CtxAccess(CharacterOwner))
	{
		const float PawnRadius = CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleRadius();
		return FMath::Clamp(PawnRadius - GetPerchRadiusThreshold(Ctx), 0.1f, PawnRadius);
	}
	return 0.f;
}

bool IsInWater(FISPCMovementContext Ctx)
{
	const APhysicsVolume* PhysVolume = GetPhysicsVolume(Ctx);
	return PhysVolume && PhysVolume->bWaterVolume;
}

bool IsValidLandingSpot(FISPCMovementContext Ctx, const FVector& CapsuleLocation, const FHitResult& Hit)
{
	if (!Hit.bBlockingHit)
	{
		return false;
	}

	// Skip some checks if penetrating. Penetration will be handled by the FindFloor call (using a smaller capsule)
	if (!FHitResult_bStartPenetrating(Hit))
	{
		// Reject unwalkable floor normals.
		if (!IsWalkable(Hit, Comp->GetWalkableFloorZ()))
		{
			return false;
		}

		float PawnRadius, PawnHalfHeight;
		CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

		// Reject hits that are above our lower hemisphere (can happen when sliding down a vertical surface).
		const float LowerHemisphereZ = Hit.Location.z - PawnHalfHeight + PawnRadius;
		if (Hit.ImpactPoint.z >= LowerHemisphereZ)
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
		if (Hit.Normal.z < KINDA_SMALL_NUMBER)
		{
			// Normal is nearly horizontal or downward, that's a penetration adjustment next to a vertical or overhanging wall. Don't pop to the floor.
			return false;
		}
	}

	FFindFloorResult FloorResult;
	FindFloor(Ctx, CapsuleLocation, FloorResult, false, &Hit);

	if (!FloorResult.IsWalkableFloor())
	{
		return false;
	}

	return true;
}

bool ShouldCheckForValidLandingSpot(FISPCMovementContext Ctx, float DeltaTime, const FVector& Delta, const FHitResult& Hit)
{
	// See if we hit an edge of a surface on the lower portion of the capsule.
	// In this case the normal will not equal the impact normal, and a downward sweep may find a walkable surface on top of the edge.
	if (Hit.Normal.z > KINDA_SMALL_NUMBER && !Hit.Normal.Equals(Hit.ImpactNormal))
	{
		const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);
		if (IsWithinEdgeTolerance(PawnLocation, Hit.ImpactPoint, CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleRadius()))
		{
			return true;
		}
	}

	return false;
}

FVector GetFallingLateralAcceleration(FISPCMovementContext Ctx, float DeltaTime)
{
	// No acceleration in Z
	FVector FallAcceleration = FVector(CtxAccess(Acceleration).x, CtxAccess(Acceleration).y, 0.f);

	// bound acceleration, falling object has minimal ability to impact acceleration
	if (!HasAnimRootMotion(Ctx) && FallAcceleration.SizeSquared2D() > 0.f)
	{
		FallAcceleration = GetAirControl(Ctx, DeltaTime, Comp->AirControl, FallAcceleration);
		FallAcceleration = FallAcceleration.GetClampedToMaxSize(GetMaxAcceleration(Ctx));
	}

	return FallAcceleration;
}

static uint32 s_WarningCount = 0;
float GetSimulationTimeStep(FISPCMovementContext Ctx, float RemainingTime, int32 Iterations)
{
	// TODO ISPC: Move MaxSimulation* to system and/or make uniform.
	if (RemainingTime > Comp->MaxSimulationTimeStep)
	{
		if (Iterations < CtxAccess(MaxSimulationIterations))
		{
			// Subdivide moves to be no longer than MaxSimulationTimeStep seconds
			RemainingTime = min(Comp->MaxSimulationTimeStep, RemainingTime * 0.5f);
		}
		else
		{
			// If this is the last iteration, just use all the remaining time. This is usually better than cutting things short, as the simulation won't move far enough otherwise.
			// Print a throttled warning.
#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
			if ((s_WarningCount++ < 100) || (GFrameCounter & 15) == 0)
			{
				UE_LOG(LogISPCCharacterMovement, Warning, TEXT("GetSimulationTimeStep() - Max iterations %d hit while remaining time %.6f > MaxSimulationTimeStep (%.3f) for '%s', movement '%s'"), CtxAccess(MaxSimulationIterations), RemainingTime, Comp->MaxSimulationTimeStep, *GetNameSafe(CtxAccess(CharacterOwner)), *GetMovementName(Ctx));
			}
#endif
		}
	}

	// no less than MIN_TICK_TIME (to avoid potential divide-by-zero during simulation).
	return max(MIN_TICK_TIME, RemainingTime);
}

void CalcVelocity(FISPCMovementContext Ctx, float DeltaTime, float Friction, bool bFluid, float BrakingDeceleration)
{
	// Do not update velocity when using root motion or when SimulatedProxy - SimulatedProxy are repped their Velocity
	if (!HasValidData(Ctx) || HasAnimRootMotion(Ctx) || DeltaTime < MIN_TICK_TIME || (CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner_Role) == ROLE_SimulatedProxy))
	{
		return;
	}

	Friction = max(0.f, Friction);
	const float MaxAccel = GetMaxAcceleration(Ctx);
	float MaxSpeed = GetMaxSpeed(Ctx);
	
	// Check if path following requested movement
	bool bZeroRequestedAcceleration = true;
	FVector RequestedAcceleration = FVector_ZeroVector;
	float RequestedSpeed = 0.0f;
	if (ApplyRequestedMove(Ctx, DeltaTime, MaxAccel, MaxSpeed, Friction, BrakingDeceleration, RequestedAcceleration, RequestedSpeed))
	{
		RequestedAcceleration = RequestedAcceleration.GetClampedToMaxSize(MaxAccel);
		bZeroRequestedAcceleration = false;
	}

	if (Comp->bForceMaxAccel)
	{
		// Force acceleration at full speed.
		// In consideration order for direction: Acceleration, then Velocity, then Pawn's rotation.
		if (CtxAccess(Acceleration).SizeSquared() > SMALL_NUMBER)
		{
			CtxAccess(Acceleration) = CtxAccess(Acceleration).GetSafeNormal() * MaxAccel;
		}
		else 
		{
			CtxAccess(Acceleration) = MaxAccel * (CtxAccess(Velocity).SizeSquared() < SMALL_NUMBER ? CtxAccess(UpdatedComponent)->GetForwardVector() : CtxAccess(Velocity).GetSafeNormal());
		}

		Comp->AnalogInputModifier = 1.f;
	}

	// Path following above didn't care about the analog modifier, but we do for everything else below, so get the fully modified value.
	// Use max of requested speed and max speed if we modified the speed in ApplyRequestedMove above.
	MaxSpeed = max3(RequestedSpeed, MaxSpeed * Comp->AnalogInputModifier, GetMinAnalogSpeed(Ctx));

	// Apply braking or deceleration
	const bool bZeroAcceleration = FVector_IsZero(CtxAccess(Acceleration));
	const bool bVelocityOverMax = IsExceedingMaxSpeed(Ctx, MaxSpeed);
	
	// Only apply braking if there is no acceleration, or we are over our max speed and need to slow down to it.
	if ((bZeroAcceleration && bZeroRequestedAcceleration) || bVelocityOverMax)
	{
		const FVector OldVelocity = CtxAccess(Velocity);

		const float ActualBrakingFriction = (Comp->bUseSeparateBrakingFriction ? Comp->BrakingFriction : Friction);
		ApplyVelocityBraking(Ctx, DeltaTime, ActualBrakingFriction, BrakingDeceleration);
	
		// Don't allow braking to lower us below max speed if we started above it.
		if (bVelocityOverMax && CtxAccess(Velocity).SizeSquared() < FMath_Square(MaxSpeed) && FVector::DotProduct(CtxAccess(Acceleration), OldVelocity) > 0.0f)
		{
			CtxAccess(Velocity) = OldVelocity.GetSafeNormal() * MaxSpeed;
		}
	}
	else if (!bZeroAcceleration)
	{
		// Friction affects our ability to change direction. This is only done for input acceleration, not path following.
		const FVector AccelDir = CtxAccess(Acceleration).GetSafeNormal();
		const float VelSize = CtxAccess(Velocity).Size();
		CtxAccess(Velocity) = CtxAccess(Velocity) - (CtxAccess(Velocity) - AccelDir * VelSize) * min(DeltaTime * Friction, 1.f);
	}

	// Apply fluid friction
	if (bFluid)
	{
		CtxAccess(Velocity) = CtxAccess(Velocity) * (1.f - min(Friction * DeltaTime, 1.f));
	}

	// Apply acceleration
	const float NewMaxSpeed = (IsExceedingMaxSpeed(Ctx, MaxSpeed)) ? CtxAccess(Velocity).Size() : MaxSpeed;
	CtxAccess(Velocity) += CtxAccess(Acceleration) * DeltaTime;
	CtxAccess(Velocity) += RequestedAcceleration * DeltaTime;
	CtxAccess(Velocity) = CtxAccess(Velocity).GetClampedToMaxSize(NewMaxSpeed);

	if (Comp->bUseRVOAvoidance)
	{
		//CalcAvoidanceVelocity(Comp->DeltaTime);	// TODO ISPC
		unimplemented();
	}
}

void PhysWalking(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	SCOPE_CYCLE_COUNTER(STAT_CharPhysWalking);


	if (deltaTime < MIN_TICK_TIME)
	{
		return;
	}

	if (!CtxAccess(CharacterOwner) || (!CtxAccess(CharacterOwner)->Controller && !Comp->bRunPhysicsWithNoController && !HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity() && (CtxAccess(CharacterOwner_Role) != ROLE_SimulatedProxy)))
	{
		CtxAccess(Acceleration) = FVector_ZeroVector;
		CtxAccess(Velocity) = FVector_ZeroVector;
		return;
	}

	if (!CtxAccess(UpdatedComponent)->IsQueryCollisionEnabled())
	{
		SetMovementMode(Ctx, MOVE_Walking);
		return;
	}

	checkCode(ensureMsgf(!CtxAccess(Velocity).ContainsNaN(), TEXT("PhysWalking: Velocity contains NaN before Iteration (%s)\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(Velocity).ToString()));

	CtxAccess(bJustTeleported) = false;
	bool bCheckedFall = false;
	bool bTriedLedgeMove = false;
	float remainingTime = deltaTime;

	// Perform the move
	while ((remainingTime >= MIN_TICK_TIME) && (Iterations < CtxAccess(MaxSimulationIterations)) && CtxAccess(CharacterOwner) && (CtxAccess(CharacterOwner)->Controller || Comp->bRunPhysicsWithNoController || HasAnimRootMotion(Ctx) || Comp->CurrentRootMotion.HasOverrideVelocity() || (CtxAccess(CharacterOwner_Role) == ROLE_SimulatedProxy)))
	{
		Iterations++;
		CtxAccess(bJustTeleported) = false;
		const float timeTick = GetSimulationTimeStep(Ctx, remainingTime, Iterations);
		remainingTime -= timeTick;

		// Save current values
		UPrimitiveComponent * const OldBase = GetMovementBase(Ctx);
		const FVector PreviousBaseLocation = (OldBase != NULL) ? OldBase->GetComponentLocation() : FVector_ZeroVector;
		const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
		const FFindFloorResult OldFloor = CtxAccess(CurrentFloor);

		RestorePreAdditiveRootMotionVelocity(Ctx);

		// Ensure velocity is horizontal.
		MaintainHorizontalGroundVelocity(Ctx);
		const FVector OldVelocity = CtxAccess(Velocity);
		CtxAccess(Acceleration).z = 0.f;

		// Apply acceleration
		if (!HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity())
		{
			CalcVelocity(Ctx, timeTick, Comp->GroundFriction, false, GetMaxBrakingDeceleration(Ctx));
			checkCode(ensureMsgf(!CtxAccess(Velocity).ContainsNaN(), TEXT("PhysWalking: Velocity contains NaN after CalcVelocity (%s)\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(Velocity).ToString()));
		}

		ApplyRootMotionToVelocity(Ctx, timeTick);
		checkCode(ensureMsgf(!CtxAccess(Velocity).ContainsNaN(), TEXT("PhysWalking: Velocity contains NaN after Root Motion application (%s)\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(Velocity).ToString()));

		if (IsFalling(Ctx))
		{
			// Root motion could have put us into Falling.
			// No movement has taken place this movement tick so we pass on full time/past iteration count
			StartNewPhysics(Ctx, remainingTime + timeTick, Iterations - 1);
			return;
		}

		// Compute move parameters
		const FVector MoveVelocity = CtxAccess(Velocity);
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
			MoveAlongFloor(Ctx, MoveVelocity, timeTick, &StepDownResult);

			if (IsFalling(Ctx))
			{
				// pawn decided to jump up
				const float DesiredDist = Delta.Size();
				if (DesiredDist > KINDA_SMALL_NUMBER)
				{
					const float ActualDist = (GetUpdatedComponentLocation(Ctx) - OldLocation).Size2D();
					remainingTime += timeTick * (1.f - min(1.f, ActualDist / DesiredDist));
				}
				StartNewPhysics(Ctx, remainingTime, Iterations);
				return;
			}
			else if (IsSwimming(Ctx)) //just entered water
			{
				StartSwimming(Ctx, OldLocation, OldVelocity, timeTick, remainingTime, Iterations);
				return;
			}
		}

		// Update floor.
		// StepUp might have already done it for us.
		if (StepDownResult.bComputedFloor)
		{
			CtxAccess(CurrentFloor) = StepDownResult.FloorResult;
		}
		else
		{
			FindFloor(Ctx, GetUpdatedComponentLocation(Ctx), CtxAccess(CurrentFloor), bZeroDelta, NULL);
		}

		// check for ledges here
		const bool bCheckLedges = !CanWalkOffLedges(Ctx);
		if (bCheckLedges && !CtxAccess(CurrentFloor).IsWalkableFloor())
		{
			// calculate possible alternate movement
			const FVector GravDir = FVector(0.f, 0.f, -1.f);
			const FVector NewDelta = bTriedLedgeMove ? FVector_ZeroVector : GetLedgeMove(Ctx, OldLocation, Delta, GravDir);
			if (!FVector_IsZero(NewDelta))
			{
				// first revert this move
				RevertMove(Ctx, OldLocation, OldBase, PreviousBaseLocation, OldFloor, false);

				// avoid repeated ledge moves if the first one fails
				bTriedLedgeMove = true;

				// Try new movement direction
				CtxAccess(Velocity) = NewDelta / timeTick;
				remainingTime += timeTick;
				continue;
			}
			else
			{
				// see if it is OK to jump
				// @todo collision : only thing that can be problem is that oldbase has world collision on
				bool bMustJump = bZeroDelta || (OldBase == NULL || (!OldBase->IsQueryCollisionEnabled() && MovementBaseUtility::IsDynamicBase(OldBase)));
				if ((bMustJump || !bCheckedFall) && CheckFall(Ctx, OldFloor, CtxAccess(CurrentFloor).HitResult, Delta, OldLocation, remainingTime, timeTick, Iterations, bMustJump))
				{
					return;
				}
				bCheckedFall = true;

				// revert this move
				RevertMove(Ctx, OldLocation, OldBase, PreviousBaseLocation, OldFloor, true);
				remainingTime = 0.f;
				break;
			}
		}
		else
		{
			// Validate the floor check
			if (CtxAccess(CurrentFloor).IsWalkableFloor())
			{
				if (Comp->ShouldCatchAir(OldFloor, CtxAccess(CurrentFloor)))
				{
					CtxAccess(CharacterOwner)->OnWalkingOffLedge(OldFloor.HitResult.ImpactNormal, OldFloor.HitResult.Normal, OldLocation, timeTick);
					if (IsMovingOnGround(Ctx))
					{
						// If still walking, then fall. If not, assume the user set a different mode they want to keep.
						StartFalling(Ctx, Iterations, remainingTime, timeTick, Delta, OldLocation);
					}
					return;
				}

				AdjustFloorHeight(Ctx);
				SetBase(Ctx, CtxAccess(CurrentFloor).HitResult.Component.Get(), CtxAccess(CurrentFloor).HitResult.BoneName);
			}
			else if (CtxAccess(CurrentFloor).HitResult.bStartPenetrating && remainingTime <= 0.f)
			{
				// The floor check failed because it started in penetration
				// We do not want to try to move downward because the downward sweep failed, rather we'd like to try to pop out of the floor.
				FHitResult Hit(CtxAccess(CurrentFloor).HitResult);
				Hit.TraceEnd = Hit.TraceStart + FVector(0.f, 0.f, MAX_FLOOR_DIST);
				const FVector RequestedAdjustment = GetPenetrationAdjustment(Ctx, Hit);
				Comp->ResolvePenetration(RequestedAdjustment, Hit, CtxAccess(UpdatedComponent_ComponentQuat));
				CtxAccess(bForceNextFloorCheck) = true;
			}

			// check if just entered water
			if (IsSwimming(Ctx))
			{
				StartSwimming(Ctx, OldLocation, CtxAccess(Velocity), timeTick, remainingTime, Iterations);
				return;
			}

			// See if we need to start falling.
			if (!CtxAccess(CurrentFloor).IsWalkableFloor() && !CtxAccess(CurrentFloor).HitResult.bStartPenetrating)
			{
				const bool bMustJump = CtxAccess(bJustTeleported) || bZeroDelta || (OldBase == NULL || (!OldBase->IsQueryCollisionEnabled() && MovementBaseUtility::IsDynamicBase(OldBase)));
				if ((bMustJump || !bCheckedFall) && CheckFall(Ctx, OldFloor, CtxAccess(CurrentFloor).HitResult, Delta, OldLocation, remainingTime, timeTick, Iterations, bMustJump))
				{
					return;
				}
				bCheckedFall = true;
			}
		}


		// Allow overlap events and such to change physics state and velocity
		if (IsMovingOnGround(Ctx))
		{
			// Make velocity reflect actual move
			if (!CtxAccess(bJustTeleported) && !HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity() && timeTick >= MIN_TICK_TIME)
			{
				// TODO-RootMotionSource: Allow this to happen during partial override Velocity, but only set allowed axes?
				CtxAccess(Velocity) = (GetUpdatedComponentLocation(Ctx) - OldLocation) / timeTick;
			}
		}

		// If we didn't move at all this iteration then abort (since future iterations will also be stuck).
		if (GetUpdatedComponentLocation(Ctx) == OldLocation)
		{
			remainingTime = 0.f;
			break;
		}
	}

	if (IsMovingOnGround(Ctx))
	{
		MaintainHorizontalGroundVelocity(Ctx);
	}
}

void PhysNavWalking(FISPCMovementContext Ctx, float deltaTime, int32 Iterations)
{
	unimplemented();
#if 0	// TODO ISPC
	SCOPE_CYCLE_COUNTER(STAT_CharPhysNavWalking);

	if (deltaTime < MIN_TICK_TIME)
	{
		return;
	}

	if ((!CtxAccess(CharacterOwner) || !CtxAccess(CharacterOwner)->Controller) && !Comp->bRunPhysicsWithNoController && !HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity())
	{
		CtxAccess(Acceleration) = FVector_ZeroVector;
		CtxAccess(Velocity) = FVector_ZeroVector;
		return;
	}

	RestorePreAdditiveRootMotionVelocity(Ctx);

	// Ensure velocity is horizontal.
	MaintainHorizontalGroundVelocity(Ctx);
	checkCode(ensureMsgf(!CtxAccess(Velocity).ContainsNaN(), TEXT("PhysNavWalking: Velocity contains NaN before CalcVelocity (%s)\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(Velocity).ToString()));

	//bound acceleration
	CtxAccess(Acceleration).z = 0.f;
	if (!HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity())
	{
		CalcVelocity(Ctx, deltaTime, Comp->GroundFriction, false, GetMaxBrakingDeceleration(Ctx));
		checkCode(ensureMsgf(!CtxAccess(Velocity).ContainsNaN(), TEXT("PhysNavWalking: Velocity contains NaN after CalcVelocity (%s)\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(Velocity).ToString()));
	}

	ApplyRootMotionToVelocity(Ctx, deltaTime);

	if( IsFalling(Ctx) )
	{
		// Root motion could have put us into Falling
		StartNewPhysics(Ctx, deltaTime, Iterations);
		return;
	}

	Iterations++;

	FVector DesiredMove = CtxAccess(Velocity);
	DesiredMove.z = 0.f;

	const FVector OldLocation = GetActorFeetLocation(Ctx);
	const FVector DeltaMove = DesiredMove * deltaTime;

	FVector AdjustedDest = OldLocation + DeltaMove;
	FNavLocation DestNavLocation;

	bool bSameNavLocation = false;
	if (Comp->CachedNavLocation.NodeRef != INVALID_NAVNODEREF)
	{
		if (Comp->bProjectNavMeshWalking)
		{
			const float DistSq2D = (OldLocation - Comp->CachedNavLocation.Location).SizeSquared2D();
			const float DistZ = FMath::Abs(OldLocation.z - Comp->CachedNavLocation.Location.Z);

			const float TotalCapsuleHeight = CtxAccess(CharacterOwner_CapsuleComponent_Size).y * CtxAccess(CharacterOwner_CapsuleComponent_Size).z * 2.0f;
			const float ProjectionScale = (OldLocation.z > Comp->CachedNavLocation.Location.Z) ? Comp->NavMeshProjectionHeightScaleUp : Comp->NavMeshProjectionHeightScaleDown;
			const float DistZThr = TotalCapsuleHeight * max(0.f, ProjectionScale);

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
		UE_LOG(LogUnrolledNavMeshMovement, VeryVerbose, TEXT("%s using cached navmesh location! (bProjectNavMeshWalking = %d)"), *GetNameSafe(CtxAccess(CharacterOwner)), Comp->bProjectNavMeshWalking);
	}
	else
	{
		SCOPE_CYCLE_COUNTER(STAT_CharNavProjectPoint);

		// Start the trace from the Z location of the last valid trace.
		// Otherwise if we are projecting our location to the underlying geometry and it's far above or below the navmesh,
		// we'll follow that geometry's plane out of range of valid navigation.
		if (bSameNavLocation && Comp->bProjectNavMeshWalking)
		{
			AdjustedDest.z = Comp->CachedNavLocation.Location.z;
		}

		// Find the point on the NavMesh
		const bool bHasNavigationData = FindNavFloor(Ctx, AdjustedDest, DestNavLocation);
		if (!bHasNavigationData)
		{
			SetMovementMode(Ctx, MOVE_Walking);
			return;
		}

		Comp->CachedNavLocation = DestNavLocation;
	}

	if (DestNavLocation.NodeRef != INVALID_NAVNODEREF)
	{
		FVector NewLocation(AdjustedDest.x, AdjustedDest.y, DestNavLocation.Location.Z);
		if (Comp->bProjectNavMeshWalking)
		{
			SCOPE_CYCLE_COUNTER(STAT_CharNavProjectLocation);
			const float TotalCapsuleHeight = CtxAccess(CharacterOwner_CapsuleComponent_Size).y * CtxAccess(CharacterOwner_CapsuleComponent_Size).z * 2.0f;
			const float UpOffset = TotalCapsuleHeight * max(0.f, Comp->NavMeshProjectionHeightScaleUp);
			const float DownOffset = TotalCapsuleHeight * max(0.f, Comp->NavMeshProjectionHeightScaleDown);
			NewLocation = ProjectLocationFromNavMesh(Comp-> deltaTime, OldLocation, NewLocation, UpOffset, DownOffset);
		}

		FVector AdjustedDelta = NewLocation - OldLocation;

		if (!AdjustedDelta.IsNearlyZero())
		{
			FHitResult HitResult;
			const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
			SafeMoveUpdatedComponent(Ctx, AdjustedDelta, UpdatedComponent->GetComponentQuat(), bSweepWhileNavWalking, HitResult);
		}

		// Update velocity to reflect actual move
		if (!bJustTeleported && !HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasVelocity())
		{
			CtxAccess(Velocity) = (GetActorFeetLocation(Ctx) - OldLocation) / deltaTime;
			MaintainHorizontalGroundVelocity(Ctx);
		}

		bJustTeleported = false;
	}
	else
	{
		StartFalling(Ctx, Iterations, deltaTime, deltaTime, DeltaMove, OldLocation);
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

	if (deltaTime < MIN_TICK_TIME)
	{
		return;
	}

	FVector FallAcceleration = GetFallingLateralAcceleration(Ctx, deltaTime);
	FallAcceleration.z = 0.f;
	const bool bHasAirControl = (FallAcceleration.SizeSquared2D() > 0.f);

	float remainingTime = deltaTime;
	while( (remainingTime >= MIN_TICK_TIME) && (Iterations < CtxAccess(MaxSimulationIterations)) )
	{
		Iterations++;
		const float timeTick = GetSimulationTimeStep(Ctx, remainingTime, Iterations);
		remainingTime -= timeTick;
		
		const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
		const FQuat PawnRotation = CtxAccess(UpdatedComponent_ComponentQuat);
		CtxAccess(bJustTeleported) = false;

		RestorePreAdditiveRootMotionVelocity(Ctx);

		FVector OldVelocity = CtxAccess(Velocity);
		FVector VelocityNoAirControl = CtxAccess(Velocity);

		// Apply input
		if (!HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity())
		{
			const float MaxDecel = GetMaxBrakingDeceleration(Ctx);
			// Compute VelocityNoAirControl
			if (bHasAirControl)
			{
				// Find velocity *without* acceleration.
				TGuardValue<FVector> RestoreAcceleration(CtxAccess(Acceleration), FVector_ZeroVector);
				TGuardValue<FVector> RestoreVelocity(CtxAccess(Velocity), CtxAccess(Velocity));
				CtxAccess(Velocity).z = 0.f;
				CalcVelocity(Ctx, timeTick, Comp->FallingLateralFriction, false, MaxDecel);
				VelocityNoAirControl = FVector(CtxAccess(Velocity).x, CtxAccess(Velocity).y, OldVelocity.Z);
			}

			// Compute Velocity
			{
				// Acceleration = FallAcceleration for CalcVelocity(), but we restore it after using it.
				TGuardValue<FVector> RestoreAcceleration(CtxAccess(Acceleration), FallAcceleration);
				CtxAccess(Velocity).z = 0.f;
				CalcVelocity(Ctx, timeTick, Comp->FallingLateralFriction, false, MaxDecel);
				CtxAccess(Velocity).z = OldVelocity.z;
			}

			// Just copy Velocity to VelocityNoAirControl if they are the same (ie no acceleration).
			if (!bHasAirControl)
			{
				VelocityNoAirControl = CtxAccess(Velocity);
			}
		}

		// Apply gravity
		const FVector Gravity(0.f, 0.f, GetGravityZ(Ctx));
		CtxAccess(Velocity) = NewFallVelocity(Ctx, CtxAccess(Velocity), Gravity, timeTick);
		VelocityNoAirControl = NewFallVelocity(Ctx, VelocityNoAirControl, Gravity, timeTick);
		const FVector AirControlAccel = (CtxAccess(Velocity) - VelocityNoAirControl) / timeTick;

		ApplyRootMotionToVelocity(Ctx, timeTick);

		if( Comp->bNotifyApex && CtxAccess(CharacterOwner)->Controller && (CtxAccess(Velocity).z <= 0.f) )
		{
			// Just passed jump apex since now going down
			Comp->bNotifyApex = false;
			NotifyJumpApex(Ctx);
		}


		// Move
		FHitResult Hit(1.f);
		FVector Adjusted = 0.5f*(OldVelocity + CtxAccess(Velocity)) * timeTick;
		const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
		SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, Adjusted, PawnRotation, true, Hit);
		
		if (!HasValidData(Ctx))
		{
			return;
		}
		
		float LastMoveTimeSlice = timeTick;
		float subTimeTickRemaining = timeTick * (1.f - Hit.Time);
		
		if ( IsSwimming(Ctx) ) //just entered water
		{
			remainingTime += subTimeTickRemaining;
			StartSwimming(Ctx, OldLocation, OldVelocity, timeTick, remainingTime, Iterations);
			return;
		}
		else if ( Hit.bBlockingHit )
		{
			if (IsValidLandingSpot(Ctx, GetUpdatedComponentLocation(Ctx), Hit))
			{
				remainingTime += subTimeTickRemaining;
				ProcessLanded(Ctx, Hit, remainingTime, Iterations);
				return;
			}
			else
			{
				// Compute impact deflection based on final velocity, not integration step.
				// This allows us to compute a new velocity from the deflected vector, and ensures the full gravity effect is included in the slide result.
				Adjusted = CtxAccess(Velocity) * timeTick;

				// See if we can convert a normally invalid landing spot (based on the hit result) to a usable one.
				if (!FHitResult_bStartPenetrating(Hit) && ShouldCheckForValidLandingSpot(Ctx, timeTick, Adjusted, Hit))
				{
					const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);
					FFindFloorResult FloorResult;
					FindFloor(Ctx, PawnLocation, FloorResult, false);
					if (FloorResult.IsWalkableFloor() && IsValidLandingSpot(Ctx, PawnLocation, FloorResult.HitResult))
					{
						remainingTime += subTimeTickRemaining;
						ProcessLanded(Ctx, FloorResult.HitResult, remainingTime, Iterations);
						return;
					}
				}

				HandleImpact(Ctx, Hit, LastMoveTimeSlice, Adjusted);
				
				// If we've changed physics mode, abort.
				if (!HasValidData(Ctx) || !IsFalling(Ctx))
				{
					return;
				}

				// Limit air control based on what we hit.
				// We moved to the impact point using air control, but may want to deflect from there based on a limited air control acceleration.
				if (bHasAirControl)
				{
					const bool bCheckLandingSpot = false; // we already checked above.
					const FVector AirControlDeltaV = LimitAirControl(Ctx, LastMoveTimeSlice, AirControlAccel, Hit, bCheckLandingSpot) * LastMoveTimeSlice;
					Adjusted = (VelocityNoAirControl + AirControlDeltaV) * LastMoveTimeSlice;
				}

				const FVector OldHitNormal = Hit.Normal;
				const FVector OldHitImpactNormal = Hit.ImpactNormal;				
				FVector Delta = ComputeSlideVector(Ctx, Adjusted, 1.f - Hit.Time, OldHitNormal, Hit);

				// Compute velocity after deflection (only gravity component for RootMotion)
				if (subTimeTickRemaining > KINDA_SMALL_NUMBER && !CtxAccess(bJustTeleported))
				{
					const FVector NewVelocity = (Delta / subTimeTickRemaining);
					CtxAccess(Velocity) = HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity() ? FVector(CtxAccess(Velocity).x, CtxAccess(Velocity).y, NewVelocity.Z) : NewVelocity;
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

						if (IsValidLandingSpot(Ctx, GetUpdatedComponentLocation(Ctx), Hit))
						{
							remainingTime += subTimeTickRemaining;
							ProcessLanded(Ctx, Hit, remainingTime, Iterations);
							return;
						}

						HandleImpact(Ctx, Hit, LastMoveTimeSlice, Delta);

						// If we've changed physics mode, abort.
						if (!HasValidData(Ctx) || !IsFalling(Ctx))
						{
							return;
						}

						// Act as if there was no air control on the last move when computing new deflection.
						if (bHasAirControl && Hit.Normal.z > VERTICAL_SLOPE_NORMAL_Z)
						{
							const FVector LastMoveNoAirControl = VelocityNoAirControl * LastMoveTimeSlice;
							Delta = ComputeSlideVector(Ctx, LastMoveNoAirControl, 1.f, OldHitNormal, Hit);
						}

						FVector PreTwoWallDelta = Delta;
						TwoWallAdjust(Ctx, Delta, Hit, OldHitNormal);

						// Limit air control, but allow a slide along the second wall.
						if (bHasAirControl)
						{
							const bool bCheckLandingSpot = false; // we already checked above.
							const FVector AirControlDeltaV = LimitAirControl(Ctx, subTimeTickRemaining, AirControlAccel, Hit, bCheckLandingSpot) * subTimeTickRemaining;

							// Only allow if not back in to first wall
							if (FVector::DotProduct(AirControlDeltaV, OldHitNormal) > 0.f)
							{
								Delta += (AirControlDeltaV * subTimeTickRemaining);
							}
						}

						// Compute velocity after deflection (only gravity component for RootMotion)
						if (subTimeTickRemaining > KINDA_SMALL_NUMBER && !CtxAccess(bJustTeleported))
						{
							const FVector NewVelocity = (Delta / subTimeTickRemaining);
							CtxAccess(Velocity) = HasAnimRootMotion(Ctx) && !Comp->CurrentRootMotion.HasOverrideVelocity() ? FVector(CtxAccess(Velocity).x, CtxAccess(Velocity).y, NewVelocity.Z) : NewVelocity;
						}

						// bDitch=true means that pawn is straddling two slopes, neither of which he can stand on
						bool bDitch = ( (OldHitImpactNormal.z > 0.f) && (Hit.ImpactNormal.z > 0.f) && (FMath::Abs(Delta.Z) <= KINDA_SMALL_NUMBER) && ((Hit.ImpactNormal | OldHitImpactNormal) < 0.f) );
						SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, Delta, PawnRotation, true, Hit);
						if ( Hit.Time == 0.f )
						{
							// if we are stuck then try to side step
							FVector SideDelta = (OldHitNormal + Hit.ImpactNormal).GetSafeNormal2D();
							if ( SideDelta.IsNearlyZero() )
							{
								SideDelta = FVector(OldHitNormal.y, -OldHitNormal.x, 0).GetSafeNormal();
							}
							SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, SideDelta, PawnRotation, true, Hit);
						}
							
						if ( bDitch || IsValidLandingSpot(Ctx, GetUpdatedComponentLocation(Ctx), Hit) || Hit.Time == 0.f  )
						{
							remainingTime = 0.f;
							ProcessLanded(Ctx, Hit, remainingTime, Iterations);
							return;
						}
						else if (GetPerchRadiusThreshold(Ctx) > 0.f && Hit.Time == 1.f && OldHitImpactNormal.z >= Comp->GetWalkableFloorZ())
						{
							// We might be in a virtual 'ditch' within our perch radius. This is rare.
							const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);
							const float ZMovedDist = FMath::Abs(PawnLocation.z - OldLocation.Z);
							const float MovedDist2DSq = (PawnLocation - OldLocation).SizeSquared2D();
							if (ZMovedDist <= 0.2f * timeTick && MovedDist2DSq <= 4.f * timeTick)
							{
								CtxAccess(Velocity).x += 0.25f * GetMaxSpeed(Ctx) * (FMath::FRand() - 0.5f);
								CtxAccess(Velocity).y += 0.25f * GetMaxSpeed(Ctx) * (FMath::FRand() - 0.5f);
								CtxAccess(Velocity).z = max<float>(Comp->JumpZVelocity * 0.25f, 1.f);
								Delta = CtxAccess(Velocity) * timeTick;
								SafeMoveUpdatedComponent(Ctx, bMoveIgnoreFirstBlockingOverlap, Delta, PawnRotation, true, Hit);
							}
						}
					}
				}
			}
		}

		if (CtxAccess(Velocity).SizeSquared2D() <= KINDA_SMALL_NUMBER * 10.f)
		{
			CtxAccess(Velocity).x = 0.f;
			CtxAccess(Velocity).y = 0.f;
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
		if (Comp->GetNavData() == NULL)
		{
			NewMovementMode = MOVE_Walking;
		}
#endif
	}

	// Do nothing if nothing is changing.
	if (CtxAccess(MovementMode) == NewMovementMode)
	{
		// Allow changes in custom sub-mode.
		if ((NewMovementMode != MOVE_Custom) || (NewCustomMode == Comp->CustomMovementMode))
		{
			return;
		}
	}

	const EMovementMode PrevMovementMode = CtxAccess(MovementMode);
	const uint8 PrevCustomMode = Comp->CustomMovementMode;

	CtxAccess(MovementMode) = NewMovementMode;
	Comp->CustomMovementMode = NewCustomMode;

	// We allow setting movement mode before we have a component to update, in case this happens at startup.
	if (!HasValidData(Ctx))
	{
		return;
	}
	
	// Handle change in movement mode
	OnMovementModeChanged(Ctx, PrevMovementMode, PrevCustomMode);

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
	const bool bOnGround = (CtxAccess(MovementMode) == MOVE_Walking || CtxAccess(MovementMode) == MOVE_NavWalking);
	if (bOnGround && CtxAccess(MovementMode) != NewGroundMovementMode)
	{
		SetMovementMode(Ctx, NewGroundMovementMode);
	}
#endif
}

void SetDefaultMovementMode(FISPCMovementContext Ctx)
{
	// check for water volume
	if (CanEverSwim(Ctx) && IsInWater(Ctx))
	{
		SetMovementMode(Ctx, Comp->DefaultWaterMovementMode);
	}
	else if ( !CtxAccess(CharacterOwner) || CtxAccess(MovementMode) != Comp->DefaultLandMovementMode )
	{
		const float SavedVelocityZ = CtxAccess(Velocity).z;
		SetMovementMode(Ctx, Comp->DefaultLandMovementMode);

		// Avoid 1-frame delay if trying to walk but walking fails at this location.
		if (CtxAccess(MovementMode) == MOVE_Walking && GetMovementBase(Ctx) == NULL)
		{
			CtxAccess(Velocity).z = SavedVelocityZ; // Prevent temporary walking state from zeroing Z velocity.
			SetMovementMode(Ctx, MOVE_Falling);
		}
	}
}

void OnMovementModeChanged(FISPCMovementContext Ctx, EMovementMode PreviousMovementMode, uint8 PreviousCustomMode)
{
	if (!HasValidData(Ctx))
	{
		return;
	}

	// Update collision settings if needed
	if (CtxAccess(MovementMode) == MOVE_NavWalking)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		Comp->SetNavWalkingPhysics(true);
		SetGroundMovementMode(Ctx, CtxAccess(MovementMode));
		// Walking uses only XY velocity
		CtxAccess(Velocity).z = 0.f;
#endif
	}
	else if (PreviousMovementMode == MOVE_NavWalking)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		if (CtxAccess(MovementMode) == Comp->DefaultLandMovementMode || Comp->IsWalking())
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
	if (CtxAccess(MovementMode) == MOVE_Walking)
	{
		// Walking uses only XY velocity, and must be on a walkable floor, with a Base.
		CtxAccess(Velocity).z = 0.f;
		Comp->bCrouchMaintainsBaseLocation = true;
		SetGroundMovementMode(Ctx, CtxAccess(MovementMode));

		// make sure we update our new floor/base on initial entry of the walking physics
		FindFloor(Ctx, GetUpdatedComponentLocation(Ctx), CtxAccess(CurrentFloor), false);
		AdjustFloorHeight(Ctx);
		SetBaseFromFloor(Ctx, CtxAccess(CurrentFloor));
	}
	else
	{
		CtxAccess(CurrentFloor).Clear();
		Comp->bCrouchMaintainsBaseLocation = false;

		if (CtxAccess(MovementMode) == MOVE_Falling)
		{
			CtxAccess(Velocity) += GetImpartedMovementBaseVelocity(Ctx);
			// TODO ISPC: foreach_active?
			CtxAccess(CharacterOwner)->Falling();
		}

		SetBase(Ctx, NULL);

		if (CtxAccess(MovementMode) == MOVE_None)
		{
			// Kill velocity and clear queued up events
			StopMovementKeepPathing(Ctx);
			ClearJumpInput(CtxAccess(CharacterOwner));
			ClearAccumulatedForces(Ctx);
		}
	}

	if (CtxAccess(MovementMode) == MOVE_Falling && PreviousMovementMode != MOVE_Falling && Comp->PathFollowingComp.IsValid())
	{
		// TODO ISPC: foreach_active?
		Comp->PathFollowingComp->OnStartedFalling();
	}

	// TODO ISPC: foreach_active?
	CtxAccess(CharacterOwner)->OnMovementModeChanged(PreviousMovementMode, PreviousCustomMode);
	ensureMsgf(Comp->GetGroundMovementMode() == MOVE_Walking || Comp->GetGroundMovementMode() == MOVE_NavWalking, TEXT("Invalid GroundMovementMode %d. MovementMode: %d, PreviousMovementMode: %d"), Comp->GetGroundMovementMode(), CtxAccess(MovementMode).GetValue(), PreviousMovementMode);
};

bool CheckLedgeDirection(FISPCMovementContext Ctx, const FVector& OldLocation, const FVector& SideStep, const FVector& GravDir)
{
	const FVector SideDest = OldLocation + SideStep;
	FCollisionQueryParams CapsuleParams(SCENE_QUERY_STAT(CheckLedgeDirection), false, CtxAccess(CharacterOwner));
	FCollisionResponseParams ResponseParam;
	InitCollisionParams(Ctx, CapsuleParams, ResponseParam);
	// ISPC: This can be cached, no point in unrolling.
	const FCollisionShape CapsuleShape = CtxAccess(PawnCapsuleCollisionShape_ShrinkCapsuleExtent_None);
	const ECollisionChannel CollisionChannel = CtxAccess(UpdatedComponent_CollisionObjectType);
	FHitResult Result(1.f);
	SweepSingleByChannel(CtxAccess(Comp), &Result, OldLocation, SideDest, FQuat_Identity, CollisionChannel, CapsuleShape, CapsuleParams, ResponseParam);

	if ( !Result.bBlockingHit || IsWalkable(Result, Comp->GetWalkableFloorZ()) )
	{
		if ( !Result.bBlockingHit )
		{
			SweepSingleByChannel(CtxAccess(Comp), &Result, SideDest, SideDest + GravDir * (Comp->MaxStepHeight + Comp->LedgeCheckThreshold), FQuat_Identity, CollisionChannel, CapsuleShape, CapsuleParams, ResponseParam);
		}
		if ( (Result.Time < 1.f) && IsWalkable(Result, Comp->GetWalkableFloorZ()) )
		{
			return true;
		}
	}
	return false;
}

FVector GetLedgeMove(FISPCMovementContext Ctx, const FVector& OldLocation, const FVector& Delta, const FVector& GravDir)
{
	if (!HasValidData(Ctx) || FVector_IsZero(Delta))
	{
		return FVector_ZeroVector;
	}

	FVector SideDir(Delta.y, -1.f * Delta.x, 0.f);
		
	// try left
	if ( CheckLedgeDirection(Ctx, OldLocation, SideDir, GravDir) )
	{
		return SideDir;
	}

	// try right
	SideDir *= -1.f;
	if ( CheckLedgeDirection(Ctx, OldLocation, SideDir, GravDir) )
	{
		return SideDir;
	}
	
	return FVector_ZeroVector;
}

bool CanWalkOffLedges(FISPCMovementContext Ctx)
{
	if (!Comp->bCanWalkOffLedgesWhenCrouching && IsCrouching(Ctx))
	{
		return false;
	}	

	return Comp->bCanWalkOffLedges;
}

bool CheckFall(FISPCMovementContext Ctx, const FFindFloorResult& OldFloor, const FHitResult& Hit, const FVector& Delta, const FVector& OldLocation, float remainingTime, float timeTick, int32 Iterations, bool bMustJump)
{
	if (!HasValidData(Ctx))
	{
		return false;
	}

	if (bMustJump || CanWalkOffLedges(Ctx))
	{
		CtxAccess(CharacterOwner)->OnWalkingOffLedge(OldFloor.HitResult.ImpactNormal, OldFloor.HitResult.Normal, OldLocation, timeTick);
		if (IsMovingOnGround(Ctx))
		{
			// If still walking, then fall. If not, assume the user set a different mode they want to keep.
			StartFalling(Ctx, Iterations, remainingTime, timeTick, Delta, OldLocation);
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
					: remainingTime + timeTick * (1.f - min(1.f,ActualDist/DesiredDist));

	if (IsMovingOnGround(Ctx) )
	{
		// This is to catch cases where the first frame of PIE is executed, and the
		// level is not yet visible. In those cases, the player will fall out of the
		// world... So, don't set MOVE_Falling straight away.
		if ( !GIsEditor || (GetWorld()->HasBegunPlay() && (GetWorld()->GetTimeSeconds() >= 1.f)) )
		{
			SetMovementMode(Ctx, MOVE_Falling); //default behavior if script didn't change physics
		}
		else
		{
			// Make sure that the floor check code continues processing during this delay.
			CtxAccess(bForceNextFloorCheck) = true;
		}
	}
	StartNewPhysics(Comp,remainingTime,Iterations);
}

void FindFloor(FISPCMovementContext Ctx, const FVector& CapsuleLocation, FFindFloorResult& OutFloorResult, bool bZeroDelta, const FHitResult* DownwardSweepResult)
{
	SCOPE_CYCLE_COUNTER(STAT_CharFindFloor);

	// No collision, no floor...
	if (!HasValidData(Ctx) || !CtxAccess(UpdatedComponent)->IsQueryCollisionEnabled())
	{
		OutFloorResult.Clear();
		return;
	}

	UE_LOG(LogISPCCharacterMovement, VeryVerbose, TEXT("[Role:%d] FindFloor: %s at location %s"), (int32)CtxAccess(CharacterOwner_Role), *GetNameSafe(CtxAccess(CharacterOwner)), *CapsuleLocation.ToString());
	check(CtxAccess(CharacterOwner)->GetCapsuleComponent());

	// Increase height check slightly if walking, to prevent floor height adjustment from later invalidating the floor result.
	const float HeightCheckAdjust = (IsMovingOnGround(Ctx) ? MAX_FLOOR_DIST + KINDA_SMALL_NUMBER : -MAX_FLOOR_DIST);

	float FloorSweepTraceDist = max(MAX_FLOOR_DIST, Comp->MaxStepHeight + HeightCheckAdjust);
	float FloorLineTraceDist = FloorSweepTraceDist;
	bool bNeedToValidateFloor = true;

	// Sweep floor
	if (FloorLineTraceDist > 0.f || FloorSweepTraceDist > 0.f)
	{
		if (Comp->bAlwaysCheckFloor || !bZeroDelta || CtxAccess(bForceNextFloorCheck) || CtxAccess(bJustTeleported))
		{
			CtxAccess(bForceNextFloorCheck) = false;
			ComputeFloorDist(Ctx, CapsuleLocation, FloorLineTraceDist, FloorSweepTraceDist, OutFloorResult, CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleRadius(), DownwardSweepResult);
		}
		else
		{
			// Force floor check if base has collision disabled or if it does not block us.
			UPrimitiveComponent* MovementBase = CtxAccess(CharacterOwner_MovementBase);
			const AActor* BaseActor = MovementBase ? MovementBase->GetOwner() : NULL;
			const ECollisionChannel CollisionChannel = CtxAccess(UpdatedComponent_CollisionObjectType);

			if (MovementBase != NULL)
			{
				CtxAccess(bForceNextFloorCheck) = !MovementBase->IsQueryCollisionEnabled()
					|| MovementBase->GetCollisionResponseToChannel(CollisionChannel) != ECR_Block
					|| MovementBaseUtility::IsDynamicBase(MovementBase);
			}

			const bool IsActorBasePendingKill = BaseActor && BaseActor->IsPendingKill();

			if (!CtxAccess(bForceNextFloorCheck) && !IsActorBasePendingKill && MovementBase)
			{
				//UE_LOG(LogISPCCharacterMovement, Log, TEXT("%s SKIP check for floor"), *CharacterOwner->GetName());
				OutFloorResult = CtxAccess(CurrentFloor);
				bNeedToValidateFloor = false;
			}
			else
			{
				CtxAccess(bForceNextFloorCheck) = false;
				ComputeFloorDist(Ctx, CapsuleLocation, FloorLineTraceDist, FloorSweepTraceDist, OutFloorResult, CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleRadius(), DownwardSweepResult);
			}
		}
	}

	// OutFloorResult.HitResult is now the result of the vertical floor check.
	// See if we should try to "perch" at this location.
	if (bNeedToValidateFloor && OutFloorResult.bBlockingHit && !OutFloorResult.bLineTrace)
	{
		const bool bCheckRadius = true;
		if (ShouldComputePerchResult(Ctx, OutFloorResult.HitResult, bCheckRadius))
		{
			float MaxPerchFloorDist = max(MAX_FLOOR_DIST, Comp->MaxStepHeight + HeightCheckAdjust);
			if (IsMovingOnGround(Ctx))
			{
				MaxPerchFloorDist += max(0.f, Comp->PerchAdditionalHeight);
			}

			FFindFloorResult PerchFloorResult;
			if (ComputePerchResult(Ctx, GetValidPerchRadius(Ctx), OutFloorResult.HitResult, MaxPerchFloorDist, PerchFloorResult))
			{
				// Don't allow the floor distance adjustment to push us up too high, or we will move beyond the perch distance and fall next time.
				const float AvgFloorDist = (MIN_FLOOR_DIST + MAX_FLOOR_DIST) * 0.5f;
				const float MoveUpDist = (AvgFloorDist - OutFloorResult.FloorDist);
				if (MoveUpDist + PerchFloorResult.FloorDist >= MaxPerchFloorDist)
				{
					OutFloorResult.FloorDist = AvgFloorDist;
				}

				// If the regular capsule is on an unwalkable surface but the perched one would allow us to stand, override the normal to be one that is walkable.
				if (!OutFloorResult.bWalkableFloor)
				{
					OutFloorResult.SetFromLineTrace(PerchFloorResult.HitResult, OutFloorResult.FloorDist, min(PerchFloorResult.FloorDist, PerchFloorResult.LineDist), true);
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

bool HasValidData(const varying FISPCMovementContext Ctx)
{
	bool bIsValid = CtxAccess(UpdatedComponent) && IsValid(CtxAccess(CharacterOwner));
#if ENABLE_NAN_DIAGNOSTIC
	if (bIsValid)
	{
		// NaN-checking updates
		if (CtxAccess(Velocity).ContainsNaN())
		{
			logOrEnsureNanError(TEXT("UCharacterMovementComponent::HasValidData() detected NaN/INF for (%s) in Velocity:\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(Velocity).ToString());
			CtxAccess(Velocity) = FVector_ZeroVector;
		}
		if (!CtxAccess(UpdatedComponent)->GetComponentTransform().IsValid())
		{
			logOrEnsureNanError(TEXT("UCharacterMovementComponent::HasValidData() detected NaN/INF for (%s) in UpdatedComponent->ComponentTransform:\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(UpdatedComponent)->GetComponentTransform().ToHumanReadableString());
		}
		if (CtxAccess(UpdatedComponent)->GetComponentRotation().ContainsNaN())
		{
			logOrEnsureNanError(TEXT("UCharacterMovementComponent::HasValidData() detected NaN/INF for (%s) in UpdatedComponent->GetComponentRotation():\n%s"), *GetPathNameSafe(Ctx), *CtxAccess(UpdatedComponent)->GetComponentRotation().ToString());
		}
	}
#endif
	return bIsValid;
}

#if UNIMPLEMENTED_CODE
void ComputeFloorDist(FISPCMovementContext Ctx, const FVector& CapsuleLocation, float LineDistance, float SweepDistance, FFindFloorResult& OutFloorResult, float SweepRadius, const FHitResult* DownwardSweepResult)
{
	UE_LOG(LogISPCCharacterMovement, VeryVerbose, TEXT("[Role:%d] ComputeFloorDist: %s at location %s"), (int32)CtxAccess(CharacterOwner_Role), *GetNameSafe(CtxAccess(CharacterOwner)), *CapsuleLocation.ToString());
	OutFloorResult.Clear();

	float PawnRadius, PawnHalfHeight;
	CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

	bool bSkipSweep = false;
	if (DownwardSweepResult != NULL && DownwardSweepResult->IsValidBlockingHit())
	{
		// Only if the supplied sweep was vertical and downward.
		if ((DownwardSweepResult->TraceStart.z > DownwardSweepResult->TraceEnd.Z) &&
			(DownwardSweepResult->TraceStart - DownwardSweepResult->TraceEnd).SizeSquared2D() <= KINDA_SMALL_NUMBER)
		{
			// Reject hits that are barely on the cusp of the radius of the capsule
			if (IsWithinEdgeTolerance(DownwardSweepResult->Location, DownwardSweepResult->ImpactPoint, PawnRadius))
			{
				// Don't try a redundant sweep, regardless of whether this sweep is usable.
				bSkipSweep = true;

				const bool bIsWalkable = IsWalkable(*DownwardSweepResult, Comp->GetWalkableFloorZ());
				const float FloorDist = (CapsuleLocation.z - DownwardSweepResult->Location.Z);
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
	FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(ComputeFloorDist), false, CtxAccess(CharacterOwner));
	FCollisionResponseParams ResponseParam;
	InitCollisionParams(Ctx, QueryParams, ResponseParam);
	const ECollisionChannel CollisionChannel = CtxAccess(UpdatedComponent_CollisionObjectType);

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
		bBlockingHit = FloorSweepTest(Ctx, Hit, CapsuleLocation, CapsuleLocation + FVector(0.f, 0.f, -TraceDist), CollisionChannel, CapsuleShape, QueryParams, ResponseParam);

		if (bBlockingHit)
		{
			// Reject hits adjacent to us, we only care about hits on the bottom portion of our capsule.
			// Check 2D distance to impact point, reject if within a tolerance from radius.
			if (FHitResult_bStartPenetrating(Hit) || !IsWithinEdgeTolerance(CapsuleLocation, Hit.ImpactPoint, CapsuleShape.Capsule.Radius))
			{
				// Use a capsule with a slightly smaller radius and shorter height to avoid the adjacent object.
				// Capsule must not be nearly zero or the trace will fall back to a line trace from the start point and have the wrong length.
				CapsuleShape.Capsule.Radius = max(0.f, CapsuleShape.Capsule.Radius - SWEEP_EDGE_REJECT_DISTANCE - KINDA_SMALL_NUMBER);
				if (!CapsuleShape.IsNearlyZero())
				{
					ShrinkHeight = (PawnHalfHeight - PawnRadius) * (1.f - ShrinkScaleOverlap);
					TraceDist = SweepDistance + ShrinkHeight;
					CapsuleShape.Capsule.HalfHeight = max(PawnHalfHeight - ShrinkHeight, CapsuleShape.Capsule.Radius);
					Hit.Reset(1.f, false);

					bBlockingHit = FloorSweepTest(Ctx, Hit, CapsuleLocation, CapsuleLocation + FVector(0.f, 0.f, -TraceDist), CollisionChannel, CapsuleShape, QueryParams, ResponseParam);
				}
			}

			// Reduce hit distance by ShrinkHeight because we shrank the capsule for the trace.
			// We allow negative distances here, because this allows us to pull out of penetrations.
			const float MaxPenetrationAdjust = max(MAX_FLOOR_DIST, PawnRadius);
			const float SweepResult = max(-MaxPenetrationAdjust, Hit.Time * TraceDist - ShrinkHeight);

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
				const float MaxPenetrationAdjust = max(MAX_FLOOR_DIST, PawnRadius);
				const float LineResult = max(-MaxPenetrationAdjust, Hit.Time * TraceDist - ShrinkHeight);

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
	)
{
	bool bBlockingHit = false;

	if (!Comp->bUseFlatBaseForFloorChecks)
	{
		bBlockingHit = SweepSingleByChannel(CtxAccess(Comp), &OutHit, Start, End, FQuat_Identity, TraceChannel, CollisionShape, Params, ResponseParam);
	}
	else
	{
		// Test with a box that is enclosed by the capsule.
		const float CapsuleRadius = CollisionShape.GetCapsuleRadius();
		const float CapsuleHeight = CollisionShape.GetCapsuleHalfHeight();
		const FCollisionShape BoxShape = FCollisionShape::MakeBox(FVector(CapsuleRadius * 0.707f, CapsuleRadius * 0.707f, CapsuleHeight));

		// First test with the box rotated so the corners are along the major axes (ie rotated 45 degrees).
		bBlockingHit = SweepSingleByChannel(CtxAccess(Comp), &OutHit, Start, End, FQuat(FVector(0.f, 0.f, -1.f), PI * 0.25f), TraceChannel, BoxShape, Params, ResponseParam);

		if (!bBlockingHit)
		{
			// Test again with the same box, not rotated.
			OutHit.Reset(1.f, false);
			bBlockingHit = SweepSingleByChannel(CtxAccess(Comp), &OutHit, Start, End, FQuat_Identity, TraceChannel, BoxShape, Params, ResponseParam);
		}
	}

	return bBlockingHit;
}

void RevertMove(FISPCMovementContext Ctx, const FVector& OldLocation, UPrimitiveComponent* OldBase, const FVector& PreviousBaseLocation, const FFindFloorResult& OldFloor, bool bFailMove)
{
	//UE_LOG(LogISPCCharacterMovement, Log, TEXT("RevertMove from %f %f %f to %f %f %f"), CharacterOwner->Location.x, CharacterOwner->Location.y, CharacterOwner->Location.Z, OldLocation.x, OldLocation.y, OldLocation.Z);
	// TODO ISPC: foreach_active?
	CtxAccess(UpdatedComponent)->SetWorldLocation(OldLocation, false);

	//UE_LOG(LogISPCCharacterMovement, Log, TEXT("Now at %f %f %f"), CharacterOwner->Location.x, CharacterOwner->Location.y, CharacterOwner->Location.Z);
	CtxAccess(bJustTeleported) = false;
	// if our previous base couldn't have moved or changed in any physics-affecting way, restore it
	if (IsValid(OldBase) &&
		(!MovementBaseUtility::IsDynamicBase(OldBase) ||
		(OldBase->Mobility == EComponentMobility::Static) ||
			(OldBase->GetComponentLocation() == PreviousBaseLocation)
			)
		)
	{
		CtxAccess(CurrentFloor) = OldFloor;
		SetBase(Ctx, OldBase, OldFloor.HitResult.BoneName);
	}
	else
	{
		SetBase(Ctx, NULL);
	}

	if (bFailMove)
	{
		// end movement now
		CtxAccess(Velocity) = FVector_ZeroVector;
		CtxAccess(Acceleration) = FVector_ZeroVector;
		//UE_LOG(LogISPCCharacterMovement, Log, TEXT("%s FAILMOVE RevertMove"), *CharacterOwner->GetName());
	}
}

FVector ComputeGroundMovementDelta(FISPCMovementContext Ctx, const FVector& Delta, const FHitResult& RampHit, const bool bHitFromLineTrace)
{
	const FVector FloorNormal = RampHit.ImpactNormal;
	const FVector ContactNormal = RampHit.Normal;

	if (FloorNormal.z < (1.f - KINDA_SMALL_NUMBER) && FloorNormal.z > KINDA_SMALL_NUMBER && ContactNormal.z > KINDA_SMALL_NUMBER && !bHitFromLineTrace && IsWalkable(RampHit, Comp->GetWalkableFloorZ()))
	{
		// Compute a vector that moves parallel to the surface, by projecting the horizontal movement direction onto the ramp.
		const float FloorDotDelta = (FloorNormal | Delta);
		FVector RampMovement(Delta.x, Delta.y, -FloorDotDelta / FloorNormal.Z);
		
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
			if (Hit == NULL)
			{
				UE_LOG(LogISPCCharacterMovement, Log, TEXT("%s is stuck and failed to move! (%d other events since notify)"), GetName(CtxAccess(CharacterOwner)), Comp->StuckWarningCountSinceNotify);
			}
			else
			{
				UE_LOG(LogISPCCharacterMovement, Log, TEXT("%s is stuck and failed to move! Velocity: X=%3.2f Y=%3.2f Z=%3.2f Location: X=%3.2f Y=%3.2f Z=%3.2f Normal: X=%3.2f Y=%3.2f Z=%3.2f PenetrationDepth:%.3f Actor:%s Component:%s BoneName:%s (%d other events since notify)"),
					   *GetNameSafe(CtxAccess(CharacterOwner)),
					   CtxAccess(Velocity).x, CtxAccess(Velocity).y, CtxAccess(Velocity).Z,
					   Hit->Location.x, Hit->Location.y, Hit->Location.Z,
					   Hit->Normal.x, Hit->Normal.y, Hit->Normal.Z,
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
	CtxAccess(bJustTeleported) = true;
}

void MoveAlongFloor(FISPCMovementContext Ctx, const FVector& InVelocity, float DeltaSeconds, UCharacterMovementComponent::FStepDownResult* OutStepDownResult)
{
	if (!CtxAccess(CurrentFloor).IsWalkableFloor())
	{
		return;
	}

	// Move along the current floor
	const FVector Delta = FVector(InVelocity.x, InVelocity.y, 0.f) * DeltaSeconds;
	FHitResult Hit(1.f);
	FVector RampVector = ComputeGroundMovementDelta(Ctx, Delta, CtxAccess(CurrentFloor).HitResult, CtxAccess(CurrentFloor).bLineTrace);
	const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
	SafeMoveUpdatedComponent(Ctx, bMoveIgnoreFirstBlockingOverlap, RampVector, CtxAccess(UpdatedComponent_ComponentQuat), true, Hit);
	float LastMoveTimeSlice = DeltaSeconds;
	
	if (FHitResult_bStartPenetrating(Hit))
	{
		// Allow this hit to be used as an impact we can deflect off, otherwise we do nothing the rest of the update and appear to hitch.
		HandleImpact(Ctx, Hit);
		SlideAlongSurface(Ctx, Delta, 1.f, Hit.Normal, Hit, true);

		if (FHitResult_bStartPenetrating(Hit))
		{
			OnCharacterStuckInGeometry(Ctx, &Hit);
		}
	}
	else if (Hit.IsValidBlockingHit())
	{
		// We impacted something (most likely another ramp, but possibly a barrier).
		float PercentTimeApplied = Hit.Time;
		if ((Hit.Time > 0.f) && (Hit.Normal.z > KINDA_SMALL_NUMBER) && IsWalkable(Hit, Comp->GetWalkableFloorZ()))
		{
			// Another walkable ramp.
			const float InitialPercentRemaining = 1.f - PercentTimeApplied;
			RampVector = ComputeGroundMovementDelta(Ctx, Delta * InitialPercentRemaining, Hit, false);
			LastMoveTimeSlice = InitialPercentRemaining * LastMoveTimeSlice;
			SafeMoveUpdatedComponent(Ctx, bMoveIgnoreFirstBlockingOverlap, RampVector, CtxAccess(UpdatedComponent_ComponentQuat), true, Hit);

			const float SecondHitPercent = Hit.Time * InitialPercentRemaining;
			PercentTimeApplied = FMath::Clamp(PercentTimeApplied + SecondHitPercent, 0.f, 1.f);
		}

		if (Hit.IsValidBlockingHit())
		{
			if (CanStepUp(Ctx, Hit) || (CtxAccess(CharacterOwner_MovementBase) != NULL && CtxAccess(CharacterOwner_MovementBase)->GetOwner() == Hit.GetActor()))
			{
				// hit a barrier, try to step up
				const FVector GravDir(0.f, 0.f, -1.f);
				if (!StepUp(Ctx, GravDir, Delta * (1.f - PercentTimeApplied), Hit, OutStepDownResult))
				{
					UE_LOG(LogISPCCharacterMovement, Verbose, TEXT("- StepUp (ImpactNormal %s, Normal %s"), *Hit.ImpactNormal.ToString(), *Hit.Normal.ToString());
					HandleImpact(Ctx, Hit, LastMoveTimeSlice, RampVector);
					SlideAlongSurface(Ctx, Delta, 1.f - PercentTimeApplied, Hit.Normal, Hit, true);
				}
				else
				{
					// Don't recalculate velocity based on this height adjustment, if considering vertical adjustments.
					UE_LOG(LogISPCCharacterMovement, Verbose, TEXT("+ StepUp (ImpactNormal %s, Normal %s"), *Hit.ImpactNormal.ToString(), *Hit.Normal.ToString());
					CtxAccess(bJustTeleported) |= !Comp->bMaintainHorizontalGroundVelocity;
				}
			}
			else if ( Hit.Component.IsValid() && !Hit.Component.Get()->CanCharacterStepUp(CtxAccess(CharacterOwner)) )
			{
				HandleImpact(Ctx, Hit, LastMoveTimeSlice, RampVector);
				SlideAlongSurface(Ctx, Delta, 1.f - PercentTimeApplied, Hit.Normal, Hit, true);
			}
		}
	}
}

void MaintainHorizontalGroundVelocity(FISPCMovementContext Ctx)
{
	if (CtxAccess(Velocity).z != 0.f)
	{
		if (Comp->bMaintainHorizontalGroundVelocity)
		{
			// Ramp movement already maintained the velocity, so we just want to remove the vertical component.
			CtxAccess(Velocity).z = 0.f;
		}
		else
		{
			// Rescale velocity to be horizontal but maintain magnitude of last update.
			CtxAccess(Velocity) = CtxAccess(Velocity).GetSafeNormal2D() * CtxAccess(Velocity).Size();
		}
	}
}

FVector GetPenetrationAdjustment(FISPCMovementContext Ctx, const FHitResult& Hit)
{
	if (!FHitResult_bStartPenetrating(Hit))
	{
		return FVector_ZeroVector;
	}

	static auto* CVarPenetrationPullbackDistance = IConsoleManager::Get().FindConsoleVariable(TEXT("p.PenetrationPullbackDistance"))->AsVariableFloat();

	FVector Result;
	const float PullBackDistance = FMath::Abs(CVarPenetrationPullbackDistance->GetValueOnGameThread());
	const float PenetrationDepth = (Hit.PenetrationDepth > 0.f ? Hit.PenetrationDepth : 0.125f);

	Result = Hit.Normal * (PenetrationDepth + PullBackDistance);

	Result = ConstrainDirectionToPlane(Ctx, Result);

	if (CtxAccess(CharacterOwner))
	{
		const bool bIsProxy = (CtxAccess(CharacterOwner_Role) == ROLE_SimulatedProxy);
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

bool ShouldComputePerchResult(FISPCMovementContext Ctx, const FHitResult& InHit, bool bCheckRadius)
{
	if (!InHit.IsValidBlockingHit())
	{
		return false;
	}

	// Don't try to perch if the edge radius is very small.
	if (GetPerchRadiusThreshold(Ctx) <= SWEEP_EDGE_REJECT_DISTANCE)
	{
		return false;
	}

	if (bCheckRadius)
	{
		const float DistFromCenterSq = (InHit.ImpactPoint - InHit.Location).SizeSquared2D();
		const float StandOnEdgeRadius = GetValidPerchRadius(Ctx);
		if (DistFromCenterSq <= FMath_Square(StandOnEdgeRadius))
		{
			// Already within perch radius.
			return false;
		}
	}
	
	return true;
}

bool ComputePerchResult(FISPCMovementContext Ctx, const float TestRadius, const FHitResult& InHit, const float InMaxFloorDist, FFindFloorResult& OutPerchFloorResult)
{
	if (InMaxFloorDist <= 0.f)
	{
		return 0.f;
	}

	// Sweep further than actual requested distance, because a reduced capsule radius means we could miss some hits that the normal radius would contact.
	float PawnRadius, PawnHalfHeight;
	CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

	const float InHitAboveBase = max(0.f, InHit.ImpactPoint.z - (InHit.Location.z - PawnHalfHeight));
	const float PerchLineDist = max(0.f, InMaxFloorDist - InHitAboveBase);
	const float PerchSweepDist = max(0.f, InMaxFloorDist);

	const float ActualSweepDist = PerchSweepDist + PawnRadius;
	ComputeFloorDist(Ctx, InHit.Location, PerchLineDist, ActualSweepDist, OutPerchFloorResult, TestRadius);

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

bool CanStepUp(FISPCMovementContext Ctx, const FHitResult& Hit)
{
	if (!Hit.IsValidBlockingHit() || !HasValidData(Ctx) || CtxAccess(MovementMode) == MOVE_Falling)
	{
		return false;
	}

	// No component for "fake" hits when we are on a known good base.
	const UPrimitiveComponent* HitComponent = Hit.Component.Get();
	if (!HitComponent)
	{
		return true;
	}

	if (!HitComponent->CanCharacterStepUp(CtxAccess(CharacterOwner)))
	{
		return false;
	}

	// No actor for "fake" hits when we are on a known good base.
	const AActor* HitActor = Hit.GetActor();
	if (!HitActor)
	{
		 return true;
	}

	if (!HitActor->CanBeBaseForCharacter(CtxAccess(CharacterOwner)))
	{
		return false;
	}

	return true;
}


bool StepUp(FISPCMovementContext Ctx, const FVector& GravDir, const FVector& Delta, const FHitResult &InHit, UCharacterMovementComponent::FStepDownResult* OutStepDownResult)
{
	SCOPE_CYCLE_COUNTER(STAT_CharStepUp);

	if (!CanStepUp(Ctx, InHit) || Comp->MaxStepHeight <= 0.f)
	{
		return false;
	}

	const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
	float PawnRadius, PawnHalfHeight;
	CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleSize(PawnRadius, PawnHalfHeight);

	// Don't bother stepping up if top of capsule is hitting something.
	const float InitialImpactZ = InHit.ImpactPoint.z;
	if (InitialImpactZ > OldLocation.z + (PawnHalfHeight - PawnRadius))
	{
		return false;
	}

	if (FVector_IsZero(GravDir))
	{
		return false;
	}

	// Gravity should be a normalized direction
	ensure(GravDir.IsNormalized());

	float StepTravelUpHeight = Comp->MaxStepHeight;
	float StepTravelDownHeight = StepTravelUpHeight;
	const float StepSideZ = -1.f * FVector::DotProduct(InHit.ImpactNormal, GravDir);
	float PawnInitialFloorBaseZ = OldLocation.z - PawnHalfHeight;
	float PawnFloorPointZ = PawnInitialFloorBaseZ;

	if (IsMovingOnGround(Ctx) && CtxAccess(CurrentFloor).IsWalkableFloor())
	{
		// Since we float a variable amount off the floor, we need to enforce max step height off the actual point of impact with the floor.
		const float FloorDist = max(0.f, CtxAccess(CurrentFloor).GetDistanceToFloor());
		PawnInitialFloorBaseZ -= FloorDist;
		StepTravelUpHeight = max(StepTravelUpHeight - FloorDist, 0.f);
		StepTravelDownHeight = (Comp->MaxStepHeight + MAX_FLOOR_DIST*2.f);

		const bool bHitVerticalFace = !IsWithinEdgeTolerance(InHit.Location, InHit.ImpactPoint, PawnRadius);
		if (!CtxAccess(CurrentFloor).bLineTrace && !bHitVerticalFace)
		{
			PawnFloorPointZ = CtxAccess(CurrentFloor).HitResult.ImpactPoint.z;
		}
		else
		{
			// Base floor point is the base of the capsule moved down by how far we are hovering over the surface we are hitting.
			PawnFloorPointZ -= CtxAccess(CurrentFloor).FloorDist;
		}
	}

	// Don't step up if the impact is below us, accounting for distance from floor.
	if (InitialImpactZ <= PawnInitialFloorBaseZ)
	{
		return false;
	}

	// Scope our movement updates, and do not apply them until all intermediate moves are completed.
	// TODO ISPC
	FScopedMovementUpdate ScopedStepUpMovement(CtxAccess(UpdatedComponent), EScopedUpdate::DeferredUpdates);

	// step up - treat as vertical wall
	FHitResult SweepUpHit(1.f);
	const FQuat PawnRotation = CtxAccess(UpdatedComponent_ComponentQuat);
	MoveUpdatedComponent(Ctx, -GravDir * StepTravelUpHeight, PawnRotation, true, &SweepUpHit);

	if (SweepUpFHitResult_bStartPenetrating(Hit))
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
		if (FHitResult_bStartPenetrating(Hit))
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
			HandleImpact(Ctx, SweepUpHit);
		}

		// pawn ran into a wall
		HandleImpact(Ctx, Hit);
		if (IsFalling(Ctx))
		{
			return true;
		}

		// adjust and try again
		const float ForwardHitTime = Hit.Time;
		const float ForwardSlideAmount = SlideAlongSurface(Ctx, Delta, 1.f - Hit.Time, Hit.Normal, Hit, true);
		
		if (IsFalling(Ctx))
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
	MoveUpdatedComponent(Ctx, GravDir * StepTravelDownHeight, CtxAccess(UpdatedComponent_ComponentQuat), true, &Hit);

	// If step down was initially penetrating abort the step up
	if (FHitResult_bStartPenetrating(Hit))
	{
		ScopedStepUpMovement.RevertMove();
		return false;
	}

	UCharacterMovementComponent::FStepDownResult StepDownResult;
	if (Hit.IsValidBlockingHit())
	{	
		// See if this step sequence would have allowed us to travel higher than our max step height allows.
		const float DeltaZ = Hit.ImpactPoint.z - PawnFloorPointZ;
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
			if (Hit.Location.z > OldLocation.Z)
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
		if (DeltaZ > 0.f && !CanStepUp(Ctx, Hit))
		{
			//UE_LOG(LogCharacterMovement, VeryVerbose, TEXT("- Reject StepUp (up onto surface with !CanStepUp())"));
			ScopedStepUpMovement.RevertMove();
			return false;
		}

		// See if we can validate the floor as a result of this step down. In almost all cases this should succeed, and we can avoid computing the floor outside this method.
		if (OutStepDownResult != NULL)
		{
			FindFloor(Ctx, GetUpdatedComponentLocation(Ctx), StepDownResult.FloorResult, false, &Hit);

			// Reject unwalkable normals if we end up higher than our initial height.
			// It's fine to walk down onto an unwalkable surface, don't reject those moves.
			if (Hit.Location.z > OldLocation.Z)
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
	CtxAccess(bJustTeleported) |= !Comp->bMaintainHorizontalGroundVelocity;

	return true;
}

FVector GetImpartedMovementBaseVelocity(FISPCMovementContext Ctx)
{
	FVector Result = FVector_ZeroVector;
	if (CtxAccess(CharacterOwner))
	{
		UPrimitiveComponent* MovementBase = CtxAccess(CharacterOwner_MovementBase);
		if (MovementBaseUtility::IsDynamicBase(MovementBase))
		{
			FVector BaseVelocity = MovementBaseUtility::GetMovementBaseVelocity(MovementBase, CtxAccess(CharacterOwner)->GetBasedMovement().BoneName);
			
			if (Comp->bImpartBaseAngularVelocity)
			{
				const FVector CharacterBasePosition = (GetUpdatedComponentLocation(Ctx) - FVector(0.f, 0.f, CtxAccess(CharacterOwner_CapsuleComponent_Size).y * CtxAccess(CharacterOwner_CapsuleComponent_Size).z));
				const FVector BaseTangentialVel = MovementBaseUtility::GetMovementBaseTangentialVelocity(MovementBase, CtxAccess(CharacterOwner)->GetBasedMovement().BoneName, CharacterBasePosition);
				BaseVelocity += BaseTangentialVel;
			}

			if (Comp->bImpartBaseVelocityX)
			{
				Result.x = BaseVelocity.x;
			}
			if (Comp->bImpartBaseVelocityY)
			{
				Result.y = BaseVelocity.y;
			}
			if (Comp->bImpartBaseVelocityZ)
			{
				Result.z = BaseVelocity.z;
			}
		}
	}
	
	return Result;
}
#endif

bool HandlePendingLaunch(FISPCMovementContext Ctx)
{
	if (!FVector_IsZero(CtxAccess(PendingLaunchVelocity)) && HasValidData(Ctx))
	{
		CtxAccess(Velocity) = CtxAccess(PendingLaunchVelocity);
		SetMovementMode(Ctx, MOVE_Falling);
		CtxAccess(PendingLaunchVelocity) = FVector_ZeroVector;
		return true;
	}

	return false;
}

#if UNIMPLEMENTED_CODE
void AdjustFloorHeight(FISPCMovementContext Ctx)
{
	SCOPE_CYCLE_COUNTER(STAT_CharAdjustFloorHeight);

	// If we have a floor check that hasn't hit anything, don't adjust height.
	if (!CtxAccess(CurrentFloor).IsWalkableFloor())
	{
		return;
	}

	float OldFloorDist = CtxAccess(CurrentFloor).FloorDist;
	if (CtxAccess(CurrentFloor).bLineTrace)
	{
		if (OldFloorDist < MIN_FLOOR_DIST && CtxAccess(CurrentFloor).LineDist >= MIN_FLOOR_DIST)
		{
			// This would cause us to scale unwalkable walls
			UE_LOG(LogISPCCharacterMovement, VeryVerbose, TEXT("Adjust floor height aborting due to line trace with small floor distance (line: %.2f, sweep: %.2f)"), CtxAccess(CurrentFloor).LineDist, CtxAccess(CurrentFloor).FloorDist);
			return;
		}
		else
		{
			// Falling back to a line trace means the sweep was unwalkable (or in penetration). Use the line distance for the vertical adjustment.
			OldFloorDist = CtxAccess(CurrentFloor).LineDist;
		}
	}

	// Move up or down to maintain floor height.
	if (OldFloorDist < MIN_FLOOR_DIST || OldFloorDist > MAX_FLOOR_DIST)
	{
		FHitResult AdjustHit(1.f);
		const float InitialZ = GetUpdatedComponentLocation(Ctx).z;
		const float AvgFloorDist = (MIN_FLOOR_DIST + MAX_FLOOR_DIST) * 0.5f;
		const float MoveDist = AvgFloorDist - OldFloorDist;
		
		const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
		SafeMoveUpdatedComponent( Comp, bMoveIgnoreFirstBlockingOverlap, FVector(0.f,0.f,MoveDist), CtxAccess(UpdatedComponent_ComponentQuat), true, AdjustHit );
		UE_LOG(LogISPCCharacterMovement, VeryVerbose, TEXT("Adjust floor height %.3f (Hit = %d)"), MoveDist, AdjustHit.bBlockingHit);

		if (!AdjustHit.IsValidBlockingHit())
		{
			CtxAccess(CurrentFloor).FloorDist += MoveDist;
		}
		else if (MoveDist > 0.f)
		{
			const float CurrentZ = GetUpdatedComponentLocation(Ctx).z;
			CtxAccess(CurrentFloor).FloorDist += CurrentZ - InitialZ;
		}
		else
		{
			checkSlow(MoveDist < 0.f);
			const float CurrentZ = GetUpdatedComponentLocation(Ctx).z;
			CtxAccess(CurrentFloor).FloorDist = CurrentZ - AdjustHit.Location.z;
			if (IsWalkable(AdjustHit, Comp->GetWalkableFloorZ()))
			{
				CtxAccess(CurrentFloor).SetFromSweep(AdjustHit, CtxAccess(CurrentFloor).FloorDist, true);
			}
		}

		// Don't recalculate velocity based on this height adjustment, if considering vertical adjustments.
		// Also avoid it if we moved out of penetration
		CtxAccess(bJustTeleported) |= !Comp->bMaintainHorizontalGroundVelocity || (OldFloorDist < 0.f);
		
		// If something caused us to adjust our height (especially a depentration) we should ensure another check next frame or we will keep a stale result.
		CtxAccess(bForceNextFloorCheck) = true;
	}
}

UPrimitiveComponent* GetMovementBase(FISPCMovementContext Ctx)
{
	return CtxAccess(CharacterOwner) ? CtxAccess(CharacterOwner_MovementBase) : NULL;
}

void SetBase( FISPCMovementContext Ctx, UPrimitiveComponent* NewBase, FName BoneName, bool bNotifyActor )
{
	// prevent from changing Base while server is NavWalking (no Base in that mode), so both sides are in sync
	// otherwise it will cause problems with position smoothing

	if (CtxAccess(CharacterOwner) && !Comp->bIsNavWalkingOnServer)
	{
		CtxAccess(CharacterOwner)->SetBase(NewBase, NewBase ? BoneName : NAME_None, bNotifyActor);
	}
}

void SetBaseFromFloor(FISPCMovementContext Ctx, const FFindFloorResult& FloorResult)
{
	if (FloorResult.IsWalkableFloor())
	{
		SetBase(Ctx, FloorResult.HitResult.GetComponent(), FloorResult.HitResult.BoneName);
	}
	else
	{
		SetBase(Ctx, NULL);
	}
}
#endif

void MaybeUpdateBasedMovement(FISPCMovementContext Ctx, float DeltaSeconds)
{
#if UNIMPLEMENTED_CODE
	CtxAccess(bDeferUpdateBasedMovement) = false;

	const /*UPrimitiveComponent**/void* MovementBase = CtxAccess(CharacterOwner_MovementBase);
	if (MovementBaseUtility_UseRelativeLocation(MovementBase))
	{
		const bool bBaseIsSimulatingPhysics = MovementBase->IsSimulatingPhysics();
		
		// Temporarily disabling deferred tick on skeletal mesh components that sim physics.
		// We need to be consistent on when we read the bone locations for those, and while this reads
		// the wrong location, the relative changes (which is what we care about) will be accurate.
		// TODO ISPC: Support the post-physics tick group.
		const bool bAllowDefer = false && (bBaseIsSimulatingPhysics && !Cast<USkeletalMeshComponent>(MovementBase));
		
		if (!bBaseIsSimulatingPhysics || !bAllowDefer)
		{
			CtxAccess(bDeferUpdateBasedMovement) = false;
			UpdateBasedMovement(Ctx, DeltaSeconds);
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
			CtxAccess(bDeferUpdateBasedMovement) = true;
			// If previously not simulating, remove tick dependencies and use post physics tick function.
#if 0	// TODO ISPC
			if (!PostPhysicsTickFunction.IsTickFunctionEnabled())
			{
				PostPhysicsTickFunction.SetTickFunctionEnable(true);
				MovementBaseUtility::RemoveTickDependency(PrimaryComponentTick, MovementBase);
			}
#endif
		}
	}
#endif
}

void MaybeSaveBaseLocation(FISPCMovementContext Ctx)
{
	if (!CtxAccess(bDeferUpdateBasedMovement))
	{
		SaveBaseLocation(Ctx);
	}
	else { unimplemented(); }	// TODO ISPC
}

void SaveBaseLocation(FISPCMovementContext Ctx)
{
	if (!HasValidData(Ctx))
	{
		return;
	}

	const void* MovementBase = CtxAccess(CharacterOwner_MovementBase);
	if (MovementBaseUtility_UseRelativeLocation(MovementBase) && !CtxAccess(CharacterOwner_IsMatineeControlled))
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		// Read transforms into OldBaseLocation, OldBaseQuat
		MovementBaseUtility::GetMovementBaseTransform(MovementBase, CtxAccess(CharacterOwner)->GetBasedMovement().BoneName, Comp->OldBaseLocation, Comp->OldBaseQuat);

		// Location
		const FVector RelativeLocation = GetUpdatedComponentLocation(Ctx) - Comp->OldBaseLocation;

		// Rotation
		// TODO ISPC: foreach_active
		if (Comp->bIgnoreBaseRotation)
		{
			// Absolute rotation
			CtxAccess(CharacterOwner)->SaveRelativeBasedMovement(RelativeLocation, CtxAccess(UpdatedComponent)->GetComponentRotation(), false);
		}
		else
		{
			// Relative rotation
			const FRotator RelativeRotation = (FQuatRotationMatrix(CtxAccess(UpdatedComponent_ComponentQuat)) * FQuatRotationMatrix(Comp->OldBaseQuat).GetTransposed()).Rotator();
			CtxAccess(CharacterOwner)->SaveRelativeBasedMovement(RelativeLocation, RelativeRotation, true);
		}
#endif
	}
}

bool CanCrouchInCurrentState(FISPCMovementContext Ctx)
{
	if (!CtxAccess(NavAgentProps_bCanCrouch))	// ISPC: Inlined call to UNavMovementComponent::CanEverCrouch().
	{
		return false;
	}

	return IsFalling(Ctx) || IsMovingOnGround(Ctx);
}

void Crouch(FISPCMovementContext Ctx, bool bClientSimulation)
{
	if (!HasValidData(Ctx))
	{
		return;
	}

	if (!bClientSimulation && !CanCrouchInCurrentState(Ctx))
	{
		return;
	}

	// See if collision is already at desired size.
	if (CtxAccess(CharacterOwner_CapsuleComponent_Size).y == CtxAccess(CrouchedHalfHeight))
	{
		if (!bClientSimulation)
		{
			SetCharacterOwner_bIsCrouched(CtxAccess(Comp), true);
			// ISPC: Mirror into our own data.
			CtxAccess(CharacterOwner_bIsCrouched) = true;
		}
		CharacterOwner_OnStartCrouch( CtxAccess(Comp), 0.f, 0.f );
		return;
	}

	if (bClientSimulation && CtxAccess(CharacterOwner_Role) == ROLE_SimulatedProxy)
	{
		// restore collision size before crouching
		RestoreDefaultCapsuleSize(CtxAccess(CharacterOwner));
		// ISPC: Mirror to local data.
		CtxAccess(CharacterOwner_CapsuleComponent_Size).x = CtxAccess(DefaultCharacter_CapsuleComponent_UnscaledSize).x;
		CtxAccess(CharacterOwner_CapsuleComponent_Size).y = CtxAccess(DefaultCharacter_CapsuleComponent_UnscaledSize).y;

		CtxAccess(bShrinkProxyCapsule) = true;
	}

	// Change collision size to crouching dimensions
	// OldUnscaledRadius == OldSize.x
	// OldUnscaledHalfHeight == OldSize.y
	// ComponentScale == OldSize.z
	const float<3> OldSize = CtxAccess(CharacterOwner_CapsuleComponent_Size);
	// Height is not allowed to be smaller than radius.
	const float ClampedCrouchedHalfHeight = max(0.f, max(OldSize.x, CtxAccess(CrouchedHalfHeight)));
	SetCapsuleSize(CtxAccess(CharacterOwner), OldSize.x, ClampedCrouchedHalfHeight);
	// ISPC: Mirror to local data.
	CtxAccess(CharacterOwner_CapsuleComponent_Size).y = ClampedCrouchedHalfHeight;
	float HalfHeightAdjust = (OldSize.y - ClampedCrouchedHalfHeight);
	float ScaledHalfHeightAdjust = HalfHeightAdjust * OldSize.z;

	if( !bClientSimulation )
	{
		// Crouching to a larger height? (this is rare)
		if (ClampedCrouchedHalfHeight > OldSize.y)
		{
			FCollisionQueryParams CapsuleParams;
			FCollisionResponseParams ResponseParam;
			FName CrouchTrace;	// FIXME ISPC: SCENE_QUERY_STAT(CrouchTrace)
			UpdatedPrimitive_InitSweepCollisionParams(CtxAccess(UpdatedPrimitive), CrouchTrace, CtxAccess(CharacterOwner), &CapsuleParams, &ResponseParam);
			const bool bEncroached = OverlapBlockingTestByChannel(CtxAccess(Comp), GetUpdatedComponentLocation(Ctx) - MakeFVector(0.f,0.f,ScaledHalfHeightAdjust), FQuat_Identity,
				CtxAccess(UpdatedComponent_CollisionObjectType), &CtxAccess(PawnCapsuleCollisionShape_ShrinkCapsuleExtent_None), &CapsuleParams, &ResponseParam);

			// If encroached, cancel
			if( bEncroached )
			{
				SetCapsuleSize(CtxAccess(CharacterOwner), OldSize.x, OldSize.y);
				// ISPC: Mirror to local data.
				CtxAccess(CharacterOwner_CapsuleComponent_Size).y = OldSize.y;
				return;
			}
		}

		if (CtxAccess(bCrouchMaintainsBaseLocation))
		{
			// Intentionally not using MoveUpdatedComponent, where a horizontal plane constraint would prevent the base of the capsule from staying at the same spot.
			MoveComponent(CtxAccess(UpdatedComponent), MakeFVector(0.f, 0.f, -ScaledHalfHeightAdjust), CtxAccess(UpdatedComponent_ComponentQuat), true, NULL, MOVECOMP_NoFlags, TeleportPhysics);
		}

		CtxAccess(CharacterOwner_bIsCrouched) = true;
	}

	CtxAccess(bForceNextFloorCheck) = true;

	// OnStartCrouch takes the change from the Default size, not the current one (though they are usually the same).
	const float MeshAdjust = ScaledHalfHeightAdjust;
	HalfHeightAdjust = (CtxAccess(DefaultCharacter_CapsuleComponent_UnscaledSize).y - ClampedCrouchedHalfHeight);
	ScaledHalfHeightAdjust = HalfHeightAdjust * OldSize.z;

#if 0	// TODO ISPC
	AdjustProxyCapsuleSize(Ctx);
#endif
	OnStartCrouch( CtxAccess(CharacterOwner), HalfHeightAdjust, ScaledHalfHeightAdjust );

	// Don't smooth this change in mesh position
	if (bClientSimulation && CtxAccess(CharacterOwner_Role) == ROLE_SimulatedProxy)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		FNetworkPredictionData_Client_Character* ClientData = GetPredictionData_Client_Character();
		if (ClientData && ClientData->MeshTranslationOffset.z != 0.f)
		{
			ClientData->MeshTranslationOffset -= FVector(0.f, 0.f, MeshAdjust);
			ClientData->OriginalMeshTranslationOffset = ClientData->MeshTranslationOffset;
		}
#endif
	}
}

void UnCrouch(FISPCMovementContext Ctx, bool bClientSimulation)
{
	if (!HasValidData(Ctx))
	{
		return;
	}

	// See if collision is already at desired size.
	if( CtxAccess(CharacterOwner_CapsuleComponent_Size).y == CtxAccess(DefaultCharacter_CapsuleComponent_UnscaledSize).y )
	{
		if (!bClientSimulation)
		{
			CtxAccess(CharacterOwner_bIsCrouched) = false;
		}
		OnEndCrouch( CtxAccess(CharacterOwner), 0.f, 0.f );
		return;
	}

	const float CurrentCrouchedHalfHeight = CtxAccess(CharacterOwner_CapsuleComponent_Size).y * CtxAccess(CharacterOwner_CapsuleComponent_Size).z;

	const float ComponentScale = CtxAccess(CharacterOwner_CapsuleComponent_Size).z;
	const float OldUnscaledHalfHeight = CtxAccess(CharacterOwner_CapsuleComponent_Size).y;
	const float HalfHeightAdjust = CtxAccess(DefaultCharacter_CapsuleComponent_UnscaledSize).y - OldUnscaledHalfHeight;
	const float ScaledHalfHeightAdjust = HalfHeightAdjust * ComponentScale;
	const FVector PawnLocation = GetUpdatedComponentLocation(Ctx);

	// Grow to uncrouched size.
#if 0	// TODO ISPC
	check(CtxAccess(CharacterOwner)->GetCapsuleComponent());
#endif

	if( !bClientSimulation )
	{
		// Try to stay in place and see if the larger capsule fits. We use a slightly taller capsule to avoid penetration.
		const float SweepInflation = KINDA_SMALL_NUMBER * 10.f;
		FCollisionQueryParams CapsuleParams;// (SCENE_QUERY_STAT(CrouchTrace), false, CtxAccess(CharacterOwner));
		FCollisionResponseParams ResponseParam;
		FName CrouchTrace;	// FIXME ISPC: SCENE_QUERY_STAT(CrouchTrace)
		UpdatedPrimitive_InitSweepCollisionParams(CtxAccess(UpdatedPrimitive), CrouchTrace, CtxAccess(CharacterOwner), &CapsuleParams, &ResponseParam);

		// Compensate for the difference between current capsule size and standing size
		FVector StandingCapsuleExtent = GetPawnCapsuleExtent(Ctx, MakeFVector2D(0.f, -SweepInflation - ScaledHalfHeightAdjust));
		FCollisionShape StandingCapsuleShape;
		MakeCapsuleCollisionShape(StandingCapsuleExtent, &StandingCapsuleShape); // Shrink by negative amount, so actually grow it.
		const ECollisionChannel CollisionChannel = CtxAccess(UpdatedComponent_CollisionObjectType);
		bool bEncroached = true;

		if (!CtxAccess(bCrouchMaintainsBaseLocation))
		{
			// Expand in place
			bEncroached = OverlapBlockingTestByChannel(CtxAccess(Comp), PawnLocation, FQuat_Identity, CollisionChannel, &StandingCapsuleShape, &CapsuleParams, &ResponseParam);
		
			if (bEncroached)
			{
				// Try adjusting capsule position to see if we can avoid encroachment.
				if (ScaledHalfHeightAdjust > 0.f)
				{
					// Shrink to a short capsule, sweep down to base to find where that would hit something, and then try to stand up from there.
					float PawnRadius = CtxAccess(CharacterOwner_CapsuleComponent_Size).x * CtxAccess(CharacterOwner_CapsuleComponent_Size).z;
					float PawnHalfHeight = CtxAccess(CharacterOwner_CapsuleComponent_Size).y * CtxAccess(CharacterOwner_CapsuleComponent_Size).z;
					const float ShrinkHalfHeight = PawnHalfHeight - PawnRadius;
					const float TraceDist = PawnHalfHeight - ShrinkHalfHeight;
					const FVector Down = MakeFVector(0.f, 0.f, -TraceDist);

					FHitResult Hit = MakeFHitResult(1.f);
					FVector ShortCapsuleExtent = GetPawnCapsuleExtent(Ctx, MakeFVector2D(0.f, ShrinkHalfHeight));
					FCollisionShape ShortCapsuleShape;
					MakeCapsuleCollisionShape(ShortCapsuleExtent, &ShortCapsuleShape);
					const bool bBlockingHit = SweepSingleByChannel(CtxAccess(Comp), &Hit, PawnLocation, PawnLocation + Down, FQuat_Identity, CollisionChannel, &ShortCapsuleShape, &CapsuleParams, &FCollisionResponseParams_DefaultResponseParam);
					if (FHitResult_bStartPenetrating(Hit))
					{
						bEncroached = true;
					}
					else
					{
						// Compute where the base of the sweep ended up, and see if we can stand there
						const float DistanceToBase = (Hit.Time * TraceDist) + ShortCapsuleExtent.z;
						const FVector NewLoc = MakeFVector(PawnLocation.x, PawnLocation.y, PawnLocation.z - DistanceToBase + PawnHalfHeight + SweepInflation + MIN_FLOOR_DIST / 2.f);
						bEncroached = OverlapBlockingTestByChannel(CtxAccess(Comp), NewLoc, FQuat_Identity, CollisionChannel, &StandingCapsuleShape, &CapsuleParams, &ResponseParam);
						if (!bEncroached)
						{
							// Intentionally not using MoveUpdatedComponent, where a horizontal plane constraint would prevent the base of the capsule from staying at the same spot.
							MoveComponent(CtxAccess(UpdatedComponent), NewLoc - PawnLocation, CtxAccess(UpdatedComponent_ComponentQuat), false, NULL, MOVECOMP_NoFlags, TeleportPhysics);
						}
					}
				}
			}
		}
		else
		{
			// Expand while keeping base location the same.
			FVector StandingLocation = PawnLocation + MakeFVector(0.f, 0.f, StandingCapsuleExtent.z - CurrentCrouchedHalfHeight);
			bEncroached = OverlapBlockingTestByChannel(CtxAccess(Comp), StandingLocation, FQuat_Identity, CollisionChannel, &StandingCapsuleShape, &CapsuleParams, &ResponseParam);

			if (bEncroached)
			{
				if (IsMovingOnGround(Ctx))
				{
					// Something might be just barely overhead, try moving down closer to the floor to avoid it.
					const float MinFloorDist = KINDA_SMALL_NUMBER * 10.f;
					if (FFindFloorResult_bBlockingHit(&CtxAccess(CurrentFloor)) && CtxAccess(CurrentFloor).FloorDist > MinFloorDist)
					{
						StandingLocation.z -= CtxAccess(CurrentFloor).FloorDist - MinFloorDist;
						bEncroached = OverlapBlockingTestByChannel(CtxAccess(Comp), StandingLocation, FQuat_Identity, CollisionChannel, &StandingCapsuleShape, &CapsuleParams, &ResponseParam);
					}
				}				
			}

			if (!bEncroached)
			{
				// Commit the change in location.
				MoveComponent(CtxAccess(UpdatedComponent), StandingLocation - PawnLocation, CtxAccess(UpdatedComponent_ComponentQuat), false, NULL, MOVECOMP_NoFlags, TeleportPhysics);
				CtxAccess(bForceNextFloorCheck) = true;
			}
		}

		// If still encroached then abort.
		if (bEncroached)
		{
			return;
		}

		CtxAccess(CharacterOwner_bIsCrouched) = false;
	}	
	else
	{
		CtxAccess(bShrinkProxyCapsule) = true;
	}

	// Now call SetCapsuleSize() to cause touch/untouch events and actually grow the capsule
	SetCapsuleSize(CtxAccess(CharacterOwner),
		CtxAccess(DefaultCharacter_CapsuleComponent_UnscaledSize).x,
		CtxAccess(DefaultCharacter_CapsuleComponent_UnscaledSize).y);

	const float MeshAdjust = ScaledHalfHeightAdjust;
#if 0	// TODO ISPC
	AdjustProxyCapsuleSize(Ctx);
#endif
	OnEndCrouch( CtxAccess(CharacterOwner), HalfHeightAdjust, ScaledHalfHeightAdjust );

	// Don't smooth this change in mesh position
	if (bClientSimulation && CtxAccess(CharacterOwner_Role) == ROLE_SimulatedProxy)
	{
#if 1	// TODO ISPC
		unimplemented();
#else
		FNetworkPredictionData_Client_Character* ClientData = GetPredictionData_Client_Character();
		if (ClientData && ClientData->MeshTranslationOffset.z != 0.f)
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
	if (!HasValidData(Ctx))
	{
		return;
	}

#if UNIMPLEMENTED_CODE
	const UPrimitiveComponent* MovementBase = CtxAccess(CharacterOwner_MovementBase);
	if (!MovementBaseUtility_UseRelativeLocation(MovementBase))
	{
		return;
	}

	if (!IsValid(MovementBase) || !IsValid(MovementBase->GetOwner()))
	{
		SetBase(Ctx, NULL);
		return;
	}

	// Ignore collision with bases during these movements.
	TGuardValue<EMoveComponentFlags> ScopedFlagRestore(CtxAccess(MoveComponentFlags), CtxAccess(MoveComponentFlags) | MOVECOMP_IgnoreBases);

	FQuat DeltaQuat = FQuat_Identity;
	FVector DeltaPosition = FVector_ZeroVector;

	FQuat NewBaseQuat;
	FVector NewBaseLocation;
	if (!MovementBaseUtility::GetMovementBaseTransform(MovementBase, CtxAccess(CharacterOwner)->GetBasedMovement().BoneName, NewBaseLocation, NewBaseQuat))
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

		if( CtxAccess(CharacterOwner_IsMatineeControlled) )
		{
			FRotationTranslationMatrix HardRelMatrix(CtxAccess(CharacterOwner)->GetBasedMovement().Rotation, CtxAccess(CharacterOwner)->GetBasedMovement().Location);
			const FMatrix NewWorldTM = HardRelMatrix * NewLocalToWorld;
			const FQuat NewWorldRot = Comp->bIgnoreBaseRotation ? CtxAccess(UpdatedComponent_ComponentQuat) : NewWorldTM.ToQuat();
			MoveUpdatedComponent( Comp, NewWorldTM.GetOrigin() - GetUpdatedComponentLocation(Ctx), NewWorldRot, true );
		}
		else
		{
			FQuat FinalQuat = CtxAccess(UpdatedComponent_ComponentQuat);
			
			if (bRotationChanged && !Comp->bIgnoreBaseRotation)
			{
				// Apply change in rotation and pipe through FaceRotation to maintain axis restrictions
				const FQuat PawnOldQuat = CtxAccess(UpdatedComponent_ComponentQuat);
				const FQuat TargetQuat = DeltaQuat * FinalQuat;
				FRotator TargetRotator(TargetQuat);
				CtxAccess(CharacterOwner)->FaceRotation(TargetRotator, 0.f);
				FinalQuat = CtxAccess(UpdatedComponent_ComponentQuat);

				if (PawnOldQuat.Equals(FinalQuat, 1e-6f))
				{
					// Nothing changed. This means we probably are using another rotation mechanism (bOrientToMovement etc). We should still follow the base object.
					// @todo: This assumes only Yaw is used, currently a valid assumption. This is the only reason FaceRotation() is used above really, aside from being a virtual hook.
					if (Comp->bOrientRotationToMovement || (Comp->bUseControllerDesiredRotation && CtxAccess(CharacterOwner)->Controller))
					{
						TargetRotator.Pitch = 0.f;
						TargetRotator.Roll = 0.f;
						MoveUpdatedComponent(Ctx, FVector_ZeroVector, TargetRotator.Quaternion(), false);
						FinalQuat = CtxAccess(UpdatedComponent_ComponentQuat);
					}
				}

				// Pipe through ControlRotation, to affect camera.
				if (CtxAccess(CharacterOwner)->Controller)
				{
					const FQuat PawnDeltaRotation = FinalQuat * PawnOldQuat.Inverse();
					FRotator FinalRotation = FinalQuat.Rotator();
					UpdateBasedRotation(Ctx, FinalRotation, PawnDeltaRotation.Rotator());
					FinalQuat = CtxAccess(UpdatedComponent_ComponentQuat);
				}
			}

			// We need to offset the base of the character here, not its origin, so offset by half height
			float HalfHeight, Radius;
			CtxAccess(CharacterOwner)->GetCapsuleComponent()->GetScaledCapsuleSize(Radius, HalfHeight);

			FVector const BaseOffset(0.0f, 0.0f, HalfHeight);
			FVector const LocalBasePos = OldLocalToWorld.InverseTransformPosition(GetUpdatedComponentLocation(Ctx) - BaseOffset);
			FVector const NewWorldPos = ConstrainLocationToPlane(Ctx, NewLocalToWorld.TransformPosition(LocalBasePos) + BaseOffset);
			DeltaPosition = ConstrainDirectionToPlane(Ctx, NewWorldPos - GetUpdatedComponentLocation(Ctx));

			// move attached actor
			if (Comp->bFastAttachedMove)
			{
				// we're trusting no other obstacle can prevent the move here
				// TODO ISPC: foreach_active
				CtxAccess(UpdatedComponent)->SetWorldLocationAndRotation(NewWorldPos, FinalQuat, false);
			}
			else
			{
				// hack - transforms between local and world space introducing slight error FIXMESTEVE - discuss with engine team: just skip the transforms if no rotation?
				FVector BaseMoveDelta = NewBaseLocation - Comp->OldBaseLocation;
				if (!bRotationChanged && (BaseMoveDelta.x == 0.f) && (BaseMoveDelta.y == 0.f))
				{
					DeltaPosition.x = 0.f;
					DeltaPosition.y = 0.f;
				}

				FHitResult MoveOnBaseHit(1.f);
				const FVector OldLocation = GetUpdatedComponentLocation(Ctx);
				MoveUpdatedComponent(Ctx, DeltaPosition, FinalQuat, true, &MoveOnBaseHit);
				if ((GetUpdatedComponentLocation(Ctx) - (OldLocation + DeltaPosition)).IsNearlyZero() == false)
				{
#if 0	// TODO ISPC: This is empty in all implementations that concern us.
					Comp->OnUnableToFollowBaseMove(DeltaPosition, OldLocation, MoveOnBaseHit);
#endif
				}
			}
		}

		if (MovementBase->IsSimulatingPhysics() && CtxAccess(CharacterOwner)_GetMesh)
		{
			// TODO ISPC: foreach_active
			CtxAccess(CharacterOwner)_GetMesh->ApplyDeltaToAllPhysicsTransforms(DeltaPosition, DeltaQuat);
		}
	}
#endif
}

void UpdateBasedRotation(FISPCMovementContext Ctx, FRotator& FinalRotation, const FRotator& ReducedRotation)
{
#if UNIMPLEMENTED_CODE
	AController* Controller = CtxAccess(CharacterOwner) ? CtxAccess(CharacterOwner)->Controller : NULL;
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
		FinalRotation.Roll = CtxAccess(UpdatedComponent)->GetComponentRotation().Roll;
		FRotator NewRotation = Controller->GetControlRotation();
		NewRotation.Roll = ControllerRoll;
		Controller->SetControlRotation(NewRotation);
	}
#endif
}

bool SafeMoveUpdatedComponent(FISPCMovementContext Ctx, const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap, const FVector& Delta, const FQuat& NewRotation, bool bSweep, FHitResult& OutHit, ETeleportType Teleport)
{
#if UNIMPLEMENTED_CODE
	if (CtxAccess(UpdatedComponent) == NULL)
	{
		OutHit.Reset(1.f);
		return false;
	}

	bool bMoveResult = false;

	// Scope for move flags
	{
		// Conditionally ignore blocking overlaps (based on CVar)
		const EMoveComponentFlags IncludeBlockingOverlapsWithoutEvents = (MOVECOMP_NeverIgnoreBlockingOverlaps | MOVECOMP_DisableBlockingOverlapDispatch);
		TGuardValue<EMoveComponentFlags> ScopedFlagRestore(CtxAccess(MoveComponentFlags), bMoveIgnoreFirstBlockingOverlap ? CtxAccess(MoveComponentFlags) : (CtxAccess(MoveComponentFlags) | IncludeBlockingOverlapsWithoutEvents));
		bMoveResult = MoveUpdatedComponent(Ctx, Delta, NewRotation, bSweep, &OutHit, Teleport);
	}

	// Handle initial penetrations
	if (OutFHitResult_bStartPenetrating(Hit) && CtxAccess(UpdatedComponent))
	{
		const FVector RequestedAdjustment = GetPenetrationAdjustment(Ctx, OutHit);
		if (ResolvePenetration(Ctx, RequestedAdjustment, OutHit, NewRotation))
		{
			// Retry original move
			bMoveResult = MoveUpdatedComponent(Ctx, Delta, NewRotation, bSweep, &OutHit, Teleport);
		}
	}

	return bMoveResult;
#endif
}

bool ResolvePenetration(FISPCMovementContext Ctx, const FVector& ProposedAdjustment, const FHitResult& Hit, const FQuat& NewRotation)
{
#if UNIMPLEMENTED_CODE
	// If movement occurs, mark that we teleported, so we don't incorrectly adjust velocity based on a potentially very different movement than our movement direction.

	// SceneComponent can't be in penetration, so this function really only applies to PrimitiveComponent.
	const FVector Adjustment = ConstrainDirectionToPlane(Ctx, ProposedAdjustment);
	if (!FVector_IsZero(Adjustment) && Comp->UpdatedPrimitive)
	{
		// See if we can fit at the adjusted location without overlapping anything.
		const void* ActorOwner = CtxAccess(UpdatedComponent_Owner);
		if (!ActorOwner)
		{
			return CtxAccess(bJustTeleported);
		}

		UE_LOG(LogISPCCharacterMovement, Verbose, TEXT("ResolvePenetration: %s.%s at location %s inside %s.%s at location %s by %.3f (netmode: %d)"),
			*ActorOwner->GetName(),
			*CtxAccess(UpdatedComponent)->GetName(),
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
		bool bEncroached = OverlapTest(Ctx, Hit.TraceStart + Adjustment, NewRotation, Comp->UpdatedPrimitive->GetCollisionObjectType(), Comp->UpdatedPrimitive->GetCollisionShape(OverlapInflation), ActorOwner);
		if (!bEncroached)
		{
			// Move without sweeping.
			MoveUpdatedComponent(Ctx, Adjustment, NewRotation, false, NULL, TeleportPhysics);
			UE_LOG(LogISPCCharacterMovement, Verbose, TEXT("ResolvePenetration:   teleport by %s"), *Adjustment.ToString());
			CtxAccess(bJustTeleported) = true;
			return CtxAccess(bJustTeleported);
		}
		else
		{
			// Disable MOVECOMP_NeverIgnoreBlockingOverlaps if it is enabled, otherwise we wouldn't be able to sweep out of the object to fix the penetration.
			TGuardValue<EMoveComponentFlags> ScopedFlagRestore(CtxAccess(MoveComponentFlags), EMoveComponentFlags(CtxAccess(MoveComponentFlags) & (~MOVECOMP_NeverIgnoreBlockingOverlaps)));

			// Try sweeping as far as possible...
			FHitResult SweepOutHit(1.f);
			bool bMoved = MoveUpdatedComponent(Ctx, Adjustment, NewRotation, true, &SweepOutHit, TeleportPhysics);
			UE_LOG(LogISPCCharacterMovement, Verbose, TEXT("ResolvePenetration:   sweep by %s (success = %d)"), *Adjustment.ToString(), bMoved);

			// Still stuck?
			if (!bMoved && SweepOutFHitResult_bStartPenetrating(Hit))
			{
				// Combine two MTD results to get a new direction that gets out of multiple surfaces.
				const FVector SecondMTD = GetPenetrationAdjustment(Ctx, SweepOutHit);
				const FVector CombinedMTD = Adjustment + SecondMTD;
				if (SecondMTD != Adjustment && !FVector_IsZero(CombinedMTD))
				{
					bMoved = MoveUpdatedComponent(Ctx, CombinedMTD, NewRotation, true, NULL, TeleportPhysics);
					UE_LOG(LogISPCCharacterMovement, Verbose, TEXT("ResolvePenetration:   sweep by %s (MTD combo success = %d)"), *CombinedMTD.ToString(), bMoved);
				}
			}

			// Still stuck?
			if (!bMoved)
			{
				// Try moving the proposed adjustment plus the attempted move direction. This can sometimes get out of penetrations with multiple objects
				const FVector MoveDelta = ConstrainDirectionToPlane(Ctx, Hit.TraceEnd - Hit.TraceStart);
				if (!FVector_IsZero(MoveDelta))
				{
					bMoved = MoveUpdatedComponent(Ctx, Adjustment + MoveDelta, NewRotation, true, NULL, TeleportPhysics);
					UE_LOG(LogISPCCharacterMovement, Verbose, TEXT("ResolvePenetration:   sweep by %s (adjusted attempt success = %d)"), *(Adjustment + MoveDelta).ToString(), bMoved);
				}
			}

			CtxAccess(bJustTeleported) |= bMoved;
			return CtxAccess(bJustTeleported);
		}
	}

	return CtxAccess(bJustTeleported);
#endif
}

bool MoveUpdatedComponent(FISPCMovementContext Ctx, const FVector& Delta, const FQuat& NewRotation, bool bSweep, FHitResult* OutHit, ETeleportType Teleport)
{
	if (CtxAccess(UpdatedComponent))
	{
		const FVector NewDelta = ConstrainDirectionToPlane(Ctx, Delta);
		return MoveComponent(CtxAccess(UpdatedComponent), NewDelta, NewRotation, bSweep, OutHit, CtxAccess(MoveComponentFlags), Teleport);
	}

	return false;
}

FVector ConstrainDirectionToPlane(FISPCMovementContext Ctx, FVector Direction)
{
#if UNIMPLEMENTED_CODE
	if (CtxAccess(bConstrainToPlane))
	{
		Direction = FVector::VectorPlaneProject(Direction, Comp->PlaneConstraintNormal);
	}

	return Direction;
#endif
}

FVector ConstrainLocationToPlane(FISPCMovementContext Ctx, FVector Location)
{
#if UNIMPLEMENTED_CODE
	if (CtxAccess(bConstrainToPlane))
	{
		Location = FVector::PointPlaneProject(Location, Comp->PlaneConstraintOrigin, Comp->PlaneConstraintNormal);
	}

	return Location;
#endif
}

FVector ConstrainNormalToPlane(FISPCMovementContext Ctx, FVector Normal)
{
#if UNIMPLEMENTED_CODE
	if (CtxAccess(bConstrainToPlane))
	{
		Normal = FVector::VectorPlaneProject(Normal, Comp->PlaneConstraintNormal).GetSafeNormal();
	}

	return Normal;
#endif
}

void SnapUpdatedComponentToPlane(FISPCMovementContext Ctx)
{
#if UNIMPLEMENTED_CODE
	if (CtxAccess(UpdatedComponent) && CtxAccess(bConstrainToPlane))
	{
		CtxAccess(UpdatedComponent)->SetWorldLocation( ConstrainLocationToPlane(Ctx, GetUpdatedComponentLocation(Ctx)) );
	}
#endif
}

bool OverlapTest(FISPCMovementContext Ctx, const FVector& Location, const FQuat& RotationQuat, const ECollisionChannel CollisionChannel, const FCollisionShape& CollisionShape, const /*AActor**/void* IgnoreActor)
{
#if UNIMPLEMENTED_CODE
	FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(MovementOverlapTest), false, IgnoreActor);
	FCollisionResponseParams ResponseParam;
	// TODO ISPC: Fold these two calls together?
	InitCollisionParams(Ctx, QueryParams, ResponseParam);
	return OverlapBlockingTestByChannel(CtxAccess(Comp), Location, RotationQuat, CollisionChannel, CollisionShape, QueryParams, ResponseParam);
#endif
}

bool IsExceedingMaxSpeed(FISPCMovementContext Ctx, float MaxSpeed)
{
	MaxSpeed = max(0.f, MaxSpeed);
	const float MaxSpeedSquared = FMath_Square(MaxSpeed);
	
	// Allow 1% error tolerance, to account for numeric imprecision.
	const float OverVelocityPercent = 1.01f;
	return (FVector_SizeSquared(CtxAccess(Velocity)) > MaxSpeedSquared * OverVelocityPercent);
}

void RestorePreAdditiveRootMotionVelocity(FISPCMovementContext Ctx)
{
#if 1	// TODO ISPC
	check(!HasRootMotionSources(Ctx));
#else
	// Restore last frame's pre-additive Velocity if we had additive applied 
	// so that we're not adding more additive velocity than intended
	if( Comp->CurrentRootMotion.bIsAdditiveVelocityApplied )
	{
#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			FString AdjustedDebugString = FString::Printf(TEXT("RestorePreAdditiveRootMotionVelocity Velocity(%s) LastPreAdditiveVelocity(%s)"), 
				*CtxAccess(Velocity).ToCompactString(), *Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
		}
#endif

		CtxAccess(Velocity) = Comp->CurrentRootMotion.LastPreAdditiveVelocity;
		Comp->CurrentRootMotion.bIsAdditiveVelocityApplied = false;
	}
#endif
}

void ApplyRootMotionToVelocity(FISPCMovementContext Ctx, float deltaTime)
{
#if 1	// TODO_ISPC
	check(!HasRootMotionSources(Ctx));
#else
	SCOPE_CYCLE_COUNTER(STAT_CharacterMovementRootMotionSourceApply);

	// Animation root motion is distinct from root motion sources right now and takes precedence
	if( HasAnimRootMotion(Ctx) && deltaTime > 0.f )
	{
		CtxAccess(Velocity) = ConstrainAnimRootMotionVelocity(Ctx, Comp->AnimRootMotionVelocity, CtxAccess(Velocity));
		return;
	}

	const FVector OldVelocity = CtxAccess(Velocity);

	bool bAppliedRootMotion = false;

	// Apply override velocity
	if( Comp->CurrentRootMotion.HasOverrideVelocity() )
	{
		Comp->CurrentRootMotion.AccumulateOverrideRootMotionVelocity(deltaTime, *CtxAccess(CharacterOwner), *Comp, CtxAccess(Velocity));
		bAppliedRootMotion = true;

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			FString AdjustedDebugString = FString::Printf(TEXT("ApplyRootMotionToVelocity HasOverrideVelocity Velocity(%s)"),
				*CtxAccess(Velocity).ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
		}
#endif
	}

	// Next apply additive root motion
	if( Comp->CurrentRootMotion.HasAdditiveVelocity() )
	{
		Comp->CurrentRootMotion.LastPreAdditiveVelocity = CtxAccess(Velocity); // Save off pre-additive Velocity for restoration next tick
		Comp->CurrentRootMotion.AccumulateAdditiveRootMotionVelocity(deltaTime, *CtxAccess(CharacterOwner), *Comp, CtxAccess(Velocity));
		Comp->CurrentRootMotion.bIsAdditiveVelocityApplied = true; // Remember that we have it applied
		bAppliedRootMotion = true;

#if ROOT_MOTION_DEBUG
		if (RootMotionSourceDebug::CVarDebugRootMotionSources.GetValueOnAnyThread() == 1)
		{
			FString AdjustedDebugString = FString::Printf(TEXT("ApplyRootMotionToVelocity HasAdditiveVelocity Velocity(%s) LastPreAdditiveVelocity(%s)"),
				*CtxAccess(Velocity).ToCompactString(), *Comp->CurrentRootMotion.LastPreAdditiveVelocity.ToCompactString());
			RootMotionSourceDebug::PrintOnScreen(*CtxAccess(CharacterOwner), AdjustedDebugString);
		}
#endif
	}

	// Switch to Falling if we have vertical velocity from root motion so we can lift off the ground
	const FVector AppliedVelocityDelta = CtxAccess(Velocity) - OldVelocity;
	if( bAppliedRootMotion && AppliedVelocityDelta.z != 0.f && IsMovingOnGround(Ctx) )
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
			LiftoffBound = max(GetGravityZ(Ctx) * deltaTime, SMALL_NUMBER);
		}

		if( AppliedVelocityDelta.z > LiftoffBound )
		{
			SetMovementMode(Ctx, MOVE_Falling);
		}
	}
#endif	// TODO_ISPC
}

FVector ConstrainAnimRootMotionVelocity(FISPCMovementContext Ctx, const FVector& RootMotionVelocity, const FVector& CurrentVelocity)
{
	FVector Result = RootMotionVelocity;

	// Do not override Velocity.z if in falling physics, we want to keep the effect of gravity.
	if (IsFalling(Ctx))
	{
		Result.z = CurrentVelocity.z;
	}

	return Result;
}

void ApplyVelocityBraking(FISPCMovementContext Ctx, float DeltaTime, float Friction, float BrakingDeceleration)
{
	if (FVector_IsZero(CtxAccess(Velocity)) || !HasValidData(Ctx) || HasAnimRootMotion(Ctx) || DeltaTime < MIN_TICK_TIME)
	{
		return;
	}

	const float FrictionFactor = max(0.f, CtxAccess(BrakingFrictionFactor));
	Friction = max(0.f, Friction * FrictionFactor);
	BrakingDeceleration = max(0.f, BrakingDeceleration);
	const bool bZeroFriction = (Friction == 0.f);
	const bool bZeroBraking = (BrakingDeceleration == 0.f);

	if (bZeroFriction && bZeroBraking)
	{
		return;
	}

	const FVector OldVel = CtxAccess(Velocity);

	// subdivide braking to get reasonably consistent results at lower frame rates
	// (important for packet loss situations w/ networking)
	float RemainingTime = DeltaTime;
	const float MaxTimeStep = (1.0f / 33.0f);

	// Decelerate to brake to a stop
	const FVector RevAccel = (bZeroBraking ? FVector_ZeroVector : (-BrakingDeceleration * FVector_GetSafeNormal(CtxAccess(Velocity))));
	while( RemainingTime >= MIN_TICK_TIME )
	{
		// Zero friction uses constant deceleration, so no need for iteration.
		const float dt = ((RemainingTime > MaxTimeStep && !bZeroFriction) ? min(MaxTimeStep, RemainingTime * 0.5f) : RemainingTime);
		RemainingTime -= dt;

		// apply friction and braking
		CtxAccess(Velocity) = CtxAccess(Velocity) + ((-Friction) * CtxAccess(Velocity) + RevAccel) * dt ;
		
		// Don't reverse direction
		if (FVector_Dot(CtxAccess(Velocity), OldVel) <= 0.f)
		{
			CtxAccess(Velocity) = FVector_ZeroVector;
			return;
		}
	}

	// Clamp to zero if nearly zero, or if below min threshold and braking.
	const float VSizeSq = FVector_SizeSquared(CtxAccess(Velocity));
	if (VSizeSq <= KINDA_SMALL_NUMBER || (!bZeroBraking && VSizeSq <= FMath_Square(BRAKE_TO_STOP_VELOCITY)))
	{
		CtxAccess(Velocity) = FVector_ZeroVector;
	}
}


void ApplyAccumulatedForces(FISPCMovementContext Ctx, float DeltaSeconds)
{
	if (CtxAccess(PendingImpulseToApply).z != 0.f || CtxAccess(PendingForceToApply).z != 0.f)
	{
		// check to see if applied momentum is enough to overcome gravity
		if ( IsMovingOnGround(Ctx) && (CtxAccess(PendingImpulseToApply).z + (CtxAccess(PendingForceToApply).z * DeltaSeconds) + (GetGravityZ(Ctx) * DeltaSeconds) > SMALL_NUMBER))
		{
			SetMovementMode(Ctx, MOVE_Falling);
		}
	}

	CtxAccess(Velocity) += CtxAccess(PendingImpulseToApply) + (CtxAccess(PendingForceToApply) * DeltaSeconds);
	
	// Don't call ClearAccumulatedForces() because it could affect launch velocity
	CtxAccess(PendingImpulseToApply) = FVector_ZeroVector;
	CtxAccess(PendingForceToApply) = FVector_ZeroVector;
}

void ClearAccumulatedForces(FISPCMovementContext Ctx)
{
	CtxAccess(PendingImpulseToApply) = FVector_ZeroVector;
	CtxAccess(PendingForceToApply) = FVector_ZeroVector;
	CtxAccess(PendingLaunchVelocity) = FVector_ZeroVector;
}

#if UNIMPLEMENTED_CODE
void NotifyJumpApex(FISPCMovementContext Ctx)
{
	if( CtxAccess(CharacterOwner) )
	{
		// TODO ISPC: foreach_active
		CtxAccess(CharacterOwner)->NotifyJumpApex();
	}
}

FVector NewFallVelocity(FISPCMovementContext Ctx, const FVector& InitialVelocity, const FVector& Gravity, float DeltaTime)
{
	FVector Result = InitialVelocity;

	if (!FVector_IsZero(Gravity) && (Comp->bApplyGravityWhileJumping || !(CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner)->IsJumpProvidingForce())))
	{
		// Apply gravity.
		Result += Gravity * DeltaTime;

		const FVector GravityDir = FVector_GetSafeNormal(Gravity);
		const float TerminalLimit = FMath::Abs(GetPhysicsVolume(Ctx)->TerminalVelocity);

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

	CtxAccess(Acceleration) = FVector_ZeroVector; 
	Comp->bHasRequestedVelocity = false;
	Comp->RequestedVelocity = FVector_ZeroVector;
}

void ProcessLanded(FISPCMovementContext Ctx, const FHitResult& Hit, float remainingTime, int32 Iterations)
{
	SCOPE_CYCLE_COUNTER(STAT_CharProcessLanded);

	if( CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner)->ShouldNotifyLanded(Hit) )
	{
		CtxAccess(CharacterOwner)->Landed(Hit);
	}
	if( IsFalling(Ctx) )
	{
		if (Comp->GetGroundMovementMode() == MOVE_NavWalking)
		{
			// verify navmesh projection and current floor
			// otherwise movement will be stuck in infinite loop:
			// navwalking -> (no navmesh) -> falling -> (standing on something) -> navwalking -> ....

			const FVector TestLocation = GetActorFeetLocation(Ctx);
			FNavLocation NavLocation;

			const bool bHasNavigationData = FindNavFloor(Ctx, TestLocation, NavLocation);
			if (!bHasNavigationData || NavLocation.NodeRef == INVALID_NAVNODEREF)
			{
				SetGroundMovementMode(Ctx, MOVE_Walking);
				UE_LOG(LogUnrolledNavMeshMovement, Verbose, TEXT("ProcessLanded(): %s tried to go to NavWalking but couldn't find NavMesh! Using Walking instead."), *GetNameSafe(CtxAccess(CharacterOwner)));
			}
		}

		SetPostLandedPhysics(Ctx, Hit);
	}
	// TODO ISPC: foreach_active?
	if (Comp->PathFollowingComp.IsValid())
	{
		Comp->PathFollowingComp->OnLanded();
	}

	StartNewPhysics(Ctx, remainingTime, Iterations);
}

void SetPostLandedPhysics(FISPCMovementContext Ctx, const FHitResult& Hit)
{
	if( CtxAccess(CharacterOwner) )
	{
		if (CanEverSwim(Ctx) && IsInWater(Ctx))
		{
			SetMovementMode(Ctx, MOVE_Swimming);
		}
		else
		{
			const FVector PreImpactAccel = CtxAccess(Acceleration) + (IsFalling(Ctx) ? FVector(0.f, 0.f, GetGravityZ(Ctx)) : FVector_ZeroVector);
			const FVector PreImpactVelocity = CtxAccess(Velocity);

			if (Comp->DefaultLandMovementMode == MOVE_Walking ||
				Comp->DefaultLandMovementMode == MOVE_NavWalking ||
				Comp->DefaultLandMovementMode == MOVE_Falling)
			{
				SetMovementMode(Ctx, Comp->GetGroundMovementMode());
			}
			else
			{
				SetDefaultMovementMode(Ctx);
			}
			
			ApplyImpactPhysicsForces(Ctx, Hit, PreImpactAccel, PreImpactVelocity);
		}
	}
}

void HandleImpact(FISPCMovementContext Ctx, const FHitResult& Impact, float TimeSlice, const FVector& MoveDelta)
{
	SCOPE_CYCLE_COUNTER(STAT_CharHandleImpact);

	if (CtxAccess(CharacterOwner))
	{
		CtxAccess(CharacterOwner)->MoveBlockedBy(Impact);
	}

	if (Comp->PathFollowingComp.IsValid())
	{	// Also notify path following!
		// TODO_ISPC: foreach_active
		Comp->PathFollowingComp->OnMoveBlockedBy(Impact);
	}

	APawn* OtherPawn = Cast<APawn>(Impact.GetActor());
	if (OtherPawn)
	{
		NotifyBumpedPawn(Ctx, OtherPawn);
	}

	if (Comp->bEnablePhysicsInteraction)
	{
		const FVector ForceAccel = CtxAccess(Acceleration) + (IsFalling(Ctx) ? FVector(0.f, 0.f, GetGravityZ(Ctx)) : FVector_ZeroVector);
		ApplyImpactPhysicsForces(Ctx, Impact, ForceAccel, CtxAccess(Velocity));
	}
}

void UpdateComponentVelocity(FISPCMovementContext Ctx)
{
	if ( CtxAccess(UpdatedComponent) )
	{
		CtxAccess(UpdatedComponent)->ComponentVelocity = CtxAccess(Velocity);
	}
}

void ApplyImpactPhysicsForces(FISPCMovementContext Ctx, const FHitResult& Impact, const FVector& ImpactAcceleration, const FVector& ImpactVelocity)
{
	if (Comp->bEnablePhysicsInteraction && Impact.bBlockingHit )
	{
		if (UPrimitiveComponent* ImpactComponent = Impact.GetComponent())
		{
			FBodyInstance* BI = ImpactComponent->GetBodyInstance(Impact.BoneName);
			if(BI != NULL && BI->IsInstanceSimulatingPhysics())
			{
				FVector ForcePoint = Impact.ImpactPoint;

				const float BodyMass = max(BI->GetBodyMass(), 1.0f);

				if(Comp->bPushForceUsingZOffset)
				{
					FBox Bounds = BI->GetBodyBounds();

					FVector Center, Extents;
					Bounds.GetCenterAndExtents(Center, Extents);

					if (!Extents.IsNearlyZero())
					{
						ForcePoint.z = Center.z + Extents.z * Comp->PushForcePointZOffsetFactor;
					}
				}

				FVector Force = Impact.ImpactNormal * -1.0f;

				float PushForceModificator = 1.0f;

				const FVector ComponentVelocity = ImpactComponent->GetPhysicsLinearVelocity();
				const FVector VirtualVelocity = FVector_IsZero(ImpactAcceleration) ? ImpactVelocity : FVector_GetSafeNormal(ImpactAcceleration) * GetMaxSpeed(Ctx);

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

bool FindNavFloor(FISPCMovementContext Ctx, const FVector& TestLocation, FNavLocation& NavFloorLocation)
{
#if 1	// TODO ISPC
	unimplemented();
	return false;
#else
	const ANavigationData* NavData = Comp->GetNavData();
	if (NavData == NULL)
	{
		return false;
	}

	INavAgentInterface* MyNavAgent = CastChecked<INavAgentInterface>(CtxAccess(CharacterOwner));
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
	if (IsMovingOnGround(Ctx))
	{
		// We don't want to be pushed up an unwalkable surface.
		if (Normal.z > 0.f)
		{
			if (!IsWalkable(Hit, Comp->GetWalkableFloorZ()))
			{
				Normal = Normal.GetSafeNormal2D();
			}
		}
		else if (Normal.z < -KINDA_SMALL_NUMBER)
		{
			// Don't push down into the floor when the impact is on the upper portion of the capsule.
			if (CtxAccess(CurrentFloor).FloorDist < MIN_FLOOR_DIST && FFindFloorResult_bBlockingHit(&CtxAccess(CurrentFloor)))
			{
				const FVector FloorNormal = CtxAccess(CurrentFloor).HitResult.Normal;
				const bool bFloorOpposedToMovement = (Delta | FloorNormal) < 0.f && (FloorNormal.z < 1.f - DELTA);
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

		FVector SlideDelta = ComputeSlideVector(Ctx, Delta, Time, Normal, Hit);

		if ((SlideDelta | Delta) > 0.f)
		{
			const FQuat Rotation = CtxAccess(UpdatedComponent_ComponentQuat);
			const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap = !!CVars::MoveIgnoreFirstBlockingOverlap->GetInt();
			SafeMoveUpdatedComponent(Ctx, bMoveIgnoreFirstBlockingOverlap, SlideDelta, Rotation, true, Hit);

			const float FirstHitPercent = Hit.Time;
			PercentTimeApplied = FirstHitPercent;
			if (Hit.IsValidBlockingHit())
			{
				// Notify first impact
				if (bHandleImpact)
				{
					HandleImpact(Ctx, Hit, FirstHitPercent * Time, SlideDelta);
				}

				// Compute new slide normal when hitting multiple surfaces.
				TwoWallAdjust(Ctx, SlideDelta, Hit, OldHitNormal);

				// Only proceed if the new direction is of significant length and not in reverse of original attempted move.
				if (!SlideDelta.IsNearlyZero(1e-3f) && (SlideDelta | Delta) > 0.f)
				{
					// Perform second move
					SafeMoveUpdatedComponent(Ctx, bMoveIgnoreFirstBlockingOverlap, SlideDelta, Rotation, true, Hit);
					const float SecondHitPercent = Hit.Time * (1.f - FirstHitPercent);
					PercentTimeApplied += SecondHitPercent;

					// Notify second impact
					if (bHandleImpact && Hit.bBlockingHit)
					{
						HandleImpact(Ctx, Hit, SecondHitPercent * Time, SlideDelta);
					}
				}
			}

			return FMath::Clamp(PercentTimeApplied, 0.f, 1.f);
		}

		return 0.f;
	}
}

void TwoWallAdjust(FISPCMovementContext Ctx, FVector& InOutDelta, const FHitResult& Hit, const FVector& OldHitNormal)
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
			Delta = ComputeSlideVector(Ctx, Delta, 1.f - Hit.Time, HitNormal, Hit);
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

	if (IsMovingOnGround(Ctx))
	{
		// Allow slides up walkable surfaces, but not unwalkable ones (treat those as vertical barriers).
		if (InOutDelta.z > 0.f)
		{
			if ((Hit.Normal.z >= Comp->GetWalkableFloorZ() || IsWalkable(Hit, Comp->GetWalkableFloorZ())) && Hit.Normal.z > KINDA_SMALL_NUMBER)
			{
				// Maintain horizontal velocity
				const float Time = (1.f - Hit.Time);
				const FVector ScaledDelta = InOutDelta.GetSafeNormal() * InDelta.Size();
				InOutDelta = FVector(InDelta.x, InDelta.y, ScaledDelta.z / Hit.Normal.Z) * Time;
			}
			else
			{
				InOutDelta.z = 0.f;
			}
		}
		else if (InOutDelta.z < 0.f)
		{
			// Don't push down into the floor.
			if (CtxAccess(CurrentFloor).FloorDist < MIN_FLOOR_DIST && FFindFloorResult_bBlockingHit(&CtxAccess(CurrentFloor)))
			{
				InOutDelta.z = 0.f;
			}
		}
	}
}

FVector Super_ComputeSlideVector(FISPCMovementContext Ctx, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit)
{
	if (!CtxAccess(bConstrainToPlane))
	{
		return FVector::VectorPlaneProject(Delta, Normal) * Time;
	}
	else
	{
		const FVector ProjectedNormal = ConstrainNormalToPlane(Ctx, Normal);
		return FVector::VectorPlaneProject(Delta, ProjectedNormal) * Time;
	}
}

FVector ComputeSlideVector(FISPCMovementContext Ctx, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit)
{
	FVector Result = Super_ComputeSlideVector(Ctx, Delta, Time, Normal, Hit);

	// prevent boosting up slopes
	if (IsFalling(Ctx))
	{
		Result = HandleSlopeBoosting(Ctx, Result, Delta, Time, Normal, Hit);
	}

	return Result;
}

FVector HandleSlopeBoosting(FISPCMovementContext Ctx, const FVector& SlideResult, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit)
{
	FVector Result = SlideResult;

	if (Result.z > 0.f)
	{
		// Don't move any higher than we originally intended.
		const float ZLimit = Delta.z * Time;
		if (Result.z - ZLimit > KINDA_SMALL_NUMBER)
		{
			if (ZLimit > 0.f)
			{
				// Rescale the entire vector (not just the Z component) otherwise we change the direction and likely head right back into the impact.
				const float UpPercent = ZLimit / Result.z;
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
			const FVector Adjust = Super_ComputeSlideVector(Ctx, RemainderXY, 1.f, NormalXY, Hit);
			Result += Adjust;
		}
	}

	return Result;
}

FVector LimitAirControl(FISPCMovementContext Ctx, float DeltaTime, const FVector& FallAcceleration, const FHitResult& HitResult, bool bCheckForValidLandingSpot)
{
	FVector Result(FallAcceleration);

	if (HitResult.IsValidBlockingHit() && HitResult.Normal.z > VERTICAL_SLOPE_NORMAL_Z)
	{
		if (!bCheckForValidLandingSpot || !IsValidLandingSpot(Ctx, HitResult.Location, HitResult))
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
		if (Comp->AirControlBoostMultiplier > 0.f && CtxAccess(Velocity).SizeSquared2D() < FMath_Square(Comp->AirControlBoostVelocityThreshold))
		{
			TickAirControl = min(1.f, Comp->AirControlBoostMultiplier * TickAirControl);
		}
	}

	return TickAirControl * FallAcceleration;
}

FString GetMovementName(FISPCMovementContext Ctx)
{
	// TODO ISPC: foreach_active?
	if( CtxAccess(CharacterOwner) )
	{
		if ( CtxAccess(CharacterOwner)->GetRootComponent() && CtxAccess(CharacterOwner)->GetRootComponent()->IsSimulatingPhysics() )
		{
			return TEXT("Rigid Body");
		}
		else if ( CtxAccess(CharacterOwner_IsMatineeControlled) )
		{
			return TEXT("Matinee");
		}
	}

	// Using character movement
	switch( CtxAccess(MovementMode) )
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
	CtxAccess(Velocity) = FVector_ZeroVector;
	UpdateComponentVelocity(Ctx);
	StopActiveMovement(Ctx);
}

void StopMovementKeepPathing(FISPCMovementContext Ctx)
{
	Comp->bStopMovementAbortPaths = false;
	StopMovementImmediately(Ctx);
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
		RequestedSpeed = (Comp->bRequestedMoveWithMaxSpeed ? MaxSpeed : min(MaxSpeed, RequestedSpeed));
		
		// Compute actual requested velocity
		const FVector MoveVelocity = RequestedMoveDir * RequestedSpeed;
		
		// Compute acceleration. Use MaxAccel to limit speed increase, 1% buffer.
		FVector NewAcceleration = FVector_ZeroVector;
		const float CurrentSpeedSq = CtxAccess(Velocity).SizeSquared();
		if (Comp->bRequestedMoveUseAcceleration && CurrentSpeedSq < FMath_Square(RequestedSpeed * 1.01f))
		{
			// Turn in the same manner as with input acceleration.
			const float VelSize = FMath::Sqrt(CurrentSpeedSq);
			CtxAccess(Velocity) = CtxAccess(Velocity) - (CtxAccess(Velocity) - RequestedMoveDir * VelSize) * min(DeltaTime * Friction, 1.f);

			// How much do we need to accelerate to get to the new velocity?
			NewAcceleration = ((MoveVelocity - CtxAccess(Velocity)) / DeltaTime);
			NewAcceleration = NewAcceleration.GetClampedToMaxSize(MaxAccel);
		}
		else
		{
			// Just set velocity directly.
			// If decelerating we do so instantly, so we don't slide through the destination if we can't brake fast enough.
			CtxAccess(Velocity) = MoveVelocity;
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

FRotator GetDeltaRotation(FISPCMovementContext Ctx, float DeltaTime)
{
	return FRotator(GetAxisDeltaRotation(Comp->RotationRate.Pitch, DeltaTime), GetAxisDeltaRotation(Comp->RotationRate.yaw, DeltaTime), GetAxisDeltaRotation(Comp->RotationRate.Roll, DeltaTime));
}

FRotator ComputeOrientToMovementRotation(FISPCMovementContext Ctx, const FRotator& CurrentRotation, float DeltaTime, FRotator& DeltaRotation)
{
	if (CtxAccess(Acceleration).SizeSquared() < KINDA_SMALL_NUMBER)
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
	return CtxAccess(Acceleration).GetSafeNormal().Rotation();
}

bool ShouldRemainVertical(FISPCMovementContext Ctx)
{
	// Always remain vertical when walking or falling.
	return IsMovingOnGround(Ctx) || IsFalling(Ctx);
}

void PhysicsRotation(FISPCMovementContext Ctx, float DeltaTime)
{
	if (!(Comp->bOrientRotationToMovement || Comp->bUseControllerDesiredRotation))
	{
		return;
	}

	if (!HasValidData(Ctx) || (!CtxAccess(CharacterOwner)->Controller && !Comp->bRunPhysicsWithNoController))
	{
		return;
	}

	FRotator CurrentRotation = CtxAccess(UpdatedComponent)->GetComponentRotation(); // Normalized
	CurrentRotation.DiagnosticCheckNaN(TEXT("CharacterMovementComponent::PhysicsRotation(): CurrentRotation"));

	FRotator DeltaRot = GetDeltaRotation(Ctx, DeltaTime);
	DeltaRot.DiagnosticCheckNaN(TEXT("CharacterMovementComponent::PhysicsRotation(): GetDeltaRotation"));

	FRotator DesiredRotation = CurrentRotation;
	if (Comp->bOrientRotationToMovement)
	{
		DesiredRotation = ComputeOrientToMovementRotation(Ctx, CurrentRotation, DeltaTime, DeltaRot);
	}
	else if (CtxAccess(CharacterOwner)->Controller && Comp->bUseControllerDesiredRotation)
	{
		DesiredRotation = CtxAccess(CharacterOwner)->Controller->GetDesiredRotation();
	}
	else
	{
		return;
	}

	if (ShouldRemainVertical(Ctx))
	{
		DesiredRotation.Pitch = 0.f;
		DesiredRotation.yaw = FRotator::NormalizeAxis(DesiredRotation.yaw);
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
		if (!FMath::IsNearlyEqual(CurrentRotation.yaw, DesiredRotation.yaw, AngleTolerance))
		{
			DesiredRotation.yaw = FMath::FixedTurn(CurrentRotation.yaw, DesiredRotation.yaw, DeltaRot.yaw);
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

bool HasRootMotionSources(FISPCMovementContext Ctx)
{
	return CtxAccess(CurrentRootMotion_HasActiveRootMotionSources) || (CtxAccess(CharacterOwner) && CtxAccess(CharacterOwner_IsPlayingRootMotion) && CtxAccess(CharacterOwner_GetMesh));
}

bool HasAnimRootMotion(FISPCMovementContext Ctx)
{
	return CtxAccess(RootMotionParams_bHasRootMotion);
}
