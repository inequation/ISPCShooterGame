/**
 * Movement component and system meant for use with bots.
 */

#pragma once
#include "Player/ShooterCharacterMovement.h"
#include "ShooterUnrolledCppMovement.generated.h"

UCLASS()
class UShooterUnrolledCppMovement : public UShooterCharacterMovement
{
	GENERATED_UCLASS_BODY()

public:
	virtual void InitializeComponent() override;
	virtual void UninitializeComponent() override;

	/** Perform movement on an autonomous client */
	virtual void PerformMovement(float DeltaTime) override;

	friend class UShooterUnrolledCppMovementSystem;
};

USTRUCT()
struct FSystemTickFunction : public FTickFunction
{
	GENERATED_USTRUCT_BODY()

	class UShooterUnrolledCppMovementSystem* System;

	FSystemTickFunction()
		: FTickFunction()
		, System(nullptr)
	{}

	virtual void ExecuteTick(float DeltaTime, ELevelTick TickType, ENamedThreads::Type CurrentThread, const FGraphEventRef& MyCompletionGraphEvent) override;
	virtual FString DiagnosticMessage() override;
};

template<>
struct TStructOpsTypeTraits<FSystemTickFunction> : public TStructOpsTypeTraitsBase2<FSystemTickFunction>
{
	enum
	{
		WithCopy = false
	};
};

UCLASS()
class UShooterUnrolledCppMovementSystem : public UObject
{
	GENERATED_UCLASS_BODY()

public:
	void Initialize();
	void Uninitialize();
	void RegisterComponent(UShooterUnrolledCppMovement* Comp);
	void UnregisterComponent(UShooterUnrolledCppMovement* Comp);

	void Tick(float DeltaTime);

	//~ Begin UObject interface.
	virtual void BeginDestroy() override;
	//~ End UObject interface.

	/** Main tick function for the System */
	UPROPERTY(EditDefaultsOnly, Category = "SystemTick")
	struct FSystemTickFunction TickFunction;

	/** changes physics based on MovementMode */
	void StartNewPhysics(UShooterUnrolledCppMovement* Comp, float deltaTime, int32 Iterations);

	/**
	 * Change movement mode.
	 *
	 * @param NewMovementMode	The new movement mode
	 * @param NewCustomMode		The new custom sub-mode, only applicable if NewMovementMode is Custom.
	 */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	void SetMovementMode(UShooterUnrolledCppMovement* Comp, EMovementMode NewMovementMode, uint8 NewCustomMode = 0);

	/**
	 * Set movement mode to use when returning to walking movement (either MOVE_Walking or MOVE_NavWalking).
	 * If movement mode is currently one of Walking or NavWalking, this will also change the current movement mode (via SetMovementMode())
	 * if the new mode is not the current ground mode.
	 * 
	 * @param  NewGroundMovementMode New ground movement mode. Must be either MOVE_Walking or MOVE_NavWalking, other values are ignored.
	 * @see GroundMovementMode
	 */
	void SetGroundMovementMode(UShooterUnrolledCppMovement* Comp, EMovementMode NewGroundMovementMode);

	/** Set movement mode to the default based on the current physics volume. */
	void SetDefaultMovementMode(UShooterUnrolledCppMovement* Comp);

	/**
	 * If we have a movement base, get the velocity that should be imparted by that base, usually when jumping off of it.
	 * Only applies the components of the velocity enabled by bImpartBaseVelocityX, bImpartBaseVelocityY, bImpartBaseVelocityZ.
	 */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	FVector GetImpartedMovementBaseVelocity(UShooterUnrolledCppMovement* Comp) const;

	//BEGIN UMovementComponent Interface
	float GetMaxSpeed(UShooterUnrolledCppMovement* Comp) const;
	void StopActiveMovement(UShooterUnrolledCppMovement* Comp);
	bool IsCrouching(UShooterUnrolledCppMovement* Comp) const;
	bool IsFalling(UShooterUnrolledCppMovement* Comp) const;
	bool IsMovingOnGround(UShooterUnrolledCppMovement* Comp) const;
	bool IsSwimming(UShooterUnrolledCppMovement* Comp) const;
	bool IsFlying(UShooterUnrolledCppMovement* Comp) const;
	float GetGravityZ(UShooterUnrolledCppMovement* Comp) const;
	void AddRadialForce(UShooterUnrolledCppMovement* Comp, const FVector& Origin, float Radius, float Strength, enum ERadialImpulseFalloff Falloff);
	void AddRadialImpulse(UShooterUnrolledCppMovement* Comp, const FVector& Origin, float Radius, float Strength, enum ERadialImpulseFalloff Falloff, bool bVelChange);
	//END UMovementComponent Interface

	//Begin UPawnMovementComponent Interface
	void NotifyBumpedPawn(UShooterUnrolledCppMovement* Comp, APawn* BumpedPawn);
	//End UPawnMovementComponent Interface

	/** Stops movement immediately (zeroes velocity, usually zeros acceleration for components with acceleration). */
	UFUNCTION(BlueprintCallable, Category="Components|Movement")
	void StopMovementImmediately(UShooterUnrolledCppMovement* Comp);

	/** Stops movement immediately (reset velocity) but keeps following current path */
	UFUNCTION(BlueprintCallable, Category="Components|Movement")
	void StopMovementKeepPathing(UShooterUnrolledCppMovement* Comp);

	/** @return Maximum acceleration for the current state. */
	UFUNCTION(BlueprintCallable, Category = "Pawn|Components|CharacterMovement")
	float GetMinAnalogSpeed(UShooterUnrolledCppMovement* Comp) const;

	/** @return whether this pawn is currently allowed to walk off ledges */
	bool CanWalkOffLedges(UShooterUnrolledCppMovement* Comp) const;

	/** 
	 * @param Delta is the current move delta (which ended up going over a ledge).
	 * @return new delta which moves along the ledge
	 */
	FVector GetLedgeMove(UShooterUnrolledCppMovement* Comp, const FVector& OldLocation, const FVector& Delta, const FVector& GravDir) const;

	/** @return The distance from the edge of the capsule within which we don't allow the character to perch on the edge of a surface. */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	float GetPerchRadiusThreshold(UShooterUnrolledCppMovement* Comp) const;

	/**
	 * Checks if new capsule size fits (no encroachment), and call CharacterOwner->OnStartCrouch() if successful.
	 * In general you should set bWantsToCrouch instead to have the crouch persist during movement, or just use the crouch functions on the owning Character.
	 * @param	bClientSimulation	true when called when bIsCrouched is replicated to non owned clients, to update collision cylinder and offset.
	 */
	void Crouch(UShooterUnrolledCppMovement* Comp, bool bClientSimulation = false);
	
	/**
	 * Checks if default capsule size fits (no encroachment), and trigger OnEndCrouch() on the owner if successful.
	 * @param	bClientSimulation	true when called when bIsCrouched is replicated to non owned clients, to update collision cylinder and offset.
	 */
	void UnCrouch(UShooterUnrolledCppMovement* Comp, bool bClientSimulation = false);

	/** @return true if the character is allowed to crouch in the current state. By default it is allowed when walking or falling, if CanEverCrouch() is true. */
	bool CanCrouchInCurrentState(UShooterUnrolledCppMovement* Comp) const;

	/** @return true if there is a suitable floor SideStep from current position. */
	bool CheckLedgeDirection(UShooterUnrolledCppMovement* Comp, const FVector& OldLocation, const FVector& SideStep, const FVector& GravDir) const;

	/**
	 * Returns the radius within which we can stand on the edge of a surface without falling (if this is a walkable surface).
	 * Simply computed as the capsule radius minus the result of GetPerchRadiusThreshold().
	 */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	float GetValidPerchRadius(UShooterUnrolledCppMovement* Comp) const;

	/**
	 * Returns true if the current velocity is exceeding the given max speed (usually the result of GetMaxSpeed()), within a small error tolerance.
	 * Note that under normal circumstances updates cause by acceleration will not cause this to be true, however external forces or changes in the max speed limit
	 * can cause the max speed to be violated.
	 */
	UFUNCTION(BlueprintCallable, Category="Components|Movement")
	bool IsExceedingMaxSpeed(UShooterUnrolledCppMovement* Comp, float MaxSpeed) const;

	APhysicsVolume* GetPhysicsVolume(UShooterUnrolledCppMovement* Comp) const;

	/** Return true if we have a valid CharacterOwner and UpdatedComponent. */
	bool HasValidData(const UShooterUnrolledCppMovement* Comp) const;

	/** @return Maximum deceleration for the current state when braking (ie when there is no acceleration). */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	float GetMaxBrakingDeceleration(UShooterUnrolledCppMovement* Comp) const;

	/** @return Maximum acceleration for the current state. */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	float GetMaxAcceleration(UShooterUnrolledCppMovement* Comp) const;

	/** return true if it's in PhysicsVolume with water flag **/
	bool IsInWater(UShooterUnrolledCppMovement* Comp) const;

	/**
	 * Updates Velocity and Acceleration based on the current state, applying the effects of friction and acceleration or deceleration. Does not apply gravity.
	 * This is used internally during movement updates. Normally you don't need to call this from outside code, but you might want to use it for custom movement modes.
	 *
	 * @param	DeltaTime						time elapsed since last frame.
	 * @param	Friction						coefficient of friction when not accelerating, or in the direction opposite acceleration.
	 * @param	bFluid							true if moving through a fluid, causing Friction to always be applied regardless of acceleration.
	 * @param	BrakingDeceleration				deceleration applied when not accelerating, or when exceeding max velocity.
	 */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	void CalcVelocity(UShooterUnrolledCppMovement* Comp, float DeltaTime, float Friction, bool bFluid, float BrakingDeceleration);

	/** @returns location of controlled actor's "feet" meaning center of bottom of collision bounding box */
	FORCEINLINE FVector GetActorFeetLocation(UShooterUnrolledCppMovement* Comp) const { return Comp->UpdatedComponent ? (Comp->UpdatedComponent->GetComponentLocation() - FVector(0,0,Comp->UpdatedComponent->Bounds.BoxExtent.Z)) : FNavigationSystem::InvalidLocation; }

	/** @Return MovementMode string */
	FString GetMovementName(UShooterUnrolledCppMovement* Comp) const;

	/**
	 * Project a location to navmesh to find adjusted height.
	 * @param TestLocation		Location to project
	 * @param NavFloorLocation	Location on navmesh
	 * @return True if projection was performed (successfully or not)
	 */
	bool FindNavFloor(UShooterUnrolledCppMovement* Comp, const FVector& TestLocation, FNavLocation& NavFloorLocation) const;

	/** @return true if component can swim */
	FORCEINLINE bool CanEverSwim(UShooterUnrolledCppMovement* Comp) const { return Comp->NavAgentProps.bCanSwim; }

protected:
	/** Perform movement on an autonomous client */
	void PerformMovement(UShooterUnrolledCppMovement* Comp, float DeltaTime);

	/** @note Movement update functions should only be called through StartNewPhysics()*/
	void PhysWalking(UShooterUnrolledCppMovement* Comp, float deltaTime, int32 Iterations);

	/** @note Movement update functions should only be called through StartNewPhysics()*/
	void PhysNavWalking(UShooterUnrolledCppMovement* Comp, float deltaTime, int32 Iterations);

	/** @note Movement update functions should only be called through StartNewPhysics()*/
	void PhysFlying(UShooterUnrolledCppMovement* Comp, float deltaTime, int32 Iterations);

	/** @note Movement update functions should only be called through StartNewPhysics()*/
	void PhysSwimming(UShooterUnrolledCppMovement* Comp, float deltaTime, int32 Iterations);

	/** @note Movement update functions should only be called through StartNewPhysics()*/
	void PhysCustom(UShooterUnrolledCppMovement* Comp, float deltaTime, int32 Iterations);

	void PhysFalling(UShooterUnrolledCppMovement* Comp, float deltaTime, int32 Iterations);

	/** 
	 * Handle start swimming functionality
	 * @param OldLocation - Location on last tick
	 * @param OldVelocity - velocity at last tick
	 * @param timeTick - time since at OldLocation
	 * @param remainingTime - DeltaTime to complete transition to swimming
	 * @param Iterations - physics iteration count
	 */
	void StartSwimming(UShooterUnrolledCppMovement* Comp, FVector OldLocation, FVector OldVelocity, float timeTick, float remainingTime, int32 Iterations);

	/** Transition from walking to falling */
	void StartFalling(UShooterUnrolledCppMovement* Comp, int32 Iterations, float remainingTime, float timeTick, const FVector& Delta, const FVector& subLoc);

	/**
	 * Sweeps a vertical trace to find the floor for the capsule at the given location. Will attempt to perch if ShouldComputePerchResult() returns true for the downward sweep result.
	 * No floor will be found if collision is disabled on the capsule!
	 *
	 * @param CapsuleLocation:		Location where the capsule sweep should originate
	 * @param OutFloorResult:		[Out] Contains the result of the floor check. The HitResult will contain the valid sweep or line test upon success, or the result of the sweep upon failure.
	 * @param bZeroDelta:			If true, the capsule was not actively moving in this update (can be used to avoid unnecessary floor tests).
	 * @param DownwardSweepResult:	If non-null and it contains valid blocking hit info, this will be used as the result of a downward sweep test instead of doing it as part of the update.
	 */
	void FindFloor(UShooterUnrolledCppMovement* Comp, const FVector& CapsuleLocation, FFindFloorResult& OutFloorResult, bool bZeroDelta, const FHitResult* DownwardSweepResult = nullptr) const;

	/**
	 * Compute distance to the floor from bottom sphere of capsule and store the result in OutFloorResult.
	 * This distance is the swept distance of the capsule to the first point impacted by the lower hemisphere, or distance from the bottom of the capsule in the case of a line trace.
	 * This function does not care if collision is disabled on the capsule (unlike FindFloor).
	 * @see FindFloor
	 *
	 * @param CapsuleLocation:	Location of the capsule used for the query
	 * @param LineDistance:		If non-zero, max distance to test for a simple line check from the capsule base. Used only if the sweep test fails to find a walkable floor, and only returns a valid result if the impact normal is a walkable normal.
	 * @param SweepDistance:	If non-zero, max distance to use when sweeping a capsule downwards for the test. MUST be greater than or equal to the line distance.
	 * @param OutFloorResult:	Result of the floor check. The HitResult will contain the valid sweep or line test upon success, or the result of the sweep upon failure.
	 * @param SweepRadius:		The radius to use for sweep tests. Should be <= capsule radius.
	 * @param DownwardSweepResult:	If non-null and it contains valid blocking hit info, this will be used as the result of a downward sweep test instead of doing it as part of the update.
	 */
	void ComputeFloorDist(UShooterUnrolledCppMovement* Comp, const FVector& CapsuleLocation, float LineDistance, float SweepDistance, FFindFloorResult& OutFloorResult, float SweepRadius, const FHitResult* DownwardSweepResult = NULL) const;

	/**
	 * Sweep against the world and return the first blocking hit.
	 * Intended for tests against the floor, because it may change the result of impacts on the lower area of the test (especially if bUseFlatBaseForFloorChecks is true).
	 *
	 * @param OutHit			First blocking hit found.
	 * @param Start				Start location of the capsule.
	 * @param End				End location of the capsule.
	 * @param TraceChannel		The 'channel' that this trace is in, used to determine which components to hit.
	 * @param CollisionShape	Capsule collision shape.
	 * @param Params			Additional parameters used for the trace.
	 * @param ResponseParam		ResponseContainer to be used for this trace.
	 * @return True if OutHit contains a blocking hit entry.
	 */
	bool FloorSweepTest(
		UShooterUnrolledCppMovement* Comp,
		struct FHitResult& OutHit,
		const FVector& Start,
		const FVector& End,
		ECollisionChannel TraceChannel,
		const struct FCollisionShape& CollisionShape,
		const struct FCollisionQueryParams& Params,
		const struct FCollisionResponseParams& ResponseParam
		) const;

	/** Check if pawn is falling */
	bool CheckFall(UShooterUnrolledCppMovement* Comp, const FFindFloorResult& OldFloor, const FHitResult& Hit, const FVector& Delta, const FVector& OldLocation, float remainingTime, float timeTick, int32 Iterations, bool bMustJump);

	/** 
	 *  Revert to previous position OldLocation, return to being based on OldBase.
	 *  if bFailMove, stop movement and notify controller
	 */	
	void RevertMove(UShooterUnrolledCppMovement* Comp, const FVector& OldLocation, UPrimitiveComponent* OldBase, const FVector& InOldBaseLocation, const FFindFloorResult& OldFloor, bool bFailMove);

	/** Perform rotation over deltaTime */
	void PhysicsRotation(UShooterUnrolledCppMovement* Comp, float DeltaTime);

	/** if true, DesiredRotation will be restricted to only Yaw component in PhysicsRotation() */
	bool ShouldRemainVertical(UShooterUnrolledCppMovement* Comp) const;

	/**
	 * Compute a vector of movement, given a delta and a hit result of the surface we are on.
	 *
	 * @param Delta:				Attempted movement direction
	 * @param RampHit:				Hit result of sweep that found the ramp below the capsule
	 * @param bHitFromLineTrace:	Whether the floor trace came from a line trace
	 *
	 * @return If on a walkable surface, this returns a vector that moves parallel to the surface. The magnitude may be scaled if bMaintainHorizontalGroundVelocity is true.
	 * If a ramp vector can't be computed, this will just return Delta.
	 */
	FVector ComputeGroundMovementDelta(UShooterUnrolledCppMovement* Comp, const FVector& Delta, const FHitResult& RampHit, const bool bHitFromLineTrace) const;

	/**
	 * Move along the floor, using CurrentFloor and ComputeGroundMovementDelta() to get a movement direction.
	 * If a second walkable surface is hit, it will also be moved along using the same approach.
	 *
	 * @param InVelocity:			Velocity of movement
	 * @param DeltaSeconds:			Time over which movement occurs
	 * @param OutStepDownResult:	[Out] If non-null, and a floor check is performed, this will be updated to reflect that result.
	 */
	void MoveAlongFloor(UShooterUnrolledCppMovement* Comp, const FVector& InVelocity, float DeltaSeconds, UCharacterMovementComponent::FStepDownResult* OutStepDownResult = nullptr);

	/** Notification that the character is stuck in geometry.  Only called during walking movement. */
	void OnCharacterStuckInGeometry(UShooterUnrolledCppMovement* Comp, const FHitResult* Hit);

	/**
	 * Adjusts velocity when walking so that Z velocity is zero.
	 * When bMaintainHorizontalGroundVelocity is false, also rescales the velocity vector to maintain the original magnitude, but in the horizontal direction.
	 */
	void MaintainHorizontalGroundVelocity(UShooterUnrolledCppMovement* Comp);

	/** Overridden to enforce max distances based on hit geometry. */
	FVector GetPenetrationAdjustment(UShooterUnrolledCppMovement* Comp, const FHitResult& Hit) const;

	/** Overridden to set bJustTeleported to true, so we don't make incorrect velocity calculations based on adjusted movement. */
	bool ResolvePenetration(UShooterUnrolledCppMovement* Comp, const FVector& Adjustment, const FHitResult& Hit, const FQuat& NewRotation);

	/**
	 * Check if the result of a sweep test (passed in InHit) might be a valid location to perch, in which case we should use ComputePerchResult to validate the location.
	 * @see ComputePerchResult
	 * @param InHit:			Result of the last sweep test before this query.
	 * @param bCheckRadius:		If true, only allow the perch test if the impact point is outside the radius returned by GetValidPerchRadius().
	 * @return Whether perching may be possible, such that ComputePerchResult can return a valid result.
	 */
	bool ShouldComputePerchResult(UShooterUnrolledCppMovement* Comp, const FHitResult& InHit, bool bCheckRadius = true) const;

	/**
	 * Compute the sweep result of the smaller capsule with radius specified by GetValidPerchRadius(),
	 * and return true if the sweep contacts a valid walkable normal within InMaxFloorDist of InHit.ImpactPoint.
	 * This may be used to determine if the capsule can or cannot stay at the current location if perched on the edge of a small ledge or unwalkable surface.
	 * Note: Only returns a valid result if ShouldComputePerchResult returned true for the supplied hit value.
	 *
	 * @param TestRadius:			Radius to use for the sweep, usually GetValidPerchRadius().
	 * @param InHit:				Result of the last sweep test before the query.
	 * @param InMaxFloorDist:		Max distance to floor allowed by perching, from the supplied contact point (InHit.ImpactPoint).
	 * @param OutPerchFloorResult:	Contains the result of the perch floor test.
	 * @return True if the current location is a valid spot at which to perch.
	 */
	bool ComputePerchResult(UShooterUnrolledCppMovement* Comp, const float TestRadius, const FHitResult& InHit, const float InMaxFloorDist, FFindFloorResult& OutPerchFloorResult) const;

	/** Called after MovementMode has changed. Base implementation does special handling for starting certain modes, then notifies the CharacterOwner. */
	void OnMovementModeChanged(UShooterUnrolledCppMovement* Comp, EMovementMode PreviousMovementMode, uint8 PreviousCustomMode);

	/** Adjust distance from floor, trying to maintain a slight offset from the floor when walking (based on CurrentFloor). */
	void AdjustFloorHeight(UShooterUnrolledCppMovement* Comp);

	/** Return PrimitiveComponent we are based on (standing and walking on). */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	UPrimitiveComponent* GetMovementBase(UShooterUnrolledCppMovement* Comp) const;

	/** @return true if we can step up on the actor in the given FHitResult. */
	bool CanStepUp(UShooterUnrolledCppMovement* Comp, const FHitResult& Hit) const;

	/** 
	 * Move up steps or slope. Does nothing and returns false if CanStepUp(Hit) returns false.
	 *
	 * @param GravDir			Gravity vector direction (assumed normalized or zero)
	 * @param Delta				Requested move
	 * @param Hit				[In] The hit before the step up.
	 * @param OutStepDownResult	[Out] If non-null, a floor check will be performed if possible as part of the final step down, and it will be updated to reflect this result.
	 * @return true if the step up was successful.
	 */
	bool StepUp(UShooterUnrolledCppMovement* Comp, const FVector& GravDir, const FVector& Delta, const FHitResult &Hit, struct UCharacterMovementComponent::FStepDownResult* OutStepDownResult = NULL);

	/** Update the base of the character, which is the PrimitiveComponent we are standing on. */
	void SetBase(UShooterUnrolledCppMovement* Comp, UPrimitiveComponent* NewBase, const FName BoneName = NAME_None, bool bNotifyActor=true);

	/**
	 * Update the base of the character, using the given floor result if it is walkable, or null if not. Calls SetBase().
	 */
	void SetBaseFromFloor(UShooterUnrolledCppMovement* Comp, const FFindFloorResult& FloorResult);

	/** Update or defer updating of position based on Base movement */
	void MaybeUpdateBasedMovement(UShooterUnrolledCppMovement* Comp, float DeltaSeconds);

	/** Update position based on Base movement */
	void UpdateBasedMovement(UShooterUnrolledCppMovement* Comp, float DeltaSeconds);

	/** Update controller's view rotation as pawn's base rotates */
	void UpdateBasedRotation(UShooterUnrolledCppMovement* Comp, FRotator& FinalRotation, const FRotator& ReducedRotation);

	/** Call SaveBaseLocation() if not deferring updates (bDeferUpdateBasedMovement is false). */
	void MaybeSaveBaseLocation(UShooterUnrolledCppMovement* Comp);

	/** Update OldBaseLocation and OldBaseQuat if there is a valid movement base, and store the relative location/rotation if necessary. Ignores bDeferUpdateBasedMovement and forces the update. */
	void SaveBaseLocation(UShooterUnrolledCppMovement* Comp);

	/**
	 * Calls MoveUpdatedComponent(), handling initial penetrations by calling ResolvePenetration().
	 * If this adjustment succeeds, the original movement will be attempted again.
	 * @note The 'Teleport' flag is currently always treated as 'None' (not teleporting) when used in an active FScopedMovementUpdate.
	 * @return result of the final MoveUpdatedComponent() call.
	 */
	bool SafeMoveUpdatedComponent(UShooterUnrolledCppMovement* Comp, const /*uniform*/ bool bMoveIgnoreFirstBlockingOverlap, const FVector& Delta, const FQuat& NewRotation,    bool bSweep, FHitResult& OutHit, ETeleportType Teleport = ETeleportType::None);

	bool MoveUpdatedComponent(UShooterUnrolledCppMovement* Comp, const FVector& Delta, const FQuat& NewRotation, bool bSweep, FHitResult* OutHit = NULL, ETeleportType Teleport = ETeleportType::None);

	/** Update ComponentVelocity of UpdatedComponent. This needs to be called by derived classes at the end of an update whenever Velocity has changed.	 */
	void UpdateComponentVelocity(UShooterUnrolledCppMovement* Comp);

	void SetUpdatedComponent(UShooterUnrolledCppMovement* Comp, USceneComponent* NewUpdatedComponent);

	/**
	 * Constrain a direction vector to the plane constraint, if enabled.
	 * @see SetPlaneConstraint
	 */
	UFUNCTION(BlueprintCallable, Category="Components|Movement|Planar")
	FVector ConstrainDirectionToPlane(UShooterUnrolledCppMovement* Comp, FVector Direction) const;

	/** Constrain a position vector to the plane constraint, if enabled. */
	UFUNCTION(BlueprintCallable, Category="Components|Movement|Planar")
	FVector ConstrainLocationToPlane(UShooterUnrolledCppMovement* Comp, FVector Location) const;

	/** Constrain a normal vector (of unit length) to the plane constraint, if enabled. */
	UFUNCTION(BlueprintCallable, Category="Components|Movement|Planar")
	FVector ConstrainNormalToPlane(UShooterUnrolledCppMovement* Comp, FVector Normal) const;

	/** Snap the updated component to the plane constraint, if enabled. */
	UFUNCTION(BlueprintCallable, Category="Components|Movement|Planar")
	void SnapUpdatedComponentToPlane(UShooterUnrolledCppMovement* Comp);

	/** Return true if the given collision shape overlaps other geometry at the given location and rotation. The collision params are set by InitCollisionParams(). */
	bool OverlapTest(UShooterUnrolledCppMovement* Comp, const FVector& Location, const FQuat& RotationQuat, const ECollisionChannel CollisionChannel, const FCollisionShape& CollisionShape, const AActor* IgnoreActor) const;

	/** Restores Velocity to LastPreAdditiveVelocity during Root Motion Phys*() function calls */
	void RestorePreAdditiveRootMotionVelocity(UShooterUnrolledCppMovement* Comp);

	/** Applies root motion from root motion sources to velocity (override and additive) */
	void ApplyRootMotionToVelocity(UShooterUnrolledCppMovement* Comp, float deltaTime);

	/**
	 * Constrain components of root motion velocity that may not be appropriate given the current movement mode (e.g. when falling Z may be ignored).
	 */
	FVector ConstrainAnimRootMotionVelocity(UShooterUnrolledCppMovement* Comp, const FVector& RootMotionVelocity, const FVector& CurrentVelocity) const;

	/** @return true if we have Root Motion from any source to use in PerformMovement() physics. */
	bool HasRootMotionSources(UShooterUnrolledCppMovement* Comp) const;

	/** @return true if we have Root Motion from animation to use in PerformMovement() physics. 
		Not valid outside of the scope of that function. Since RootMotion is extracted and used in it. */
	bool HasAnimRootMotion(UShooterUnrolledCppMovement* Comp) const;

	/** Slows towards stop. */
	void ApplyVelocityBraking(UShooterUnrolledCppMovement* Comp, float DeltaTime, float Friction, float BrakingDeceleration);

	/** Applies momentum accumulated through AddImpulse() and AddForce(), then clears those forces. Does *not* use ClearAccumulatedForces() since that would clear pending launch velocity as well. */
	void ApplyAccumulatedForces(UShooterUnrolledCppMovement* Comp, float DeltaSeconds);

	/** Clears forces accumulated through AddImpulse() and AddForce(), and also pending launch velocity. */
	UFUNCTION(BlueprintCallable, Category="Pawn|Components|CharacterMovement")
	void ClearAccumulatedForces(UShooterUnrolledCppMovement* Comp);

	/** Update the character state in PerformMovement right before doing the actual position change */
	void UpdateCharacterStateBeforeMovement(UShooterUnrolledCppMovement* Comp);

	/** Update the character state in PerformMovement after the position change. Some rotation updates happen after this. */
	void UpdateCharacterStateAfterMovement(UShooterUnrolledCppMovement* Comp);

	/**
	 * Get the lateral acceleration to use during falling movement. The Z component of the result is ignored.
	 * Default implementation returns current Acceleration value modified by GetAirControl(), with Z component removed,
	 * with magnitude clamped to GetMaxAcceleration().
	 * This function is used internally by PhysFalling().
	 *
	 * @param DeltaTime Time step for the current update.
	 * @return Acceleration to use during falling movement.
	 */
	FVector GetFallingLateralAcceleration(UShooterUnrolledCppMovement* Comp, float DeltaTime);

	/**
	 * Get the air control to use during falling movement.
	 * Given an initial air control (TickAirControl), applies the result of BoostAirControl().
	 * This function is used internally by GetFallingLateralAcceleration().
	 *
	 * @param DeltaTime			Time step for the current update.
	 * @param TickAirControl	Current air control value.
	 * @param FallAcceleration	Acceleration used during movement.
	 * @return Air control to use during falling movement.
	 * @see AirControl, BoostAirControl(), LimitAirControl(), GetFallingLateralAcceleration()
	 */
	FVector GetAirControl(UShooterUnrolledCppMovement* Comp, float DeltaTime, float TickAirControl, const FVector& FallAcceleration);

	/**
	 * Compute remaining time step given remaining time and current iterations.
	 * The last iteration (limited by MaxSimulationIterations) always returns the remaining time, which may violate MaxSimulationTimeStep.
	 *
	 * @param RemainingTime		Remaining time in the tick.
	 * @param Iterations		Current iteration of the tick (starting at 1).
	 * @return The remaining time step to use for the next sub-step of iteration.
	 * @see MaxSimulationTimeStep, MaxSimulationIterations
	 */
	float GetSimulationTimeStep(UShooterUnrolledCppMovement* Comp, float RemainingTime, int32 Iterations) const;

	/** Called if bNotifyApex is true and character has just passed the apex of its jump. */
	void NotifyJumpApex(UShooterUnrolledCppMovement* Comp);

	/**
	 * Compute new falling velocity from given velocity and gravity. Applies the limits of the current Physics Volume's TerminalVelocity.
	 */
	FVector NewFallVelocity(UShooterUnrolledCppMovement* Comp, const FVector& InitialVelocity, const FVector& Gravity, float DeltaTime) const;

	/** Verify that the supplied hit result is a valid landing spot when falling. */
	bool IsValidLandingSpot(UShooterUnrolledCppMovement* Comp, const FVector& CapsuleLocation, const FHitResult& Hit) const;

	/**
	 * Determine whether we should try to find a valid landing spot after an impact with an invalid one (based on the Hit result).
	 * For example, landing on the lower portion of the capsule on the edge of geometry may be a walkable surface, but could have reported an unwalkable impact normal.
	 */
	bool ShouldCheckForValidLandingSpot(UShooterUnrolledCppMovement* Comp, float DeltaTime, const FVector& Delta, const FHitResult& Hit) const;

	/** Handle landing against Hit surface over remaingTime and iterations, calling SetPostLandedPhysics() and starting the new movement mode. */
	void ProcessLanded(UShooterUnrolledCppMovement* Comp, const FHitResult& Hit, float remainingTime, int32 Iterations);

	/** Use new physics after landing. Defaults to swimming if in water, walking otherwise. */
	void SetPostLandedPhysics(UShooterUnrolledCppMovement* Comp, const FHitResult& Hit);

	/** Handle a blocking impact. Calls ApplyImpactPhysicsForces for the hit, if bEnablePhysicsInteraction is true. */
	void HandleImpact(UShooterUnrolledCppMovement* Comp, const FHitResult& Hit, float TimeSlice=0.f, const FVector& MoveDelta = FVector::ZeroVector);

	/**
	 * Apply physics forces to the impacted component, if bEnablePhysicsInteraction is true.
	 * @param Impact				HitResult that resulted in the impact
	 * @param ImpactAcceleration	Acceleration of the character at the time of impact
	 * @param ImpactVelocity		Velocity of the character at the time of impact
	 */
	void ApplyImpactPhysicsForces(UShooterUnrolledCppMovement* Comp, const FHitResult& Impact, const FVector& ImpactAcceleration, const FVector& ImpactVelocity);

	/** Custom version of SlideAlongSurface that handles different movement modes separately; namely during walking physics we might not want to slide up slopes. */
	float SlideAlongSurface(UShooterUnrolledCppMovement* Comp, const FVector& Delta, float Time, const FVector& Normal, FHitResult& Hit, bool bHandleImpact);

	/** Custom version that allows upwards slides when walking if the surface is walkable. */
	void TwoWallAdjust(UShooterUnrolledCppMovement* Comp, FVector& Delta, const FHitResult& Hit, const FVector& OldHitNormal) const;

	/**
	 * Calculate slide vector along a surface.
	 * Has special treatment when falling, to avoid boosting up slopes (calling HandleSlopeBoosting() in this case).
	 *
	 * @param Delta:	Attempted move.
	 * @param Time:		Amount of move to apply (between 0 and 1).
	 * @param Normal:	Normal opposed to movement. Not necessarily equal to Hit.Normal (but usually is).
	 * @param Hit:		HitResult of the move that resulted in the slide.
	 * @return			New deflected vector of movement.
	 */
	FVector ComputeSlideVector(UShooterUnrolledCppMovement* Comp, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit) const;
	/** ISPC: Transposed implementation of MovementComponent::ComputeSlideVector(). */
	FVector Super_ComputeSlideVector(UShooterUnrolledCppMovement* Comp, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit) const;

	/** 
	 * Limit the slide vector when falling if the resulting slide might boost the character faster upwards.
	 * @param SlideResult:	Vector of movement for the slide (usually the result of ComputeSlideVector)
	 * @param Delta:		Original attempted move
	 * @param Time:			Amount of move to apply (between 0 and 1).
	 * @param Normal:		Normal opposed to movement. Not necessarily equal to Hit.Normal (but usually is).
	 * @param Hit:			HitResult of the move that resulted in the slide.
	 * @return:				New slide result.
	 */
	FVector HandleSlopeBoosting(UShooterUnrolledCppMovement* Comp, const FVector& SlideResult, const FVector& Delta, const float Time, const FVector& Normal, const FHitResult& Hit) const;

	/**
	 * Limits the air control to use during falling movement, given an impact while falling.
	 * This function is used internally by PhysFalling().
	 *
	 * @param DeltaTime			Time step for the current update.
	 * @param FallAcceleration	Acceleration used during movement.
	 * @param HitResult			Result of impact.
	 * @param bCheckForValidLandingSpot If true, will use IsValidLandingSpot() to determine if HitResult is a walkable surface. If false, this check is skipped.
	 * @return Modified air control acceleration to use during falling movement.
	 * @see PhysFalling()
	 */
	FVector LimitAirControl(UShooterUnrolledCppMovement* Comp, float DeltaTime, const FVector& FallAcceleration, const FHitResult& HitResult, bool bCheckForValidLandingSpot);

	/** @return how far to rotate character during the time interval DeltaTime. */
	FRotator GetDeltaRotation(UShooterUnrolledCppMovement* Comp, float DeltaTime) const;

	/**
	  * Compute a target rotation based on current movement. Used by PhysicsRotation() when bOrientRotationToMovement is true.
	  * Default implementation targets a rotation based on Acceleration.
	  *
	  * @param CurrentRotation	- Current rotation of the Character
	  * @param DeltaTime		- Time slice for this movement
	  * @param DeltaRotation	- Proposed rotation change based simply on DeltaTime * RotationRate
	  *
	  * @return The target rotation given current movement.
	  */
	FRotator ComputeOrientToMovementRotation(UShooterUnrolledCppMovement* Comp, const FRotator& CurrentRotation, float DeltaTime, FRotator& DeltaRotation) const;

	/**
	 * Use velocity requested by path following to compute a requested acceleration and speed.
	 * This does not affect the Acceleration member variable, as that is used to indicate input acceleration.
	 * This may directly affect current Velocity.
	 *
	 * @param DeltaTime				Time slice for this operation
	 * @param MaxAccel				Max acceleration allowed in OutAcceleration result.
	 * @param MaxSpeed				Max speed allowed when computing OutRequestedSpeed.
	 * @param Friction				Current friction.
	 * @param BrakingDeceleration	Current braking deceleration.
	 * @param OutAcceleration		Acceleration computed based on requested velocity.
	 * @param OutRequestedSpeed		Speed of resulting velocity request, which can affect the max speed allowed by movement.
	 * @return Whether there is a requested velocity and acceleration, resulting in valid OutAcceleration and OutRequestedSpeed values.
	 */
	bool ApplyRequestedMove(UShooterUnrolledCppMovement* Comp, float DeltaTime, float MaxAccel, float MaxSpeed, float Friction, float BrakingDeceleration, FVector& OutAcceleration, float& OutRequestedSpeed);

	/** Handle a pending launch during an update. Returns true if the launch was triggered. */
	bool HandlePendingLaunch(UShooterUnrolledCppMovement* Comp);

	/** Internal function to call OnMovementUpdated delegate on CharacterOwner. */
	void CallMovementUpdateDelegate(UShooterUnrolledCppMovement* Comp, float DeltaSeconds, const FVector& OldLocation, const FVector& OldVelocity);

protected:
	UPROPERTY()
	TArray<UShooterUnrolledCppMovement*> Components;
};
