#pragma once

#include "CppInterop.h"

#ifdef ISPC
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

	inline varying bool insert(varying bool v, uniform int32 index, uniform bool u)
	{
		return (varying bool)insert((varying int8)v, index, (uniform int8)u);
	}
	inline varying FVector insert(varying FVector v, uniform int32 index, uniform FVector u)
	{
		v.x = insert(v.x, index, u.x);
		v.y = insert(v.y, index, u.y);
		v.z = insert(v.z, index, u.z);
		return v;
	}

	#define DefineCppCallback_1Arg(FuncName, Arg1Type, Arg1, CppCode)	\
		void FuncName(Arg1Type uniform Arg1)	\
		{	\
			extern "C" void FuncName ## _CppCallback(Arg1Type uniform Arg1);\
			FuncName ## _CppCallback(Arg1);	\
		}	\
		inline void FuncName(Arg1Type varying Arg1)	\
		{	\
			foreach_active (Index)	\
			{	\
				FuncName(extract(Arg1, Index));\
			}	\
		}

	#define DefineCppCallback_2Arg(FuncName, Arg1Type, Arg1, Arg2Type, Arg2, CppCode)	\
		void FuncName(Arg1Type uniform Arg1, Arg2Type uniform Arg2)	\
		{	\
			extern "C" void FuncName ## _CppCallback(Arg1Type uniform Arg1, Arg2Type uniform Arg2);\
			FuncName ## _CppCallback(Arg1, Arg2);	\
		}	\
		inline void FuncName(Arg1Type varying Arg1, Arg2Type varying Arg2)	\
		{	\
			foreach_active (Index)	\
			{	\
				FuncName(extract(Arg1, Index), extract(Arg2, Index));\
			}	\
		}

	#define DefineCppCallback_3Arg(FuncName, Arg1Type, Arg1, Arg2Type, Arg2, Arg3Type, Arg3, CppCode)	\
		void FuncName(Arg1Type uniform Arg1, Arg2Type uniform Arg2, Arg3Type uniform Arg3)	\
		{	\
			extern "C" void FuncName ## _CppCallback(Arg1Type uniform Arg1, Arg2Type uniform Arg2, Arg3Type uniform Arg3);\
			FuncName ## _CppCallback(Arg1, Arg2, Arg3);	\
		}	\
		inline void FuncName(Arg1Type varying Arg1, Arg2Type varying Arg2, Arg3Type varying Arg3)	\
		{	\
			foreach_active (Index)	\
			{	\
				FuncName(extract(Arg1, Index), extract(Arg2, Index), extract(Arg3, Index));\
			}	\
		}

	#define DefineCppCallback_1Arg_RetVal(ReturnType, FuncName, Arg1Type, Arg1, CppCode)	\
		ReturnType uniform FuncName(Arg1Type uniform Arg1)	\
		{	\
			extern "C" ReturnType uniform FuncName ## _CppCallback(Arg1Type uniform Arg1);\
			return FuncName ## _CppCallback(Arg1);	\
		}	\
		inline ReturnType varying FuncName(Arg1Type varying Arg1)	\
		{	\
			ReturnType varying ReturnValue;	\
			foreach_active (Index)	\
			{	\
				ReturnValue = insert(ReturnValue, Index, FuncName(extract(Arg1, Index)));\
			}	\
		}

	#define DefineCppCallback_2Arg_RetVal(ReturnType, FuncName, Arg1Type, Arg1, Arg2Type, Arg2, CppCode)	\
		ReturnType uniform FuncName(Arg1Type uniform Arg1, Arg2Type uniform Arg2)	\
		{	\
			extern "C" ReturnType uniform FuncName ## _CppCallback(Arg1Type uniform Arg1, Arg2Type uniform Arg2);\
			return FuncName ## _CppCallback(Arg1, Arg2);	\
		}	\
		inline varying ReturnType FuncName(Arg1Type varying Arg1, Arg2Type varying Arg2)	\
		{	\
			ReturnType varying ReturnValue;	\
			foreach_active (Index)	\
			{	\
				ReturnValue = insert(ReturnValue, Index, FuncName(extract(Arg1, Index), extract(Arg2, Index)));\
			}	\
		}
#else
	#define	AccessComp	((UShooterUnrolledCppMovement*)_Comp)

	#define DefineCppCallback_1Arg(FuncName, Arg1Type, Arg1, CppCode)	\
		extern "C" void FuncName ## _CppCallback(Arg1Type Arg1) { CppCode }
	
	#define DefineCppCallback_2Arg(FuncName, Arg1Type, Arg1, Arg2Type, Arg2, CppCode)	\
		extern "C" void FuncName ## _CppCallback(Arg1Type Arg1, Arg2Type Arg2) { CppCode }

	#define DefineCppCallback_3Arg(FuncName, Arg1Type, Arg1, Arg2Type, Arg2, Arg3Type, Arg3, CppCode)	\
		extern "C" void FuncName ## _CppCallback(Arg1Type Arg1, Arg2Type Arg2, Arg3Type Arg3) { CppCode }

	#define DefineCppCallback_1Arg_RetVal(ReturnType, FuncName, Arg1Type, Arg1, CppCode)	\
		extern "C" ReturnType FuncName ## _CppCallback(Arg1Type Arg1) { CppCode }

	#define DefineCppCallback_2Arg_RetVal(ReturnType, FuncName, Arg1Type, Arg1, Arg2Type, Arg2, CppCode)	\
		extern "C" ReturnType FuncName ## _CppCallback(Arg1Type Arg1, Arg2Type Arg2) { CppCode }
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
		CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleRadius(), DefaultCharacter->GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight());
	})

DefineCppCallback_3Arg(SetCapsuleSize,
	const void*, _CharacterOwner, float, Radius, float, HalfHeight,
	{
		auto* CharacterOwner = (ACharacter*)_CharacterOwner;
		CharacterOwner->GetCapsuleComponent()->SetCapsuleSize(Radius, HalfHeight);
	})
