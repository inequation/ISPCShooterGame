// Copyright 1998-2018 Epic Games, Inc. All Rights Reserved.

#include "ShooterGame.h"
#include "Bots/ShooterBot.h"
#include "Bots/ShooterAIController.h"
#include "Bots/ShooterUnrolledCppMovement.h"

TAutoConsoleVariable<int32> GMovementImplementation(
	TEXT("ispc.MovementImplementation"),
	1,
	TEXT("Which movement implementation to use for bots (needs bot respawn to take effect):\n")
	TEXT("0 (default): vanilla Unreal object-oriented components\n")
	TEXT("1: unrolled system in C++ with lightweight components\n")
	/*TEXT("2: unrolled system in ISPC with lightweight components")*/,
	ECVF_Default
);

AShooterBot::AShooterBot(const FObjectInitializer& ObjectInitializer) 
	: Super(
		GMovementImplementation.GetValueOnGameThread() == 0
		? ObjectInitializer.SetDefaultSubobjectClass<UShooterCharacterMovement>(ACharacter::CharacterMovementComponentName)
		: ObjectInitializer.SetDefaultSubobjectClass<UShooterUnrolledCppMovement>(ACharacter::CharacterMovementComponentName)
	)
{
	AIControllerClass = AShooterAIController::StaticClass();

	UpdatePawnMeshes();

	bUseControllerRotationYaw = true;
}

bool AShooterBot::IsFirstPerson() const
{
	return false;
}

void AShooterBot::FaceRotation(FRotator NewRotation, float DeltaTime)
{
	FRotator CurrentRotation = FMath::RInterpTo(GetActorRotation(), NewRotation, DeltaTime, 8.0f);

	Super::FaceRotation(CurrentRotation, DeltaTime);
}
