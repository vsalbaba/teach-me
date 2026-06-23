# Experiment 2: Runtime Enhancement Baseline

**Result: PASS**

## What was tested

Deployed the same Employee entity application as experiment 1, but WITHOUT
build-time bytecode enhancement. The persistence.xml sets
`jboss.as.jpa.classtransformer=true` so the EAP runtime enhancer activates
during deployment.

## What happened

1. Entity class was verified as plain (no enhancement markers) before deployment
2. Deployment succeeded
3. Server logs confirm runtime enhancement activity:
   - `added entity class transformer 'WildFlyClassTransformer' for 'test-runtime.war#testPU'`
   - `rewrite entity class 'com/test/entity/Employee' using transformer`
   - `Enhancing [com.test.entity.Employee] as Entity`
   - `Weaving in PersistentAttributeInterceptable implementation`
4. Servlet returned HTTP 200 with all checks passing:
   - `RUNTIME_ENHANCED=true` (ManagedTypeHelper confirms enhancement)
   - `LAZY_LOADING_CAPABLE=true` (PersistentAttributeInterceptable implemented)
   - `SELF_DIRTINESS_TRACKER=true` (dirty tracking support added)
   - `PERSISTENCE_OK=true` (entity create/read works)

## Notable observation

The runtime enhancer also adds the `@EnhancementInfo` annotation with
`version=6.6.51.Final-redhat-00001`. This was unexpected -- it means
`@EnhancementInfo` is not exclusive to build-time enhancement. Both build-time
(experiment 1) and runtime enhancement paths add this annotation with the
Hibernate ORM version used for enhancement.

This is relevant for experiment 3 (version mismatch) -- the version mismatch
detection may compare the `@EnhancementInfo` version against the runtime ORM
version, but since runtime enhancement always uses the same ORM version as
runtime, a mismatch can only occur with build-time enhancement.
