#pragma once

#include "CppInterop.h"

#ifdef ISPC
	inline void* uniform extract(void* varying x, uniform int i)
	{
		return (void* uniform)extract((unsigned int64)x, i);
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

	#define DefineCppCallback_1Arg_RetVal(ReturnType, FuncName, Arg1Type, Arg1, CppCode)	\
		ReturnType uniform FuncName(Arg1Type uniform Arg1)	\
		{	\
			extern "C" ReturnType uniform FuncName ## _CppCallback(Arg1Type uniform Arg1);\
			return FuncName ## _CppCallback(Arg1);	\
		}	\
		inline ReturnType varying FuncName(varying Arg1Type Arg1)	\
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
	#define DefineCppCallback_1Arg(FuncName, Arg1Type, Arg1, CppCode)	\
		extern "C" void FuncName ## _CppCallback(Arg1Type Arg1) { CppCode }
	
	#define DefineCppCallback_2Arg(FuncName, Arg1Type, Arg1, Arg2Type, Arg2, CppCode)	\
		extern "C" void FuncName ## _CppCallback(Arg1Type Arg1, Arg2Type Arg2) { CppCode }

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
