# Manual Test Experiments: EAP7-1648 -- Build-time Hibernate Entity Enhancement

## Experiment 1: Happy Path
Build an application with `hibernate-enhance-maven-plugin`, deploy to EAP 8.2,
and confirm that build-time bytecode enhancement is active. Verify lazy loading
works correctly. Check whether trace message HHH90009001 ("Skipping enhancement
-- already annotated with @EnhancementInfo") is emitted in the server log.

Note: HHH90009001 is not emitted in ORM 6.6.x -- expected in ORM 7.x+.

## Experiment 2: Runtime Enhancement Baseline
Deploy the same application WITHOUT build-time enhancement to EAP 8.2. Confirm
the runtime enhancer activates instead. This establishes the baseline behavior
that build-time enhancement is meant to replace.

## Experiment 3: Version Mismatch
Build-time enhance an application with a DIFFERENT Hibernate ORM version than
the one shipped in EAP. Deploy to EAP and verify the deployment fails with a
clear version mismatch error message:
"Mismatch between Hibernate version used for bytecode enhancement (%s) and runtime (%s)"

## Experiment 4: Ant Enhancement
Enhance compiled classes using Hibernate's Ant `EnhancementTask` instead of
the Maven plugin. Deploy the enhanced application to EAP 8.2 and confirm
enhancement is active and the application works correctly.

## Experiment 5: Version Mismatch Detection (Integration)
Build-time enhance an application with a different Hibernate ORM version than
the one in EAP. Verify deployment fails with a clear version mismatch error.

## Experiment 6: Enhancement Options (Integration)
Test with supported configuration: `enableLazyInitialization=true`,
`enableDirtyTracking=true`. Verify unsupported options
(`enableAssociationManagement`, `enableExtendedEnhancement`) are not enabled
or produce expected behavior when set.
