#pragma once

#include "CppCallbackMacros.h"

#ifndef ISPC
	#define	AccessComp	((UShooterUnrolledCppMovement*)_Comp)
#endif

DefineCppCallback_2Arg(ConsumeRootMotion,
	void*, _Comp, float, DeltaSeconds,
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
		return static_cast<UObject*>(_Obj)->IsPendingKill();
	})

DefineCppCallback_1Arg_RetVal(FVector, GetUpdatedComponentLocation,
	const void*, _Comp,
	{
		return AccessComp->UpdatedComponent->GetComponentLocation();
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
		FCollisionQueryParams* Query = new (_OutParams) FCollisionQueryParams(TraceTag, false, static_cast<AActor*>(_InIgnoreActor));
		FCollisionResponseParams Response = new (_OutResponseParam) FCollisionResponseParams();
		static_cast<UPrimitiveComponent*>(_UpdatedPrimitive)->InitSweepCollisionParams(
			*Query, *Response);
	});

DefineCppCallback_7Arg(OverlapBlockingTestByChannel,
	const void*, _Comp, const FVector, Pos, const FQuat, Rot,
	/*ECollisionChannel*/uint8, TraceChannel, const void*, _CollisionShape,
	const /*FCollisionQueryParams**/void*, _Params, const /*FCollisionResponseParams**/void*, _ResponseParam,
	{
		AccessComp(GetWorld())->OverlapBlockingTestByChannel(
			Pos, Rot, (ECollisionChannel)TraceChannel, _CollisionShape,
			*static_cast<FCollisionQueryParams*>(_CapsuleParams),
			*static_cast<FCollisionResponseParams*>(_ResponseParam));
	})

DefineCppCallback_7Arg(MoveComponent,
	const void*, _Comp, const FVector, Delta, const FQuat, NewRotation, bool, bSweep, /*FHitResult**/void*, _Hit, /*EMoveComponentFlags*/uint8, MoveFlags, /*ETeleportType*/uint8, Teleport,
	{
		static_cast<USceneComponent*>(_Comp)->MoveComponent(
			Delta,
			NewRotation,
			bSweep,
			static_cast<FHitResult*>(_Hit),
			(EMoveComponentFlags)MoveFlags,
			(ETeleportType)Teleport);
	})
