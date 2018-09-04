#include "CppCallbackMacros.h"

#ifdef ISPC
	#define Marshalled_FVector	FVector
#else
	#define Marshalled_FVector	ispc::float3
	#define	AccessComp	((UShooterUnrolledCppMovement*)_Comp)
#endif

DefineCppCallback_2Arg(ConsumeRootMotion,
	const void*, _Comp, float, DeltaSeconds,
	{
		auto* Comp = (UShooterUnrolledCppMovement*)_Comp;
		// Consume root motion
		//Comp->TickCharacterPose(DeltaSeconds);	// TODO ISPC Actual
		Comp->RootMotionParams.Clear();
		Comp->CurrentRootMotion.Clear();
	})

DefineCppCallback_1Arg_RetVal(bool, IsPendingKill,
	const void*, _Obj,
	{
		return static_cast<const UObject*>(_Obj)->IsPendingKill();
	})

DefineCppCallback_1Arg_RetVal(Marshalled_FVector, GetUpdatedComponentLocation,
	const void*, _Comp,
	{
		FVector Result = AccessComp->UpdatedComponent->GetComponentLocation();
		return *reinterpret_cast<ispc::float3*>(&Result);
	})

DefineCppCallback_2Arg(SetCharacterOwner_bIsCrouched,
	const void*, _Comp, const bool, bValue,
	{
		AccessComp->CharacterOwner->bIsCrouched = bValue;
	})

DefineCppCallback_3Arg(CharacterOwner_OnStartCrouch,
	const void*, _Comp, const float, HeightAdjust, const float, ScaledHeightAdjust,
	{
		AccessComp->CharacterOwner->OnStartCrouch(HeightAdjust, ScaledHeightAdjust);
	})

DefineCppCallback_1Arg(RestoreDefaultCapsuleSize,
	const void*, _CharacterOwner,
	{
		auto* CharacterOwner = (ACharacter*)_CharacterOwner;
		ACharacter* DefaultCharacter = CharacterOwner->GetClass()->GetDefaultObject<ACharacter>();
		CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(
			DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleRadius(),
			DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight());
	})

DefineCppCallback_3Arg(SetCapsuleSize,
	const void*, _CharacterOwner, float, Radius, float, HalfHeight,
	{
		auto* CharacterOwner = (ACharacter*)_CharacterOwner;
		CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(Radius, HalfHeight);
	})

DefineCppCallback_5Arg(UpdatedPrimitive_InitSweepCollisionParams,
	const void*, _UpdatedPrimitive, FName, InTraceTag, const void*, _InIgnoreActor,
	void*, _OutParams, void*, _OutResponseParam,
	{
		// FIXME: Trace tag?
		FName TraceTag = NAME_None;
		FCollisionQueryParams* Query = new (_OutParams) FCollisionQueryParams(TraceTag, false, (AActor*)_InIgnoreActor);
		FCollisionResponseParams* Response = new (_OutResponseParam) FCollisionResponseParams();
		((UPrimitiveComponent*)_UpdatedPrimitive)->InitSweepCollisionParams(
			*Query, *Response);
	});

DefineCppCallback_7Arg_RetVal(bool, OverlapBlockingTestByChannel,
	const void*, _Comp, const FVector, Pos, const FQuat, Rot,
	/*ECollisionChannel*/uint8, TraceChannel, const void*, _CollisionShape,
	const /*FCollisionQueryParams**/void*, _Params, const /*FCollisionResponseParams**/void*, _ResponseParam,
	{
		return AccessComp->GetWorld()->OverlapBlockingTestByChannel(
			Pos, Rot, (ECollisionChannel)TraceChannel,
			*((FCollisionShape*)_CollisionShape),
			*((FCollisionQueryParams*)_Params),
			*((FCollisionResponseParams*)_ResponseParam));
	})

DefineCppCallback_9Arg_RetVal(bool, SweepSingleByChannel,
	const void*, _Comp, /*FHitResult**/void*, _OutHit, const FVector, Start,
	const FVector, End, const FQuat, Rot, /*ECollisionChannel*/uint8, TraceChannel,
	const /*FCollisionShape**/void*, _CollisionShape, const /*FCollisionQueryParams**/void*, _Params,
	const /*FCollisionResponseParams**/void*, _ResponseParam,
	{
		return AccessComp->GetWorld()->SweepSingleByChannel(
			*static_cast<FHitResult*>(_OutHit),
			Start, End, Rot, (ECollisionChannel)TraceChannel,
			*((FCollisionShape*)_CollisionShape),
			*((FCollisionQueryParams*)_Params),
			*((FCollisionResponseParams*)_ResponseParam));
	})

DefineCppCallback_7Arg_RetVal(bool, MoveComponent,
	const void*, _Comp, const FVector, Delta, const FQuat, NewRotation, bool, bSweep, /*FHitResult**/void*, _Hit, /*EMoveComponentFlags*/uint8, MoveFlags, /*ETeleportType*/uint8, Teleport,
	{
		return ((USceneComponent*)_Comp)->MoveComponent(
			Delta,
			NewRotation,
			bSweep,
			static_cast<FHitResult*>(_Hit),
			(EMoveComponentFlags)MoveFlags,
			(ETeleportType)Teleport);
	})

DefineCppCallback_3Arg(OnStartCrouch,
	const void*, _CharacterOwner, float, HeightAdjust, float, ScaledHeightAdjust,
	{
		((ACharacter*)_CharacterOwner)->OnStartCrouch(HeightAdjust, ScaledHeightAdjust);
	})

DefineCppCallback_3Arg(OnEndCrouch,
	const void*, _CharacterOwner, float, HeightAdjust, float, ScaledHeightAdjust,
	{
		((ACharacter*)_CharacterOwner)->OnEndCrouch(HeightAdjust, ScaledHeightAdjust);
	})

DefineCppCallback_2Arg(MakeCapsuleCollisionShape,
	FVector, Extent, /*FCollisionShape**/void*, _OutShape,
	{
		*static_cast<FCollisionShape*>(_OutShape) = FCollisionShape::MakeCapsule(Extent);
	})

DefineCppCallback_1Arg(ClearJumpInput,
	const void*, _CharacterOwner,
	{
		((ACharacter*)_CharacterOwner)->ClearJumpInput();
	})

DefineCppCallback_2Arg_RetVal(float, MaybeModifyWalkableFloorZ,
	const FWeakObjectPtr, _HitComponent, float, TestWalkableZ,
	{
		auto& HitObject = *const_cast<FWeakObjectPtr*>(&_HitComponent);
		const UPrimitiveComponent* HitComponent = Cast<UPrimitiveComponent>(HitObject.Get());
		if (HitComponent)
		{
			const FWalkableSlopeOverride& SlopeOverride = HitComponent->GetWalkableSlopeOverride();
			return SlopeOverride.ModifyWalkableFloorZ(TestWalkableZ);
		}
		return TestWalkableZ;
	})

DefineCppCallback_4Arg(OnCharacterMovementUpdated,
	const void*, _CharacterOwner, float, DeltaTime, const FVector, OldLocation, const FVector, OldVelocity,
	{
		((ACharacter*)_CharacterOwner)->OnCharacterMovementUpdated.Broadcast(DeltaTime, OldLocation, OldVelocity);
	})

DefineCppCallback_1Arg(CancelAdaptiveReplication,
	const void*, _Comp,
	{
		const UWorld* MyWorld = AccessComp->GetWorld();
		if (MyWorld)
		{
			UNetDriver* NetDriver = MyWorld->GetNetDriver();
			if (NetDriver && NetDriver->IsServer())
			{
				FNetworkObjectInfo* NetActor = NetDriver->FindOrAddNetworkObjectInfo(AccessComp->CharacterOwner);

				if (NetActor && MyWorld->GetTimeSeconds() <= NetActor->NextUpdateTime && NetDriver->IsNetworkActorUpdateFrequencyThrottled(*NetActor))
				{
					if (AccessComp->ShouldCancelAdaptiveReplication())
					{
						NetDriver->CancelAdaptiveReplication(*NetActor);
					}
				}
			}
		}
	})

DefineCppCallback_1Arg_RetVal(float, GetPhysicsVolume_GetGravityZ,
	const void*, _MoveComp,
	{
		auto* MoveComp = (UCharacterMovementComponent*)_MoveComp;
		if (MoveComp->UpdatedComponent)
		{
			return MoveComp->UpdatedComponent->GetPhysicsVolume()->GetGravityZ();
		}
		return MoveComp->GetWorld()->GetDefaultPhysicsVolume()->GetGravityZ();
	})